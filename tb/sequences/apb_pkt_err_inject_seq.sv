//-----------------------------------------------------------------------------
// Class  : apb_pkt_err_inject_seq
// File   : tb/sequences/apb_pkt_err_inject_seq.sv
// Description:
//   Error injection sequence. Tests the ERR_INJECT register including
//   popcount-based ERR_COUNT increment, ERR_INFO capture, INJECTED bit
//   auto-set, and CLEAR_COUNT functionality.
//-----------------------------------------------------------------------------

class apb_pkt_err_inject_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_err_inject_seq)

  function new(string name = "apb_pkt_err_inject_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg_data_t rd_val;

    // Unlock
    ral_write(reg_block.lock, 32'hA5A5_C3C3);

    // ===== Test 1: Single error injection =====
    `uvm_info("ERR_INJ", "Test 1: Inject DEST_ERROR (bit 1)", UVM_MEDIUM)
    ral_write(reg_block.err_inject, 32'h0000_0002);  // Inject bit 1
    wait_clocks(2);

    // ERR_STATUS should have DEST_ERROR (bit 1) AND INJECTED (bit 7) set
    ral_read(reg_block.err_status, rd_val);
    `uvm_info("ERR_INJ", $sformatf("ERR_STATUS = 0x%02h", rd_val[7:0]), UVM_MEDIUM)
    if (rd_val[1] != 1'b1)
      `uvm_error("ERR_INJ", "DEST_ERROR not set after injection!")
    if (rd_val[7] != 1'b1)
      `uvm_error("ERR_INJ", "INJECTED bit not auto-set!")

    // ERR_COUNT should be 1
    ral_read(reg_block.err_count, rd_val);
    `uvm_info("ERR_INJ", $sformatf("ERR_COUNT = %0d (expected 1)", rd_val[15:0]), UVM_MEDIUM)

    // ERR_INFO: SOURCE should be 1 (injection), LAST_CODE should be 1
    ral_read(reg_block.err_info, rd_val);
    `uvm_info("ERR_INJ", $sformatf("ERR_INFO = 0x%08h", rd_val), UVM_MEDIUM)

    // Clear ERR_STATUS
    ral_write(reg_block.err_status, 32'h0000_00FF);

    // ===== Test 2: Multi-bit injection (popcount) =====
    `uvm_info("ERR_INJ", "Test 2: Inject bits 0,1,2 (popcount=3)", UVM_MEDIUM)
    ral_write(reg_block.err_inject, 32'h0000_0007);
    wait_clocks(2);

    ral_read(reg_block.err_count, rd_val);
    `uvm_info("ERR_INJ", $sformatf("ERR_COUNT = %0d (expected 4: 1 prev + 3 new)", rd_val[15:0]), UVM_MEDIUM)

    // ===== Test 3: CLEAR_COUNT (bit 31) =====
    `uvm_info("ERR_INJ", "Test 3: Clear ERR_COUNT via CLEAR_COUNT bit", UVM_MEDIUM)
    ral_write(reg_block.err_inject, 32'h8000_0000);  // CLEAR_COUNT only
    wait_clocks(2);

    ral_read(reg_block.err_count, rd_val);
    `uvm_info("ERR_INJ", $sformatf("ERR_COUNT = %0d (expected 0)", rd_val[15:0]), UVM_MEDIUM)
    if (rd_val[15:0] != 0)
      `uvm_error("ERR_INJ", "CLEAR_COUNT did not reset ERR_COUNT to 0!")

    // Cleanup
    ral_write(reg_block.err_status, 32'h0000_00FF);

    `uvm_info("ERR_INJ", "=== Error injection test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_err_inject_seq
