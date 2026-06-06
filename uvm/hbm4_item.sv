// =============================================================================
//  hbm4_item.sv  —  Sequence Item (UVM 1.1d compatible)
//  Fix: uvm_field_sarray_int not in UVM 1.1d → use do_copy/do_compare manually
// =============================================================================
class hbm4_item extends uvm_sequence_item;
    `uvm_object_utils(hbm4_item)

    // -------------------------------------------------------------------------
    // Stimulus fields
    // -------------------------------------------------------------------------
    rand logic        op;           // 0=WRITE 1=READ
    rand logic [3:0]  row_addr;
    rand logic [3:0]  col_addr;
    rand logic [31:0] wr_data [0:7];
    rand logic [1:0]  dm_mask;

    // Response fields (filled by monitor)
    logic [31:0]      rd_data [0:7];
    logic             rd_valid;

    // -------------------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------------------
    constraint c_row_range { row_addr inside {[4'h0 : 4'hF]}; }
    constraint c_col_range { col_addr inside {[4'h0 : 4'hF]}; }

    constraint c_op_dist {
        op dist { 1'b0 := 50, 1'b1 := 50 };
    }

    constraint c_dm_dist {
        dm_mask dist { 2'b00 := 40, 2'b01 := 20, 2'b10 := 20, 2'b11 := 20 };
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "hbm4_item");
        super.new(name);
    endfunction

    // -------------------------------------------------------------------------
    // do_copy
    // -------------------------------------------------------------------------
    function void do_copy(uvm_object rhs);
        hbm4_item rhs_;
        int i;
        super.do_copy(rhs);
        if (!$cast(rhs_, rhs))
            `uvm_fatal("ITEM", "do_copy: type mismatch")
        op       = rhs_.op;
        row_addr = rhs_.row_addr;
        col_addr = rhs_.col_addr;
        dm_mask  = rhs_.dm_mask;
        rd_valid = rhs_.rd_valid;
        for (i = 0; i < 8; i++) begin
            wr_data[i] = rhs_.wr_data[i];
            rd_data[i] = rhs_.rd_data[i];
        end
    endfunction

    // -------------------------------------------------------------------------
    // do_compare
    // -------------------------------------------------------------------------
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        hbm4_item rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (op       == rhs_.op      &&
                row_addr == rhs_.row_addr &&
                col_addr == rhs_.col_addr);
    endfunction

    // -------------------------------------------------------------------------
    // convert2string
    // -------------------------------------------------------------------------
    function string convert2string();
        string s;
        s = $sformatf("op=%s row=0x%0h col=0x%0h dm=%b wd0=0x%08h",
                       op ? "READ" : "WRITE",
                       row_addr, col_addr, dm_mask, wr_data[0]);
        return s;
    endfunction

endclass : hbm4_item
