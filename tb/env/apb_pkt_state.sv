//-----------------------------------------------------------------------------
// apb_pkt_state : small shared object (env owns it). Holds the few DUT-side
// facts that the RAL mirror cannot express by itself (spec 3.6 lock, 5.12 pulses).
//-----------------------------------------------------------------------------
class apb_pkt_state extends uvm_object;
  `uvm_object_utils(apb_pkt_state)

  bit          locked = 1'b1;        // CSR bank powers up locked
  bit          cont_q;               // GEN_CTRL.CONTINUOUS as the DUT sees it (pre-write)
  uvm_reg      lockable_regs[$];     // registers gated by LOCK (spec 3.6)

  // run accounting (scoreboard)
  int unsigned starts_since_clear;
  int unsigned exp_total;
  bit          exp_all_drop;
  bit          ovf_possible;
  bit          done_seen;
  bit          sticky_ok;            // sticky-bit expectations still valid (no software clear since START)
  bit [31:0]   exp_irq, exp_err;     // bits that must still read 1 in IRQ_STATUS / ERR_STATUS

  function new(string name = "apb_pkt_state");
    super.new(name);
  endfunction

  function bit is_lockable(uvm_reg r);
    foreach (lockable_regs[i]) if (lockable_regs[i] == r) return 1'b1;
    return 1'b0;
  endfunction

  function void clear_stats();
    starts_since_clear = 0; exp_total = 0;
    exp_all_drop = 0; ovf_possible = 0; done_seen = 0;
    sticky_ok = 0; exp_irq = 0; exp_err = 0;
  endfunction

  function void reset_all();          // hard reset or SOFT_RESET.PULSE
    locked = 1'b1; cont_q = 1'b0; clear_stats();
  endfunction
endclass : apb_pkt_state
