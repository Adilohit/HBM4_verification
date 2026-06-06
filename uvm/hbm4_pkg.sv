// =============================================================================
//  hbm4_pkg.sv  —  UVM Package for HBM4 Bank Model
//  Compatible with QuestaSim 10.7c / UVM 1.1d (built-in mtiUvm)
// =============================================================================
package hbm4_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------------------------
    // Global Parameters matching DUT
    // -------------------------------------------------------------------------
    parameter int DQ_W      = 32;
    parameter int WL        = 4;
    parameter int RL        = 6;
    parameter int BL        = 8;
    parameter int tRCD      = 7;
    parameter int tWR       = 6;
    parameter int tRTP      = 4;
    parameter int tRP       = 7;
    parameter int tWTR      = 4;
    parameter int MEM_DEPTH = 16;
    parameter int DATA_CK   = 2;   // BL/4

    parameter int NUM_ROWS  = 16;
    parameter int NUM_COLS  = 16;
    parameter int MEM_SIZE  = 16;

    // Include order is critical — each file depends on the ones above it
    `include "hbm4_item.sv"
    `include "hbm4_seq_lib.sv"
    `include "hbm4_driver.sv"
    `include "hbm4_monitor.sv"
    `include "hbm4_scoreboard.sv"
    `include "hbm4_coverage.sv"
    `include "hbm4_agent.sv"
    `include "hbm4_env.sv"
    `include "hbm4_test_lib.sv"

endpackage : hbm4_pkg
