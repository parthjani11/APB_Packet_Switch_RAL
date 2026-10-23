//-----------------------------------------------------------------------------
// Class  : apb_pkt_ral_access_seq
// File   : tb/sequences/apb_pkt_ral_access_seq.sv
// Description:
//   Wrapper around uvm_reg_access_seq. Performs frontdoor read/write
//   access to all registers and verifies correct behavior per access policy.
//   Requires the CSR bank to be unlocked first.
//-----------------------------------------------------------------------------

class apb_pkt_ral_access_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_ral_access_seq)

  function new(string name = "apb_pkt_ral_access_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_access_seq acc_seq;

    // Must unlock first
    `uvm_info("REG_ACC", "Unlocking CSR bank before access test", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    `uvm_info("REG_ACC", "Running uvm_reg_access_seq on all registers", UVM_MEDIUM)

    acc_seq = uvm_reg_access_seq::type_id::create("acc_seq");
    acc_seq.model = reg_block;
    acc_seq.start(null, this);

    // Re-lock
    ral_write(reg_block.lock, 32'h0000_0000);

    `uvm_info("REG_ACC", "=== Register access test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_ral_access_seq
