//-----------------------------------------------------------------------------
// Class  : apb_pkt_ral_adapter
// File   : tb/ral/apb_pkt_ral_adapter.sv
// Description:
//   RAL-to-APB adapter. Converts between uvm_reg_bus_op (RAL layer) and
//   apb_seq_item (bus agent layer). Used by the register model's default_map
//   to perform frontdoor register accesses, and by the predictor to decode
//   observed bus transactions back into register operations.
//-----------------------------------------------------------------------------

class apb_pkt_ral_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_pkt_ral_adapter)

  function new(string name = "apb_pkt_ral_adapter");
    super.new(name);
    // Indicate that this adapter supports byte enables
    supports_byte_enable = 0;
    // Indicate that this adapter provides responses
    provides_responses = 0;
  endfunction

  // -------------------------------------------------------------------------
  // reg2bus: Convert RAL operation → APB transaction
  // -------------------------------------------------------------------------
  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_seq_item apb_item = apb_seq_item::type_id::create("apb_item");

    apb_item.addr = rw.addr[15:0];
    apb_item.data = rw.data;
    apb_item.rw   = (rw.kind == UVM_WRITE) ? 1'b1 : 1'b0;

    return apb_item;
  endfunction

  // -------------------------------------------------------------------------
  // bus2reg: Convert observed APB transaction → RAL operation
  // -------------------------------------------------------------------------
  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    apb_seq_item apb_item;
    if (!$cast(apb_item, bus_item)) begin
      `uvm_fatal("CAST_ERR", "bus2reg: failed to cast bus_item to apb_seq_item")
    end

    rw.addr   = apb_item.addr;
    rw.data   = apb_item.rw ? apb_item.data : apb_item.rdata;
    rw.kind   = apb_item.rw ? UVM_WRITE : UVM_READ;
    rw.status = apb_item.slverr ? UVM_NOT_OK : UVM_IS_OK;
  endfunction

endclass : apb_pkt_ral_adapter
