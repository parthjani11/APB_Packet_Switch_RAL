//-----------------------------------------------------------------------------
// Package : apb_pkt_reg_pkg
// File    : tb/ral/apb_pkt_reg_pkg.sv
// Description:
//   RAL package. Imports UVM and the APB agent package, then includes
//   all RAL model files in dependency order.
//-----------------------------------------------------------------------------

package apb_pkt_reg_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import apb_agent_pkg::*;

  `include "apb_pkt_reg_field_defs.sv"
  `include "apb_pkt_reg_block.sv"
  `include "apb_pkt_ral_adapter.sv"

endpackage : apb_pkt_reg_pkg
