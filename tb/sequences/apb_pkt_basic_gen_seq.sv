//-----------------------------------------------------------------------------
// Class  : apb_pkt_basic_gen_seq
// File   : tb/sequences/apb_pkt_basic_gen_seq.sv
// Description:
//   Full programming flow sequence (Steps 1-9 from spec §3.7):
//   Unlock → Enable ports → Enable switch + IRQ → Configure packet →
//   Enable interrupts → Start generator → Wait → Check results → Re-lock.
//-----------------------------------------------------------------------------

class apb_pkt_basic_gen_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_basic_gen_seq)

  // Configurable parameters
  int unsigned pkt_count    = 4;
  int unsigned pkt_length   = 4;
  int unsigned pkt_interval = 2;
  int unsigned pkt_seed     = 8'h10;
  int unsigned pkt_dst      = 1;
  int unsigned pkt_src      = 0;

  function new(string name = "apb_pkt_basic_gen_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;
    uvm_reg_data_t pkt_cfg_val;

    // ===== STEP 1: UNLOCK =====
    `uvm_info("BASIC_GEN", "Step 1: Unlock CSR bank", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // ===== STEP 2: ENABLE PORTS =====
    `uvm_info("BASIC_GEN", "Step 2: Enable all ports and forwarding", UVM_MEDIUM)
    ral_write(reg_block.port_enable, 32'h0000_000F);
    ral_write(reg_block.fwd_enable,  32'h0000_000F);

    // ===== STEP 3: ENABLE SWITCH + GLOBAL IRQ =====
    `uvm_info("BASIC_GEN", "Step 3: Enable switch + global IRQ", UVM_MEDIUM)
    ral_write(reg_block.switch_ctrl, 32'h0000_0009);  // ENABLE=1, IRQ_GLOBAL_EN=1

    // ===== STEP 4: CONFIGURE PACKET FORMAT =====
    `uvm_info("BASIC_GEN", "Step 4: Configure packet format", UVM_MEDIUM)
    pkt_cfg_val = pack_fld(reg_block.gen_pkt_cfg.seed, pkt_seed) | pack_fld(reg_block.gen_pkt_cfg.length, pkt_length) |
                  pack_fld(reg_block.gen_pkt_cfg.src_port, pkt_src) | pack_fld(reg_block.gen_pkt_cfg.dst_port, pkt_dst);
    ral_write(reg_block.gen_pkt_cfg,  pkt_cfg_val);
    ral_write(reg_block.gen_interval, pkt_interval);
    ral_write(reg_block.gen_count,    pkt_count);

    // ===== STEP 5: ENABLE INTERRUPTS =====
    `uvm_info("BASIC_GEN", "Step 5: Enable GEN_DONE + START_ACK interrupts", UVM_MEDIUM)
    ral_write(reg_block.irq_enable, 32'h0000_0041);  // bits 0 and 6

    // ===== STEP 6: START GENERATOR =====
    `uvm_info("BASIC_GEN", "Step 6: Start generator (ENABLE + START)", UVM_MEDIUM)
    ral_write(reg_block.gen_ctrl, 32'h0000_0003);     // ENABLE=1, START=1

    // ===== STEP 7: WAIT FOR COMPLETION =====
    `uvm_info("BASIC_GEN", "Step 7: Waiting for generator to complete...", UVM_MEDIUM)
    begin
      int timeout = 1000;
      int count = 0;
      do begin
        wait_clocks(5);
        ral_read(reg_block.gen_status, rd_val);
        count++;
      end while (fval(rd_val, reg_block.gen_status.done) != 1'b1 && count < timeout);  // Wait for DONE bit

      if (fval(rd_val, reg_block.gen_status.done) != 1'b1)
        `uvm_error("BASIC_GEN", "Generator did not complete within timeout!")
      else
        `uvm_info("BASIC_GEN", $sformatf("Generator DONE after %0d polls", count), UVM_MEDIUM)
    end

    // Wait extra cycles for queue drain
    wait_clocks(50);

    // ===== STEP 8: CHECK RESULTS =====
    `uvm_info("BASIC_GEN", "Step 8: Checking results", UVM_MEDIUM)

    ral_read(reg_block.stat_rx, rd_val);
    `uvm_info("BASIC_GEN", $sformatf("STAT_RX  = %0d (expected %0d)", rd_val[15:0], pkt_count), UVM_MEDIUM)
    if (rd_val[15:0] != pkt_count)
      `uvm_error("BASIC_GEN", $sformatf("STAT_RX mismatch: got %0d, expected %0d", rd_val[15:0], pkt_count))

    ral_read(reg_block.stat_tx, rd_val);
    `uvm_info("BASIC_GEN", $sformatf("STAT_TX  = %0d (expected %0d)", rd_val[15:0], pkt_count), UVM_MEDIUM)
    if (rd_val[15:0] != pkt_count)
      `uvm_error("BASIC_GEN", $sformatf("STAT_TX mismatch: got %0d, expected %0d", rd_val[15:0], pkt_count))

    ral_read(reg_block.stat_drop, rd_val);
    `uvm_info("BASIC_GEN", $sformatf("STAT_DROP = %0d (expected 0)", rd_val[15:0]), UVM_MEDIUM)
    if (rd_val[15:0] != 0)
      `uvm_error("BASIC_GEN", $sformatf("STAT_DROP should be 0, got %0d", rd_val[15:0]))

    // Check IRQ_STATUS
    ral_read(reg_block.irq_status, rd_val);
    `uvm_info("BASIC_GEN", $sformatf("IRQ_STATUS = 0x%02h", rd_val[7:0]), UVM_MEDIUM)
    if (rd_val[0] != 1'b1)
      `uvm_error("BASIC_GEN", "GEN_DONE bit not set in IRQ_STATUS!")
    if (rd_val[6] != 1'b1)
      `uvm_error("BASIC_GEN", "START_ACK bit not set in IRQ_STATUS!")

    // Clear all IRQ status
    ral_write(reg_block.irq_status, 32'h0000_00FF);

    // ===== STEP 9: RE-LOCK =====
    `uvm_info("BASIC_GEN", "Step 9: Re-lock CSR bank", UVM_MEDIUM)
    ral_write(reg_block.lock, 32'h0000_0000);

    `uvm_info("BASIC_GEN", "=== Basic generation test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_basic_gen_seq
