//-----------------------------------------------------------------------------
// apb_pkt_scoreboard : transaction-level checker fed by apb_monitor.
//  1. APB response rules      (spec 3.5)  : pslverr / rdata on illegal access
//  2. Read-vs-mirror compare  (non-volatile fields only; RAL is the reference)
//  3. WO registers read as 0
//  4. Run accounting: RX + DROP == packets requested (exact split when no
//     queue overflow is possible: interval >= length)           (spec 7)
// MUST see a transaction BEFORE the predictor does (predictor overwrites the
// mirror on reads) -> env connects it first on monitor.ap.
//-----------------------------------------------------------------------------
class apb_pkt_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_pkt_scoreboard)

  uvm_analysis_imp #(apb_seq_item, apb_pkt_scoreboard) analysis_export;
  apb_pkt_reg_block m_ral;
  apb_pkt_state     st;
  int unsigned      n_chk, n_err;

  function new(string name = "apb_pkt_scoreboard", uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  protected function automatic uvm_reg_data_t fld_val(uvm_reg_data_t w, uvm_reg_field f);
    return (w >> f.get_lsb_pos()) & ((uvm_reg_data_t'(1) << f.get_n_bits()) - 1);
  endfunction

  protected function void flag(string id, string msg);
    n_err++;
    `uvm_error(id, msg)
  endfunction

  virtual function void write(apb_seq_item t);
    uvm_reg rg;
    bit     illegal = (t.addr[1:0] != 2'b00) || (t.addr > 16'h0060);
    n_chk++;
    if (t.slverr !== illegal)
      flag("PSLVERR", $sformatf("%s : expected pslverr=%0b", t.convert2string(), illegal));
    if (illegal) begin
      if (!t.rw && t.rdata !== 32'h0)
        flag("RDATA_ERR", $sformatf("illegal read must return 0: %s", t.convert2string()));
      return;
    end
    rg = m_ral.default_map.get_reg_by_offset(t.addr, 0);
    if (rg == null) return;
    if (t.rw) on_write(rg, t); else on_read(rg, t);
  endfunction

  protected function void on_read(uvm_reg rg, apb_seq_item t);
    uvm_reg_field f[$];
    if (rg == m_ral.irq_force || rg == m_ral.err_inject || rg == m_ral.soft_reset) begin
      if (t.rdata !== 32'h0)
        flag("WO_READ", $sformatf("%s is write-only, read 0x%08h", rg.get_name(), t.rdata));
      return;
    end
    rg.get_fields(f);
    foreach (f[i]) begin
      uvm_reg_data_t e_val, g_val;
      if (f[i].is_volatile()) continue;
      e_val = f[i].get_mirrored_value();
      g_val = fld_val(t.rdata, f[i]);
      if (g_val !== e_val)
        flag("RD_MIRROR", $sformatf("%s.%s read 0x%0h, mirror 0x%0h",
                                    rg.get_name(), f[i].get_name(), g_val, e_val));
    end
    chk_status(rg, t);
    if (rg == m_ral.gen_status) begin
      if (fld_val(t.rdata, m_ral.gen_status.done)) begin
        if (!st.done_seen && st.starts_since_clear == 1) set_sticky_expect();
        st.done_seen = 1;
      end
    end
    else if (rg == m_ral.stat_rx)    chk_stat("STAT_RX",   t.rdata[15:0], 1'b1);
    else if (rg == m_ral.stat_tx)    chk_stat("STAT_TX",   t.rdata[15:0], 1'b1);   // TX == RX in this slice
    else if (rg == m_ral.stat_drop)  chk_stat("STAT_DROP", t.rdata[15:0], 1'b0);
    else if (rg == m_ral.irq_status) chk_sticky("IRQ_STATUS", t.rdata, st.exp_irq);
    else if (rg == m_ral.err_status) chk_sticky("ERR_STATUS", t.rdata, st.exp_err);
  endfunction

  protected function void on_write(uvm_reg rg, apb_seq_item t);
    if (st.locked && st.is_lockable(rg)) return;           // DUT ignores it
    if (rg == m_ral.irq_status || rg == m_ral.err_status) st.sticky_ok = 0;   // W1C: stop tracking
    if (rg == m_ral.switch_ctrl) begin
      if (fld_val(t.data, m_ral.switch_ctrl.stat_clear)) st.clear_stats();
    end
    else if (rg == m_ral.gen_ctrl) begin
      if (fld_val(t.data, m_ral.gen_ctrl.enable) && fld_val(t.data, m_ral.gen_ctrl.start))
        on_start();
      st.cont_q = fld_val(t.data, m_ral.gen_ctrl.continuous);
    end
  endfunction

  // Only the first START after a stat-clear/reset is modelled; later ones disable the check
  protected function void on_start();
    int unsigned dst, len, cnt, itv;
    bit [3:0]    pen, fwd;
    st.done_seen = 0;
    st.starts_since_clear++;
    if (st.starts_since_clear != 1) return;
    st.sticky_ok = 1; st.exp_irq = 0; st.exp_err = 0;
    dst = m_ral.gen_pkt_cfg.dst_port.get_mirrored_value();
    len = m_ral.gen_pkt_cfg.length.get_mirrored_value();
    cnt = m_ral.gen_count.count.get_mirrored_value();
    itv = m_ral.gen_interval.interval.get_mirrored_value();
    pen = m_ral.port_enable.port_en.get_mirrored_value();
    fwd = m_ral.fwd_enable.fwd_en.get_mirrored_value();
    len = (len == 0) ? 1 : (len > 16) ? 16 : len;       // generator clamps (spec 5.13)
    cnt = (cnt == 0) ? 1 : cnt;                         // 0 means 1 at START (spec 5.15)
    st.exp_all_drop = !(m_ral.switch_ctrl.enable.get_mirrored_value() && pen[dst[1:0]] && fwd[dst[1:0]]);
    st.exp_total    = cnt;
    st.ovf_possible = (cnt > 1) && (itv < len);
    if (st.cont_q) st.starts_since_clear = 2;           // continuous run: not modelled
  endfunction

  protected function void chk_stat(string nm, bit [15:0] got, bit is_rx);
    int unsigned total = st.exp_total;
    if (!st.done_seen || st.starts_since_clear != 1) return;
    if (st.exp_all_drop) begin
      if (got != (is_rx ? 0 : total))
        flag("RUN_ACCT", $sformatf("%s=%0d, expected %0d (all packets dropped)", nm, got, is_rx ? 0 : total));
    end
    else if (!st.ovf_possible) begin
      if (got != (is_rx ? total : 0))
        flag("RUN_ACCT", $sformatf("%s=%0d, expected %0d", nm, got, is_rx ? total : 0));
    end
    else if (got > total)
      flag("RUN_ACCT", $sformatf("%s=%0d exceeds packets generated (%0d)", nm, got, total));
  endfunction

  protected function automatic uvm_reg_data_t fmask(uvm_reg_field f);
    return ((uvm_reg_data_t'(1) << f.get_n_bits()) - 1) << f.get_lsb_pos();
  endfunction

  protected function void expect_eq(string what, uvm_reg_data_t got, uvm_reg_data_t exp);
    if (got !== exp) flag("STATUS", $sformatf("%s: read 0x%0h, expected 0x%0h", what, got, exp));
  endfunction

  // Consistency inside ONE read of a live status register (no timing race with other reads)
  protected function void chk_status(uvm_reg rg, apb_seq_item t);
    uvm_reg_data_t d = t.rdata;
    if (rg == m_ral.switch_status) begin
      uvm_reg_data_t run = fld_val(d, m_ral.switch_status.gen_running);
      expect_eq("SWITCH_STATUS.READY",    fld_val(d, m_ral.switch_status.ready), !run);
      if (run && !fld_val(d, m_ral.switch_status.busy))
        flag("STATUS", "SWITCH_STATUS: GEN_RUNNING=1 but BUSY=0");
      expect_eq("SWITCH_STATUS.LOCKED",   fld_val(d, m_ral.switch_status.locked), st.locked);
      expect_eq("SWITCH_STATUS.SWITCH_ENABLED", fld_val(d, m_ral.switch_status.switch_enabled),
                m_ral.switch_ctrl.enable.get_mirrored_value());
      expect_eq("SWITCH_STATUS.PORT_ENABLED",   fld_val(d, m_ral.switch_status.port_enabled),
                m_ral.port_enable.port_en.get_mirrored_value());
    end
    else if (rg == m_ral.port_status) begin
      uvm_reg_field lv[4] = '{m_ral.port_status.port0_level, m_ral.port_status.port1_level,
                              m_ral.port_status.port2_level, m_ral.port_status.port3_level};
      foreach (lv[i])
        if (fld_val(d, lv[i]) > 16) flag("STATUS", $sformatf("PORT%0d_LEVEL=%0d exceeds queue depth 16", i, fld_val(d, lv[i])));
    end
    else if (rg == m_ral.gen_status) begin
      uvm_reg_data_t fsm = fld_val(d, m_ral.gen_status.fsm);          // 0 IDLE, 1 SEND, 2 GAP, 3 DONE
      expect_eq("GEN_STATUS.RUNNING", fld_val(d, m_ral.gen_status.running), (fsm == 1 || fsm == 2));
      expect_eq("GEN_STATUS.DONE",    fld_val(d, m_ral.gen_status.done),    (fsm == 3));
    end
  endfunction

  // Events that MUST have happened once DONE is seen (spec 7): sticky until software clears them
  protected function void set_sticky_expect();
    st.exp_irq = fmask(m_ral.irq_status.start_ack) | fmask(m_ral.irq_status.gen_done) |
                 fmask(st.exp_all_drop ? m_ral.irq_status.packet_dropped : m_ral.irq_status.packet_forwarded);
    st.exp_err = st.exp_all_drop ? fmask(m_ral.err_status.dest_error) : '0;
  endfunction

  protected function void chk_sticky(string nm, uvm_reg_data_t got, uvm_reg_data_t exp);
    if (!st.sticky_ok) return;
    if ((got & exp) !== exp)
      flag("STICKY", $sformatf("%s=0x%0h but bits 0x%0h must still be set (no software clear)", nm, got[7:0], exp[7:0]));
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("APB transfers checked=%0d  errors=%0d", n_chk, n_err), UVM_LOW)
  endfunction
endclass : apb_pkt_scoreboard
