//-----------------------------------------------------------------------------
// Class  : apb_pkt_boundary_seq
// File   : tb/sequences/apb_pkt_boundary_seq.sv
// Description:
//   Boundary test sequence. Verifies pslverr assertion for:
//   1. Unaligned addresses (e.g., 0x02, 0x05)
//   2. Out-of-range addresses (e.g., 0x64, 0xFFFC)
//   3. Valid aligned addresses produce no error
//-----------------------------------------------------------------------------

class apb_pkt_boundary_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_boundary_seq)

  function new(string name = "apb_pkt_boundary_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_seq_item item;

    // ===== Test 1: Unaligned read =====
    `uvm_info("BOUNDARY", "Test 1: Read from unaligned address 0x0002", UVM_MEDIUM)
    item = apb_seq_item::type_id::create("item");
    item.addr = 16'h0002;
    item.rw   = 1'b0;
    item.data = 32'h0;
    item.c_addr_aligned.constraint_mode(0);  // Disable alignment constraint
    item.c_addr_range.constraint_mode(0);    // Disable range constraint
    start_item(item);
    finish_item(item);
    if (item.slverr != 1'b1)
      `uvm_error("BOUNDARY", "pslverr not asserted for unaligned read at 0x0002!")
    else
      `uvm_info("BOUNDARY", "PASS: pslverr asserted for unaligned read", UVM_MEDIUM)
    if (item.rdata != 32'h0)
      `uvm_error("BOUNDARY", $sformatf("Unaligned read should return 0, got 0x%08h", item.rdata))

    // ===== Test 2: Unaligned write =====
    `uvm_info("BOUNDARY", "Test 2: Write to unaligned address 0x0005", UVM_MEDIUM)
    item = apb_seq_item::type_id::create("item");
    item.addr = 16'h0005;
    item.rw   = 1'b1;
    item.data = 32'hDEAD_BEEF;
    item.c_addr_aligned.constraint_mode(0);
    item.c_addr_range.constraint_mode(0);
    start_item(item);
    finish_item(item);
    if (item.slverr != 1'b1)
      `uvm_error("BOUNDARY", "pslverr not asserted for unaligned write at 0x0005!")
    else
      `uvm_info("BOUNDARY", "PASS: pslverr asserted for unaligned write", UVM_MEDIUM)

    // ===== Test 3: Out-of-range read =====
    `uvm_info("BOUNDARY", "Test 3: Read from out-of-range address 0x0064", UVM_MEDIUM)
    item = apb_seq_item::type_id::create("item");
    item.addr = 16'h0064;
    item.rw   = 1'b0;
    item.data = 32'h0;
    item.c_addr_aligned.constraint_mode(0);
    item.c_addr_range.constraint_mode(0);
    start_item(item);
    finish_item(item);
    if (item.slverr != 1'b1)
      `uvm_error("BOUNDARY", "pslverr not asserted for out-of-range read at 0x0064!")
    else
      `uvm_info("BOUNDARY", "PASS: pslverr asserted for out-of-range read", UVM_MEDIUM)

    // ===== Test 4: Out-of-range write =====
    `uvm_info("BOUNDARY", "Test 4: Write to out-of-range address 0xFFFC", UVM_MEDIUM)
    item = apb_seq_item::type_id::create("item");
    item.addr = 16'hFFFC;
    item.rw   = 1'b1;
    item.data = 32'h1234_5678;
    item.c_addr_aligned.constraint_mode(0);
    item.c_addr_range.constraint_mode(0);
    start_item(item);
    finish_item(item);
    if (item.slverr != 1'b1)
      `uvm_error("BOUNDARY", "pslverr not asserted for out-of-range write!")
    else
      `uvm_info("BOUNDARY", "PASS: pslverr asserted for out-of-range write", UVM_MEDIUM)

    // ===== Test 5: Valid aligned address has no error =====
    `uvm_info("BOUNDARY", "Test 5: Read from valid address 0x0000 (DEVICE_ID)", UVM_MEDIUM)
    item = apb_seq_item::type_id::create("item");
    item.addr = 16'h0000;
    item.rw   = 1'b0;
    item.data = 32'h0;
    item.c_addr_aligned.constraint_mode(0);
    item.c_addr_range.constraint_mode(0);
    start_item(item);
    finish_item(item);
    if (item.slverr != 1'b0)
      `uvm_error("BOUNDARY", "pslverr asserted for valid address 0x0000!")
    else
      `uvm_info("BOUNDARY", "PASS: no pslverr for valid address", UVM_MEDIUM)

    `uvm_info("BOUNDARY", "=== Boundary test COMPLETE ===", UVM_LOW)
  endtask

endclass : apb_pkt_boundary_seq
