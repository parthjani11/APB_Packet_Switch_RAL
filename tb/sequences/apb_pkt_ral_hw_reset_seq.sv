//-----------------------------------------------------------------------------
// Class  : apb_pkt_ral_hw_reset_seq
// File   : tb/sequences/apb_pkt_ral_hw_reset_seq.sv
// Description:
//   Wrapper around uvm_reg_hw_reset_seq. Reads every register after reset
//   and verifies its value matches the RAL model's reset value.
//-----------------------------------------------------------------------------

class apb_pkt_ral_hw_reset_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_ral_hw_reset_seq)

  function new(string name = "apb_pkt_ral_hw_reset_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_hw_reset_seq reset_seq;

    `uvm_info("HW_RESET", "Running uvm_reg_hw_reset_seq on all registers", UVM_MEDIUM)

    reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
    reset_seq.model = reg_block;
    // write-only registers have nothing to read back
    skip_reg(reg_block.irq_force,  "NO_REG_HW_RESET_TEST");
    skip_reg(reg_block.err_inject, "NO_REG_HW_RESET_TEST");
    skip_reg(reg_block.soft_reset, "NO_REG_HW_RESET_TEST");
    reset_seq.start(null, this);

    `uvm_info("HW_RESET", "=== Hardware reset value check COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_ral_hw_reset_seq
