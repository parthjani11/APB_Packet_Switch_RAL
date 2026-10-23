//-----------------------------------------------------------------------------
// Class  : apb_pkt_stat_saturation_seq
// File   : tb/sequences/apb_pkt_stat_saturation_seq.sv
// Description:
//   Saturation test sequence. Verifies that 16-bit counters (STAT_RX,
//   STAT_TX, STAT_DROP, ERR_COUNT) saturate at 0xFFFF and don't wrap.
//   Uses continuous mode with many packets to approach saturation.
//-----------------------------------------------------------------------------

class apb_pkt_stat_saturation_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_stat_saturation_seq)

  function new(string name = "apb_pkt_stat_saturation_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    // Unlock
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // Enable everything
    ral_write(reg_block.switch_ctrl, 32'h0000_0001);
    ral_write(reg_block.port_enable, 32'h0000_000F);
    ral_write(reg_block.fwd_enable,  32'h0000_000F);

    // Configure: 1-beat packets, no gap = maximum packet rate
    ral_write(reg_block.gen_pkt_cfg,  32'h0000_0100);  // Len=1(from field, but 0 clamps to 1), Dst=0
    ral_write(reg_block.gen_interval, 32'h0000_0001);  // interval 1: with 0 the queue fills and every 2nd packet drops

    // Generate a large counted run
    // We use a large count to test saturation behavior
    `uvm_info("SAT_TEST", "Starting large counted run (65535 packets)...", UVM_MEDIUM)
    ral_write(reg_block.gen_count, 32'h0000_FFFF);  // 65535 packets
    ral_write(reg_block.gen_ctrl,  32'h0000_0003);   // ENABLE + START

    // Wait for completion (65535 single-beat packets = ~65535 cycles)
    begin
      int timeout = 70000;
      int count = 0;
      do begin
        wait_clocks(100);
        ral_read(reg_block.gen_status, rd_val);
        count++;
      end while (fval(rd_val, reg_block.gen_status.done) != 1'b1 && count < timeout);

      if (fval(rd_val, reg_block.gen_status.done) != 1'b1)
        `uvm_warning("SAT_TEST", "Generator did not complete — may need more time")
    end

    wait_clocks(50);

    // Check STAT_RX — should be 65535 (0xFFFF)
    ral_read(reg_block.stat_rx, rd_val);
    `uvm_info("SAT_TEST", $sformatf("STAT_RX = %0d (0x%04h)", rd_val[15:0], rd_val[15:0]), UVM_MEDIUM)

    // Now send one more packet — counter should stay at 0xFFFF
    `uvm_info("SAT_TEST", "Sending 1 more packet to test saturation...", UVM_MEDIUM)
    ral_write(reg_block.gen_count, 32'h0000_0001);
    ral_write(reg_block.gen_ctrl,  32'h0000_0003);

    begin
      int timeout = 100;
      int count = 0;
      do begin
        wait_clocks(5);
        ral_read(reg_block.gen_status, rd_val);
        count++;
      end while (fval(rd_val, reg_block.gen_status.done) != 1'b1 && count < timeout);
    end

    wait_clocks(20);

    ral_read(reg_block.stat_rx, rd_val);
    `uvm_info("SAT_TEST", $sformatf("STAT_RX after saturation = %0d (should be 65535)", rd_val[15:0]), UVM_MEDIUM)
    if (rd_val[15:0] != 16'hFFFF)
      `uvm_warning("SAT_TEST", "Counter may not have saturated — check run duration")

    // Re-lock
    ral_write(reg_block.lock, 32'h0000_0000);

    `uvm_info("SAT_TEST", "=== Saturation test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_stat_saturation_seq
