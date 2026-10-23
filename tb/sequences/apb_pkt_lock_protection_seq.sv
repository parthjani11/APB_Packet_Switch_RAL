//-----------------------------------------------------------------------------
// Class  : apb_pkt_lock_protection_seq
// File   : tb/sequences/apb_pkt_lock_protection_seq.sv
// Description:
//   Lock protection sequence. Verifies that:
//   1. Lockable registers are blocked when locked
//   2. W1C/WO registers remain accessible when locked
//   3. Unlocking allows configuration writes
//-----------------------------------------------------------------------------

class apb_pkt_lock_protection_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_lock_protection_seq)

  function new(string name = "apb_pkt_lock_protection_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;
    uvm_reg_data_t before_val;

    // Ensure we start locked
    ral_write(reg_block.lock, 32'h0000_0000);

    // ===== Test 1: Lockable register writes are blocked =====
    `uvm_info("LOCK_PROT", "Test 1: Writing to locked PORT_ENABLE should be ignored", UVM_MEDIUM)
    ral_read(reg_block.port_enable, before_val);
    ral_write(reg_block.port_enable, 32'h0000_0005);  // Try to change
    ral_read(reg_block.port_enable, rd_val);
    if (rd_val[3:0] != before_val[3:0])
      `uvm_error("LOCK_PROT", "PORT_ENABLE changed while locked!")
    else
      `uvm_info("LOCK_PROT", "PASS: PORT_ENABLE unchanged (write blocked)", UVM_MEDIUM)

    // ===== Test 2: W1C registers remain writable when locked =====
    `uvm_info("LOCK_PROT", "Test 2: W1C IRQ_STATUS should be writable when locked", UVM_MEDIUM)
    // Force an IRQ event first
    ral_write(reg_block.irq_force, 32'h0000_0080);  // Always accessible
    wait_clocks(2);
    ral_read(reg_block.irq_status, rd_val);
    if (rd_val[7] != 1'b1)
      `uvm_error("LOCK_PROT", "IRQ_FORCE did not work when locked!")

    // Clear it with W1C
    ral_write(reg_block.irq_status, 32'h0000_0080);
    wait_clocks(2);
    ral_read(reg_block.irq_status, rd_val);
    if (rd_val[7] != 1'b0)
      `uvm_error("LOCK_PROT", "W1C clear of IRQ_STATUS failed when locked!")
    else
      `uvm_info("LOCK_PROT", "PASS: W1C IRQ_STATUS works while locked", UVM_MEDIUM)

    // ===== Test 3: SOFT_RESET accessible when locked =====
    `uvm_info("LOCK_PROT", "Test 3: SOFT_RESET should be accessible when locked", UVM_MEDIUM)
    // (Don't actually reset — just verify the write goes through without error)
    // We'll test ERR_INJECT instead as it's also always-accessible WO
    ral_write(reg_block.err_inject, 32'h0000_0001);
    wait_clocks(2);
    ral_read(reg_block.err_status, rd_val);
    if (rd_val[0] != 1'b1)
      `uvm_error("LOCK_PROT", "ERR_INJECT did not work when locked!")
    else
      `uvm_info("LOCK_PROT", "PASS: ERR_INJECT works while locked", UVM_MEDIUM)

    // ===== Test 4: Unlock and verify writes succeed =====
    `uvm_info("LOCK_PROT", "Test 4: Unlock and write PORT_ENABLE", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'hA5A5_C3C3);
    ral_write(reg_block.port_enable, 32'h0000_0005);
    ral_read(reg_block.port_enable, rd_val);
    if (rd_val[3:0] != 4'h5)
      `uvm_error("LOCK_PROT", "PORT_ENABLE not updated after unlock!")
    else
      `uvm_info("LOCK_PROT", "PASS: PORT_ENABLE changed after unlock", UVM_MEDIUM)

    // Restore defaults and re-lock
    ral_write(reg_block.port_enable, 32'h0000_000F);
    ral_write(reg_block.err_status,  32'h0000_00FF);
    ral_write(reg_block.lock, 32'h0000_0000);

    `uvm_info("LOCK_PROT", "=== Lock protection test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_lock_protection_seq
