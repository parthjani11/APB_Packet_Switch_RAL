//-----------------------------------------------------------------------------
// Interface : apb_if
// File      : tb/apb_agent/apb_if.sv
// Description:
//   SystemVerilog interface for the AMBA APB3 bus. Provides clocking blocks
//   for master driver and monitor, plus modports for directed connectivity.
//-----------------------------------------------------------------------------

interface apb_if (
  input logic pclk,
  input logic presetn
);

  // -------------------------------------------------------------------------
  // APB Signals
  // -------------------------------------------------------------------------
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [15:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  // IRQ (directly from DUT)
  logic        irq;

  // -------------------------------------------------------------------------
  // Clocking Block: Master Driver
  // -------------------------------------------------------------------------
  clocking drv_cb @(posedge pclk);
    default input #1step output #0;
    output psel, penable, pwrite, paddr, pwdata;
    input  prdata, pready, pslverr;
  endclocking

  // -------------------------------------------------------------------------
  // Clocking Block: Monitor
  // -------------------------------------------------------------------------
  clocking mon_cb @(posedge pclk);
    default input #1step output #0;
    input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr, irq;
  endclocking

  // -------------------------------------------------------------------------
  // Modports
  // -------------------------------------------------------------------------
  // Defined idle levels from time 0 (a clocking-block drive only takes effect at the first clock edge)
  initial begin
    psel = 1'b0; penable = 1'b0; pwrite = 1'b0; paddr = '0; pwdata = '0;
  end

  modport DRIVER  (clocking drv_cb, input pclk, presetn);
  modport MONITOR (clocking mon_cb, input pclk, presetn);

endinterface : apb_if
