//-----------------------------------------------------------------------------
// apb_pkt_reg_field_defs.sv : all 25 CSRs of apb_pkt_switch (spec sections 4 and 5)
// Every register is 32 bits. Layout/reset/access are taken from the spec tables;
// reserved bits are RAZ/WI -> modelled as "RO" fields reset to 0.
//-----------------------------------------------------------------------------

// Common base: one helper creates + configures a field the same way everywhere.
virtual class apb_pkt_reg_base extends uvm_reg;
  function new(string name);
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  // configure(parent, size, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible)
  // individually_accessible=0: APB3 has no PSTRB, so a field access is always a whole-register access.
  protected function uvm_reg_field add_fld(string name, int unsigned size, int unsigned lsb,
                                           string access, bit vol, uvm_reg_data_t rst);
    uvm_reg_field f = uvm_reg_field::type_id::create(name);
    f.configure(this, size, lsb, access, vol, rst, 1, (access == "RW" || access == "WO"), 0);
    return f;
  endfunction

  protected function void add_rsvd(int unsigned lsb, int unsigned size);
    void'(add_fld($sformatf("rsvd_%0d", lsb), size, lsb, "RO", 0, 0));
  endfunction
endclass

//============================ STATUS / IDENTIFICATION (RO) ====================
// 1  DEVICE_ID 0x00  reset 0x02A55357
class apb_pkt_device_id_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_device_id_reg)
  rand uvm_reg_field revision, vendor_id, product_id;
  function new(string name = "apb_pkt_device_id_reg"); super.new(name); endfunction
  virtual function void build();
    revision   = add_fld("revision",   8, 24, "RO", 0, 8'h02);
    vendor_id  = add_fld("vendor_id",  8, 16, "RO", 0, 8'hA5);
    product_id = add_fld("product_id", 16, 0, "RO", 0, 16'h5357);   // "SW"
  endfunction
endclass

// 2  VERSION 0x04  reset 0x00010200 (1.2.0)
class apb_pkt_version_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_version_reg)
  rand uvm_reg_field major, minor, patch;
  function new(string name = "apb_pkt_version_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(24, 8);
    major = add_fld("major", 8, 16, "RO", 0, 8'h01);
    minor = add_fld("minor", 8,  8, "RO", 0, 8'h02);
    patch = add_fld("patch", 8,  0, "RO", 0, 8'h00);
  endfunction
endclass

// 3  SWITCH_STATUS 0x08  reset 0x000000F9  (all live => volatile)
class apb_pkt_switch_status_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_switch_status_reg)
  rand uvm_reg_field gen_fsm, err_pending, gen_running, port_enabled, locked, switch_enabled, busy, ready;
  function new(string name = "apb_pkt_switch_status_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(18, 14);
    gen_fsm        = add_fld("gen_fsm",        2, 16, "RO", 1, 0);
    add_rsvd(10, 6);
    err_pending    = add_fld("err_pending",    1,  9, "RO", 1, 0);
    gen_running    = add_fld("gen_running",    1,  8, "RO", 1, 0);
    port_enabled   = add_fld("port_enabled",   4,  4, "RO", 1, 4'hF);
    locked         = add_fld("locked",         1,  3, "RO", 1, 1);
    switch_enabled = add_fld("switch_enabled", 1,  2, "RO", 1, 0);
    busy           = add_fld("busy",           1,  1, "RO", 1, 0);
    ready          = add_fld("ready",          1,  0, "RO", 1, 1);
  endfunction
endclass

// 4  PORT_STATUS 0x0C  reset 0
class apb_pkt_port_status_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_port_status_reg)
  rand uvm_reg_field port3_level, port2_level, port1_level, port0_level;
  function new(string name = "apb_pkt_port_status_reg"); super.new(name); endfunction
  virtual function void build();
    port3_level = add_fld("port3_level", 8, 24, "RO", 1, 0);
    port2_level = add_fld("port2_level", 8, 16, "RO", 1, 0);
    port1_level = add_fld("port1_level", 8,  8, "RO", 1, 0);
    port0_level = add_fld("port0_level", 8,  0, "RO", 1, 0);
  endfunction
endclass

// 5  GEN_STATUS 0x10  reset 0
class apb_pkt_gen_status_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_gen_status_reg)
  rand uvm_reg_field remaining, fsm, done, running;
  function new(string name = "apb_pkt_gen_status_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(24, 8);
    remaining = add_fld("remaining", 16, 8, "RO", 1, 0);
    add_rsvd(4, 4);
    fsm       = add_fld("fsm",     2, 2, "RO", 1, 0);
    done      = add_fld("done",    1, 1, "RO", 1, 0);
    running   = add_fld("running", 1, 0, "RO", 1, 0);
  endfunction
endclass

// 6  STAT_RX 0x14   7  STAT_TX 0x18   8  STAT_DROP 0x1C  (16-bit saturating counters)
class apb_pkt_stat_rx_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_stat_rx_reg)
  rand uvm_reg_field rx_packets;
  function new(string name = "apb_pkt_stat_rx_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(16, 16);
    rx_packets = add_fld("rx_packets", 16, 0, "RO", 1, 0);
  endfunction
endclass

class apb_pkt_stat_tx_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_stat_tx_reg)
  rand uvm_reg_field tx_packets;
  function new(string name = "apb_pkt_stat_tx_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(16, 16);
    tx_packets = add_fld("tx_packets", 16, 0, "RO", 1, 0);
  endfunction
endclass

class apb_pkt_stat_drop_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_stat_drop_reg)
  rand uvm_reg_field dropped_packets;
  function new(string name = "apb_pkt_stat_drop_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(16, 16);
    dropped_packets = add_fld("dropped_packets", 16, 0, "RO", 1, 0);
  endfunction
endclass

//============================ CONFIGURATION (lockable RW) =====================
// 9  SWITCH_CTRL 0x20  reset 0  (STAT_CLEAR is a WO pulse)
class apb_pkt_switch_ctrl_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_switch_ctrl_reg)
  rand uvm_reg_field irq_global_en, stat_clear, enable;
  function new(string name = "apb_pkt_switch_ctrl_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(4, 28);
    irq_global_en = add_fld("irq_global_en", 1, 3, "RW", 0, 0);
    add_rsvd(2, 1);
    stat_clear    = add_fld("stat_clear",    1, 1, "WO", 0, 0);
    enable        = add_fld("enable",        1, 0, "RW", 0, 0);
  endfunction
endclass

// 10  PORT_ENABLE 0x24  reset 0xF
class apb_pkt_port_enable_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_port_enable_reg)
  rand uvm_reg_field port_en;
  function new(string name = "apb_pkt_port_enable_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(4, 28);
    port_en = add_fld("port_en", 4, 0, "RW", 0, 4'hF);
  endfunction
endclass

// 11  FWD_ENABLE 0x28  reset 0xF
class apb_pkt_fwd_enable_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_fwd_enable_reg)
  rand uvm_reg_field fwd_en;
  function new(string name = "apb_pkt_fwd_enable_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(4, 28);
    fwd_en = add_fld("fwd_en", 4, 0, "RW", 0, 4'hF);
  endfunction
endclass

// 12  GEN_CTRL 0x2C  reset 0  (START, STOP are WO pulses)
class apb_pkt_gen_ctrl_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_gen_ctrl_reg)
  rand uvm_reg_field continuous, stop, start, enable;
  function new(string name = "apb_pkt_gen_ctrl_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(4, 28);
    continuous = add_fld("continuous", 1, 3, "RW", 0, 0);
    stop       = add_fld("stop",       1, 2, "WO", 0, 0);
    start      = add_fld("start",      1, 1, "WO", 0, 0);
    enable     = add_fld("enable",     1, 0, "RW", 0, 0);
  endfunction
endclass

// 13  GEN_PKT_CFG 0x30  reset 0x00000401
class apb_pkt_gen_pkt_cfg_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_gen_pkt_cfg_reg)
  rand uvm_reg_field seed, length, src_port, dst_port;
  function new(string name = "apb_pkt_gen_pkt_cfg_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(24, 8);
    seed     = add_fld("seed",     8, 16, "RW", 0, 8'h00);
    length   = add_fld("length",   8,  8, "RW", 0, 8'h04);
    add_rsvd(4, 4);
    src_port = add_fld("src_port", 2,  2, "RW", 0, 0);
    dst_port = add_fld("dst_port", 2,  0, "RW", 0, 2'd1);
  endfunction
endclass

// 14  GEN_INTERVAL 0x34  reset 2        15  GEN_COUNT 0x38  reset 4
class apb_pkt_gen_interval_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_gen_interval_reg)
  rand uvm_reg_field interval;
  function new(string name = "apb_pkt_gen_interval_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(16, 16);
    interval = add_fld("interval", 16, 0, "RW", 0, 16'd2);
  endfunction
endclass

class apb_pkt_gen_count_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_gen_count_reg)
  rand uvm_reg_field count;
  function new(string name = "apb_pkt_gen_count_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(16, 16);
    count = add_fld("count", 16, 0, "RW", 0, 16'd4);
  endfunction
endclass

//============================ INTERRUPTS ======================================
// 16  IRQ_STATUS 0x3C  W1C, hardware-set => volatile
class apb_pkt_irq_status_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_irq_status_reg)
  rand uvm_reg_field sw_event, start_ack, queue_almost_full, packet_forwarded,
                     packet_dropped, queue_overflow, error, gen_done;
  function new(string name = "apb_pkt_irq_status_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(8, 24);
    sw_event          = add_fld("sw_event",          1, 7, "W1C", 1, 0);
    start_ack         = add_fld("start_ack",         1, 6, "W1C", 1, 0);
    queue_almost_full = add_fld("queue_almost_full", 1, 5, "W1C", 1, 0);
    packet_forwarded  = add_fld("packet_forwarded",  1, 4, "W1C", 1, 0);
    packet_dropped    = add_fld("packet_dropped",    1, 3, "W1C", 1, 0);
    queue_overflow    = add_fld("queue_overflow",    1, 2, "W1C", 1, 0);
    error             = add_fld("error",             1, 1, "W1C", 1, 0);
    gen_done          = add_fld("gen_done",          1, 0, "W1C", 1, 0);
  endfunction
endclass

// 17  IRQ_ENABLE 0x40  (one enable per IRQ_STATUS bit)
class apb_pkt_irq_enable_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_irq_enable_reg)
  rand uvm_reg_field sw_event_en, start_ack_en, queue_af_en, packet_fwd_en,
                     packet_drop_en, overflow_en, error_en, gen_done_en;
  function new(string name = "apb_pkt_irq_enable_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(8, 24);
    sw_event_en    = add_fld("sw_event_en",    1, 7, "RW", 0, 0);
    start_ack_en   = add_fld("start_ack_en",   1, 6, "RW", 0, 0);
    queue_af_en    = add_fld("queue_af_en",    1, 5, "RW", 0, 0);
    packet_fwd_en  = add_fld("packet_fwd_en",  1, 4, "RW", 0, 0);
    packet_drop_en = add_fld("packet_drop_en", 1, 3, "RW", 0, 0);
    overflow_en    = add_fld("overflow_en",    1, 2, "RW", 0, 0);
    error_en       = add_fld("error_en",       1, 1, "RW", 0, 0);
    gen_done_en    = add_fld("gen_done_en",    1, 0, "RW", 0, 0);
  endfunction
endclass

// 18  IRQ_FORCE 0x44  WO: each 1 sets the matching IRQ_STATUS bit
class apb_pkt_irq_force_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_irq_force_reg)
  rand uvm_reg_field force_bits;                      // "force" is a SV keyword
  function new(string name = "apb_pkt_irq_force_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(8, 24);
    force_bits = add_fld("force_bits", 8, 0, "WO", 0, 0);
  endfunction
endclass

//============================ ERRORS ==========================================
// 19  ERR_STATUS 0x48  W1C, volatile
class apb_pkt_err_status_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_err_status_reg)
  rand uvm_reg_field injected, length_error, crc_error, protocol_error,
                     undersize, queue_overflow, dest_error, bus_error;
  function new(string name = "apb_pkt_err_status_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(8, 24);
    injected       = add_fld("injected",       1, 7, "W1C", 1, 0);
    length_error   = add_fld("length_error",   1, 6, "W1C", 1, 0);
    crc_error      = add_fld("crc_error",      1, 5, "W1C", 1, 0);
    protocol_error = add_fld("protocol_error", 1, 4, "W1C", 1, 0);
    undersize      = add_fld("undersize",      1, 3, "W1C", 1, 0);
    queue_overflow = add_fld("queue_overflow", 1, 2, "W1C", 1, 0);
    dest_error     = add_fld("dest_error",     1, 1, "W1C", 1, 0);
    bus_error      = add_fld("bus_error",      1, 0, "W1C", 1, 0);
  endfunction
endclass

// 20  ERR_ENABLE 0x4C  (promotes ERR_STATUS bits to IRQ_STATUS.ERROR)
class apb_pkt_err_enable_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_err_enable_reg)
  rand uvm_reg_field injected_en, length_en, crc_en, protocol_en,
                     undersize_en, overflow_en, dest_en, bus_en;
  function new(string name = "apb_pkt_err_enable_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(8, 24);
    injected_en  = add_fld("injected_en",  1, 7, "RW", 0, 0);
    length_en    = add_fld("length_en",    1, 6, "RW", 0, 0);
    crc_en       = add_fld("crc_en",       1, 5, "RW", 0, 0);
    protocol_en  = add_fld("protocol_en",  1, 4, "RW", 0, 0);
    undersize_en = add_fld("undersize_en", 1, 3, "RW", 0, 0);
    overflow_en  = add_fld("overflow_en",  1, 2, "RW", 0, 0);
    dest_en      = add_fld("dest_en",      1, 1, "RW", 0, 0);
    bus_en       = add_fld("bus_en",       1, 0, "RW", 0, 0);
  endfunction
endclass

// 21  ERR_INJECT 0x50  WO diagnostics; bit 31 clears ERR_COUNT/ERR_INFO
class apb_pkt_err_inject_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_err_inject_reg)
  rand uvm_reg_field clear_count, injected, length, crc, protocol, undersize, overflow, dest, bus;
  function new(string name = "apb_pkt_err_inject_reg"); super.new(name); endfunction
  virtual function void build();
    clear_count = add_fld("clear_count", 1, 31, "WO", 0, 0);
    add_rsvd(8, 23);
    injected    = add_fld("injected",  1, 7, "WO", 0, 0);
    length      = add_fld("length",    1, 6, "WO", 0, 0);
    crc         = add_fld("crc",       1, 5, "WO", 0, 0);
    protocol    = add_fld("protocol",  1, 4, "WO", 0, 0);
    undersize   = add_fld("undersize", 1, 3, "WO", 0, 0);
    overflow    = add_fld("overflow",  1, 2, "WO", 0, 0);
    dest        = add_fld("dest",      1, 1, "WO", 0, 0);
    bus         = add_fld("bus",       1, 0, "WO", 0, 0);
  endfunction
endclass

// 22  ERR_COUNT 0x54  (saturating)
class apb_pkt_err_count_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_err_count_reg)
  rand uvm_reg_field error_count;
  function new(string name = "apb_pkt_err_count_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(16, 16);
    error_count = add_fld("error_count", 16, 0, "RO", 1, 0);
  endfunction
endclass

// 23  ERR_INFO 0x58  last-error snapshot
class apb_pkt_err_info_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_err_info_reg)
  rand uvm_reg_field tx_snapshot, dest_port, source, last_code;
  function new(string name = "apb_pkt_err_info_reg"); super.new(name); endfunction
  virtual function void build();
    tx_snapshot = add_fld("tx_snapshot", 12, 20, "RO", 1, 0);
    add_rsvd(18, 2);
    dest_port   = add_fld("dest_port",    2, 16, "RO", 1, 0);
    source      = add_fld("source",       8,  8, "RO", 1, 0);
    last_code   = add_fld("last_code",    8,  0, "RO", 1, 0);
  endfunction
endclass

//============================ CONTROL =========================================
// 24  LOCK 0x5C  reset 1. Write: full 32-bit key compare. Read: {31'b0, LOCKED}.
//     One 32-bit RW field; apb_pkt_lock_cb (env) makes the mirror follow the spec.
class apb_pkt_lock_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_lock_reg)
  rand uvm_reg_field key;
  function new(string name = "apb_pkt_lock_reg"); super.new(name); endfunction
  virtual function void build();
    key = add_fld("key", 32, 0, "RW", 0, 32'h1);
  endfunction
endclass

// 25  SOFT_RESET 0x60  WO pulse
class apb_pkt_soft_reset_reg extends apb_pkt_reg_base;
  `uvm_object_utils(apb_pkt_soft_reset_reg)
  rand uvm_reg_field pulse;
  function new(string name = "apb_pkt_soft_reset_reg"); super.new(name); endfunction
  virtual function void build();
    add_rsvd(1, 31);
    pulse = add_fld("pulse", 1, 0, "WO", 0, 0);
  endfunction
endclass
