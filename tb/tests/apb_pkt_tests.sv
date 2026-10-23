//-----------------------------------------------------------------------------
// Tests. One generic test runs ANY registered sequence by name (+SEQ=<name>),
// one regression test runs the whole library with a soft reset in between.
//-----------------------------------------------------------------------------
class apb_pkt_base_test extends uvm_test;
  `uvm_component_utils(apb_pkt_base_test)
  apb_pkt_env m_env;

  function new(string name = "apb_pkt_base_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_env = apb_pkt_env::type_id::create("m_env", this);
    uvm_top.set_timeout(50ms, 1);                  // stat_saturation needs ~1.3 ms of sim time
  endfunction

  protected task wait_for_reset();
    if (m_env.vif.presetn !== 1'b1) @(posedge m_env.vif.presetn);
    repeat (5) @(posedge m_env.vif.pclk);
  endtask

  protected task run_seq(apb_pkt_base_seq s);
    s.reg_block = m_env.m_ral;                     // sequences use RAL frontdoor
    s.start(m_env.m_apb_agent.m_sequencer);
  endtask
endclass : apb_pkt_base_test

class apb_pkt_seq_test extends apb_pkt_base_test;
  `uvm_component_utils(apb_pkt_seq_test)
  string seq_name = "apb_pkt_basic_gen_seq";

  function new(string name = "apb_pkt_seq_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_object       o;
    apb_pkt_base_seq s;
    void'($value$plusargs("SEQ=%s", seq_name));
    o = uvm_factory::get().create_object_by_name(seq_name, get_full_name(), seq_name);
    if (o == null || !$cast(s, o))
      `uvm_fatal("SEQ", $sformatf("'%s' is not a registered apb_pkt_base_seq", seq_name))
    phase.raise_objection(this, "seq_test");
    wait_for_reset();
    run_seq(s);
    #200ns;
    phase.drop_objection(this, "seq_test");
  endtask
endclass : apb_pkt_seq_test

class apb_pkt_regress_test extends apb_pkt_base_test;
  `uvm_component_utils(apb_pkt_regress_test)
  string seq_list[$] = '{
    "apb_pkt_ral_hw_reset_seq", "apb_pkt_unlock_seq", "apb_pkt_lock_seq",
    "apb_pkt_basic_gen_seq", "apb_pkt_drop_scenario_seq", "apb_pkt_irq_test_seq",
    "apb_pkt_err_inject_seq", "apb_pkt_lock_protection_seq", "apb_pkt_boundary_seq",
    "apb_pkt_continuous_mode_seq", "apb_pkt_stat_saturation_seq", "apb_pkt_reset_seq",
    "apb_pkt_ral_access_seq", "apb_pkt_ral_bit_bash_seq" };

  function new(string name = "apb_pkt_regress_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_status_e status;
    phase.raise_objection(this, "regress");
    wait_for_reset();
    foreach (seq_list[i]) begin
      uvm_object       o = uvm_factory::get().create_object_by_name(seq_list[i], get_full_name(), seq_list[i]);
      apb_pkt_base_seq s;
      if (o == null || !$cast(s, o)) begin
        `uvm_error("SEQ", $sformatf("cannot create '%s'", seq_list[i]))
        continue;
      end
      m_env.m_ral.soft_reset.write(status, 32'h1);    // known state between sequences
      `uvm_info("REGRESS", $sformatf("---- %s ----", seq_list[i]), UVM_LOW)
      run_seq(s);
    end
    #200ns;
    phase.drop_objection(this, "regress");
  endtask
endclass : apb_pkt_regress_test

//-----------------------------------------------------------------------------
// apb_pkt_ral_selftest : DUT-independent proof of the mirror callbacks.
// Observed APB transfers are fed straight into the predictor (as the monitor
// would) and the mirror is checked after each one.
//   run:  make questa TEST=apb_pkt_ral_selftest
//-----------------------------------------------------------------------------
class apb_pkt_ral_selftest extends apb_pkt_base_test;
  `uvm_component_utils(apb_pkt_ral_selftest)
  int unsigned errs, checks;

  function new(string name = "apb_pkt_ral_selftest", uvm_component parent);
    super.new(name, parent);
  endfunction

  protected function void obs(bit rw, bit [15:0] addr, bit [31:0] data);   // one observed transfer
    apb_seq_item t = apb_seq_item::type_id::create("t");
    t.rw = rw; t.addr = addr; t.data = data; t.rdata = data; t.slverr = 1'b0;
    m_env.m_predictor.write(t);
  endfunction

  protected function void chk(string what, uvm_reg_data_t got, uvm_reg_data_t exp);
    checks++;
    if (got !== exp) begin
      errs++;
      `uvm_error("SELFTEST", $sformatf("%s: got 0x%0h, expected 0x%0h", what, got, exp))
    end
    else `uvm_info("SELFTEST", $sformatf("ok  %s = 0x%0h", what, got), UVM_MEDIUM)
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_pkt_reg_block r = m_env.m_ral;
    phase.raise_objection(this, "selftest");
    // 1 power-up state is locked
    chk("lock mirror at reset",              r.lock.get_mirrored_value(),        32'h1);
    // 2 lockable write ignored while locked
    obs(1, 16'h24, 32'h5);
    chk("PORT_ENABLE write while locked",    r.port_enable.get_mirrored_value(), 32'hF);
    // 3 W1C is NOT gated by the lock (IRQ_STATUS accessible while locked)
    void'(r.irq_status.predict(32'hFF));
    obs(1, 16'h3C, 32'h41);
    chk("IRQ_STATUS W1C 0x41 while locked",  r.irq_status.get_mirrored_value(),  32'hBE);
    // 4 key unlocks, mirror reads back LOCKED=0
    obs(1, 16'h5C, 32'hA5A5_C3C3);
    chk("lock mirror after key",             r.lock.get_mirrored_value(),        32'h0);
    // 5 unlocked write lands
    obs(1, 16'h24, 32'h5);
    chk("PORT_ENABLE write unlocked",        r.port_enable.get_mirrored_value(), 32'h5);
    // 6 pulse fields read back 0 (mask 0x9)
    obs(1, 16'h2C, 32'h3);
    chk("GEN_CTRL write 0x3 (START pulse)",  r.gen_ctrl.get_mirrored_value(),    32'h1);
    obs(1, 16'h20, 32'hB);
    chk("SWITCH_CTRL write 0xB (STAT_CLEAR)",r.switch_ctrl.get_mirrored_value(), 32'h9);
    // 7 LENGTH 0 is stored as 1
    obs(1, 16'h30, 32'h0010_0001);
    chk("GEN_PKT_CFG length 0 -> 1",         r.gen_pkt_cfg.get_mirrored_value(), 32'h0010_0101);
    // 8 any non-key value re-locks, later writes ignored
    obs(1, 16'h5C, 32'h0);
    chk("lock mirror after non-key",         r.lock.get_mirrored_value(),        32'h1);
    obs(1, 16'h24, 32'hA);
    chk("PORT_ENABLE after re-lock",         r.port_enable.get_mirrored_value(), 32'h5);
    // 9 SOFT_RESET restores every mirror and re-locks
    obs(1, 16'h60, 32'h1);
    chk("PORT_ENABLE after soft reset",      r.port_enable.get_mirrored_value(), 32'hF);
    chk("GEN_PKT_CFG after soft reset",      r.gen_pkt_cfg.get_mirrored_value(), 32'h401);
    chk("lock mirror after soft reset",      r.lock.get_mirrored_value(),        32'h1);
    `uvm_info("SELFTEST", $sformatf("%0d checks, %0d errors -> %s", checks, errs,
              (errs == 0) ? "ALL PASSED" : "FAILED"), UVM_NONE)
    phase.drop_objection(this, "selftest");
  endtask
endclass : apb_pkt_ral_selftest
