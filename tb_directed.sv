//-----------------------------------------------------------------------------
// tb_directed.sv : plain SystemVerilog self-checking test for apb_pkt_switch (no UVM).
// Follows spec section 6: unlock, program, run, check; drop scenario; errors; soft reset.
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_directed;
  import apb_pkt_pkg::*;

  logic        pclk = 1'b0, presetn = 1'b0;
  logic        psel = 1'b0, penable = 1'b0, pwrite = 1'b0;
  logic [15:0] paddr = 16'h0;
  logic [31:0] pwdata = 32'h0;
  wire  [31:0] prdata;
  wire         pready, pslverr, irq;

  int errors = 0, checks = 0;

  always #5 pclk = ~pclk;                                   // 100 MHz

  apb_pkt_switch dut (.pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
                      .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata), .prdata(prdata),
                      .pready(pready), .pslverr(pslverr), .irq(irq));

  initial if ($test$plusargs("WAVES")) begin
    $dumpfile("tb_directed.vcd");
    $dumpvars(0, tb_directed);
  end

  initial begin #2ms; $display("TEST FAILED: timeout"); $finish; end

  // ---- APB master, race-free in any simulator: drive 1 ns after the rising edge, sample mid-cycle.
  //   posedge A : SETUP  (psel=1, penable=0)
  //   posedge B : ACCESS (penable=1)
  //   negedge   : sample PRDATA/PSLVERR (stable; exactly what the DUT captures at the next posedge)
  //   posedge C : transfer completes, back to idle
  task automatic apb_write(input logic [15:0] a, input logic [31:0] d, output logic err);
    @(posedge pclk); #1; psel = 1'b1; penable = 1'b0; pwrite = 1'b1; paddr = a; pwdata = d;
    @(posedge pclk); #1; penable = 1'b1;
    @(negedge pclk); err = pslverr;
    @(posedge pclk); #1; psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
  endtask

  task automatic apb_read(input logic [15:0] a, output logic [31:0] d, output logic err);
    @(posedge pclk); #1; psel = 1'b1; penable = 1'b0; pwrite = 1'b0; paddr = a;
    @(posedge pclk); #1; penable = 1'b1;
    @(negedge pclk); d = prdata; err = pslverr;
    @(posedge pclk); #1; psel = 1'b0; penable = 1'b0;
  endtask

  task automatic fail(input string msg);
    errors++;
    $display("[%0t] ERROR: %s", $time, msg);
  endtask

  task automatic wr(input logic [15:0] a, input logic [31:0] d);
    logic e;
    apb_write(a, d, e);
    checks++;
    if (e) fail($sformatf("unexpected PSLVERR on write 0x%04h", a));
  endtask

  task automatic rd_chk(input string nm, input logic [15:0] a, input logic [31:0] exp,
                        input logic [31:0] mask = 32'hFFFF_FFFF);
    logic [31:0] d; logic e;
    apb_read(a, d, e);
    checks++;
    if (e || ((d & mask) !== (exp & mask)))
      fail($sformatf("%s @0x%04h read 0x%08h, expected 0x%08h (mask 0x%08h) pslverr=%0b", nm, a, d, exp, mask, e));
    else
      $display("[%0t] ok    %-28s = 0x%08h", $time, nm, d);
  endtask

  task automatic poll_done(input int max_polls);            // GEN_STATUS.DONE is bit 1
    logic [31:0] d; logic e; int n = 0;
    do begin apb_read(ADDR_GEN_STATUS, d, e); n++; end while (!d[1] && n < max_polls);
    checks++;
    if (!d[1]) fail("generator DONE not seen");
  endtask

  task automatic illegal_rd(input logic [15:0] a);          // spec 3.5: pslverr=1, read data 0
    logic [31:0] d; logic e;
    apb_read(a, d, e);
    checks++;
    if (!e || d !== 32'h0) fail($sformatf("illegal read 0x%04h: pslverr=%0b data=0x%08h", a, e, d));
    else $display("[%0t] ok    illegal read 0x%04h -> pslverr, data 0", $time, a);
  endtask

  task automatic illegal_wr(input logic [15:0] a);
    logic e;
    apb_write(a, 32'hFFFF_FFFF, e);
    checks++;
    if (!e) fail($sformatf("illegal write 0x%04h: pslverr not asserted", a));
    else $display("[%0t] ok    illegal write 0x%04h -> pslverr", $time, a);
  endtask

  initial begin
    $display("==== apb_pkt_switch directed test ====");
    repeat (5) @(posedge pclk);
    #1 presetn = 1'b1;
    repeat (3) @(posedge pclk);

    // 1. identification and power-up state
    rd_chk("DEVICE_ID",             ADDR_DEVICE_ID,     32'h02A5_5357);
    rd_chk("VERSION",               ADDR_VERSION,       32'h0001_0200);
    rd_chk("SWITCH_STATUS reset",   ADDR_SWITCH_STATUS, 32'h0000_00F9);
    rd_chk("LOCK reset (locked)",   ADDR_LOCK,          32'h1);

    // 2. lock: writes to all nine lockable registers are ignored while locked (spec 3.6)
    wr(ADDR_SWITCH_CTRL,  32'hFFFF_FFFF);  wr(ADDR_PORT_ENABLE, 32'h5);
    wr(ADDR_FWD_ENABLE,   32'h5);          wr(ADDR_GEN_CTRL,    32'hFFFF_FFFF);
    wr(ADDR_GEN_PKT_CFG,  32'hFFFF_FFFF);  wr(ADDR_GEN_INTERVAL,32'h1234);
    wr(ADDR_GEN_COUNT,    32'h5678);       wr(ADDR_IRQ_ENABLE,  32'hFF);
    wr(ADDR_ERR_ENABLE,   32'hFF);
    rd_chk("SWITCH_CTRL (locked wr)",  ADDR_SWITCH_CTRL,  32'h0);
    rd_chk("PORT_ENABLE (locked wr)",  ADDR_PORT_ENABLE,  32'hF);
    rd_chk("FWD_ENABLE (locked wr)",   ADDR_FWD_ENABLE,   32'hF);
    rd_chk("GEN_CTRL (locked wr)",     ADDR_GEN_CTRL,     32'h0);
    rd_chk("GEN_PKT_CFG (locked wr)",  ADDR_GEN_PKT_CFG,  32'h0000_0401);
    rd_chk("GEN_INTERVAL (locked wr)", ADDR_GEN_INTERVAL, 32'h2);
    rd_chk("GEN_COUNT (locked wr)",    ADDR_GEN_COUNT,    32'h4);
    rd_chk("IRQ_ENABLE (locked wr)",   ADDR_IRQ_ENABLE,   32'h0);
    rd_chk("ERR_ENABLE (locked wr)",   ADDR_ERR_ENABLE,   32'h0);
    // IRQ_FORCE and W1C stay accessible while locked
    wr(ADDR_IRQ_FORCE, 32'h80);
    rd_chk("IRQ_STATUS SW_EVENT forced", ADDR_IRQ_STATUS, 32'h80, 32'h80);
    wr(ADDR_IRQ_STATUS, 32'h80);
    rd_chk("IRQ_STATUS SW_EVENT cleared", ADDR_IRQ_STATUS, 32'h00, 32'h80);

    // 3. unlock with the key
    wr(ADDR_LOCK, UNLOCK_KEY);
    rd_chk("LOCK after key",        ADDR_LOCK,          32'h0);
    wr(ADDR_ERR_ENABLE,  32'h0000_0002);                      // unlocked write lands
    rd_chk("ERR_ENABLE",            ADDR_ERR_ENABLE,    32'h2);

    // 4. spec 6.1: four packets, source 0 -> destination 1
    wr(ADDR_PORT_ENABLE, 32'h0000_000F);
    wr(ADDR_FWD_ENABLE,  32'h0000_000F);
    wr(ADDR_SWITCH_CTRL, 32'h0000_0009);
    wr(ADDR_GEN_PKT_CFG, 32'h0010_0401);
    wr(ADDR_GEN_INTERVAL,32'h0000_0002);
    wr(ADDR_GEN_COUNT,   32'h0000_0004);
    wr(ADDR_IRQ_ENABLE,  32'h0000_0041);
    wr(ADDR_GEN_CTRL,    32'h0000_0003);
    poll_done(500);
    rd_chk("STAT_RX",               ADDR_STAT_RX,       32'd4);
    rd_chk("STAT_TX",               ADDR_STAT_TX,       32'd4);
    rd_chk("STAT_DROP",             ADDR_STAT_DROP,     32'd0);
    rd_chk("GEN_STATUS (DONE,fsm=3)", ADDR_GEN_STATUS,  32'hE, 32'hF);
    rd_chk("IRQ_STATUS fwd/done/ack", ADDR_IRQ_STATUS,  32'h51, 32'h51);
    checks++;
    if (irq !== 1'b1) fail("irq should be high (GEN_DONE and START_ACK enabled, global enable on)");
    else $display("[%0t] ok    irq pin high", $time);
    wr(ADDR_IRQ_STATUS, 32'h0000_0041);                       // W1C: clear GEN_DONE and START_ACK
    rd_chk("IRQ_STATUS after W1C",  ADDR_IRQ_STATUS,    32'h0, 32'h41);
    checks++;
    if (irq !== 1'b0) fail("irq should be low after clearing the enabled bits");
    else $display("[%0t] ok    irq pin low", $time);

    // 5. spec 6.3: destination blocked by FWD_ENABLE -> all packets dropped
    wr(ADDR_IRQ_STATUS,  32'h0000_00FF);
    wr(ADDR_ERR_STATUS,  32'h0000_00FF);
    wr(ADDR_SWITCH_CTRL, 32'h0000_000B);                      // STAT_CLEAR, keep ENABLE + IRQ_GLOBAL_EN
    wr(ADDR_FWD_ENABLE,  32'h0000_0001);
    wr(ADDR_GEN_CTRL,    32'h0000_0003);
    poll_done(500);
    rd_chk("STAT_RX (dropped run)", ADDR_STAT_RX,       32'd0);
    rd_chk("STAT_DROP (dropped run)", ADDR_STAT_DROP,   32'd4);
    rd_chk("ERR_STATUS DEST_ERROR", ADDR_ERR_STATUS,    32'h02, 32'h02);
    rd_chk("IRQ_STATUS DROPPED",    ADDR_IRQ_STATUS,    32'h08, 32'h08);
    wr(ADDR_ERR_STATUS,  32'h0000_0002);
    rd_chk("ERR_STATUS after W1C",  ADDR_ERR_STATUS,    32'h00, 32'h02);

    // 6. error injection and counter clear
    wr(ADDR_ERR_INJECT,  32'h8000_0000);                      // CLEAR_COUNT
    rd_chk("ERR_COUNT cleared",     ADDR_ERR_COUNT,     32'd0);
    wr(ADDR_ERR_INJECT,  32'h0000_0002);                      // inject DEST (also sets INJECTED)
    rd_chk("ERR_STATUS injected",   ADDR_ERR_STATUS,    32'h82, 32'h82);
    rd_chk("ERR_COUNT after inject",ADDR_ERR_COUNT,     32'd1);

    // 7. illegal accesses (spec 3.5)
    illegal_rd(16'h0002);
    illegal_rd(16'h0064);
    illegal_wr(16'h0064);
    illegal_wr(16'h0025);
    rd_chk("FWD_ENABLE untouched", ADDR_FWD_ENABLE,     32'h1);

    // 8. soft reset restores defaults and re-locks
    wr(ADDR_SOFT_RESET, 32'h1);
    rd_chk("LOCK after soft reset", ADDR_LOCK,          32'h1);
    rd_chk("FWD_ENABLE after reset",ADDR_FWD_ENABLE,    32'hF);
    rd_chk("GEN_PKT_CFG after reset",ADDR_GEN_PKT_CFG,  32'h0000_0401);
    rd_chk("STAT_DROP after reset", ADDR_STAT_DROP,     32'd0);
    rd_chk("ERR_STATUS after reset",ADDR_ERR_STATUS,    32'd0);
    rd_chk("SWITCH_STATUS after reset", ADDR_SWITCH_STATUS, 32'h0000_00F9);

    // 9. queue overflow: length 1, interval 0 -> queue fills, then every other packet drops
    wr(ADDR_LOCK, UNLOCK_KEY);
    wr(ADDR_SWITCH_CTRL, 32'h0000_0009);
    wr(ADDR_GEN_PKT_CFG, 32'h0000_0101);                      // length 1, destination 1
    wr(ADDR_GEN_INTERVAL,32'h0000_0000);
    wr(ADDR_GEN_COUNT,   32'd40);
    wr(ADDR_GEN_CTRL,    32'h0000_0003);
    poll_done(500);
    begin
      logic [31:0] rx, dr; logic e1, e2;
      apb_read(ADDR_STAT_RX, rx, e1);  apb_read(ADDR_STAT_DROP, dr, e2);
      checks++;
      if (rx + dr !== 32'd40 || dr == 0 || rx < 16)
        fail($sformatf("overflow run: RX=%0d DROP=%0d (expect RX+DROP=40, DROP>0, RX>=16)", rx, dr));
      else $display("[%0t] ok    overflow run RX=%0d DROP=%0d (sum 40)", $time, rx, dr);
    end
    rd_chk("ERR_STATUS QUEUE_OVERFLOW", ADDR_ERR_STATUS, 32'h04, 32'h04);
    rd_chk("IRQ_STATUS QUEUE_OVERFLOW", ADDR_IRQ_STATUS, 32'h04, 32'h04);

    repeat (5) @(posedge pclk);
    if (errors == 0) $display("TEST PASSED (%0d checks)", checks);
    else             $display("TEST FAILED (%0d errors in %0d checks)", errors, checks);
    $finish;
  end
endmodule
