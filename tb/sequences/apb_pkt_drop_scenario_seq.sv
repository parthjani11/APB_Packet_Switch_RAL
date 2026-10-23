//-----------------------------------------------------------------------------
// Class  : apb_pkt_drop_scenario_seq
// File   : tb/sequences/apb_pkt_drop_scenario_seq.sv
// Description:
//   Drop scenario sequence (§3.8): Configures fwd_en to block the target
//   destination, generates packets, and verifies the full error chain:
//   dest_err → ERR_STATUS → err_promote → IRQ_STATUS.ERROR → irq.
//-----------------------------------------------------------------------------

class apb_pkt_drop_scenario_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_drop_scenario_seq)

  function new(string name = "apb_pkt_drop_scenario_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    // Unlock
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // Enable switch + global IRQ
    ral_write(reg_block.switch_ctrl, 32'h0000_0009);

    // Enable all ports but only allow forwarding to port 0
    ral_write(reg_block.port_enable, 32'h0000_000F);
    ral_write(reg_block.fwd_enable,  32'h0000_0001);  // Only port 0

    // Configure generator to target port 1 (which is blocked)
    ral_write(reg_block.gen_pkt_cfg,  32'h0010_0401);  // Seed=0x10, Len=4, Src=0, Dst=1
    ral_write(reg_block.gen_interval, 32'h0000_0002);
    ral_write(reg_block.gen_count,    32'h0000_0002);  // 2 packets

    // Enable error promotion: DEST_ERROR (bit 1)
    ral_write(reg_block.err_enable, 32'h0000_0002);

    // Enable IRQ for ERROR (bit 1)
    ral_write(reg_block.irq_enable, 32'h0000_000A);  // ERROR(1) + PACKET_DROPPED(3)

    // Start generator
    ral_write(reg_block.gen_ctrl, 32'h0000_0003);

    // Wait for completion
    begin
      int timeout = 500;
      int count = 0;
      do begin
        wait_clocks(5);
        ral_read(reg_block.gen_status, rd_val);
        count++;
      end while (fval(rd_val, reg_block.gen_status.done) != 1'b1 && count < timeout);
    end

    wait_clocks(30);

    // ===== VERIFY DROP RESULTS =====
    `uvm_info("DROP_SEQ", "Verifying drop scenario results...", UVM_MEDIUM)

    // STAT_RX and STAT_TX should be 0 (all dropped)
    ral_read(reg_block.stat_rx, rd_val);
    if (rd_val[15:0] != 0)
      `uvm_error("DROP_SEQ", $sformatf("STAT_RX should be 0, got %0d", rd_val[15:0]))

    // STAT_DROP should be 2
    ral_read(reg_block.stat_drop, rd_val);
    if (rd_val[15:0] != 2)
      `uvm_error("DROP_SEQ", $sformatf("STAT_DROP should be 2, got %0d", rd_val[15:0]))

    // ERR_STATUS: DEST_ERROR (bit 1) should be set
    ral_read(reg_block.err_status, rd_val);
    `uvm_info("DROP_SEQ", $sformatf("ERR_STATUS = 0x%02h", rd_val[7:0]), UVM_MEDIUM)
    if (rd_val[1] != 1'b1)
      `uvm_error("DROP_SEQ", "ERR_STATUS.DEST_ERROR not set!")

    // IRQ_STATUS: ERROR (bit 1) and PACKET_DROPPED (bit 3) should be set
    ral_read(reg_block.irq_status, rd_val);
    `uvm_info("DROP_SEQ", $sformatf("IRQ_STATUS = 0x%02h", rd_val[7:0]), UVM_MEDIUM)
    if (rd_val[1] != 1'b1)
      `uvm_error("DROP_SEQ", "IRQ_STATUS.ERROR not set!")
    if (rd_val[3] != 1'b1)
      `uvm_error("DROP_SEQ", "IRQ_STATUS.PACKET_DROPPED not set!")

    // ERR_COUNT should be >= 2
    ral_read(reg_block.err_count, rd_val);
    `uvm_info("DROP_SEQ", $sformatf("ERR_COUNT = %0d", rd_val[15:0]), UVM_MEDIUM)

    // ERR_INFO: LAST_CODE should be 1 (DEST_ERROR), SOURCE=0 (HW), DST_PORT=1
    ral_read(reg_block.err_info, rd_val);
    `uvm_info("DROP_SEQ", $sformatf("ERR_INFO = 0x%08h", rd_val), UVM_MEDIUM)

    // Clear all status
    ral_write(reg_block.irq_status, 32'h0000_00FF);
    ral_write(reg_block.err_status, 32'h0000_00FF);

    `uvm_info("DROP_SEQ", "=== Drop scenario test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_drop_scenario_seq
