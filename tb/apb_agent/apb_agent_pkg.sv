//-----------------------------------------------------------------------------
// Package : apb_agent_pkg
// File    : tb/apb_agent/apb_agent_pkg.sv
// Description:
//   Package for the reusable APB3 bus agent UVC. Imports UVM and includes
//   all agent component files in dependency order.
//-----------------------------------------------------------------------------

package apb_agent_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "apb_seq_item.sv"
  `include "apb_sequencer.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"

endpackage : apb_agent_pkg
