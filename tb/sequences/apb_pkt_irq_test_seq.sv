//-----------------------------------------------------------------------------
// Class  : apb_pkt_irq_test_seq
// File   : tb/sequences/apb_pkt_irq_test_seq.sv
// Description:
//   IRQ chain test sequence. Exercises IRQ_FORCE, per-bit masking via
//   IRQ_ENABLE, global gating via SWITCH_CTRL.IRQ_GLOBAL_EN, and W1C
//   clearing of IRQ_STATUS.
//-----------------------------------------------------------------------------

class apb_pkt_irq_test_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_irq_test_seq)

  function new(string name = "apb_pkt_irq_test_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    // Unlock
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // ===== Test 1: IRQ_FORCE sets IRQ_STATUS =====
    `uvm_info("IRQ_TEST", "Test 1: IRQ_FORCE → IRQ_STATUS", UVM_MEDIUM)
    ral_write(reg_block.irq_force, 32'h0000_0080);  // Force SW_EVENT (bit 7)
    wait_clocks(2);
    ral_read(reg_block.irq_status, rd_val);
    if (rd_val[7] != 1'b1)
      `uvm_error("IRQ_TEST", "IRQ_FORCE did not set SW_EVENT in IRQ_STATUS!")
    else
      `uvm_info("IRQ_TEST", "PASS: SW_EVENT set by IRQ_FORCE", UVM_MEDIUM)

    // ===== Test 2: W1C clears specific bits =====
    `uvm_info("IRQ_TEST", "Test 2: W1C clears specific bits", UVM_MEDIUM)
    ral_write(reg_block.irq_status, 32'h0000_0080);  // Clear bit 7 only
    wait_clocks(2);
    ral_read(reg_block.irq_status, rd_val);
    if (rd_val[7] != 1'b0)
      `uvm_error("IRQ_TEST", "W1C did not clear SW_EVENT!")
    else
      `uvm_info("IRQ_TEST", "PASS: W1C cleared SW_EVENT", UVM_MEDIUM)

    // ===== Test 3: IRQ masked when IRQ_ENABLE bit = 0 =====
    `uvm_info("IRQ_TEST", "Test 3: IRQ masking", UVM_MEDIUM)
    ral_write(reg_block.switch_ctrl, 32'h0000_0008);  // IRQ_GLOBAL_EN=1, switch disabled
    ral_write(reg_block.irq_enable,  32'h0000_0000);  // All masked
    ral_write(reg_block.irq_force,   32'h0000_0001);  // Force GEN_DONE
    wait_clocks(2);
    // IRQ should be LOW because enable mask is 0
    ral_read(reg_block.irq_status, rd_val);
    if (rd_val[0] != 1'b1)
      `uvm_error("IRQ_TEST", "GEN_DONE not set after force!")
    `uvm_info("IRQ_TEST", "IRQ_STATUS has GEN_DONE set but masked — irq should be low", UVM_MEDIUM)

    // ===== Test 4: Unmask and verify IRQ fires =====
    `uvm_info("IRQ_TEST", "Test 4: Unmasking GEN_DONE", UVM_MEDIUM)
    ral_write(reg_block.irq_enable, 32'h0000_0001);  // Enable GEN_DONE
    wait_clocks(2);
    `uvm_info("IRQ_TEST", "irq output should now be HIGH", UVM_MEDIUM)

    // ===== Test 5: Global disable =====
    `uvm_info("IRQ_TEST", "Test 5: Global IRQ disable", UVM_MEDIUM)
    ral_write(reg_block.switch_ctrl, 32'h0000_0000);  // IRQ_GLOBAL_EN=0
    wait_clocks(2);
    `uvm_info("IRQ_TEST", "irq output should now be LOW (globally disabled)", UVM_MEDIUM)

    // Cleanup
    ral_write(reg_block.irq_status, 32'h0000_00FF);
    ral_write(reg_block.switch_ctrl, 32'h0000_0000);

    `uvm_info("IRQ_TEST", "=== IRQ chain test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_irq_test_seq
