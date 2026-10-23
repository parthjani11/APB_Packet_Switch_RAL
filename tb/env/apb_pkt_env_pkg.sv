package apb_pkt_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_agent_pkg::*;
  import apb_pkt_reg_pkg::*;

  localparam logic [31:0] APB_PKT_UNLOCK_KEY = 32'hA5A5_C3C3;   // spec 5.24

  `include "apb_pkt_state.sv"
  `include "apb_pkt_reg_cbs.sv"
  `include "apb_pkt_scoreboard.sv"
  `include "apb_pkt_coverage.sv"
  `include "apb_pkt_env.sv"
endpackage : apb_pkt_env_pkg
