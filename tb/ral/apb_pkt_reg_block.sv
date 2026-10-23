//-----------------------------------------------------------------------------
// apb_pkt_reg_block : top-level register model (spec sections 4 and 8)
//   - owns the 25 register objects
//   - owns ONE address map "default_map": base 0, 4-byte bus, little endian
//-----------------------------------------------------------------------------
class apb_pkt_reg_block extends uvm_reg_block;
  `uvm_object_utils(apb_pkt_reg_block)

  apb_pkt_device_id_reg       device_id;      // 0x00
  apb_pkt_version_reg         version;        // 0x04
  apb_pkt_switch_status_reg   switch_status;  // 0x08
  apb_pkt_port_status_reg     port_status;    // 0x0C
  apb_pkt_gen_status_reg      gen_status;     // 0x10
  apb_pkt_stat_rx_reg         stat_rx;        // 0x14
  apb_pkt_stat_tx_reg         stat_tx;        // 0x18
  apb_pkt_stat_drop_reg       stat_drop;      // 0x1C
  apb_pkt_switch_ctrl_reg     switch_ctrl;    // 0x20
  apb_pkt_port_enable_reg     port_enable;    // 0x24
  apb_pkt_fwd_enable_reg      fwd_enable;     // 0x28
  apb_pkt_gen_ctrl_reg        gen_ctrl;       // 0x2C
  apb_pkt_gen_pkt_cfg_reg     gen_pkt_cfg;    // 0x30
  apb_pkt_gen_interval_reg    gen_interval;   // 0x34
  apb_pkt_gen_count_reg       gen_count;      // 0x38
  apb_pkt_irq_status_reg      irq_status;     // 0x3C
  apb_pkt_irq_enable_reg      irq_enable;     // 0x40
  apb_pkt_irq_force_reg       irq_force;      // 0x44
  apb_pkt_err_status_reg      err_status;     // 0x48
  apb_pkt_err_enable_reg      err_enable;     // 0x4C
  apb_pkt_err_inject_reg      err_inject;     // 0x50
  apb_pkt_err_count_reg       err_count;      // 0x54
  apb_pkt_err_info_reg        err_info;       // 0x58
  apb_pkt_lock_reg            lock;           // 0x5C
  apb_pkt_soft_reset_reg      soft_reset;     // 0x60

  uvm_reg_map default_map;

  function new(string name = "apb_pkt_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  // create -> configure(parent block) -> build(fields) -> add to map at byte offset
`define APB_PKT_ADD_REG(R, T, OFF, RIGHTS) \
    R = T::type_id::create(`"R`"); \
    R.configure(this, null, ""); \
    R.build(); \
    default_map.add_reg(R, OFF, RIGHTS);

  virtual function void build();
    default_map = create_map("default_map", .base_addr(0), .n_bytes(4),
                             .endian(UVM_LITTLE_ENDIAN), .byte_addressing(1));

    `APB_PKT_ADD_REG(device_id,     apb_pkt_device_id_reg,     'h00, "RO")
    `APB_PKT_ADD_REG(version,       apb_pkt_version_reg,       'h04, "RO")
    `APB_PKT_ADD_REG(switch_status, apb_pkt_switch_status_reg, 'h08, "RO")
    `APB_PKT_ADD_REG(port_status,   apb_pkt_port_status_reg,   'h0C, "RO")
    `APB_PKT_ADD_REG(gen_status,    apb_pkt_gen_status_reg,    'h10, "RO")
    `APB_PKT_ADD_REG(stat_rx,       apb_pkt_stat_rx_reg,       'h14, "RO")
    `APB_PKT_ADD_REG(stat_tx,       apb_pkt_stat_tx_reg,       'h18, "RO")
    `APB_PKT_ADD_REG(stat_drop,     apb_pkt_stat_drop_reg,     'h1C, "RO")
    `APB_PKT_ADD_REG(switch_ctrl,   apb_pkt_switch_ctrl_reg,   'h20, "RW")
    `APB_PKT_ADD_REG(port_enable,   apb_pkt_port_enable_reg,   'h24, "RW")
    `APB_PKT_ADD_REG(fwd_enable,    apb_pkt_fwd_enable_reg,    'h28, "RW")
    `APB_PKT_ADD_REG(gen_ctrl,      apb_pkt_gen_ctrl_reg,      'h2C, "RW")
    `APB_PKT_ADD_REG(gen_pkt_cfg,   apb_pkt_gen_pkt_cfg_reg,   'h30, "RW")
    `APB_PKT_ADD_REG(gen_interval,  apb_pkt_gen_interval_reg,  'h34, "RW")
    `APB_PKT_ADD_REG(gen_count,     apb_pkt_gen_count_reg,     'h38, "RW")
    `APB_PKT_ADD_REG(irq_status,    apb_pkt_irq_status_reg,    'h3C, "RW")
    `APB_PKT_ADD_REG(irq_enable,    apb_pkt_irq_enable_reg,    'h40, "RW")
    `APB_PKT_ADD_REG(irq_force,     apb_pkt_irq_force_reg,     'h44, "WO")
    `APB_PKT_ADD_REG(err_status,    apb_pkt_err_status_reg,    'h48, "RW")
    `APB_PKT_ADD_REG(err_enable,    apb_pkt_err_enable_reg,    'h4C, "RW")
    `APB_PKT_ADD_REG(err_inject,    apb_pkt_err_inject_reg,    'h50, "WO")
    `APB_PKT_ADD_REG(err_count,     apb_pkt_err_count_reg,     'h54, "RO")
    `APB_PKT_ADD_REG(err_info,      apb_pkt_err_info_reg,      'h58, "RO")
    `APB_PKT_ADD_REG(lock,          apb_pkt_lock_reg,          'h5C, "RW")
    `APB_PKT_ADD_REG(soft_reset,    apb_pkt_soft_reset_reg,    'h60, "WO")

    // Backdoor paths for uvm_reg_access_seq: only the plain-RW storage flops map 1:1 onto a register
    add_hdl_path("tb_top.dut", "RTL");
    port_enable.add_hdl_path_slice ("port_enable_q",  0, 4);
    fwd_enable.add_hdl_path_slice  ("fwd_enable_q",   0, 4);
    gen_interval.add_hdl_path_slice("gen_interval_q", 0, 16);
    gen_count.add_hdl_path_slice   ("gen_count_q",    0, 16);
    irq_enable.add_hdl_path_slice  ("irq_enable_q",   0, 8);
    err_enable.add_hdl_path_slice  ("err_enable_q",   0, 8);

    lock_model();       // freeze structure, compute addresses, enable lookup by offset
  endfunction
`undef APB_PKT_ADD_REG
endclass : apb_pkt_reg_block
