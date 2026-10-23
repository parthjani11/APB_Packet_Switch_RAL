//-----------------------------------------------------------------------------
// Class  : apb_monitor
// File   : tb/apb_agent/apb_monitor.sv
// Description:
//   APB bus monitor. Observes completed APB3 transfers on the bus and
//   broadcasts them through an analysis port to subscribers (predictor,
//   scoreboard, coverage).
//-----------------------------------------------------------------------------

class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  // Virtual interface handle
  virtual apb_if vif;

  // Analysis port to broadcast observed transactions
  uvm_analysis_port #(apb_seq_item) ap;

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "apb_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  // -------------------------------------------------------------------------
  // Build Phase
  // -------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found for apb_monitor")
  endfunction

  // -------------------------------------------------------------------------
  // Run Phase
  // -------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    forever begin
      apb_seq_item txn;

      // Wait for the access phase to complete
      @(posedge vif.pclk);
      if (vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready) begin
        txn = apb_seq_item::type_id::create("txn");
        txn.addr   = vif.mon_cb.paddr;
        txn.data   = vif.mon_cb.pwdata;
        txn.rw     = vif.mon_cb.pwrite;
        txn.rdata  = vif.mon_cb.prdata;
        txn.slverr = vif.mon_cb.pslverr;

        `uvm_info("APB_MON", txn.convert2string(), UVM_HIGH)
        ap.write(txn);
      end
    end
  endtask

endclass : apb_monitor
