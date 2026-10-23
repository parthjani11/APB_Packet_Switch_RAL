//-----------------------------------------------------------------------------
// Class  : apb_pkt_continuous_mode_seq
// File   : tb/sequences/apb_pkt_continuous_mode_seq.sv
// Description:
//   Continuous mode sequence. Sets CONTINUOUS=1, starts the generator,
//   lets it run for a while, then stops it mid-stream. Verifies that
//   packets were generated and the generator returns to IDLE.
//-----------------------------------------------------------------------------

class apb_pkt_continuous_mode_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_continuous_mode_seq)

  int unsigned run_cycles = 200;  // How many cycles to let it run

  function new(string name = "apb_pkt_continuous_mode_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    // Unlock
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // Enable everything
    ral_write(reg_block.switch_ctrl, 32'h0000_0009);
    ral_write(reg_block.port_enable, 32'h0000_000F);
    ral_write(reg_block.fwd_enable,  32'h0000_000F);

    // Configure: short packets, no gap, continuous
    ral_write(reg_block.gen_pkt_cfg,  32'h0020_0200);  // Seed=0x20, Len=2, Dst=0
    ral_write(reg_block.gen_interval, 32'h0000_0000);  // Back-to-back
    ral_write(reg_block.gen_count,    32'h0000_000A);  // Count ignored in continuous mode

    // Start in continuous mode: ENABLE=1, START=1, CONTINUOUS=1
    `uvm_info("CONT_MODE", "Starting generator in CONTINUOUS mode", UVM_MEDIUM)
    ral_write(reg_block.gen_ctrl, 32'h0000_000B);  // bits: CONTINUOUS|START|ENABLE

    // Let it run
    `uvm_info("CONT_MODE", $sformatf("Letting generator run for %0d cycles...", run_cycles), UVM_MEDIUM)
    wait_clocks(run_cycles);

    // Check that it's still running (should NOT be DONE)
    ral_read(reg_block.gen_status, rd_val);
    `uvm_info("CONT_MODE", $sformatf("GEN_STATUS = 0x%08h (RUNNING=%0b, DONE=%0b)",
              rd_val, fval(rd_val, reg_block.gen_status.running), fval(rd_val, reg_block.gen_status.done)), UVM_MEDIUM)
    if (fval(rd_val, reg_block.gen_status.running) != 1'b1)
      `uvm_error("CONT_MODE", "Generator not running in continuous mode!")
    if (fval(rd_val, reg_block.gen_status.done) == 1'b1)
      `uvm_error("CONT_MODE", "Generator reached DONE in continuous mode!")

    // Read stats — should have generated many packets
    ral_read(reg_block.stat_rx, rd_val);
    `uvm_info("CONT_MODE", $sformatf("STAT_RX = %0d packets forwarded so far", rd_val[15:0]), UVM_MEDIUM)
    if (rd_val[15:0] == 0)
      `uvm_error("CONT_MODE", "No packets generated in continuous mode!")

    // STOP the generator
    `uvm_info("CONT_MODE", "Sending STOP command", UVM_MEDIUM)
    ral_write(reg_block.gen_ctrl, 32'h0000_0005);  // STOP=1, ENABLE=1

    wait_clocks(10);

    // Verify it stopped (FSM should be IDLE)
    ral_read(reg_block.gen_status, rd_val);
    `uvm_info("CONT_MODE", $sformatf("After STOP: GEN_STATUS = 0x%08h", rd_val), UVM_MEDIUM)
    if (fval(rd_val, reg_block.gen_status.running) != 1'b0)
      `uvm_error("CONT_MODE", "Generator still running after STOP!")

    // Re-lock
    ral_write(reg_block.lock, 32'h0000_0000);

    `uvm_info("CONT_MODE", "=== Continuous mode test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_continuous_mode_seq
