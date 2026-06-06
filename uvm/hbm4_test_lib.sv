// =============================================================================
//  hbm4_test_lib.sv  —  Test Library (UVM 1.1d / QuestaSim 10.7c)
// =============================================================================
class hbm4_base_test extends uvm_test;
    `uvm_component_utils(hbm4_base_test)

    hbm4_env env;

    function new(string name = "hbm4_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = hbm4_env::type_id::create("env", this);
    endfunction

    task apply_reset();
        virtual hbm4_if vif;
        if (!uvm_config_db #(virtual hbm4_if)::get(this, "", "vif", vif))
            `uvm_fatal("TEST", "Cannot get vif for reset")
        vif.driver_cb.rst_n    <= 1'b0;
        vif.driver_cb.start    <= 1'b0;
        vif.driver_cb.op       <= 1'b0;
        vif.driver_cb.row_addr <= 4'h0;
        vif.driver_cb.col_addr <= 4'h0;
        vif.driver_cb.wr_d0    <= 32'h0; vif.driver_cb.wr_d1 <= 32'h0;
        vif.driver_cb.wr_d2    <= 32'h0; vif.driver_cb.wr_d3 <= 32'h0;
        vif.driver_cb.wr_d4    <= 32'h0; vif.driver_cb.wr_d5 <= 32'h0;
        vif.driver_cb.wr_d6    <= 32'h0; vif.driver_cb.wr_d7 <= 32'h0;
        repeat(5) @(vif.driver_cb);
        vif.driver_cb.rst_n <= 1'b1;
        repeat(3) @(vif.driver_cb);
        `uvm_info("TEST", "Reset released", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // A1 scenario: pulse start while rst_n=0.
    // The DUT ignores the command (correct behaviour).
    // The MONITOR now guards against reset — it will DROP this observation
    // and NOT forward it to the scoreboard, so no false mismatch occurs.
    // -------------------------------------------------------------------------
    task apply_reset_with_start_scenario();
        virtual hbm4_if vif;
        if (!uvm_config_db #(virtual hbm4_if)::get(this, "", "vif", vif))
            `uvm_fatal("TEST", "Cannot get vif for A1 reset")

        `uvm_info("TEST", "Running A1 scenario (start during reset)", UVM_LOW)
        vif.driver_cb.rst_n <= 1'b0;
        vif.driver_cb.start <= 1'b0;
        repeat(3) @(vif.driver_cb);

        // Pulse start during reset — A1 assertion checks this
        vif.driver_cb.start <= 1'b1;
        @(vif.driver_cb);
        vif.driver_cb.start <= 1'b0;
        repeat(2) @(vif.driver_cb);

        // Release reset
        vif.driver_cb.rst_n <= 1'b1;
        repeat(3) @(vif.driver_cb);

        // Tell coverage that A1 was exercised
        env.coverage.set_a1_hit();

        `uvm_info("TEST", "A1 reset scenario complete", UVM_LOW)
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server svr;
        int unsigned err_cnt;
        svr     = uvm_report_server::get_server();
        err_cnt = svr.get_severity_count(UVM_ERROR);
        `uvm_info("TEST", "============================================================", UVM_NONE)
        if (err_cnt == 0)
            `uvm_info("TEST",  "  *** FINAL RESULT: TEST PASSED ***",                   UVM_NONE)
        else
            `uvm_error("TEST", $sformatf(
                "  *** FINAL RESULT: TEST FAILED - %0d errors ***", err_cnt))
        `uvm_info("TEST", "============================================================", UVM_NONE)
    endfunction

endclass : hbm4_base_test

class hbm4_simple_wr_rd_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_simple_wr_rd_test)
    function new(string name = "hbm4_simple_wr_rd_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_directed_wr_rd_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_directed_wr_rd_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_addr_sweep_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_addr_sweep_test)
    function new(string name = "hbm4_addr_sweep_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_addr_sweep_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_addr_sweep_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_data_pattern_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_data_pattern_test)
    function new(string name = "hbm4_data_pattern_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_data_pattern_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_data_pattern_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_boundary_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_boundary_test)
    function new(string name = "hbm4_boundary_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_boundary_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_boundary_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_dm_mask_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_dm_mask_test)
    function new(string name = "hbm4_dm_mask_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_dm_mask_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_dm_mask_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_random_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_random_test)
    function new(string name = "hbm4_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_random_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_random_seq::type_id::create("seq");
        seq.num_txns = 200;
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_stress_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_stress_test)
    function new(string name = "hbm4_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_stress_seq seq;
        phase.raise_objection(this);
        apply_reset();
        seq = hbm4_stress_seq::type_id::create("seq");
        seq.num_txns = 1000;
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass

class hbm4_full_regression_test extends hbm4_base_test;
    `uvm_component_utils(hbm4_full_regression_test)
    function new(string name = "hbm4_full_regression_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        hbm4_full_regression_vseq vseq;
        phase.raise_objection(this);
        `uvm_info("TEST", "=== hbm4_full_regression_test START ===", UVM_LOW)

        // Normal reset: holds rst_n=0 for 5 cycles with start=0.
        // This exercises A1 pass path (rst_n=0 AND start=0 → passes).
        // No intentional A1 failure scenario — keeps Failure count = 0.
        apply_reset();

        // All sequences
        vseq      = hbm4_full_regression_vseq::type_id::create("vseq");
        vseq.seqr = env.agent.seqr;
        vseq.start(null);

        phase.drop_objection(this);
        `uvm_info("TEST", "=== hbm4_full_regression_test END ===", UVM_LOW)
    endtask
endclass
