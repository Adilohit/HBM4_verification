// =============================================================================
//  hbm4_driver.sv  —  UVM Driver (QuestaSim 10.7c / UVM 1.1d compatible)
// =============================================================================
class hbm4_driver extends uvm_driver #(hbm4_item);
    `uvm_component_utils(hbm4_driver)

    virtual hbm4_if vif;

    int unsigned total_writes = 0;
    int unsigned total_reads  = 0;

    function new(string name = "hbm4_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual hbm4_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get virtual interface from config DB")
    endfunction

    task run_phase(uvm_phase phase);
        hbm4_item item;
        drive_idle();
        forever begin
            seq_item_port.get_next_item(item);
            drive_transaction(item);
            seq_item_port.item_done();
        end
    endtask

    task drive_idle();
        @(vif.driver_cb);
        vif.driver_cb.start    <= 1'b0;
        vif.driver_cb.op       <= 1'b0;
        vif.driver_cb.row_addr <= 4'h0;
        vif.driver_cb.col_addr <= 4'h0;
        vif.driver_cb.wr_d0    <= 32'h0;
        vif.driver_cb.wr_d1    <= 32'h0;
        vif.driver_cb.wr_d2    <= 32'h0;
        vif.driver_cb.wr_d3    <= 32'h0;
        vif.driver_cb.wr_d4    <= 32'h0;
        vif.driver_cb.wr_d5    <= 32'h0;
        vif.driver_cb.wr_d6    <= 32'h0;
        vif.driver_cb.wr_d7    <= 32'h0;
    endtask

    task drive_transaction(hbm4_item item);
        logic [31:0] d [0:7];
        int i;

        // Apply DM masking into local array
        for (i = 0; i < 8; i++) d[i] = item.wr_data[i];
        if (item.dm_mask[0]) begin
            d[0] = 32'h0; d[1] = 32'h0; d[2] = 32'h0; d[3] = 32'h0;
        end
        if (item.dm_mask[1]) begin
            d[4] = 32'h0; d[5] = 32'h0; d[6] = 32'h0; d[7] = 32'h0;
        end

        @(vif.driver_cb);
        vif.driver_cb.start    <= 1'b1;
        vif.driver_cb.op       <= item.op;
        vif.driver_cb.row_addr <= item.row_addr;
        vif.driver_cb.col_addr <= item.col_addr;
        vif.driver_cb.wr_d0    <= d[0];
        vif.driver_cb.wr_d1    <= d[1];
        vif.driver_cb.wr_d2    <= d[2];
        vif.driver_cb.wr_d3    <= d[3];
        vif.driver_cb.wr_d4    <= d[4];
        vif.driver_cb.wr_d5    <= d[5];
        vif.driver_cb.wr_d6    <= d[6];
        vif.driver_cb.wr_d7    <= d[7];

        @(vif.driver_cb);
        vif.driver_cb.start <= 1'b0;

        // Wait for done
        @(vif.driver_cb iff (vif.driver_cb.done === 1'b1));

        if (item.op == 1'b0) total_writes++;
        else                 total_reads++;

        `uvm_info("DRV",
            $sformatf("[%s] row=%0h col=%0h wr=%0d rd=%0d",
                item.op ? "READ" : "WRITE",
                item.row_addr, item.col_addr,
                total_writes, total_reads), UVM_HIGH)

        @(vif.driver_cb);
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("DRV", $sformatf(
            "=== Driver: writes=%0d reads=%0d ===",
            total_writes, total_reads), UVM_LOW)
    endfunction

endclass : hbm4_driver
