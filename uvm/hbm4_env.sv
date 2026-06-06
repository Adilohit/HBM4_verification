// =============================================================================
//  hbm4_env.sv  —  UVM Environment (UVM 1.1d compatible)
// =============================================================================
class hbm4_env extends uvm_env;
    `uvm_component_utils(hbm4_env)

    hbm4_agent      agent;
    hbm4_scoreboard scoreboard;
    hbm4_coverage   coverage;

    function new(string name = "hbm4_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = hbm4_agent::type_id::create("agent", this);
        scoreboard = hbm4_scoreboard::type_id::create("scoreboard", this);
        coverage   = hbm4_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.ap.connect(scoreboard.analysis_export);
        agent.ap.connect(coverage.analysis_export);
    endfunction

endclass : hbm4_env
