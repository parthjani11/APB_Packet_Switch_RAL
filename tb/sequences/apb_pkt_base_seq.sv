//-----------------------------------------------------------------------------
// Class  : apb_pkt_base_seq
// File   : tb/sequences/apb_pkt_base_seq.sv
// Description:
//   Base virtual sequence for all APB Packet Switch test sequences.
//   Holds a handle to the register block for RAL-based register access.
//-----------------------------------------------------------------------------

class apb_pkt_base_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_pkt_base_seq)

  // Register block handle (set by test before starting sequence)
  apb_pkt_reg_block reg_block;

  // Status variable for RAL operations
  uvm_status_e status;

  function new(string name = "apb_pkt_base_seq");
    super.new(name);
  endfunction

  // Convenience: write a register by handle
  virtual task ral_write(uvm_reg r, uvm_reg_data_t value);
    r.write(status, value, .parent(this));
    if (status != UVM_IS_OK)
      `uvm_warning("RAL_WR", $sformatf("Write to %s returned status %s",
                   r.get_name(), status.name()))
  endtask

  // Convenience: read a register by handle
  virtual task ral_read(uvm_reg r, output uvm_reg_data_t value);
    r.read(status, value, .parent(this));
    if (status != UVM_IS_OK)
      `uvm_warning("RAL_RD", $sformatf("Read from %s returned status %s",
                   r.get_name(), status.name()))
  endtask


  // Guard: the test must hand over the RAL model before start()
  virtual task pre_body();
    if (reg_block == null) `uvm_fatal("NO_RAL", "reg_block was not set before start()")
  endtask

  // Field helpers: bit positions come from the RAL, never from magic numbers
  function uvm_reg_data_t fval(uvm_reg_data_t word, uvm_reg_field f);
    return (word >> f.get_lsb_pos()) & ((uvm_reg_data_t'(1) << f.get_n_bits()) - 1);
  endfunction

  function uvm_reg_data_t pack_fld(uvm_reg_field f, uvm_reg_data_t v);
    return (v & ((uvm_reg_data_t'(1) << f.get_n_bits()) - 1)) << f.get_lsb_pos();
  endfunction

  // Exclude a register from a built-in RAL test (e.g. "NO_REG_BIT_BASH_TEST")
  function void skip_reg(uvm_reg r, string test);
    uvm_resource_db #(bit)::set({"REG::", r.get_full_name()}, test, 1, this);
  endfunction

  // Convenience: wait N clock cycles (approx via #delay)
  virtual task wait_clocks(int n);
    repeat (n) #10ns;  // assumes the 100 MHz clock generated in tb_top
  endtask

endclass : apb_pkt_base_seq
