//-----------------------------------------------------------------------------
// apb_driver : pulls apb_seq_item from the sequencer and drives one AMBA 3 APB
//              transfer (SETUP phase, then ACCESS phase) on apb_if.
//-----------------------------------------------------------------------------
class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;
  int unsigned   timeout_cycles = 1000;      // PREADY watchdog (this DUT never inserts wait states)

  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found for apb_driver")
  endfunction

  virtual task run_phase(uvm_phase phase);
    drive_idle();
    if (vif.presetn !== 1'b1) @(posedge vif.presetn);     // never drive while in reset
    forever begin
      apb_seq_item req;
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();                          // RAL bus2reg() reads req after this
    end
  endtask

  protected task drive_idle();
    vif.drv_cb.psel    <= 1'b0;
    vif.drv_cb.penable <= 1'b0;
    vif.drv_cb.pwrite  <= 1'b0;
    vif.drv_cb.paddr   <= 16'h0;
    vif.drv_cb.pwdata  <= 32'h0;
  endtask

  // Edge numbering (A,B,C = consecutive pclk rising edges):
  //   after A : PSEL=1 PENABLE=0  -> the DUT sees SETUP at edge B
  //   after B : PENABLE=1         -> the DUT sees ACCESS at edge C (transfer completes if PREADY=1)
  // PRDATA/PSLVERR are only valid at the completing edge, so they are sampled there.
  virtual task drive_transfer(apb_seq_item req);
    int unsigned waited = 0;

    @(vif.drv_cb);                                  // edge A : SETUP phase
    vif.drv_cb.psel    <= 1'b1;
    vif.drv_cb.penable <= 1'b0;
    vif.drv_cb.pwrite  <= req.rw;
    vif.drv_cb.paddr   <= req.addr;
    vif.drv_cb.pwdata  <= req.data;

    @(vif.drv_cb);                                  // edge B : move to ACCESS phase
    vif.drv_cb.penable <= 1'b1;

    do begin                                        // edge C (and later, if wait states)
      @(vif.drv_cb);
      if (++waited > timeout_cycles)
        `uvm_fatal("APB_DRV", $sformatf("PREADY not seen for %0d cycles: %s", timeout_cycles, req.convert2string()))
    end while (vif.drv_cb.pready !== 1'b1);

    req.rdata  = vif.drv_cb.prdata;                 // sampled AT the completing edge
    req.slverr = vif.drv_cb.pslverr;
    `uvm_info("APB_DRV", req.convert2string(), UVM_HIGH)

    vif.drv_cb.psel    <= 1'b0;                     // back to idle
    vif.drv_cb.penable <= 1'b0;
  endtask
endclass : apb_driver
