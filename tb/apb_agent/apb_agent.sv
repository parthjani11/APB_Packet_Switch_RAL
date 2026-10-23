//-----------------------------------------------------------------------------
// Class  : apb_agent
// File   : tb/apb_agent/apb_agent.sv
// Description:
//   APB master agent. Assembles the driver, monitor, and sequencer into
//   a reusable UVM verification component. Supports both ACTIVE (with driver)
//   and PASSIVE (monitor-only) configurations.
//-----------------------------------------------------------------------------

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  // Components
  apb_driver    m_driver;
  apb_monitor   m_monitor;
  apb_sequencer m_sequencer;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "apb_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // Build Phase
  // -------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always created
    m_monitor = apb_monitor::type_id::create("m_monitor", this);

    // Driver and sequencer only in ACTIVE mode
    if (get_is_active() == UVM_ACTIVE) begin
      m_driver    = apb_driver::type_id::create("m_driver", this);
      m_sequencer = apb_sequencer::type_id::create("m_sequencer", this);
    end
  endfunction

  // -------------------------------------------------------------------------
  // Connect Phase
  // -------------------------------------------------------------------------
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction

endclass : apb_agent
