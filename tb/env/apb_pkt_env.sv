//-----------------------------------------------------------------------------
// apb_pkt_env : mirrors the "UVM RAL TestBench" reference architecture
//   RAL model  : apb_pkt_reg_block + default_map + apb_pkt_ral_adapter
//   Bus agent  : apb_agent (sequencer, driver, monitor)
//   Predictor  : uvm_reg_predictor #(apb_seq_item)   (explicit prediction)
//   + scoreboard, coverage, register callbacks, shared state
//-----------------------------------------------------------------------------
class apb_pkt_env extends uvm_env;
  `uvm_component_utils(apb_pkt_env)

  apb_agent                          m_apb_agent;
  apb_pkt_reg_block                  m_ral;
  apb_pkt_ral_adapter                m_adapter;
  uvm_reg_predictor #(apb_seq_item)  m_predictor;
  apb_pkt_scoreboard                 m_sb;
  apb_pkt_coverage                   m_cov;
  apb_pkt_state                      m_state;
  virtual apb_if                     vif;

  function new(string name = "apb_pkt_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "apb_if not set for apb_pkt_env")
    m_state     = apb_pkt_state::type_id::create("m_state");
    m_apb_agent = apb_agent::type_id::create("m_apb_agent", this);
    m_ral       = apb_pkt_reg_block::type_id::create("m_ral");
    m_ral.configure(null, "");
    m_ral.build();                                   // also calls lock_model()
    m_adapter   = apb_pkt_ral_adapter::type_id::create("m_adapter");
    m_predictor = uvm_reg_predictor #(apb_seq_item)::type_id::create("m_predictor", this);
    m_sb        = apb_pkt_scoreboard::type_id::create("m_sb", this);
    m_cov       = apb_pkt_coverage::type_id::create("m_cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // RAL -> bus : frontdoor accesses go through the agent sequencer
    m_ral.default_map.set_sequencer(m_apb_agent.m_sequencer, m_adapter);
    m_ral.default_map.set_auto_predict(0);           // mirror updated ONLY by the predictor
    // bus -> RAL : monitor feeds the predictor
    m_predictor.map     = m_ral.default_map;
    m_predictor.adapter = m_adapter;
    m_sb.m_ral  = m_ral;  m_sb.st  = m_state;
    m_cov.m_ral = m_ral;  m_cov.st = m_state;
    // Connection order matters: analysis_port.write() calls subscribers in connect order.
    // Scoreboard and coverage must see pre-transfer mirror/lock state, so both go BEFORE the predictor.
    m_apb_agent.m_monitor.ap.connect(m_sb.analysis_export);
    m_apb_agent.m_monitor.ap.connect(m_cov.analysis_export);
    m_apb_agent.m_monitor.ap.connect(m_predictor.bus_in);
    attach_reg_cbs();
  endfunction

  protected function void attach_reg_cbs();
    apb_pkt_field_cb lock_cb, pulse_cb, len_cb;
    apb_pkt_lock_cb  key_cb;
    apb_pkt_srst_cb  srst_cb;
    uvm_reg_field    flds[$];

    m_state.lockable_regs = '{m_ral.switch_ctrl, m_ral.port_enable, m_ral.fwd_enable,
                              m_ral.gen_ctrl, m_ral.gen_pkt_cfg, m_ral.gen_interval,
                              m_ral.gen_count, m_ral.irq_enable, m_ral.err_enable};

    lock_cb  = apb_pkt_field_cb::type_id::create("lock_cb");   lock_cb.st = m_state;  lock_cb.lockable = 1;
    pulse_cb = apb_pkt_field_cb::type_id::create("pulse_cb");  pulse_cb.st = m_state; pulse_cb.pulse = 1;
    len_cb   = apb_pkt_field_cb::type_id::create("len_cb");    len_cb.st = m_state;
    len_cb.lockable = 1; len_cb.len_clamp = 1;
    key_cb   = apb_pkt_lock_cb::type_id::create("key_cb");     key_cb.st = m_state;
    srst_cb  = apb_pkt_srst_cb::type_id::create("srst_cb");    srst_cb.st = m_state; srst_cb.blk = m_ral;

    foreach (m_state.lockable_regs[i]) begin
      flds.delete();
      m_state.lockable_regs[i].get_fields(flds);
      foreach (flds[j]) uvm_reg_field_cb::add(flds[j], lock_cb);
    end
    uvm_reg_field_cb::add(m_ral.gen_ctrl.start,         pulse_cb);
    uvm_reg_field_cb::add(m_ral.gen_ctrl.stop,          pulse_cb);
    uvm_reg_field_cb::add(m_ral.switch_ctrl.stat_clear, pulse_cb);
    uvm_reg_field_cb::add(m_ral.gen_pkt_cfg.length,     len_cb);
    uvm_reg_field_cb::add(m_ral.lock.key,               key_cb);
    uvm_reg_field_cb::add(m_ral.soft_reset.pulse,       srst_cb);
  endfunction

  // configure() only stores reset values; the mirror is loaded by reset(). Do it once,
  // before any transaction, so the first read compares against the reset values.
  virtual function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    m_ral.reset();
    m_state.reset_all();
  endfunction

  // Hard reset asserted mid-test: bring the model back to power-up state
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.presetn);
      m_ral.reset();
      m_state.reset_all();
    end
  endtask
endclass : apb_pkt_env
