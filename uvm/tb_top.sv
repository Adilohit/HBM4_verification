// =============================================================================
//  tb_top.sv  —  UVM Testbench Top (QuestaSim 10.7c / UVM 1.1d)
//
//  Compilation order:
//    vlog hbm4_bank_model.sv
//    vlog hbm4_pkg.sv hbm4_if.sv tb_top.sv
//
//  Run:
//    vsim work.tb_top +UVM_TESTNAME=hbm4_full_regression_test
// =============================================================================
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

import hbm4_pkg::*;

module tb_top;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam real CK_PERIOD   = 10.0;   // 100 MHz
    localparam real CK2X_PERIOD =  5.0;   // 200 MHz

    // -------------------------------------------------------------------------
    // Clocks
    // -------------------------------------------------------------------------
    logic clk    = 1'b0;
    logic clk_2x = 1'b1;   // starts HIGH → phase-aligned posedges

    always #(CK_PERIOD   / 2.0) clk    = ~clk;
    always #(CK2X_PERIOD / 2.0) clk_2x = ~clk_2x;

    // -------------------------------------------------------------------------
    // Interface
    // -------------------------------------------------------------------------
    hbm4_if dut_if (.clk(clk), .clk_2x(clk_2x));

    // -------------------------------------------------------------------------
    // DUT — use localparams to avoid hbm4_pkg:: references in port map
    // -------------------------------------------------------------------------
    localparam int P_WL        = 4;
    localparam int P_RL        = 6;
    localparam int P_BL        = 8;
    localparam int P_tRCD      = 7;
    localparam int P_tWTR      = 4;
    localparam int P_tWR       = 6;
    localparam int P_tRTP      = 4;
    localparam int P_tRP       = 7;
    localparam int P_MEM_DEPTH = 16;
    localparam int P_DQ_W      = 32;

    hbm4_bank_model #(
        .WL       (P_WL),
        .RL       (P_RL),
        .BL       (P_BL),
        .tRCD     (P_tRCD),
        .tWTR     (P_tWTR),
        .tWR      (P_tWR),
        .tRTP     (P_tRTP),
        .tRP      (P_tRP),
        .MEM_DEPTH(P_MEM_DEPTH),
        .DQ_W     (P_DQ_W)
    ) dut (
        .clk     (clk),
        .clk_2x  (clk_2x),
        .rst_n   (dut_if.rst_n),
        .start   (dut_if.start),
        .op      (dut_if.op),
        .row_addr(dut_if.row_addr),
        .col_addr(dut_if.col_addr),
        .wr_d0(dut_if.wr_d0), .wr_d1(dut_if.wr_d1),
        .wr_d2(dut_if.wr_d2), .wr_d3(dut_if.wr_d3),
        .wr_d4(dut_if.wr_d4), .wr_d5(dut_if.wr_d5),
        .wr_d6(dut_if.wr_d6), .wr_d7(dut_if.wr_d7),
        .CK_t(dut_if.CK_t), .CK_c(dut_if.CK_c),
        .R_rise(dut_if.R_rise), .R_fall(dut_if.R_fall),
        .C_rise(dut_if.C_rise), .C_fall(dut_if.C_fall),
        .WDQS_t(dut_if.WDQS_t), .WDQS_c(dut_if.WDQS_c),
        .RDQS_t(dut_if.RDQS_t), .RDQS_c(dut_if.RDQS_c),
        .DQ      (dut_if.DQ),
        .done    (dut_if.done),
        .rd_valid(dut_if.rd_valid),
        .rd_data (dut_if.rd_data)
    );

    // -------------------------------------------------------------------------
    // UVM startup
    // -------------------------------------------------------------------------
    initial begin
        // Register the plain (non-parameterized) virtual interface
        uvm_config_db #(virtual hbm4_if)::set(null, "*", "vif", dut_if);
        run_test();
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #(CK_PERIOD * 500_000);
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500000 cycles")
    end

endmodule : tb_top
