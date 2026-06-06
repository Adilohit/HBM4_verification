module hbm4_single_write #(
    parameter WL   = 4,
    parameter BL   = 8,
    parameter tRCD = 7,
    parameter tWR  = 6,
    parameter tRP  = 7,
    parameter DQ_W = 32
)(
    input  wire clk,
    input  wire clk_2x,       // 2x base clock — drives WDQS and DQ
    input  wire rst_n,
    input  wire start,

    input  wire [3:0] row_addr,
    input  wire [3:0] col_addr,

    input  wire [DQ_W-1:0] wr_d0, wr_d1, wr_d2, wr_d3,
    input  wire [DQ_W-1:0] wr_d4, wr_d5, wr_d6, wr_d7,

    output wire CK_t,
    output wire CK_c,

    output reg  [3:0] R_rise,
    output reg  [3:0] R_fall,
    output reg  [3:0] C_rise,
    output reg  [3:0] C_fall,

    output wire WDQS_t,       // gated clk_2x → 2x CK frequency
    output wire WDQS_c,

    output wire [DQ_W-1:0] DQ,
    output wire done
);

    assign CK_t = clk;
    assign CK_c = ~clk;

    //=========================================================
    // FSM states
    //=========================================================
    localparam S_IDLE  = 0,
               S_ACT   = 1,
               S_WRITE = 2,
               S_PRE   = 3,
               S_DONE  = 4;

    reg [2:0] state, nxt;
    reg [5:0] cyc;

    assign done = (state == S_DONE);

    //=========================================================
    // Data storage
    //=========================================================
    reg [3:0] ra, ca;
    reg [DQ_W-1:0] d [0:7];

    //=========================================================
    // BL8 with DDR on 2x-WDQS → 4 beats per CK → 2 CK cycles
    //=========================================================
    localparam DATA_CK = BL / 4;   // = 2

    //=========================================================
    // Enable windows (combinational, CK-domain)
    //
    //   wdqs_en  : 1 CK preamble before data + data window
    //   dq_window: data-only window (no preamble)
    //=========================================================
    wire wdqs_en   = (state == S_WRITE) &&
                     (cyc >= (WL - 1))  &&
                     (cyc <  (WL + DATA_CK));

    wire dq_window = (state == S_WRITE) &&
                     (cyc >= WL)        &&
                     (cyc <  (WL + DATA_CK));

    //=========================================================
    // WDQS — gated clk_2x  (2 full WDQS cycles per CK cycle)
    //=========================================================
    assign WDQS_t = wdqs_en ? clk_2x : 1'b0;
    assign WDQS_c = ~WDQS_t;

    //=========================================================
    // DQ — DDR mux on clk_2x
    //
    // posedge clk_2x loads the next {dq_pos, dq_neg} pair.
    // clk_2x selects which half is driven onto the bus.
    // 4 pairs (8 beats) across 4 posedge-clk_2x events = 2 CK.
    //=========================================================
    reg [DQ_W-1:0] dq_pos, dq_neg;
    reg             dq_active;
    reg [2:0]       pair_cnt;      // 0-4

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
            // ---- first pair: d[0] on pos-edge, d[1] on neg-edge ----
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
                    // ---- burst complete: de-assert DQ ----
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

            d[0] <= wr_d0;  d[1] <= wr_d1;
            d[2] <= wr_d2;  d[3] <= wr_d3;
            d[4] <= wr_d4;  d[5] <= wr_d5;
            d[6] <= wr_d6;  d[7] <= wr_d7;
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
            S_IDLE:  nxt = start            ? S_ACT   : S_IDLE;
            S_ACT:   nxt = (cyc == tRCD)    ? S_WRITE : S_ACT;
            S_WRITE: nxt = (cyc == WL + DATA_CK + tWR) ? S_PRE : S_WRITE;
            S_PRE:   nxt = (cyc == tRP)     ? S_DONE  : S_PRE;
            S_DONE:  nxt = S_IDLE;
            default: nxt = S_IDLE;
        endcase
    end

    //=========================================================
    // Falling-edge trigger flags  (posedge clk)
    //   These are set on the SAME posedge that drives R_rise/C_rise,
    //   so the negedge block fires exactly half a CK later.
    //=========================================================
    reg r_fall_act;     // trigger R_fall with RA[3:2] on next negedge
    reg c_fall_wr;      // trigger C_fall with column addr on next negedge

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_fall_act <= 1'b0;
            c_fall_wr  <= 1'b0;
        end else begin
            r_fall_act <= (state == S_ACT  && cyc == 0);
            c_fall_wr  <= (state == S_WRITE && cyc == 0);
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
                S_ACT: begin
                    if (cyc == 0)      R_rise <= 4'bx110;           // ACT cmd
                    else if (cyc == 1) R_rise <= {ra[1:0], 2'b11};  // RA[1:0]
                end

                S_WRITE: begin
                    if (cyc == 0)      C_rise <= 4'b0001;           // WR cmd
                end

                S_PRE: begin
                    if (cyc == 0)      R_rise <= 4'bx001;           // PRE cmd
                end
            endcase
        end
    end

    //=========================================================
    // Falling-edge commands  (negedge clk → CK_t falling edge)
    //   Fires half a CK AFTER the corresponding posedge,
    //   gated by the flags registered on that same posedge.
    //=========================================================
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R_fall <= 4'h0;
            C_fall <= 4'h0;
        end else begin
            R_fall <= 4'h0;
            C_fall <= 4'h0;

            if (r_fall_act) R_fall <= {ra[3:2], 2'b11};  // RA[3:2]
            if (c_fall_wr)  C_fall <= ca;                 // col addr
        end
    end

endmodule