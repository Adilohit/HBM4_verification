// =============================================================================
//  hbm4_bank_model.sv  —  Unified HBM4 Write / Read Controller (small-scale)
//
//  FSM flow:
//    IDLE → S_ACT_CMD (2 CK) → S_tRCD (tRCD CK) → S_COL_CMD (1 CK)
//         → S_DATA → S_PRE → S_DONE → IDLE
//
//  TIMING NOTE:
//    S_COL_CMD occupies 1 CK (the column command appears on the bus here).
//    S_DATA cyc=0 starts 1 CK AFTER the column command is on the bus.
//    Therefore all latency windows inside S_DATA use (WL-1) / (RL-1)
//    so the external bus-level timing matches JEDEC:
//
//      Col cmd on bus → first data beat  = WL (or RL) CK exactly
//      Col cmd on bus → WDQS preamble    = WL-1 (or RL-1) CK
//      WDQS postamble ends               = 1 CK after last data beat
// =============================================================================

`timescale 1ns/1ps

module hbm4_bank_model #(
    parameter WL        = 4,
    parameter RL        = 6,
    parameter BL        = 8,
    parameter tRCD      = 7,
    parameter tWTR      = 4,
    parameter tWR       = 6,
    parameter tRTP      = 4,
    parameter tRP       = 7,
    parameter MEM_DEPTH = 16,
    parameter DQ_W      = 32
)(
    input  wire clk,
    input  wire clk_2x,
    input  wire rst_n,

    input  wire       start,
    input  wire       op,       // 0 = WRITE, 1 = READ
    input  wire [3:0] row_addr,
    input  wire [3:0] col_addr,

    input  wire [DQ_W-1:0] wr_d0, wr_d1, wr_d2, wr_d3,
    input  wire [DQ_W-1:0] wr_d4, wr_d5, wr_d6, wr_d7,

    output wire       CK_t, CK_c,
    output reg  [3:0] R_rise, R_fall,
    output reg  [3:0] C_rise, C_fall,

    output wire       WDQS_t, WDQS_c,
    output wire       RDQS_t, RDQS_c,

    output wire [DQ_W-1:0] DQ,

    output wire       done,
    output reg        rd_valid,
    output reg [DQ_W-1:0] rd_data [0:7]
);

    assign CK_t = clk;
    assign CK_c = ~clk;

    // =========================================================================
    // Derived constants
    // =========================================================================
    localparam DATA_CK = BL / 4;   // CK cycles for one full DDR burst = 2

    // Internal note: S_COL_CMD sets C_rise via NBA at the SAME posedge
    // that transitions state to S_DATA with cyc=0.  However, C_rise
    // (the opcode on the bus) is only visible to external observers
    // 1 CK later (standard NBA behavior).  Therefore from the bus
    // perspective (JEDEC T0), S_DATA cyc=0 starts 1 CK BEFORE T0.
    //
    //   cyc=0 : FSM transition (C_rise NBA fires, not yet visible)
    //   cyc=1 : Bus T0 (column command visible on the bus)
    //   cyc=WL   : Bus T0 + WL-1 → WDQS preamble start
    //   cyc=WL+1 : Bus T0 + WL   → first data beat
    //   cyc=WL+1+DATA_CK-1 : last data beat
    //   cyc=WL+1+DATA_CK : postamble (WDQS still toggling, no data)
    //   cyc=WL+1+DATA_CK+1 : WDQS stops

    // =========================================================================
    // FSM
    // =========================================================================
    localparam S_IDLE    = 3'd0,
               S_ACT_CMD = 3'd1,
               S_tRCD    = 3'd2,
               S_COL_CMD = 3'd3,
               S_DATA    = 3'd4,
               S_PRE     = 3'd5,
               S_DONE    = 3'd6;

    reg [2:0] state, nxt;
    reg [6:0] cyc;

    assign done = (state == S_DONE);

    // =========================================================================
    // Latched parameters
    // =========================================================================
    reg        op_r;
    reg [3:0]  ra, ca;
    reg [DQ_W-1:0] wd [0:7];

    // =========================================================================
    // Internal memory
    // =========================================================================
    reg [DQ_W-1:0] mem [0:MEM_DEPTH-1][0:7];
    wire [3:0] mem_addr = {ra[1:0], ca[1:0]};

    reg [DQ_W-1:0] d [0:7];

    // =========================================================================
    // State register + counter
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cyc   <= 7'd0;
        end else begin
            state <= nxt;
				if(nxt!=state)begin
				if(nxt==S_DATA && state==S_COL_CMD)
				cyc=7'd1;
				else
				cyc<=7'd0;
				end else begin
            cyc   <= cyc + 1;
				end
        end
    end

    // =========================================================================
    // Next-state logic
    //
    //  S_DATA exit uses internal offsets:
    //    WRITE: WL + DATA_CK + tWR - 1
    //    READ : RL + DATA_CK + tRTP - 1
    // =========================================================================
    wire [6:0] data_exit_cyc = op_r ? (7'(RL) + 1 + DATA_CK + tRTP - 1)
                                    : (7'(WL) + 1 + DATA_CK + tWR  - 1);

    always @(*) begin
        case (state)
            S_IDLE:    nxt = start                  ? S_ACT_CMD : S_IDLE;
            S_ACT_CMD: nxt = (cyc == 7'd1)          ? S_tRCD    : S_ACT_CMD;
            S_tRCD:    nxt = (cyc == 7'(tRCD) - 1)  ? S_COL_CMD : S_tRCD;
            S_COL_CMD: nxt = S_DATA;
            S_DATA:    nxt = (cyc == data_exit_cyc)  ? S_PRE     : S_DATA;
            S_PRE:     nxt = (cyc == 7'(tRP) - 1)   ? S_DONE    : S_PRE;
            S_DONE:    nxt = S_IDLE;
            default:   nxt = S_IDLE;
        endcase
    end

    // =========================================================================
    // Input latch
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_r <= 1'b0;
            ra   <= 4'd0;
            ca   <= 4'd0;
        end else if (start && (state == S_IDLE)) begin
            op_r <= op;
            ra   <= row_addr;
            ca   <= col_addr;
            wd[0] <= wr_d0; wd[1] <= wr_d1;
            wd[2] <= wr_d2; wd[3] <= wr_d3;
            wd[4] <= wr_d4; wd[5] <= wr_d5;
            wd[6] <= wr_d6; wd[7] <= wr_d7;
        end
    end

    // =========================================================================
    // Memory write — commit at data start
    // =========================================================================
    always @(posedge clk) begin
        if (state == S_DATA && !op_r && cyc == WL + 1) begin
            mem[mem_addr][0] <= wd[0]; mem[mem_addr][1] <= wd[1];
            mem[mem_addr][2] <= wd[2]; mem[mem_addr][3] <= wd[3];
            mem[mem_addr][4] <= wd[4]; mem[mem_addr][5] <= wd[5];
            mem[mem_addr][6] <= wd[6]; mem[mem_addr][7] <= wd[7];
        end
    end

    // =========================================================================
    // Burst data load — at S_COL_CMD
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d[0]<=0; d[1]<=0; d[2]<=0; d[3]<=0;
            d[4]<=0; d[5]<=0; d[6]<=0; d[7]<=0;
        end else if (state == S_COL_CMD) begin
            if (!op_r) begin
                d[0]<=wd[0]; d[1]<=wd[1]; d[2]<=wd[2]; d[3]<=wd[3];
                d[4]<=wd[4]; d[5]<=wd[5]; d[6]<=wd[6]; d[7]<=wd[7];
            end else begin
                d[0]<=mem[mem_addr][0]; d[1]<=mem[mem_addr][1];
                d[2]<=mem[mem_addr][2]; d[3]<=mem[mem_addr][3];
                d[4]<=mem[mem_addr][4]; d[5]<=mem[mem_addr][5];
                d[6]<=mem[mem_addr][6]; d[7]<=mem[mem_addr][7];
            end
        end
    end

    // =========================================================================
    // Trigger flags for negedge blocks
    // =========================================================================
    reg r_fall_act, c_fall_col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_fall_act <= 1'b0;
            c_fall_col <= 1'b0;
        end else begin
            r_fall_act <= (state == S_ACT_CMD && cyc == 7'd0);
            c_fall_col <= (state == S_COL_CMD);
        end
    end

    // =========================================================================
    // Rising-edge command outputs (posedge clk)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_rise <= 4'h0;
            C_rise <= 4'h0;
        end else begin
            R_rise <= 4'h0;
            C_rise <= 4'h0;

            case (state)
                S_ACT_CMD: begin
                    if      (cyc == 7'd0) R_rise <= 4'bx110;
                    else if (cyc == 7'd1) R_rise <= {ra[1:0], 2'b11};
                end

                S_COL_CMD: begin
                    C_rise <= op_r ? 4'b0101 : 4'b0001;
                end

                S_PRE: begin
                    if (cyc == 7'd0) R_rise <= 4'bx001;
                end
            endcase
        end
    end

    // =========================================================================
    // Falling-edge command outputs (negedge clk)
    // =========================================================================
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_fall <= 4'h0;
            C_fall <= 4'h0;
        end else begin
            R_fall <= 4'h0;
            C_fall <= 4'h0;

            if (r_fall_act) R_fall <= {ra[3:2], 2'b11};
            if (c_fall_col) C_fall <= ca;
        end
    end

    // =========================================================================
    // DQS / DQ enable windows  (using internal latency offsets)
    //
    //   JEDEC timing from column command on bus (T0):
    //
    //     cyc=0 is 1 CK BEFORE T0 (NBA delay), so all bus-referenced
    //     timings need +1 added to the cyc comparison:
    //
    //     Bus T0 + (WL-1) = preamble start  → cyc = WL
    //     Bus T0 + WL     = data start      → cyc = WL + 1
    //     Bus T0 + WL+2   = data end        → cyc = WL + 1 + DATA_CK
    //     Bus T0 + WL+3   = postamble end   → cyc = WL + 1 + DATA_CK + 1
    //
    //   DQS active window: preamble + data + postamble
    //   DQ  active window: data only
    // =========================================================================
    wire in_data = (state == S_DATA);

    // WRITE strobe: preamble(1CK) + data(2CK) + postamble(1CK)
    wire wdqs_en  = in_data && !op_r
                    && (cyc >= WL)
                    && (cyc <  (WL + 1 + DATA_CK + 1));

    // WRITE data window: data only
    wire dq_win_w = in_data && !op_r
                    && (cyc >= (WL + 1))
                    && (cyc <  (WL + 1 + DATA_CK));

    // READ strobe: preamble(1CK) + data(2CK) + postamble(1CK)
    wire rdqs_en  = in_data && op_r
                    && (cyc >= RL)
                    && (cyc <  (RL + 1 + DATA_CK + 1));

    // READ data window: data only
    wire dq_win_r = in_data && op_r
                    && (cyc >= (RL + 1))
                    && (cyc <  (RL + 1 + DATA_CK));

    wire dq_window = dq_win_w | dq_win_r;

    // =========================================================================
    // DQS outputs — gated clk_2x
    // =========================================================================
    assign WDQS_t = wdqs_en ? clk_2x : 1'b0;
    assign WDQS_c = ~WDQS_t;

    assign RDQS_t = rdqs_en ? clk_2x : 1'b0;
    assign RDQS_c = ~RDQS_t;

    // =========================================================================
    // DDR data engine  (fully combinational, synthesizable)
    //
    // No clk_2x-domain state machine needed. DQ is a pure combinational
    // mux from the pre-loaded d[] array, indexed by:
    //   - pair_idx : derived from CK-domain cyc counter (which CK of data)
    //   - clk_2x   : selects even beat (high) or odd beat (low)
    //
    // dq_window gates the output: DQ=0 during preamble and postamble.
    //
    // Since cyc updates via NBA at CK posedge, and DQ is a continuous
    // assign, the pair_idx changes AFTER CK NBA — meaning the entire
    // CK cycle (both clk_2x phases) sees the same pair_idx.
    //
    //   pair_idx=0 → d[0] on clk_2x high, d[1] on clk_2x low
    //   pair_idx=1 → d[2] on clk_2x high, d[3] on clk_2x low
    //   pair_idx=2 → d[4] on clk_2x high, d[5] on clk_2x low
    //   pair_idx=3 → d[6] on clk_2x high, d[7] on clk_2x low
    // =========================================================================

    // Pair index: 4 pairs across DATA_CK=2 CK cycles
    // Each CK cycle has 2 clk_2x cycles = 2 pairs:
    //   CK high half → pair A,  CK low half → pair B
    //
    // pair_idx = {cyc_offset[0], ~clk}
    //   cyc_offset = 0 (first data CK):  clk=1 → pair 0, clk=0 → pair 1
    //   cyc_offset = 1 (second data CK): clk=1 → pair 2, clk=0 → pair 3
    //
    // Each pair drives 2 beats: even on clk_2x high, odd on clk_2x low
    //   pair 0: d[0], d[1]    pair 1: d[2], d[3]
    //   pair 2: d[4], d[5]    pair 3: d[6], d[7]
    wire [6:0] data_cyc_ofs = cyc - (op_r ? 7'(RL) + 7'd1 : 7'(WL) + 7'd1);
    wire [1:0] pair_idx     = {data_cyc_ofs[0], ~clk};

    // DQ output — purely combinational
    reg [DQ_W-1:0] dq_out;
    always @(*) begin
        dq_out = {DQ_W{1'b0}};
        if (dq_window) begin
            if (clk_2x)
                dq_out = d[{pair_idx, 1'b0}];   // even beats: 0,2,4,6
            else
                dq_out = d[{pair_idx, 1'b1}];   // odd  beats: 1,3,5,7
        end
    end
    assign DQ = dq_out;

    // =========================================================================
    // rd_valid + rd_data capture
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid   <= 1'b0;
            rd_data[0] <= 0; rd_data[1] <= 0;
            rd_data[2] <= 0; rd_data[3] <= 0;
            rd_data[4] <= 0; rd_data[5] <= 0;
            rd_data[6] <= 0; rd_data[7] <= 0;
        end else begin
            rd_valid <= 1'b0;
            if (state == S_DATA && op_r && (cyc == RL + 1 + DATA_CK)) begin
                rd_valid   <= 1'b1;
                rd_data[0] <= d[0]; rd_data[1] <= d[1];
                rd_data[2] <= d[2]; rd_data[3] <= d[3];
                rd_data[4] <= d[4]; rd_data[5] <= d[5];
                rd_data[6] <= d[6]; rd_data[7] <= d[7];
            end
        end
    end

endmodule