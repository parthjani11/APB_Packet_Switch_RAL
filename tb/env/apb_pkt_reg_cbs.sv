//-----------------------------------------------------------------------------
// Register callbacks: teach the RAL mirror the behaviours the plain access
// policies (RW/RO/WO/W1C) cannot express. All hook uvm_reg_cbs::post_predict,
// which runs inside uvm_reg_field::do_predict, so they act on predictor updates.
//-----------------------------------------------------------------------------

// Lockable RW fields / pulse fields / LENGTH clamp (spec 3.6, 5.12, 5.13)
class apb_pkt_field_cb extends uvm_reg_cbs;
  `uvm_object_utils(apb_pkt_field_cb)
  apb_pkt_state st;
  bit lockable, pulse, len_clamp;

  function new(string name = "apb_pkt_field_cb");
    super.new(name);
  endfunction

  virtual function void post_predict(input uvm_reg_field fld,
                                     input uvm_reg_data_t previous,
                                     inout uvm_reg_data_t value,
                                     input uvm_predict_e kind,
                                     input uvm_path_e path,
                                     input uvm_reg_map map);
    if (kind != UVM_PREDICT_WRITE) return;
    if (lockable && st.locked) begin value = previous; return; end  // write ignored
    if (pulse)                         value = '0;                  // START/STOP/STAT_CLEAR read 0
    else if (len_clamp && value == 0)  value = 1;                   // LENGTH 0 is stored as 1
  endfunction
endclass : apb_pkt_field_cb

// LOCK key: full 32-bit compare on write, read-back is {31'b0, LOCKED} (spec 5.24)
class apb_pkt_lock_cb extends uvm_reg_cbs;
  `uvm_object_utils(apb_pkt_lock_cb)
  apb_pkt_state st;
  function new(string name = "apb_pkt_lock_cb");
    super.new(name);
  endfunction
  virtual function void post_predict(input uvm_reg_field fld, input uvm_reg_data_t previous,
                                     inout uvm_reg_data_t value, input uvm_predict_e kind,
                                     input uvm_path_e path, input uvm_reg_map map);
    if (kind != UVM_PREDICT_WRITE) return;
    st.locked = (value[31:0] != APB_PKT_UNLOCK_KEY);
    value     = uvm_reg_data_t'(st.locked);
  endfunction
endclass : apb_pkt_lock_cb

// SOFT_RESET.PULSE: restore every mirror to its reset value and re-lock (spec 5.25)
class apb_pkt_srst_cb extends uvm_reg_cbs;
  `uvm_object_utils(apb_pkt_srst_cb)
  apb_pkt_state  st;
  uvm_reg_block  blk;
  function new(string name = "apb_pkt_srst_cb");
    super.new(name);
  endfunction
  virtual function void post_predict(input uvm_reg_field fld, input uvm_reg_data_t previous,
                                     inout uvm_reg_data_t value, input uvm_predict_e kind,
                                     input uvm_path_e path, input uvm_reg_map map);
    if (kind != UVM_PREDICT_WRITE) return;
    if (value[0]) begin blk.reset(); st.reset_all(); end
    value = '0;
  endfunction
endclass : apb_pkt_srst_cb
