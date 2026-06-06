// =============================================================================
//  hbm4_seq_lib.sv  —  Sequence Library (UVM 1.1d / QuestaSim 10.7c)
//
//  Added: hbm4_rtl_branch_seq — targets the specific RTL branches that were
//  uncovered (Statements 65.99%, Branches 35.09%, FEC 45.19% in HTML)
//
//  Uncovered RTL branches in hbm4_bank_model.sv:
//    B1: r_fall_act path (negedge, R_fall valid)
//    B2: c_fall_col path (negedge, C_fall valid)
//    B3: ^R_rise !== 1'bx check in monitor-like tasks
//    B4: DM masking when dm_mask[0] and dm_mask[1] both active separately
//    B5: All FSM case branches: S_ACT_CMD cyc==0, cyc==1
//    B6: S_tRCD cyc == tRCD-1
//    B7: S_DATA at exact data_exit_cyc boundary
//    B8: S_PRE at cyc == tRP-1
//    B9: dq_window true vs false (WDQS vs RDQS, clk_2x true vs false)
//    B10: pair_idx all 4 values (0,1,2,3)
//    B11: data_cyc_ofs paths
//    B12: rd_valid condition at cyc == RL+1+DATA_CK
//    B13: mem_addr all 16 values
//    B14: op_r both 0 and 1 in S_COL_CMD
// =============================================================================

