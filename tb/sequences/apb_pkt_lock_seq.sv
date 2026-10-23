//-----------------------------------------------------------------------------
// Class  : apb_pkt_lock_seq
// File   : tb/sequences/apb_pkt_lock_seq.sv
// Description:
//   Lock sequence. Writes any value other than the magic key to the LOCK
//   register to re-lock the CSR bank.
//-----------------------------------------------------------------------------

class apb_pkt_lock_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_lock_seq)

  function new(string name = "apb_pkt_lock_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    `uvm_info("LOCK", "Writing 0x00000000 to LOCK register (re-lock)", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'h0000_0000);

    // Verify lock by reading LOCK register (should read 1 = locked)
    ral_read(reg_block.lock, rd_val);
    if (rd_val[0] == 1'b1)
      `uvm_info("LOCK", "CSR bank successfully LOCKED", UVM_MEDIUM)
    else
      `uvm_error("LOCK", $sformatf("Lock failed! LOCK reads 0x%08h", rd_val))
  endtask

endclass : apb_pkt_lock_seq
