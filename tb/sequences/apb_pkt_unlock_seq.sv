//-----------------------------------------------------------------------------
// Class  : apb_pkt_unlock_seq
// File   : tb/sequences/apb_pkt_unlock_seq.sv
// Description:
//   Unlock sequence. Writes the magic key (0xA5A5C3C3) to the LOCK register
//   to unlock the CSR bank for configuration.
//-----------------------------------------------------------------------------

class apb_pkt_unlock_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_unlock_seq)

  function new(string name = "apb_pkt_unlock_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    `uvm_info("UNLOCK", "Writing UNLOCK_KEY (0xA5A5C3C3) to LOCK register", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // Verify unlock by reading LOCK register (should read 0 = unlocked)
    ral_read(reg_block.lock, rd_val);
    if (rd_val[0] == 1'b0)
      `uvm_info("UNLOCK", "CSR bank successfully UNLOCKED", UVM_MEDIUM)
    else
      `uvm_error("UNLOCK", $sformatf("Unlock failed! LOCK reads 0x%08h", rd_val))
  endtask

endclass : apb_pkt_unlock_seq
