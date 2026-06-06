// =============================================================================
//  hbm4_agent.sv  —  UVM Agent (UVM 1.1d compatible)
// =============================================================================
class hbm4_agent extends uvm_agent;
    `uvm_component_utils(hbm4_agent)

    hbm4_driver                 drv;
    hbm4_monitor                mon;
    uvm_sequencer #(hbm4_item)  seqr;

    uvm_analysis_port #(hbm4_item) ap;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "hbm4_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap  = new("ap", this);
        mon = hbm4_monitor::type_id::create("mon", this);
        if (is_active == UVM_ACTIVE) begin
            drv  = hbm4_driver::type_id::create("drv", this);
            seqr = uvm_sequencer #(hbm4_item)::type_id::create("seqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        mon.ap.connect(ap);
        if (is_active == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass : hbm4_agent
