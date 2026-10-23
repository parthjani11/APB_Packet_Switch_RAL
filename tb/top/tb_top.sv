`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import apb_pkt_test_pkg::*;

  logic pclk, presetn;
  initial pclk = 1'b0;
  always #5 pclk = ~pclk;                       // 100 MHz: apb_pkt_base_seq::wait_clocks() assumes 10 ns
  initial begin
    presetn = 1'b0;
    repeat (5) @(posedge pclk);
    #1 presetn = 1'b1;
  end

  apb_if apb_vif (.pclk(pclk), .presetn(presetn));

  apb_pkt_switch dut (
    .pclk(pclk), .presetn(presetn),
    .psel(apb_vif.psel), .penable(apb_vif.penable), .pwrite(apb_vif.pwrite),
    .paddr(apb_vif.paddr), .pwdata(apb_vif.pwdata),
    .prdata(apb_vif.prdata), .pready(apb_vif.pready), .pslverr(apb_vif.pslverr),
    .irq(apb_vif.irq));

  initial if ($test$plusargs("WAVES")) begin     // make questa WAVES=1
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
  end

  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.m_env*", "vif", apb_vif);
    run_test();
  end
endmodule
