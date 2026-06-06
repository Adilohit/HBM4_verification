// =============================================================================
//  hbm4_bank_model_tb.sv  —  Testbench: WRITE then READ same row/col
//
//  CRITICAL: clk_2x uses real division (#2.5, not #(5/2)=2) for correct 2x freq.
//  Both clocks start at 0, first posedge at half-period → phase-aligned.
// =============================================================================
`timescale 1ns/1ps

module hbm4_bank_model_tb;

    parameter DQ_W        = 32;
    parameter CK_PERIOD   = 10;
    parameter CK2X_PERIOD = 5;
    parameter WL   = 4;
    parameter RL   = 6;
    parameter BL   = 8;
    parameter tRCD = 7;
    parameter tWTR = 4;
    parameter tWR  = 6;
    parameter tRTP = 4;
    parameter tRP  = 7;

    // ---- DUT signals ----
    reg  clk, clk_2x, rst_n, start, op;
    reg  [3:0]  row_addr, col_addr;
    reg  [DQ_W-1:0] wr_d0,wr_d1,wr_d2,wr_d3,wr_d4,wr_d5,wr_d6,wr_d7;
    wire        CK_t, CK_c;
    wire [3:0]  R_rise, R_fall, C_rise, C_fall;
    wire        WDQS_t, WDQS_c, RDQS_t, RDQS_c;
    wire [DQ_W-1:0] DQ;
    wire        rd_valid, done;

    // ---- Clocks ----
    // CRITICAL: clk_2x starts HIGH so its posedges at 5,10,15,20...
    // align with clk posedges at 5,15,25... (every other clk_2x posedge)
    initial clk    = 0;  always #(CK_PERIOD/2)     clk    = ~clk;      // 100 MHz
    initial clk_2x = 1;  always #(CK2X_PERIOD/2.0) clk_2x = ~clk_2x;  // 200 MHz, phase-aligned

    // ---- DUT ----
    hbm4_bank_model #(
        .WL(WL),.RL(RL),.BL(BL),
        .tRCD(tRCD),.tWTR(tWTR),.tWR(tWR),.tRTP(tRTP),.tRP(tRP),
        .DQ_W(DQ_W),.MEM_DEPTH(16)
    ) dut (
        .clk(clk),.clk_2x(clk_2x),.rst_n(rst_n),
        .start(start),.op(op),
        .row_addr(row_addr),.col_addr(col_addr),
        .wr_d0(wr_d0),.wr_d1(wr_d1),.wr_d2(wr_d2),.wr_d3(wr_d3),
        .wr_d4(wr_d4),.wr_d5(wr_d5),.wr_d6(wr_d6),.wr_d7(wr_d7),
        .CK_t(CK_t),.CK_c(CK_c),
        .R_rise(R_rise),.R_fall(R_fall),
        .C_rise(C_rise),.C_fall(C_fall),
        .WDQS_t(WDQS_t),.WDQS_c(WDQS_c),
        .RDQS_t(RDQS_t),.RDQS_c(RDQS_c),
        .DQ(DQ),.rd_valid(rd_valid),.done(done)
    );

    // =========================================================================
    // Timing reference: track column command time
    // =========================================================================
    integer col_cmd_time;
    initial col_cmd_time = 0;
    always @(posedge CK_t)
        if (C_rise == 4'b0001 || C_rise == 4'b0101)
            col_cmd_time = $time;

    // =========================================================================
    // Command bus monitor
    // =========================================================================
    always @(posedge CK_t) begin
        if (R_rise !== 4'h0 && ^R_rise !== 1'bx)
            $display("[%0t]  CK_t ↑  R_rise=%b  (row cmd)", $time, R_rise);
        if (C_rise == 4'b0001)
            $display("[%0t]  CK_t ↑  C_rise=%b  (WRITE opcode)  ← T0", $time, C_rise);
        if (C_rise == 4'b0101)
            $display("[%0t]  CK_t ↑  C_rise=%b  (READ opcode)   ← T0", $time, C_rise);
    end
    always @(negedge CK_t) begin
        if (R_fall !== 4'h0 && ^R_fall !== 1'bx)
            $display("[%0t]  CK_t ↓  R_fall=%b  (RA[3:2])", $time, R_fall);
        if (C_fall !== 4'h0)
            $display("[%0t]  CK_t ↓  C_fall=%b  (col addr)", $time, C_fall);
    end

    // =========================================================================
    // WDQS monitor — count posedges and show CK offset from col cmd
    // =========================================================================
    integer wdqs_pos_cnt;
    initial wdqs_pos_cnt = 0;
    always @(posedge WDQS_t) begin
        if (WDQS_t !== 1'bx) begin
            #1;  // settle after NBA
            wdqs_pos_cnt = wdqs_pos_cnt + 1;
            $display("[%0t]  WDQS posedge #%0d  DQ=0x%08h  (T0+%.1f CK)",
                     $time, wdqs_pos_cnt, DQ,
                     ($time - col_cmd_time) / real'(CK_PERIOD));
        end
    end
    always @(negedge WDQS_t) begin
        if (WDQS_t !== 1'bx && wdqs_pos_cnt > 0) begin
            #1;
            $display("[%0t]  WDQS negedge     DQ=0x%08h", $time, DQ);
        end
    end

    // =========================================================================
    // RDQS capture
    // =========================================================================
    reg [DQ_W-1:0] cap [0:7];
    integer rpos, rneg;
    initial begin : cap_init
        integer i;
        rpos = 0; rneg = 0;
        for (i=0; i<8; i=i+1) cap[i] = {DQ_W{1'bx}};
    end

    integer rdqs_pos_cnt;
    initial rdqs_pos_cnt = 0;

    // RDQS posedge: even beats (0,2,4,6). Skip 2 preamble posedges.
    always @(posedge RDQS_t) begin
        if (RDQS_t !== 1'bx) begin
            #1;  // settle after NBA
            rdqs_pos_cnt = rdqs_pos_cnt + 1;
            rpos = rpos + 1;
            if (rpos >= 3 && rpos <= 6)
                cap[(rpos-3)*2] = DQ;
        end
    end
    // RDQS negedge: odd beats (1,3,5,7). Skip 2 preamble negedges.
    always @(negedge RDQS_t) begin
        if (RDQS_t !== 1'bx) begin
            #1;  // settle after NBA
            rneg = rneg + 1;
            if (rneg >= 3 && rneg <= 6)
                cap[(rneg-3)*2+1] = DQ;
        end
    end

    // =========================================================================
    // Stimulus
    // =========================================================================
    reg [DQ_W-1:0] exp [0:7];
    integer fail_cnt, b;

    task do_transaction(input op_in);
        begin
            @(posedge clk); #1;
            start = 1; op = op_in;
            @(posedge clk); #1;
            start = 0;
        end
    endtask

    initial begin
        $dumpfile("hbm4_bank.vcd");
        $dumpvars(0, hbm4_bank_model_tb);

        rst_n    = 0; start = 0; op = 0;
        row_addr = 4'hA; col_addr = 4'h5;
        fail_cnt = 0;

        wr_d0=32'hD0D0_0000; exp[0]=wr_d0;
        wr_d1=32'hD1D1_1111; exp[1]=wr_d1;
        wr_d2=32'hD2D2_2222; exp[2]=wr_d2;
        wr_d3=32'hD3D3_3333; exp[3]=wr_d3;
        wr_d4=32'hD4D4_4444; exp[4]=wr_d4;
        wr_d5=32'hD5D5_5555; exp[5]=wr_d5;
        wr_d6=32'hD6D6_6666; exp[6]=wr_d6;
        wr_d7=32'hD7D7_7777; exp[7]=wr_d7;

        repeat(3) @(posedge clk); rst_n=1; repeat(2) @(posedge clk);

        // ---- WRITE ----
        $display("\n============================================================");
        $display("  WRITE  row=0x%0h  col=0x%0h  (WL=%0d, BL=%0d)",
                 row_addr, col_addr, WL, BL);
        $display("  Expected JEDEC timing from col cmd (T0):");
        $display("    WDQS preamble : T0 + %0d CK", WL-1);
        $display("    Data start    : T0 + %0d CK", WL);
        $display("    Data end      : T0 + %0d CK", WL + BL/4);
        $display("    WDQS postamble: T0 + %0d CK", WL + BL/4 + 1);
        $display("============================================================\n");

        wdqs_pos_cnt = 0;
        do_transaction(1'b0);
        wait(done); @(posedge clk);

        $display("\n  WDQS posedges total: %0d  (expect %0d: preamble=2 + data=4 + postamble=2)",
                 wdqs_pos_cnt, 8);
        $display("  WRITE done.\n");

        repeat(tWTR) @(posedge clk);

        // ---- READ ----
        $display("============================================================");
        $display("  READ   row=0x%0h  col=0x%0h  (RL=%0d, BL=%0d)",
                 row_addr, col_addr, RL, BL);
        $display("  Expected JEDEC timing from col cmd (T0):");
        $display("    RDQS preamble : T0 + %0d CK", RL-1);
        $display("    Data start    : T0 + %0d CK", RL);
        $display("    Data end      : T0 + %0d CK", RL + BL/4);
        $display("    RDQS postamble: T0 + %0d CK", RL + BL/4 + 1);
        $display("============================================================\n");

        rpos=0; rneg=0; rdqs_pos_cnt=0;
        begin : cap_reset
            integer j;
            for (j=0;j<8;j=j+1) cap[j]={DQ_W{1'bx}};
        end

        do_transaction(1'b1);
        wait(done); @(posedge clk);
        #(CK2X_PERIOD*3);

        // ---- Compare ----
        $display("\n--- Write/Read Round-trip Comparison ---");
        for (b=0; b<8; b=b+1) begin
            if (cap[b] === exp[b])
                $display("  Beat[%0d]  EXP=0x%08h  CAP=0x%08h  PASS", b, exp[b], cap[b]);
            else begin
                $display("  Beat[%0d]  EXP=0x%08h  CAP=0x%08h  FAIL <<<", b, exp[b], cap[b]);
                fail_cnt = fail_cnt + 1;
            end
        end

        $display("\n============================================================");
        if (fail_cnt==0)
            $display("  RESULT:  ALL 8 BEATS PASSED");
        else
            $display("  RESULT:  %0d BEAT(S) FAILED", fail_cnt);
        $display("============================================================\n");

        #(CK_PERIOD*3);
        if (DQ !== {DQ_W{1'b0}})
            $display("WARN: DQ not idle after transaction (DQ=0x%08h)", DQ);
        else
            $display("INFO: DQ bus idle after transaction.");

        #(CK_PERIOD*5); $finish;
    end

    initial begin #(CK_PERIOD*600); $display("TIMEOUT"); $finish; end
endmodule

