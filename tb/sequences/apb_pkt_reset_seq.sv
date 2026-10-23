//-----------------------------------------------------------------------------
// Class  : apb_pkt_reset_seq
// File   : tb/sequences/apb_pkt_reset_seq.sv
// Description:
//   Reset sequence. Drives presetn low for a number of cycles, then
//   releases it. Also supports triggering a soft reset via the SOFT_RESET
//   register.
//-----------------------------------------------------------------------------

class apb_pkt_reset_seq extends apb_pkt_base_seq;
  `uvm_object_utils(apb_pkt_reset_seq)

  // Configuration
  bit do_soft_reset = 0;  // If 1, perform soft reset via register write

  function new(string name = "apb_pkt_reset_seq");
    super.new(name);
  endfunction

  virtual task body();
    if (do_soft_reset) begin
      `uvm_info("RESET_SEQ", "Performing SOFT RESET via SOFT_RESET register", UVM_MEDIUM)
      ral_write(reg_block.soft_reset, 32'h0000_0001);
      wait_clocks(5);
    end else begin
      `uvm_info("RESET_SEQ", "Hard reset is handled by tb_top (presetn toggle)", UVM_MEDIUM)
      // Hard reset is driven by tb_top, not by sequences
      // This sequence just waits for it to complete
      wait_clocks(10);
    end
  endtask

endclass : apb_pkt_reset_seq
