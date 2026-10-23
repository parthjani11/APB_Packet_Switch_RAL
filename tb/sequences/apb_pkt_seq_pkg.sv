//-----------------------------------------------------------------------------
// Package : apb_pkt_seq_pkg
// File    : tb/sequences/apb_pkt_seq_pkg.sv
// Description:
//   Sequence package. Imports UVM, APB agent, and RAL packages, then includes
//   all test sequences in dependency order.
//-----------------------------------------------------------------------------

package apb_pkt_seq_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import apb_agent_pkg::*;
  import apb_pkt_reg_pkg::*;

  `include "apb_pkt_base_seq.sv"
  `include "apb_pkt_reset_seq.sv"
  `include "apb_pkt_unlock_seq.sv"
  `include "apb_pkt_lock_seq.sv"
  `include "apb_pkt_basic_gen_seq.sv"
  `include "apb_pkt_drop_scenario_seq.sv"
  `include "apb_pkt_irq_test_seq.sv"
  `include "apb_pkt_err_inject_seq.sv"
  `include "apb_pkt_lock_protection_seq.sv"
  `include "apb_pkt_boundary_seq.sv"
  `include "apb_pkt_continuous_mode_seq.sv"
  `include "apb_pkt_stat_saturation_seq.sv"
  `include "apb_pkt_ral_hw_reset_seq.sv"
  `include "apb_pkt_ral_bit_bash_seq.sv"
  `include "apb_pkt_ral_access_seq.sv"

endpackage : apb_pkt_seq_pkg
