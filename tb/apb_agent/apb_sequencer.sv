//-----------------------------------------------------------------------------
// Class  : apb_sequencer
// File   : tb/apb_agent/apb_sequencer.sv
// Description:
//   APB sequencer. Routes sequence items from sequences to the driver.
//   Standard UVM sequencer with no additional functionality.
//-----------------------------------------------------------------------------

class apb_sequencer extends uvm_sequencer #(apb_seq_item);
  `uvm_component_utils(apb_sequencer)

  function new(string name = "apb_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : apb_sequencer
