//-----------------------------------------------------------------------------
// Class  : apb_seq_item
// File   : tb/apb_agent/apb_seq_item.sv
// Description:
//   APB transaction item. Represents a single APB3 read or write transfer.
//   Contains address, data, direction, and response fields.
//-----------------------------------------------------------------------------

class apb_seq_item extends uvm_sequence_item;

  // -------------------------------------------------------------------------
  // Fields
  // -------------------------------------------------------------------------
  rand logic [15:0] addr;       // Byte address
  rand logic [31:0] data;       // Write data (master → slave)
  rand logic        rw;         // 1 = write, 0 = read
  logic [31:0]      rdata;      // Read data (slave → master), filled by driver
  logic             slverr;     // Slave error response

  // -------------------------------------------------------------------------
  // UVM Automation
  // -------------------------------------------------------------------------
  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(data,   UVM_ALL_ON)
    `uvm_field_int(rw,     UVM_ALL_ON)
    `uvm_field_int(rdata,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  // -------------------------------------------------------------------------
  // Constraints
  // -------------------------------------------------------------------------
  constraint c_addr_aligned {
    addr[1:0] == 2'b00;           // 4-byte aligned
  }

  constraint c_addr_range {
    addr <= 16'h0060;             // Within valid register space
  }

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------
  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  // -------------------------------------------------------------------------
  // Convert to String
  // -------------------------------------------------------------------------
  virtual function string convert2string();
    return $sformatf("APB %s addr=0x%04h data=0x%08h rdata=0x%08h slverr=%0b",
                     rw ? "WR" : "RD", addr, data, rdata, slverr);
  endfunction

endclass : apb_seq_item
