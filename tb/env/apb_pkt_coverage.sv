//-----------------------------------------------------------------------------
// apb_pkt_coverage : functional coverage sampled from monitor transactions.
// Connected BEFORE the predictor, so lock state and mirrors are pre-transfer values.
//-----------------------------------------------------------------------------

// Reusable group types (package level so several instances can exist)
covergroup cg_bits(string nm) with function sample(bit [7:0] v);   // which bits of an 8-bit register were seen/written
  option.per_instance = 1;
  option.name = nm;
  cp_bit: coverpoint v {
    wildcard bins b0 = {8'b???????1};  wildcard bins b1 = {8'b??????1?};
    wildcard bins b2 = {8'b?????1??};  wildcard bins b3 = {8'b????1???};
    wildcard bins b4 = {8'b???1????};  wildcard bins b5 = {8'b??1?????};
    wildcard bins b6 = {8'b?1??????};  wildcard bins b7 = {8'b1???????};
  }
endgroup

covergroup cg_cnt(string nm) with function sample(bit [15:0] v);   // saturating counters
  option.per_instance = 1;
  option.name = nm;
  cp_val: coverpoint v { bins zero = {0}; bins some = {[1:16'hFFFE]}; bins sat = {16'hFFFF}; }
endgroup

class apb_pkt_coverage extends uvm_subscriber #(apb_seq_item);
  `uvm_component_utils(apb_pkt_coverage)

  apb_pkt_reg_block m_ral;
  apb_pkt_state     st;

  typedef enum {ACC_OK, ACC_UNALIGNED, ACC_OOR}                       acc_e;
  typedef enum {KEY_OK, KEY_ONE_BIT_OFF, KEY_ZERO, KEY_OTHER}         key_e;
  typedef enum {BLK_NONE, BLK_SWITCH_OFF, BLK_PORT_OFF, BLK_FWD_OFF}  blk_e;

  apb_seq_item  t_q;
  acc_e         acc_cls;
  key_e         key_kind;
  blk_e         blk_cause;
  bit           snap_locked, tgt_lockable, ovf_poss, cfg_cont;
  bit [1:0]     cfg_dst;
  bit [1:0]     fsm_v;
  bit [7:0]     lvl_v;
  int unsigned  cfg_len, cfg_itv, cfg_cnt;

  cg_bits cg_irq_rd, cg_err_rd, cg_force, cg_inject;
  cg_cnt  cg_rx, cg_drop;

  covergroup cg_access;                       // every APB transfer
    option.per_instance = 1;
    cp_cls   : coverpoint acc_cls;
    cp_rw    : coverpoint t_q.rw { bins rd = {0}; bins wr = {1}; }
    cp_err   : coverpoint t_q.slverr;
    cp_addr  : coverpoint t_q.addr iff (acc_cls == ACC_OK) {
                 bins reg_a[] = {[16'h00:16'h60]} with (item % 4 == 0); }
    x_cls_rw : cross cp_cls, cp_rw;
    x_addr_rw: cross cp_addr, cp_rw;
  endgroup

  covergroup cg_lock;                         // legal writes: lock state x lockable target
    option.per_instance = 1;
    cp_locked: coverpoint snap_locked;
    cp_target: coverpoint tgt_lockable { bins lockable_wr = {1}; bins other_wr = {0}; }
    x_lk_wr  : cross cp_locked, cp_target;
  endgroup

  covergroup cg_key;                          // writes to LOCK: full 32-bit compare
    option.per_instance = 1;
    cp_key: coverpoint key_kind;              // KEY_ONE_BIT_OFF catches a partial-compare bug
  endgroup

  covergroup cg_run;                          // accepted START (enable + start, unlocked)
    option.per_instance = 1;
    cp_dst  : coverpoint cfg_dst;
    cp_len  : coverpoint cfg_len { bins one = {1}; bins few = {[2:4]}; bins mid = {[5:15]};
                                   bins max = {16}; bins over = {[17:255]}; }
    cp_itv  : coverpoint cfg_itv { bins zero = {0}; bins lo = {[1:3]}; bins hi = {[4:$]}; }
    cp_cnt  : coverpoint cfg_cnt { bins zero_as_one = {0}; bins one = {1}; bins few = {[2:8]}; bins many = {[9:$]}; }
    cp_cont : coverpoint cfg_cont;
    cp_cause: coverpoint blk_cause;           // why a packet is (not) blocked
    cp_ovf  : coverpoint ovf_poss;            // queue overflow reachable (count>1, interval<length)
    x_dst_cont : cross cp_dst, cp_cont;
    x_dst_cause: cross cp_dst, cp_cause;
    x_len_itv  : cross cp_len, cp_itv;
  endgroup

  covergroup cg_fsm;                          // generator states observed through GEN_STATUS
    option.per_instance = 1;
    cp_fsm: coverpoint fsm_v { bins s_idle = {0}; bins s_send = {1}; bins s_gap = {2}; bins s_done = {3}; }
  endgroup

  covergroup cg_qlvl;                         // queue occupancy observed through PORT_STATUS
    option.per_instance = 1;
    cp_lvl: coverpoint lvl_v { bins q_empty = {0}; bins q_low = {[1:7]}; bins q_af = {[8:15]}; bins q_full = {16}; }
  endgroup

  function new(string name = "apb_pkt_coverage", uvm_component parent);
    super.new(name, parent);
    cg_access = new(); cg_lock = new(); cg_key = new(); cg_run = new(); cg_fsm = new(); cg_qlvl = new();
    cg_irq_rd = new("irq_status_bits_read");   cg_err_rd = new("err_status_bits_read");
    cg_force  = new("irq_force_bits_written"); cg_inject = new("err_inject_bits_written");
    cg_rx     = new("stat_rx");                cg_drop   = new("stat_drop");
  endfunction

  protected function automatic uvm_reg_data_t fv(uvm_reg_data_t w, uvm_reg_field f);
    return (w >> f.get_lsb_pos()) & ((uvm_reg_data_t'(1) << f.get_n_bits()) - 1);
  endfunction

  virtual function void write(apb_seq_item t);
    uvm_reg rg;
    t_q     = t;
    acc_cls = (t.addr[1:0] != 2'b00) ? ACC_UNALIGNED : (t.addr > 16'h0060) ? ACC_OOR : ACC_OK;
    cg_access.sample();
    if (acc_cls != ACC_OK) return;
    rg = m_ral.default_map.get_reg_by_offset(t.addr, 0);
    if (rg == null) return;
    if (t.rw) on_write(rg, t); else on_read(rg, t);
  endfunction

  protected function void on_read(uvm_reg rg, apb_seq_item t);
    if      (rg == m_ral.irq_status) cg_irq_rd.sample(t.rdata[7:0]);
    else if (rg == m_ral.err_status) cg_err_rd.sample(t.rdata[7:0]);
    else if (rg == m_ral.stat_rx)    cg_rx.sample(t.rdata[15:0]);
    else if (rg == m_ral.stat_drop)  cg_drop.sample(t.rdata[15:0]);
    else if (rg == m_ral.gen_status) begin
      fsm_v = 2'(fv(t.rdata, m_ral.gen_status.fsm));
      cg_fsm.sample();
    end
    else if (rg == m_ral.port_status) begin
      uvm_reg_field lv[4] = '{m_ral.port_status.port0_level, m_ral.port_status.port1_level,
                              m_ral.port_status.port2_level, m_ral.port_status.port3_level};
      foreach (lv[i]) begin
        lvl_v = 8'(fv(t.rdata, lv[i]));
        cg_qlvl.sample();
      end
    end
  endfunction

  protected function void on_write(uvm_reg rg, apb_seq_item t);
    snap_locked  = st.locked;
    tgt_lockable = st.is_lockable(rg);
    cg_lock.sample();
    if (rg == m_ral.lock) begin
      key_kind = (t.data == APB_PKT_UNLOCK_KEY)                       ? KEY_OK :
                 ($countones(t.data ^ APB_PKT_UNLOCK_KEY) == 1)       ? KEY_ONE_BIT_OFF :
                 (t.data == 32'h0)                                    ? KEY_ZERO : KEY_OTHER;
      cg_key.sample();
    end
    else if (rg == m_ral.irq_force)  cg_force.sample(t.data[7:0]);
    else if (rg == m_ral.err_inject) cg_inject.sample(t.data[7:0]);
    else if (rg == m_ral.gen_ctrl && !st.locked &&
             t.data[m_ral.gen_ctrl.enable.get_lsb_pos()] && t.data[m_ral.gen_ctrl.start.get_lsb_pos()])
      sample_run(t);
  endfunction

  protected function void sample_run(apb_seq_item t);
    bit [3:0]    pen, fwd;
    bit          sw_en;
    int unsigned len_e, cnt_e;
    cfg_dst  = m_ral.gen_pkt_cfg.dst_port.get_mirrored_value();
    cfg_len  = m_ral.gen_pkt_cfg.length.get_mirrored_value();
    cfg_itv  = m_ral.gen_interval.interval.get_mirrored_value();
    cfg_cnt  = m_ral.gen_count.count.get_mirrored_value();
    cfg_cont = t.data[m_ral.gen_ctrl.continuous.get_lsb_pos()];
    sw_en    = m_ral.switch_ctrl.enable.get_mirrored_value();
    pen      = m_ral.port_enable.port_en.get_mirrored_value();
    fwd      = m_ral.fwd_enable.fwd_en.get_mirrored_value();
    blk_cause = !sw_en ? BLK_SWITCH_OFF : !pen[cfg_dst] ? BLK_PORT_OFF : !fwd[cfg_dst] ? BLK_FWD_OFF : BLK_NONE;
    len_e    = (cfg_len == 0) ? 1 : (cfg_len > 16) ? 16 : cfg_len;
    cnt_e    = (cfg_cnt == 0) ? 1 : cfg_cnt;
    ovf_poss = !cfg_cont && (cnt_e > 1) && (cfg_itv < len_e);
    cg_run.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("access %0.1f%%  lock %0.1f%%  key %0.1f%%  run %0.1f%%  fsm %0.1f%%  qlvl %0.1f%%",
              cg_access.get_inst_coverage(), cg_lock.get_inst_coverage(), cg_key.get_inst_coverage(),
              cg_run.get_inst_coverage(), cg_fsm.get_inst_coverage(), cg_qlvl.get_inst_coverage()), UVM_LOW)
    `uvm_info("COV", $sformatf("irq_rd %0.1f%%  err_rd %0.1f%%  irq_force %0.1f%%  err_inject %0.1f%%  stat_rx %0.1f%%  stat_drop %0.1f%%",
              cg_irq_rd.get_inst_coverage(), cg_err_rd.get_inst_coverage(), cg_force.get_inst_coverage(),
              cg_inject.get_inst_coverage(), cg_rx.get_inst_coverage(), cg_drop.get_inst_coverage()), UVM_LOW)
  endfunction
endclass : apb_pkt_coverage
