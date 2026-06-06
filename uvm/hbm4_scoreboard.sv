// =============================================================================
//  hbm4_scoreboard.sv  —  Reference Memory Scoreboard (UVM 1.1d compatible)
// =============================================================================
class hbm4_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(hbm4_scoreboard)

    uvm_analysis_imp #(hbm4_item, hbm4_scoreboard) analysis_export;

    // Reference memory: [mem_addr 0..15][beat 0..7]
    logic [31:0] ref_mem [0:15][0:7];
    bit          mem_written [0:15];

    int unsigned pass_cnt  = 0;
    int unsigned fail_cnt  = 0;
    int unsigned write_cnt = 0;
    int unsigned read_cnt  = 0;

    function new(string name = "hbm4_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        int i, j;
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        for (i = 0; i < 16; i++) begin
            mem_written[i] = 1'b0;
            for (j = 0; j < 8; j++)
                ref_mem[i][j] = 32'h0;
        end
    endfunction

    function void write(hbm4_item item);
        logic [3:0] mem_addr;
        logic [31:0] d [0:7];
        int i;
        bit local_fail;

        mem_addr = {item.row_addr[1:0], item.col_addr[1:0]};

        if (item.op == 1'b0) begin
            // WRITE
            write_cnt++;
            for (i = 0; i < 8; i++) d[i] = item.wr_data[i];
            // DM masking: driver already zeroed masked beats in wr_data
            // Scoreboard trusts what was driven
            for (i = 0; i < 8; i++)
                ref_mem[mem_addr][i] = d[i];
            mem_written[mem_addr] = 1'b1;

            `uvm_info("SB",
                $sformatf("[WRITE] b0 r%0h c%0h data=0x%08h dm=%b ref->0x%08h",
                    item.row_addr, item.col_addr,
                    item.wr_data[0], item.dm_mask,
                    ref_mem[mem_addr][0]),
                UVM_MEDIUM)

        end else begin
            // READ
            read_cnt++;
            local_fail = 1'b0;

            for (i = 0; i < 8; i++) begin
                if (item.rd_data[i] !== ref_mem[mem_addr][i]) begin
                    `uvm_error("SB",
                        $sformatf("[FAIL] b0 r%0h c%0h beat[%0d] got=0x%08h exp=0x%08h",
                            item.row_addr, item.col_addr, i,
                            item.rd_data[i], ref_mem[mem_addr][i]))
                    local_fail = 1'b1;
                end
            end

            if (local_fail) begin
                fail_cnt++;
            end else begin
                pass_cnt++;
                `uvm_info("SB",
                    $sformatf("[PASS] b0 r%0h c%0h got=0x%08h exp=0x%08h",
                        item.row_addr, item.col_addr,
                        item.rd_data[0], ref_mem[mem_addr][0]),
                    UVM_MEDIUM)
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", "============================================================", UVM_NONE)
        `uvm_info("SB", "  SCOREBOARD SUMMARY",                                        UVM_NONE)
        `uvm_info("SB", $sformatf("  Total WRITEs : %0d", write_cnt),                 UVM_NONE)
        `uvm_info("SB", $sformatf("  Total READs  : %0d", read_cnt),                  UVM_NONE)
        `uvm_info("SB", $sformatf("  PASS count   : %0d", pass_cnt),                  UVM_NONE)
        `uvm_info("SB", $sformatf("  FAIL count   : %0d", fail_cnt),                  UVM_NONE)
        if (fail_cnt == 0)
            `uvm_info("SB", "  RESULT: *** TEST PASSED - Zero Mismatches ***",         UVM_NONE)
        else
            `uvm_error("SB", $sformatf(
                "  RESULT: *** TEST FAILED - %0d Mismatches ***", fail_cnt))
        `uvm_info("SB", "============================================================", UVM_NONE)
    endfunction

endclass : hbm4_scoreboard
