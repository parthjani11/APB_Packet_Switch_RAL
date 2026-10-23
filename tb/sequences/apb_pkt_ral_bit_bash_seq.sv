//-----------------------------------------------------------------------------
// Class  : apb_pkt_ral_bit_bash_seq
// File   : tb/sequences/apb_pkt_ral_bit_bash_seq.sv
// Description:
//   Wrapper around uvm_reg_bit_bash_seq. Writes walking-1 and walking-0
//   patterns to each RW field and verifies correct behavior.
//   Requires the CSR bank to be unlocked first.
//-----------------------------------------------------------------------------

class apb_pkt_ral_bit_bash_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_ral_bit_bash_seq)

  function new(string name = "apb_pkt_ral_bit_bash_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_bit_bash_seq bb_seq;

    // Must unlock first so RW registers accept writes
    `uvm_info("BIT_BASH", "Unlocking CSR bank before bit-bash", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    `uvm_info("BIT_BASH", "Running uvm_reg_bit_bash_seq on all RW registers", UVM_MEDIUM)

    bb_seq = uvm_reg_bit_bash_seq::type_id::create("bb_seq");
    bb_seq.model = reg_block;
    // LOCK (any non-key write re-locks) and SOFT_RESET (resets the DUT) would corrupt the run
    skip_reg(reg_block.lock,       "NO_REG_BIT_BASH_TEST");
    skip_reg(reg_block.soft_reset, "NO_REG_BIT_BASH_TEST");
    bb_seq.start(null, this);

    // Re-lock
    ral_write(reg_block.lock, 32'h0000_0000);

    `uvm_info("BIT_BASH", "=== Bit bash test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_ral_bit_bash_seq
