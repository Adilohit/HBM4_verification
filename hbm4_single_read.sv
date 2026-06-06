module hbm4_single_read #(
    parameter RL   = 6,       // Read Latency (CK cycles from READ cmd to first data)
    parameter BL   = 8,       // Burst Length
    parameter tRCD = 7,       // ACT-to-READ delay
    parameter tRTP = 4,       // Read-to-Precharge delay (from READ cmd)
    parameter tRP  = 7,       // Precharge period
    parameter DQ_W = 32       // DQ bus width (per pseudo channel)
)(
    input  wire clk,
    input  wire clk_2x,       // 2x base clock — drives RDQS and DQ
    input  wire rst_n,
    input  wire start,

    input  wire [3:0] row_addr,
    input  wire [3:0] col_addr,

    // Pre-loaded read data (memory model supplies these)
    input  wire [DQ_W-1:0] rd_d0, rd_d1, rd_d2, rd_d3,
    input  wire [DQ_W-1:0] rd_d4, rd_d5, rd_d6, rd_d7,

    output wire CK_t,
    output wire CK_c,

    // Row command bus (sequential: rise on posedge CK, fall on negedge CK)
    output reg  [3:0] R_rise,
    output reg  [3:0] R_fall,

    // Column command bus (sequential: rise on posedge CK, fall on negedge CK)
    output reg  [3:0] C_rise,
    output reg  [3:0] C_fall,

    // Read Data Strobe — 2x CK frequency, gated during data window
    output wire RDQS_t,
    output wire RDQS_c,

    // Write strobes idle during read
    output wire WDQS_t,
    output wire WDQS_c,

    // Data bus
    output wire [DQ_W-1:0] DQ,

    // Read data capture outputs (active after burst completes)
    output reg  rd_valid,

    output wire done
);

    assign CK_t  = clk;
    assign CK_c  = ~clk;

    // WDQS idle during read
    assign WDQS_t = 1'b0;
    assign WDQS_c = 1'b1;

    //=========================================================
    // FSM states
    //=========================================================
    localparam S_IDLE = 0,
               S_ACT  = 1,
               S_READ = 2,
               S_PRE  = 3,
               S_DONE = 4;

    reg [2:0] state, nxt;
    reg [5:0] cyc;

    assign done = (state == S_DONE);

    //=========================================================
    // Address & data storage
    //=========================================================
    reg [3:0] ra, ca;
    reg [DQ_W-1:0] d [0:7];

    //=========================================================
    // BL8 with DDR on 2x-RDQS → 4 beats per CK → 2 CK cycles
    //=========================================================
    localparam DATA_CK = BL / 4;   // = 2

    // Minimum READ-state duration: must wait RL + DATA_CK for data,
    // and also satisfy tRTP from the READ command before PRE.
    localparam READ_DUR = (RL + DATA_CK > tRTP) ? (RL + DATA_CK) : tRTP;

    //=========================================================
    // Enable windows (combinational, CK-domain)
    //
    //   rdqs_en  : 1 CK preamble + data window
    //   dq_window: data-only window (no preamble)
    //
    // Per Figure 36: RDQS starts toggling 1 CK before first data,
    // data appears at cyc == RL after the READ command.
    //=========================================================
    wire rdqs_en   = (state == S_READ) &&
                     (cyc >= (RL - 1)) &&
                     (cyc <  (RL + DATA_CK));

    wire dq_window = (state == S_READ) &&
                     (cyc >= RL)       &&
                     (cyc <  (RL + DATA_CK));

    //=========================================================
    // RDQS — gated clk_2x  (2 full RDQS cycles per CK cycle)
    //=========================================================
    assign RDQS_t = rdqs_en ? clk_2x : 1'b0;
    assign RDQS_c = ~RDQS_t;

    //=========================================================
    // DQ — DDR output on clk_2x
    //
    // Same mechanism as write module: posedge clk_2x loads
    // {dq_pos, dq_neg} pairs, clk_2x muxes onto bus.
    // 4 pairs (8 beats) across 4 posedge-clk_2x events = 2 CK.
    //=========================================================
    reg [DQ_W-1:0] dq_pos, dq_neg;
    reg             dq_active;
    reg [2:0]       pair_cnt;

    assign DQ = dq_active ? (clk_2x ? dq_pos : dq_neg)
                          : {DQ_W{1'b0}};

    always @(posedge clk_2x or negedge rst_n) begin
        if (!rst_n) begin
            dq_pos    <= {DQ_W{1'b0}};
            dq_neg    <= {DQ_W{1'b0}};
            dq_active <= 1'b0;
            pair_cnt  <= 3'd0;
        end
        else if (dq_window && !dq_active) begin
            // First pair: d[0] on RDQS posedge, d[1] on RDQS negedge
            dq_active <= 1'b1;
            pair_cnt  <= 3'd0;
            dq_pos    <= d[0];
            dq_neg    <= d[1];
        end
        else if (dq_active) begin
            pair_cnt <= pair_cnt + 1;
            case (pair_cnt)
                3'd0: begin dq_pos <= d[2]; dq_neg <= d[3]; end
                3'd1: begin dq_pos <= d[4]; dq_neg <= d[5]; end
                3'd2: begin dq_pos <= d[6]; dq_neg <= d[7]; end
                3'd3: begin
                    // Burst complete — de-assert DQ
                    dq_pos    <= {DQ_W{1'b0}};
                    dq_neg    <= {DQ_W{1'b0}};
                    dq_active <= 1'b0;
                    pair_cnt  <= 3'd0;
                end
                default: begin
                    dq_active <= 1'b0;
                    pair_cnt  <= 3'd0;
                end
            endcase
        end
    end

    //=========================================================
    // rd_valid — pulses for 1 CK after burst completes
    //=========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_valid <= 1'b0;
        else
            rd_valid <= (state == S_READ) && (cyc == RL + DATA_CK);
    end

    //=========================================================
    // Input latch  (posedge clk)
    //=========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ra <= 4'd0;
            ca <= 4'd0;
        end
        else if (start && state == S_IDLE) begin
            ra <= row_addr;
            ca <= col_addr;

            d[0] <= rd_d0;  d[1] <= rd_d1;
            d[2] <= rd_d2;  d[3] <= rd_d3;
            d[4] <= rd_d4;  d[5] <= rd_d5;
            d[6] <= rd_d6;  d[7] <= rd_d7;
        end
    end

    //=========================================================
    // State register + cycle counter  (posedge clk)
    //=========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cyc   <= 6'd0;
        end else begin
            state <= nxt;
            cyc   <= (nxt != state) ? 6'd0 : cyc + 1;
        end
    end

    //=========================================================
    // Next-state logic
    //=========================================================
    always @(*) begin
        case (state)
            S_IDLE: nxt = start          ? S_ACT  : S_IDLE;
            S_ACT:  nxt = (cyc == tRCD)  ? S_READ : S_ACT;
            S_READ: nxt = (cyc == READ_DUR) ? S_PRE : S_READ;
            S_PRE:  nxt = (cyc == tRP)   ? S_DONE : S_PRE;
            S_DONE: nxt = S_IDLE;
            default: nxt = S_IDLE;
        endcase
    end

    //=========================================================
    // Falling-edge trigger flags  (posedge clk)
    //=========================================================
    reg r_fall_act;
    reg c_fall_rd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_fall_act <= 1'b0;
            c_fall_rd  <= 1'b0;
        end else begin
            r_fall_act <= (state == S_ACT  && cyc == 0);
            c_fall_rd  <= (state == S_READ && cyc == 0);
        end
    end

    //=========================================================
    // Rising-edge commands  (posedge clk → CK_t rising edge)
    //=========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_rise <= 4'h0;
            C_rise <= 4'h0;
        end else begin
            R_rise <= 4'h0;
            C_rise <= 4'h0;

            case (state)
                // ---- ACT: 1.5 CK row command ----
                S_ACT: begin
                    if (cyc == 0)      R_rise <= 4'bx110;           // ACT opcode
                    else if (cyc == 1) R_rise <= {ra[1:0], 2'b11};  // RA[1:0]
                end

                // ---- READ command ----
                S_READ: begin
                    if (cyc == 0)      C_rise <= 4'b0101;           // READ opcode
                end

                // ---- PRECHARGE ----
                S_PRE: begin
                    if (cyc == 0)      R_rise <= 4'bx001;           // PRE opcode
                end
            endcase
        end
    end

    //=========================================================
    // Falling-edge commands  (negedge clk → CK_t falling edge)
    //=========================================================
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_fall <= 4'h0;
            C_fall <= 4'h0;
        end else begin
            R_fall <= 4'h0;
            C_fall <= 4'h0;

            if (r_fall_act) R_fall <= {ra[3:2], 2'b11};   // RA[3:2]
            if (c_fall_rd)  C_fall <= ca;                   // Column address
        end
    end

endmodule