// =============================================================================
//  Base Sequence
// =============================================================================
class hbm4_base_seq extends uvm_sequence #(hbm4_item);
    `uvm_object_utils(hbm4_base_seq)

    function new(string name = "hbm4_base_seq");
        super.new(name);
    endfunction

    task do_write(input logic [3:0] row, col,
                  input logic [31:0] d0, d1, d2, d3, d4, d5, d6, d7,
                  input logic [1:0]  dm = 2'b00);
        hbm4_item item;
        item = hbm4_item::type_id::create("wr_item");
        start_item(item);
        item.op         = 1'b0;
        item.row_addr   = row;
        item.col_addr   = col;
        item.dm_mask    = dm;
        item.wr_data[0] = d0; item.wr_data[1] = d1;
        item.wr_data[2] = d2; item.wr_data[3] = d3;
        item.wr_data[4] = d4; item.wr_data[5] = d5;
        item.wr_data[6] = d6; item.wr_data[7] = d7;
        finish_item(item);
        `uvm_info("SEQ", $sformatf("[WRITE] r=%0h c=%0h dm=%b d0=0x%08h",
                   row, col, dm, d0), UVM_MEDIUM)
    endtask

    task do_read(input logic [3:0] row, col);
        hbm4_item item;
        item = hbm4_item::type_id::create("rd_item");
        start_item(item);
        item.op       = 1'b1;
        item.row_addr = row;
        item.col_addr = col;
        item.dm_mask  = 2'b00;
        item.wr_data[0] = 32'h0; item.wr_data[1] = 32'h0;
        item.wr_data[2] = 32'h0; item.wr_data[3] = 32'h0;
        item.wr_data[4] = 32'h0; item.wr_data[5] = 32'h0;
        item.wr_data[6] = 32'h0; item.wr_data[7] = 32'h0;
        finish_item(item);
        `uvm_info("SEQ", $sformatf("[READ ] r=%0h c=%0h", row, col), UVM_MEDIUM)
    endtask

endclass : hbm4_base_seq

// =============================================================================
//  SEQ 1: Directed Write-Read
// =============================================================================
class hbm4_directed_wr_rd_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_directed_wr_rd_seq)

    function new(string name = "hbm4_directed_wr_rd_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Directed Write-Read Sequence ===", UVM_LOW)

        do_write(4'h1, 4'h3,
                 32'h1000_0000, 32'h1010_1010, 32'h2020_2020, 32'h3030_3030,
                 32'h4040_4040, 32'h5050_5050, 32'h6060_6060, 32'h7070_7070);
        do_read(4'h1, 4'h3);

        do_write(4'h2, 4'h4,
                 32'h0, 32'h0, 32'h0, 32'h0,
                 32'h0, 32'h0, 32'h0, 32'h0);
        do_read(4'h2, 4'h4);

        do_write(4'h3, 4'h5,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        do_read(4'h3, 4'h5);

        do_write(4'h0, 4'h0,
                 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA,
                 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA);
        do_read(4'h0, 4'h0);
    endtask

endclass : hbm4_directed_wr_rd_seq

// =============================================================================
//  SEQ 2: Random Traffic
// =============================================================================
class hbm4_random_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_random_seq)
    int unsigned num_txns = 50;

    function new(string name = "hbm4_random_seq");
        super.new(name);
    endfunction

    task body();
        hbm4_item item;
        int i;
        `uvm_info("SEQ", $sformatf("=== Random Sequence (%0d txns) ===", num_txns), UVM_LOW)
        for (i = 0; i < num_txns; i++) begin
            item = hbm4_item::type_id::create("rand_item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(item);
        end
    endtask

endclass : hbm4_random_seq

// =============================================================================
//  SEQ 3: Address Sweep
// =============================================================================
class hbm4_addr_sweep_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_addr_sweep_seq)

    function new(string name = "hbm4_addr_sweep_seq");
        super.new(name);
    endfunction

    task body();
        logic [3:0] r4, c4;
        logic [31:0] d;
        int r, c;
        `uvm_info("SEQ", "=== Address Sweep Sequence ===", UVM_LOW)
        // Hit all 16 physical memory locations: mem_addr = {ra[1:0], ca[1:0]}
        // Need ra[1:0] in {0,1,2,3} and ca[1:0] in {0,1,2,3}
        for (r = 0; r < 4; r++) begin
            for (c = 0; c < 4; c++) begin
                r4 = r[3:0];
                c4 = c[3:0];
                d  = {4'(r), 4'(c), 8'hAA, 8'hBB, 8'(r^c)};
                do_write(r4, c4, d, d+1, d+2, d+3, d+4, d+5, d+6, d+7);
                do_read(r4, c4);
            end
        end
        do_write(4'hF, 4'hF,
                 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF,
                 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF);
        do_read(4'hF, 4'hF);
        do_write(4'h0, 4'h0,
                 32'hCAFE_BABE, 32'hCAFE_BABE, 32'hCAFE_BABE, 32'hCAFE_BABE,
                 32'hCAFE_BABE, 32'hCAFE_BABE, 32'hCAFE_BABE, 32'hCAFE_BABE);
        do_read(4'h0, 4'h0);
    endtask

endclass : hbm4_addr_sweep_seq

// =============================================================================
//  SEQ 4: Data Pattern Sequences
// =============================================================================
class hbm4_data_pattern_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_data_pattern_seq)

    function new(string name = "hbm4_data_pattern_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Data Pattern Sequence ===", UVM_LOW)

        // Walking 1s (one per beat, stays in [0x01:0x80] range)
        do_write(4'h0, 4'h1,
                 32'h0000_0001, 32'h0000_0002, 32'h0000_0004, 32'h0000_0008,
                 32'h0000_0010, 32'h0000_0020, 32'h0000_0040, 32'h0000_0080);
        do_read(4'h0, 4'h1);

        // Walking 0s (stays in [0xFFFFFF7F:0xFFFFFFFE] range)
        do_write(4'h0, 4'h2,
                 32'hFFFF_FFFE, 32'hFFFF_FFFD, 32'hFFFF_FFFB, 32'hFFFF_FFF7,
                 32'hFFFF_FFEF, 32'hFFFF_FFDF, 32'hFFFF_FFBF, 32'hFFFF_FF7F);
        do_read(4'h0, 4'h2);

        // Alternating AAAA/5555
        do_write(4'h1, 4'h0,
                 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555,
                 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555);
        do_read(4'h1, 4'h0);

        // Alternating 5555/AAAA
        do_write(4'h1, 4'h1,
                 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA,
                 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA);
        do_read(4'h1, 4'h1);

        // All zeros
        do_write(4'h2, 4'h0,
                 32'h0, 32'h0, 32'h0, 32'h0,
                 32'h0, 32'h0, 32'h0, 32'h0);
        do_read(4'h2, 4'h0);

        // All ones
        do_write(4'h2, 4'h1,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        do_read(4'h2, 4'h1);

        // Checkerboard FF00FF00 / 00FF00FF
        do_write(4'h3, 4'h0,
                 32'hFF00_FF00, 32'h00FF_00FF, 32'hFF00_FF00, 32'h00FF_00FF,
                 32'hFF00_FF00, 32'h00FF_00FF, 32'hFF00_FF00, 32'h00FF_00FF);
        do_read(4'h3, 4'h0);

        // Incrementing 0x0000 .. 0x7777
        do_write(4'h3, 4'h1,
                 32'h0000_0000, 32'h1111_1111, 32'h2222_2222, 32'h3333_3333,
                 32'h4444_4444, 32'h5555_5555, 32'h6666_6666, 32'h7777_7777);
        do_read(4'h3, 4'h1);
    endtask

endclass : hbm4_data_pattern_seq

// =============================================================================
//  SEQ 5: DM Mask Variations
// =============================================================================
class hbm4_dm_mask_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_dm_mask_seq)

    function new(string name = "hbm4_dm_mask_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== DM Mask Sequence ===", UVM_LOW)

        do_write(4'h0, 4'h8,
                 32'h1234_5678, 32'h1234_5678, 32'h1234_5678, 32'h1234_5678,
                 32'h1234_5678, 32'h1234_5678, 32'h1234_5678, 32'h1234_5678,
                 2'b00);
        do_read(4'h0, 4'h8);

        do_write(4'h0, 4'h9,
                 32'hABCD_EF01, 32'hABCD_EF01, 32'hABCD_EF01, 32'hABCD_EF01,
                 32'hABCD_EF01, 32'hABCD_EF01, 32'hABCD_EF01, 32'hABCD_EF01,
                 2'b01);
        do_read(4'h0, 4'h9);

        do_write(4'h0, 4'hA,
                 32'hFEDC_BA98, 32'hFEDC_BA98, 32'hFEDC_BA98, 32'hFEDC_BA98,
                 32'hFEDC_BA98, 32'hFEDC_BA98, 32'hFEDC_BA98, 32'hFEDC_BA98,
                 2'b10);
        do_read(4'h0, 4'hA);

        do_write(4'h0, 4'hB,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF,
                 2'b11);
        do_read(4'h0, 4'hB);
    endtask

endclass : hbm4_dm_mask_seq

// =============================================================================
//  SEQ 6: Back-to-Back Operations
// =============================================================================
class hbm4_b2b_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_b2b_seq)

    function new(string name = "hbm4_b2b_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Back-to-Back Sequence ===", UVM_LOW)

        // WR → WR
        do_write(4'h1, 4'h4,
                 32'hAA00_0001, 32'hAA00_0002, 32'hAA00_0003, 32'hAA00_0004,
                 32'hAA00_0005, 32'hAA00_0006, 32'hAA00_0007, 32'hAA00_0008);
        do_write(4'h1, 4'h5,
                 32'hBB00_0001, 32'hBB00_0002, 32'hBB00_0003, 32'hBB00_0004,
                 32'hBB00_0005, 32'hBB00_0006, 32'hBB00_0007, 32'hBB00_0008);

        // WR → RD same address
        do_write(4'h2, 4'h6,
                 32'hCC00_0001, 32'hCC00_0002, 32'hCC00_0003, 32'hCC00_0004,
                 32'hCC00_0005, 32'hCC00_0006, 32'hCC00_0007, 32'hCC00_0008);
        do_read(4'h2, 4'h6);

        // RD → WR
        do_read(4'h2, 4'h6);
        do_write(4'h2, 4'h6,
                 32'hDD00_0001, 32'hDD00_0002, 32'hDD00_0003, 32'hDD00_0004,
                 32'hDD00_0005, 32'hDD00_0006, 32'hDD00_0007, 32'hDD00_0008);
        do_read(4'h2, 4'h6);

        // RD → RD
        do_read(4'h3, 4'h0);
        do_read(4'h3, 4'h0);
    endtask

endclass : hbm4_b2b_seq

// =============================================================================
//  SEQ 7: Boundary Cases
// =============================================================================
class hbm4_boundary_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_boundary_seq)

    function new(string name = "hbm4_boundary_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Boundary Sequence ===", UVM_LOW)

        do_write(4'h0, 4'h0,
                 32'h0000_0001, 32'h0000_0002, 32'h0000_0004, 32'h0000_0008,
                 32'h0000_0010, 32'h0000_0020, 32'h0000_0040, 32'h0000_0080);
        do_read(4'h0, 4'h0);

        do_write(4'h0, 4'hF,
                 32'hF000_0001, 32'hF000_0002, 32'hF000_0003, 32'hF000_0004,
                 32'hF000_0005, 32'hF000_0006, 32'hF000_0007, 32'hF000_0008);
        do_read(4'h0, 4'hF);

        do_write(4'hF, 4'h0,
                 32'h0F00_0001, 32'h0F00_0002, 32'h0F00_0003, 32'h0F00_0004,
                 32'h0F00_0005, 32'h0F00_0006, 32'h0F00_0007, 32'h0F00_0008);
        do_read(4'hF, 4'h0);

        do_write(4'hF, 4'hF,
                 32'hFF00_0001, 32'hFF00_0002, 32'hFF00_0003, 32'hFF00_0004,
                 32'hFF00_0005, 32'hFF00_0006, 32'hFF00_0007, 32'hFF00_0008);
        do_read(4'hF, 4'hF);

        do_write(4'h3, 4'h3,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        do_read(4'h3, 4'h3);
    endtask

endclass : hbm4_boundary_seq

// =============================================================================
//  SEQ 8: Row Sweep
// =============================================================================
class hbm4_row_sweep_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_row_sweep_seq)

    function new(string name = "hbm4_row_sweep_seq");
        super.new(name);
    endfunction

    task body();
        logic [3:0] r4;
        logic [31:0] d;
        int r;
        `uvm_info("SEQ", "=== Row Sweep Sequence ===", UVM_LOW)
        for (r = 0; r < 16; r++) begin
            r4 = r[3:0];
            d  = {r4, 4'h3, 8'hAA, 8'h55, 8'(r)};
            do_write(r4, 4'h3, d, d+1, d+2, d+3, d+4, d+5, d+6, d+7);
            do_read(r4, 4'h3);
        end
    endtask

endclass : hbm4_row_sweep_seq

// =============================================================================
//  SEQ 9: Column Sweep
// =============================================================================
class hbm4_col_sweep_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_col_sweep_seq)

    function new(string name = "hbm4_col_sweep_seq");
        super.new(name);
    endfunction

    task body();
        logic [3:0] c4;
        logic [31:0] d;
        int c;
        `uvm_info("SEQ", "=== Column Sweep Sequence ===", UVM_LOW)
        for (c = 0; c < 16; c++) begin
            c4 = c[3:0];
            d  = {4'h5, c4, 8'hCC, 8'hDD, 8'(c)};
            do_write(4'h5, c4, d, d+1, d+2, d+3, d+4, d+5, d+6, d+7);
            do_read(4'h5, c4);
        end
    endtask

endclass : hbm4_col_sweep_seq

// =============================================================================
//  SEQ 10: FSM Coverage
// =============================================================================
class hbm4_fsm_coverage_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_fsm_coverage_seq)

    function new(string name = "hbm4_fsm_coverage_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== FSM Coverage Sequence ===", UVM_LOW)

        do_write(4'h5, 4'h5,
                 32'h1111_0001, 32'h1111_0002, 32'h1111_0003, 32'h1111_0004,
                 32'h1111_0005, 32'h1111_0006, 32'h1111_0007, 32'h1111_0008);
        do_read(4'h5, 4'h5);
        do_write(4'h6, 4'h6,
                 32'h2222_0001, 32'h2222_0002, 32'h2222_0003, 32'h2222_0004,
                 32'h2222_0005, 32'h2222_0006, 32'h2222_0007, 32'h2222_0008);
        do_write(4'h7, 4'h7,
                 32'h3333_0001, 32'h3333_0002, 32'h3333_0003, 32'h3333_0004,
                 32'h3333_0005, 32'h3333_0006, 32'h3333_0007, 32'h3333_0008);
        do_read(4'h6, 4'h6);
        do_read(4'h7, 4'h7);
    endtask

endclass : hbm4_fsm_coverage_seq

// =============================================================================
//  SEQ 11: Read Before Write
// =============================================================================
class hbm4_read_before_write_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_read_before_write_seq)

    function new(string name = "hbm4_read_before_write_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Read-Before-Write Sequence ===", UVM_LOW)
        do_read(4'h0, 4'h0);
        do_write(4'h0, 4'h0,
                 32'hFACE_CAF0, 32'hFACE_CAF1, 32'hFACE_CAF2, 32'hFACE_CAF3,
                 32'hFACE_CAF4, 32'hFACE_CAF5, 32'hFACE_CAF6, 32'hFACE_CAF7);
        do_read(4'h0, 4'h0);
    endtask

endclass : hbm4_read_before_write_seq

// =============================================================================
//  SEQ 12: RTL Branch Coverage
//  Targets the specific uncovered branches in hbm4_bank_model.sv:
//
//  From HTML report:
//    Statements : 65.99%  (824 miss)
//    Branches   : 35.09%  (503 miss)
//    FEC        : 45.19%   (57 miss)
//
//  Key uncovered areas:
//  1. R_rise X110 output (S_ACT_CMD cyc==0): every txn hits this — already covered
//  2. R_rise {ra[1:0],2b11} (cyc==1): every txn hits this
//  3. C_rise 0001 WRITE / 0101 READ: both hit by wr/rd sequences
//  4. R_rise x001 PRE (cyc==0 in S_PRE): every txn hits this
//  5. wdqs_en true/false: hit by WRITE txns
//  6. rdqs_en true/false: hit by READ txns
//  7. dq_win_w true/false: hit by WRITE txns
//  8. dq_win_r true/false: hit by READ txns
//  9. clk_2x=1 vs clk_2x=0 in DQ mux: both hit in every data transaction
//  10. pair_idx {0,1,2,3}: all hit in every data transaction (2 CK × 2 clk_2x)
//  11. data_cyc_ofs computation: all values hit
//  12. mem_addr all 16 values: add explicit hits for all {ra[1:0],ca[1:0]}
//  13. r_fall_act path (negedge): every txn
//  14. c_fall_col path (negedge): every txn
//
//  The main gaps are from the RTL's always_comb DQ mux and the
//  nested conditions in the DQS enable logic. This sequence ensures
//  WRITE and READ are exercised with all 16 mem_addr values and
//  all DQ data patterns (all-0, all-1, mid, alternating) so the
//  simulator can observe all branches of the always @(*) blocks.
// =============================================================================
class hbm4_rtl_branch_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_rtl_branch_seq)

    function new(string name = "hbm4_rtl_branch_seq");
        super.new(name);
    endfunction

    task body();
        logic [3:0] r4, c4;
        logic [31:0] d;
        int r, c;
        `uvm_info("SEQ", "=== RTL Branch Coverage Sequence ===", UVM_LOW)

        // ----------------------------------------------------------------
        // 1. All 16 physical memory addresses with WRITE then READ
        //    mem_addr = {ra[1:0], ca[1:0]}
        //    ra[1:0] in {0,1,2,3}, ca[1:0] in {0,1,2,3}
        //    This hits all branches of: mem[mem_addr][N] <= wd[N]
        //    and: d[N] <= mem[mem_addr][N]
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- All 16 mem_addr locations WR+RD --", UVM_MEDIUM)
        for (r = 0; r < 4; r++) begin
            for (c = 0; c < 4; c++) begin
                r4 = r[3:0];
                c4 = c[3:0];
                // Unique data per location so we can verify correctness
                d = {4'(r), 4'(c), 8'hDE, 8'hAD, 8'(r*4+c)};
                do_write(r4, c4, d, ~d, d+1, ~d+1, d+2, ~d+2, d+3, ~d+3);
                do_read(r4, c4);
            end
        end

        // ----------------------------------------------------------------
        // 2. DQ mux all-zero data (dq_out = 0 even during dq_window)
        //    Tests the if(dq_window) false branch → dq_out stays 0
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- DQ all-zero write --", UVM_MEDIUM)
        do_write(4'h0, 4'h0,
                 32'h0, 32'h0, 32'h0, 32'h0,
                 32'h0, 32'h0, 32'h0, 32'h0);
        do_read(4'h0, 4'h0);

        // ----------------------------------------------------------------
        // 3. DQ mux all-ones data — forces all bits of DQ to toggle 0→1
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- DQ all-ones write --", UVM_MEDIUM)
        do_write(4'h1, 4'h1,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF,
                 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        do_read(4'h1, 4'h1);

        // ----------------------------------------------------------------
        // 4. Alternating per-beat: forces DQ to toggle on every clk_2x edge
        //    pair_idx=0: d[0]=FFFF d[1]=0000  → DQ alternates every half-CK
        //    pair_idx=1: d[2]=FFFF d[3]=0000
        //    pair_idx=2: d[4]=FFFF d[5]=0000
        //    pair_idx=3: d[6]=FFFF d[7]=0000
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- DQ alternating per clk_2x edge --", UVM_MEDIUM)
        do_write(4'h2, 4'h2,
                 32'hFFFF_FFFF, 32'h0000_0000,
                 32'hFFFF_FFFF, 32'h0000_0000,
                 32'hFFFF_FFFF, 32'h0000_0000,
                 32'hFFFF_FFFF, 32'h0000_0000);
        do_read(4'h2, 4'h2);

        // ----------------------------------------------------------------
        // 5. Reverse alternating: 0000 then FFFF per pair
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- DQ reverse alternating --", UVM_MEDIUM)
        do_write(4'h3, 4'h3,
                 32'h0000_0000, 32'hFFFF_FFFF,
                 32'h0000_0000, 32'hFFFF_FFFF,
                 32'h0000_0000, 32'hFFFF_FFFF,
                 32'h0000_0000, 32'hFFFF_FFFF);
        do_read(4'h3, 4'h3);

        // ----------------------------------------------------------------
        // 6. Unique value per beat — exercises all 8 d[] array reads
        //    pair 0: d[0]=AABB d[1]=CCDD
        //    pair 1: d[2]=EEFF d[3]=0011
        //    pair 2: d[4]=2233 d[5]=4455
        //    pair 3: d[6]=6677 d[7]=8899
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- Unique per-beat data --", UVM_MEDIUM)
        do_write(4'h0, 4'h1,
                 32'hAABB_CCDD, 32'hCCDD_EEFF,
                 32'hEEFF_0011, 32'h0011_2233,
                 32'h2233_4455, 32'h4455_6677,
                 32'h6677_8899, 32'h8899_AABB);
        do_read(4'h0, 4'h1);

        // ----------------------------------------------------------------
        // 7. Multiple consecutive WRITEs to same address — verify mem update
        //    (hits the mem[mem_addr][N] write branch repeatedly)
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- Consecutive writes same addr --", UVM_MEDIUM)
        do_write(4'h1, 4'h2,
                 32'h1111_1111, 32'h1111_1111, 32'h1111_1111, 32'h1111_1111,
                 32'h1111_1111, 32'h1111_1111, 32'h1111_1111, 32'h1111_1111);
        do_write(4'h1, 4'h2,
                 32'h2222_2222, 32'h2222_2222, 32'h2222_2222, 32'h2222_2222,
                 32'h2222_2222, 32'h2222_2222, 32'h2222_2222, 32'h2222_2222);
        do_write(4'h1, 4'h2,
                 32'h3333_3333, 32'h3333_3333, 32'h3333_3333, 32'h3333_3333,
                 32'h3333_3333, 32'h3333_3333, 32'h3333_3333, 32'h3333_3333);
        do_read(4'h1, 4'h2);

        // ----------------------------------------------------------------
        // 8. WDQS/RDQS enable boundary: exercises the wdqs_en/rdqs_en
        //    conditions at cyc==WL and cyc==WL+1+DATA_CK+1 boundaries
        //    (every WRITE/READ txn already does this, but ensure variety)
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- Mixed WR/RD for DQS boundary --", UVM_MEDIUM)
        do_write(4'h2, 4'h3,
                 32'hA5A5_A5A5, 32'h5A5A_5A5A, 32'hA5A5_A5A5, 32'h5A5A_5A5A,
                 32'hA5A5_A5A5, 32'h5A5A_5A5A, 32'hA5A5_A5A5, 32'h5A5A_5A5A);
        do_read(4'h2, 4'h3);
        do_write(4'h3, 4'h2,
                 32'h5A5A_5A5A, 32'hA5A5_A5A5, 32'h5A5A_5A5A, 32'hA5A5_A5A5,
                 32'h5A5A_5A5A, 32'hA5A5_A5A5, 32'h5A5A_5A5A, 32'hA5A5_A5A5);
        do_read(4'h3, 4'h2);

        // ----------------------------------------------------------------
        // 9. R_rise X pattern (cyc==0 in S_ACT_CMD): already hit by all txns
        //    R_rise {ra[1:0],2b11} (cyc==1): all txns
        //    R_rise x001 (PRE cyc==0): all txns
        //    Add a sequence that uses all row address values to toggle
        //    R_rise[3:0] bits fully.
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- Row addr sweep for R_rise toggle --", UVM_MEDIUM)
        for (r = 0; r < 4; r++) begin
            r4 = r[3:0];
            do_write(r4, 4'h0,
                     32'hDEAD_0000 | 32'(r), 32'hDEAD_0001 | 32'(r),
                     32'hDEAD_0002 | 32'(r), 32'hDEAD_0003 | 32'(r),
                     32'hDEAD_0004 | 32'(r), 32'hDEAD_0005 | 32'(r),
                     32'hDEAD_0006 | 32'(r), 32'hDEAD_0007 | 32'(r));
            do_read(r4, 4'h0);
        end

        // ----------------------------------------------------------------
        // 10. C_fall (col addr) sweep — forces C_fall[3:0] to all values
        //     C_fall = ca[3:0], driven negedge in S_COL_CMD
        // ----------------------------------------------------------------
        `uvm_info("SEQ", "-- Col addr sweep for C_fall toggle --", UVM_MEDIUM)
        for (c = 0; c < 4; c++) begin
            c4 = c[3:0];
            do_write(4'h0, c4,
                     32'hBEEF_0000 | 32'(c), 32'hBEEF_0001 | 32'(c),
                     32'hBEEF_0002 | 32'(c), 32'hBEEF_0003 | 32'(c),
                     32'hBEEF_0004 | 32'(c), 32'hBEEF_0005 | 32'(c),
                     32'hBEEF_0006 | 32'(c), 32'hBEEF_0007 | 32'(c));
            do_read(4'h0, c4);
        end

        `uvm_info("SEQ", "=== RTL Branch Coverage Sequence Done ===", UVM_LOW)
    endtask

endclass : hbm4_rtl_branch_seq


// =============================================================================
//  SEQ 14: Enhanced DM + Data Pattern coverage
//  Ensures cg_dm hits all 4 bins even when monitor inference is used.
//  Uses strategic data patterns to guarantee dm_mask inference works:
//    dm=00: nonzero data in ALL 8 beats → beats 0-3 nonzero AND 4-7 nonzero
//    dm=01: nonzero in beats 4-7 ONLY → monitor sees d0_z=T, d1_z=F → dm=01
//    dm=10: nonzero in beats 0-3 ONLY → monitor sees d0_z=F, d1_z=T → dm=10
//    dm=11: nonzero in NONE           → beats all zero after masking → dm=11
// =============================================================================
class hbm4_dm_coverage_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_dm_coverage_seq)

    function new(string name = "hbm4_dm_coverage_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== DM Coverage Sequence ===", UVM_LOW)

        // dm=00: all 8 beats nonzero — clear non-masked case
        // Beats 0-7 all nonzero → d0_z=F, d1_z=F → dm_mask=2'b00
        do_write(4'h0, 4'h4,
                 32'hA1A1_A1A1, 32'hA2A2_A2A2, 32'hA3A3_A3A3, 32'hA4A4_A4A4,
                 32'hA5A5_A5A5, 32'hA6A6_A6A6, 32'hA7A7_A7A7, 32'hA8A8_A8A8,
                 2'b00);
        do_read(4'h0, 4'h4);

        // dm=01: beat 0-3 masked to zero, 4-7 nonzero
        // Driver sets d[0..3]=0. d[4..7]=32'hB5B5... (nonzero)
        // Monitor: d0_z=(0&&0&&0&&0)=T, d1_z=(B5..!=0)=F → dm_mask=2'b01
        do_write(4'h1, 4'h5,
                 32'hB5B5_B5B5, 32'hB6B6_B6B6, 32'hB7B7_B7B7, 32'hB8B8_B8B8,
                 32'hB9B9_B9B9, 32'hBABA_BABA, 32'hBBBB_BBBB, 32'hBCBC_BCBC,
                 2'b01);
        do_read(4'h1, 4'h5);

        // dm=10: beat 0-3 nonzero, 4-7 masked to zero
        // Driver keeps d[0..3]=32'hC3C3... d[4..7]=0
        // Monitor: d0_z=(C3..!=0)=F, d1_z=(0&&0&&0&&0)=T → dm_mask=2'b10
        do_write(4'h2, 4'h6,
                 32'hC3C3_C3C3, 32'hC4C4_C4C4, 32'hC5C5_C5C5, 32'hC6C6_C6C6,
                 32'hC7C7_C7C7, 32'hC8C8_C8C8, 32'hC9C9_C9C9, 32'hCACA_CACA,
                 2'b10);
        do_read(4'h2, 4'h6);

        // dm=11: all 8 beats masked to zero
        // Driver zeros ALL beats. Monitor: d0_z=T, d1_z=T → dm_mask=2'b11
        do_write(4'h3, 4'h7,
                 32'hD1D1_D1D1, 32'hD2D2_D2D2, 32'hD3D3_D3D3, 32'hD4D4_D4D4,
                 32'hD5D5_D5D5, 32'hD6D6_D6D6, 32'hD7D7_D7D7, 32'hD8D8_D8D8,
                 2'b11);
        do_read(4'h3, 4'h7);

        // Repeat each DM value with different data to get more samples
        // dm=01 again with different nonzero upper data
        do_write(4'h4, 4'h8,
                 32'hFACE_CAFE, 32'hFACE_CAFE, 32'hFACE_CAFE, 32'hFACE_CAFE,
                 32'h1234_5678, 32'h9ABC_DEF0, 32'hFEDC_BA98, 32'h7654_3210,
                 2'b01);
        do_read(4'h4, 4'h8);

        // dm=10 again
        do_write(4'h5, 4'h9,
                 32'h1111_2222, 32'h3333_4444, 32'h5555_6666, 32'h7777_8888,
                 32'h9999_AAAA, 32'hBBBB_CCCC, 32'hDDDD_EEEE, 32'hFFFF_0000,
                 2'b10);
        do_read(4'h5, 4'h9);

        `uvm_info("SEQ", "=== DM Coverage Sequence Done ===", UVM_LOW)
    endtask

endclass : hbm4_dm_coverage_seq

// =============================================================================
//  SEQ 15: Comprehensive Data Coverage
//  Ensures cg_data hits all named bins including walk_1s[] (8 specific values)
//  and the cg_dq_diversity bins (all_zeros, all_ones, alt_aa, alt_55).
// =============================================================================
class hbm4_data_coverage_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_data_coverage_seq)

    function new(string name = "hbm4_data_coverage_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info("SEQ", "=== Comprehensive Data Coverage Sequence ===", UVM_LOW)

        // All-zeros in beat 0 (hits cg_data.all_zeros bin)
        do_write(4'h6, 4'hA,
                 32'h0000_0000, 32'h0000_0001, 32'h0000_0002, 32'h0000_0003,
                 32'h0000_0004, 32'h0000_0005, 32'h0000_0006, 32'h0000_0007);
        do_read(4'h6, 4'hA);

        // All-ones in beat 0 (hits cg_data.all_ones bin)
        do_write(4'h7, 4'hB,
                 32'hFFFF_FFFF, 32'hFFFF_FFFE, 32'hFFFF_FFFD, 32'hFFFF_FFFC,
                 32'hFFFF_FFFB, 32'hFFFF_FFFA, 32'hFFFF_FFF9, 32'hFFFF_FFF8);
        do_read(4'h7, 4'hB);

        // Alt AAAA in beat 0 (hits cg_data.alt_aa bin)
        do_write(4'h8, 4'hC,
                 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555,
                 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555);
        do_read(4'h8, 4'hC);

        // Alt 5555 in beat 0 (hits cg_data.alt_55 bin)
        do_write(4'h9, 4'hD,
                 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA,
                 32'h5555_5555, 32'hAAAA_AAAA, 32'h5555_5555, 32'hAAAA_AAAA);
        do_read(4'h9, 4'hD);

        // Checkerboard FF00FF00 (hits checkerboard_ff00 bin)
        do_write(4'hA, 4'hE,
                 32'hFF00_FF00, 32'h00FF_00FF, 32'hFF00_FF00, 32'h00FF_00FF,
                 32'hFF00_FF00, 32'h00FF_00FF, 32'hFF00_FF00, 32'h00FF_00FF);
        do_read(4'hA, 4'hE);

        // Checkerboard 00FF00FF (hits checkerboard_00ff bin)
        do_write(4'hB, 4'hF,
                 32'h00FF_00FF, 32'hFF00_FF00, 32'h00FF_00FF, 32'hFF00_FF00,
                 32'h00FF_00FF, 32'hFF00_FF00, 32'h00FF_00FF, 32'hFF00_FF00);
        do_read(4'hB, 4'hF);

        // Walking 1s: 0x00000001 in beat 0 (hits walk_1s[0])
        do_write(4'hC, 4'h0,
                 32'h0000_0001, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000,
                 32'h0000_0000, 32'h0000_0000, 32'h0000_0000, 32'h0000_0000);
        do_read(4'hC, 4'h0);

        // Walking 1s: 0x00000002 in beat 0 (hits walk_1s[1])
        do_write(4'hD, 4'h1,
                 32'h0000_0002, 32'h0000_0001, 32'h0000_0001, 32'h0000_0001,
                 32'h0000_0001, 32'h0000_0001, 32'h0000_0001, 32'h0000_0001);
        do_read(4'hD, 4'h1);

        // Walking 1s: 0x00000004 in beat 0 (hits walk_1s[2])
        do_write(4'hE, 4'h2,
                 32'h0000_0004, 32'h0000_0002, 32'h0000_0002, 32'h0000_0002,
                 32'h0000_0002, 32'h0000_0002, 32'h0000_0002, 32'h0000_0002);
        do_read(4'hE, 4'h2);

        // Walking 1s: 0x00000008 in beat 0 (hits walk_1s[3])
        do_write(4'hF, 4'h3,
                 32'h0000_0008, 32'h0000_0004, 32'h0000_0004, 32'h0000_0004,
                 32'h0000_0004, 32'h0000_0004, 32'h0000_0004, 32'h0000_0004);
        do_read(4'hF, 4'h3);

        // Walking 1s: 0x00000010 in beat 0 (hits walk_1s[4])
        do_write(4'h0, 4'h5,
                 32'h0000_0010, 32'h0000_0008, 32'h0000_0008, 32'h0000_0008,
                 32'h0000_0008, 32'h0000_0008, 32'h0000_0008, 32'h0000_0008);
        do_read(4'h0, 4'h5);

        // Walking 1s: 0x00000020 in beat 0 (hits walk_1s[5])
        do_write(4'h1, 4'h6,
                 32'h0000_0020, 32'h0000_0010, 32'h0000_0010, 32'h0000_0010,
                 32'h0000_0010, 32'h0000_0010, 32'h0000_0010, 32'h0000_0010);
        do_read(4'h1, 4'h6);

        // Walking 1s: 0x00000040 in beat 0 (hits walk_1s[6])
        do_write(4'h2, 4'h7,
                 32'h0000_0040, 32'h0000_0020, 32'h0000_0020, 32'h0000_0020,
                 32'h0000_0020, 32'h0000_0020, 32'h0000_0020, 32'h0000_0020);
        do_read(4'h2, 4'h7);

        // Walking 1s: 0x00000080 in beat 0 (hits walk_1s[7])
        do_write(4'h3, 4'h8,
                 32'h0000_0080, 32'h0000_0040, 32'h0000_0040, 32'h0000_0040,
                 32'h0000_0040, 32'h0000_0040, 32'h0000_0040, 32'h0000_0040);
        do_read(4'h3, 4'h8);

        `uvm_info("SEQ", "=== Comprehensive Data Coverage Done ===", UVM_LOW)
    endtask

endclass : hbm4_data_coverage_seq

// =============================================================================
//  SEQ 13: Stress (1000 random transactions)
// =============================================================================
class hbm4_stress_seq extends hbm4_base_seq;
    `uvm_object_utils(hbm4_stress_seq)
    int unsigned num_txns = 1000;

    function new(string name = "hbm4_stress_seq");
        super.new(name);
    endfunction

    task body();
        hbm4_item item;
        int i;
        `uvm_info("SEQ", $sformatf("=== Stress Sequence (%0d txns) ===", num_txns), UVM_LOW)
        for (i = 0; i < num_txns; i++) begin
            item = hbm4_item::type_id::create("stress_item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("SEQ", "Randomization failed in stress_seq")
            finish_item(item);
        end
        `uvm_info("SEQ", "=== Stress Sequence Done ===", UVM_LOW)
    endtask

endclass : hbm4_stress_seq

// =============================================================================
//  VIRTUAL SEQUENCE: All directed sequences
// =============================================================================
class hbm4_directed_vseq extends uvm_sequence;
    `uvm_object_utils(hbm4_directed_vseq)

    uvm_sequencer #(hbm4_item) seqr;

    function new(string name = "hbm4_directed_vseq");
        super.new(name);
    endfunction

    task body();
        hbm4_directed_wr_rd_seq    s1;
        hbm4_addr_sweep_seq        s2;
        hbm4_data_pattern_seq      s3;
        hbm4_dm_mask_seq           s4;
        hbm4_b2b_seq               s5;
        hbm4_boundary_seq          s6;
        hbm4_fsm_coverage_seq      s7;
        hbm4_row_sweep_seq         s8;
        hbm4_col_sweep_seq         s9;
        hbm4_read_before_write_seq s10;
        hbm4_rtl_branch_seq        s11;  // NEW: RTL branch coverage

        `uvm_info("VSEQ", "=== Starting Directed Virtual Sequence ===", UVM_LOW)
        `uvm_do_on(s1,  seqr)
        `uvm_do_on(s2,  seqr)
        `uvm_do_on(s3,  seqr)
        `uvm_do_on(s4,  seqr)
        `uvm_do_on(s5,  seqr)
        `uvm_do_on(s6,  seqr)
        `uvm_do_on(s7,  seqr)
        `uvm_do_on(s8,  seqr)
        `uvm_do_on(s9,  seqr)
        `uvm_do_on(s10, seqr)
        `uvm_do_on(s11, seqr)

        // New coverage sequences
        begin
            hbm4_dm_coverage_seq   s_dm;
            hbm4_data_coverage_seq s_dat;
            `uvm_do_on(s_dm,  seqr)
            `uvm_do_on(s_dat, seqr)
        end

        `uvm_info("VSEQ", "=== Directed Virtual Sequence Complete ===", UVM_LOW)
    endtask

endclass : hbm4_directed_vseq

// =============================================================================
//  VIRTUAL SEQUENCE: Full regression
// =============================================================================
class hbm4_full_regression_vseq extends uvm_sequence;
    `uvm_object_utils(hbm4_full_regression_vseq)

    uvm_sequencer #(hbm4_item) seqr;

    function new(string name = "hbm4_full_regression_vseq");
        super.new(name);
    endfunction

    task body();
        hbm4_directed_vseq directed_vs;
        hbm4_random_seq    rand_s;
        hbm4_stress_seq    stress_s;

        `uvm_info("VSEQ", "=== Full Regression Virtual Sequence ===", UVM_LOW)

        directed_vs      = hbm4_directed_vseq::type_id::create("directed_vs");
        directed_vs.seqr = seqr;
        directed_vs.start(null);

        rand_s          = hbm4_random_seq::type_id::create("rand_s");
        rand_s.num_txns = 200;
        rand_s.start(seqr);

        stress_s          = hbm4_stress_seq::type_id::create("stress_s");
        stress_s.num_txns = 1000;
        stress_s.start(seqr);

        `uvm_info("VSEQ", "=== Full Regression Complete ===", UVM_LOW)
    endtask

endclass : hbm4_full_regression_vseq
