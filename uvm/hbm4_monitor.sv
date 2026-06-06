// =============================================================================
//  hbm4_monitor.sv  —  UVM Monitor (QuestaSim 10.7c / UVM 1.1d compatible)
// =============================================================================
class hbm4_monitor extends uvm_monitor;
    `uvm_component_utils(hbm4_monitor)

    virtual hbm4_if vif;

    uvm_analysis_port #(hbm4_item) ap;

    int unsigned total_writes_mon = 0;
    int unsigned total_reads_mon  = 0;

    function new(string name = "hbm4_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual hbm4_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get virtual interface from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            collect_transaction();
        end
    endtask

    task collect_transaction();
        hbm4_item item;
        int i;
        item = hbm4_item::type_id::create("mon_item");

        // Wait for start
        @(vif.monitor_cb iff (vif.monitor_cb.start === 1'b1));

        item.op       = vif.monitor_cb.op;
        item.row_addr = vif.monitor_cb.row_addr;
        item.col_addr = vif.monitor_cb.col_addr;
        item.wr_data[0] = vif.monitor_cb.wr_d0;
        item.wr_data[1] = vif.monitor_cb.wr_d1;
        item.wr_data[2] = vif.monitor_cb.wr_d2;
        item.wr_data[3] = vif.monitor_cb.wr_d3;
        item.wr_data[4] = vif.monitor_cb.wr_d4;
        item.wr_data[5] = vif.monitor_cb.wr_d5;
        item.wr_data[6] = vif.monitor_cb.wr_d6;
        item.wr_data[7] = vif.monitor_cb.wr_d7;

        // Infer dm_mask: driver zeros beats when dm_mask bit is set
        begin
            bit d0_z, d1_z;
            d0_z = (item.wr_data[0]==32'h0 && item.wr_data[1]==32'h0 &&
                    item.wr_data[2]==32'h0 && item.wr_data[3]==32'h0);
            d1_z = (item.wr_data[4]==32'h0 && item.wr_data[5]==32'h0 &&
                    item.wr_data[6]==32'h0 && item.wr_data[7]==32'h0);
            item.dm_mask = {d1_z, d0_z};
        end

        if (item.op == 1'b0) total_writes_mon++;
        else                 total_reads_mon++;

        // Wait for done
        @(vif.monitor_cb iff (vif.monitor_cb.done === 1'b1));

        if (item.op == 1'b1) begin
            item.rd_valid    = 1'b1;
            item.rd_data[0]  = vif.monitor_cb.rd_data[0];
            item.rd_data[1]  = vif.monitor_cb.rd_data[1];
            item.rd_data[2]  = vif.monitor_cb.rd_data[2];
            item.rd_data[3]  = vif.monitor_cb.rd_data[3];
            item.rd_data[4]  = vif.monitor_cb.rd_data[4];
            item.rd_data[5]  = vif.monitor_cb.rd_data[5];
            item.rd_data[6]  = vif.monitor_cb.rd_data[6];
            item.rd_data[7]  = vif.monitor_cb.rd_data[7];
        end else begin
            item.rd_valid = 1'b0;
            for (i = 0; i < 8; i++) item.rd_data[i] = 32'h0;
        end

        `uvm_info("MON",
            $sformatf("[%s] row=%0h col=%0h rd_valid=%0b d0=0x%08h",
                item.op ? "READ " : "WRITE",
                item.row_addr, item.col_addr,
                item.rd_valid, item.rd_data[0]), UVM_HIGH)

        ap.write(item);
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("MON", $sformatf(
            "=== Monitor: writes=%0d reads=%0d ===",
            total_writes_mon, total_reads_mon), UVM_LOW)
    endfunction

endclass : hbm4_monitor
