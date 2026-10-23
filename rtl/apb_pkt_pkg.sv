// -----------------------------------------------------------------------------
// apb_pkt_pkg.sv
// Constants for the APB 4-port packet switch + packet generator.
// -----------------------------------------------------------------------------
package apb_pkt_pkg;

  localparam int unsigned ADDR_W      = 16;
  localparam int unsigned DATA_W      = 32;
  localparam int unsigned N_PORTS     = 4;
  localparam int unsigned Q_DEPTH     = 16;
  localparam int unsigned LEN_MAX     = 16;

  localparam logic [ADDR_W-1:0] ADDR_DEVICE_ID     = 16'h0000;
  localparam logic [ADDR_W-1:0] ADDR_VERSION       = 16'h0004;
  localparam logic [ADDR_W-1:0] ADDR_SWITCH_STATUS = 16'h0008;
  localparam logic [ADDR_W-1:0] ADDR_PORT_STATUS   = 16'h000C;
  localparam logic [ADDR_W-1:0] ADDR_GEN_STATUS    = 16'h0010;
  localparam logic [ADDR_W-1:0] ADDR_STAT_RX       = 16'h0014;
  localparam logic [ADDR_W-1:0] ADDR_STAT_TX       = 16'h0018;
  localparam logic [ADDR_W-1:0] ADDR_STAT_DROP     = 16'h001C;
  localparam logic [ADDR_W-1:0] ADDR_SWITCH_CTRL   = 16'h0020;
  localparam logic [ADDR_W-1:0] ADDR_PORT_ENABLE   = 16'h0024;
  localparam logic [ADDR_W-1:0] ADDR_FWD_ENABLE    = 16'h0028;
  localparam logic [ADDR_W-1:0] ADDR_GEN_CTRL      = 16'h002C;
  localparam logic [ADDR_W-1:0] ADDR_GEN_PKT_CFG   = 16'h0030;
  localparam logic [ADDR_W-1:0] ADDR_GEN_INTERVAL = 16'h0034;
  localparam logic [ADDR_W-1:0] ADDR_GEN_COUNT     = 16'h0038;
  localparam logic [ADDR_W-1:0] ADDR_IRQ_STATUS    = 16'h003C;
  localparam logic [ADDR_W-1:0] ADDR_IRQ_ENABLE    = 16'h0040;
  localparam logic [ADDR_W-1:0] ADDR_IRQ_FORCE     = 16'h0044;
  localparam logic [ADDR_W-1:0] ADDR_ERR_STATUS    = 16'h0048;
  localparam logic [ADDR_W-1:0] ADDR_ERR_ENABLE    = 16'h004C;
  localparam logic [ADDR_W-1:0] ADDR_ERR_INJECT    = 16'h0050;
  localparam logic [ADDR_W-1:0] ADDR_ERR_COUNT     = 16'h0054;
  localparam logic [ADDR_W-1:0] ADDR_ERR_INFO      = 16'h0058;
  localparam logic [ADDR_W-1:0] ADDR_LOCK          = 16'h005C;
  localparam logic [ADDR_W-1:0] ADDR_SOFT_RESET    = 16'h0060;
  localparam logic [ADDR_W-1:0] ADDR_MAX           = 16'h0060;

  localparam logic [DATA_W-1:0] RST_DEVICE_ID   = 32'h02A5_5357; // rev 2, vendor A5, "SW"
  localparam logic [DATA_W-1:0] RST_VERSION     = 32'h0001_0200; // 1.2.0
  localparam logic [DATA_W-1:0] RST_PORT_ENABLE = 32'h0000_000F;
  localparam logic [DATA_W-1:0] RST_FWD_ENABLE = 32'h0000_000F;
  localparam logic [DATA_W-1:0] RST_GEN_PKT_CFG = 32'h0000_0401; // len=4, src=0, dst=1
  localparam logic [DATA_W-1:0] RST_GEN_INTERVAL= 32'h0000_0002;
  localparam logic [DATA_W-1:0] RST_GEN_COUNT   = 32'h0000_0004;

  localparam logic [DATA_W-1:0] UNLOCK_KEY = 32'hA5A5_C3C3;

  localparam logic [DATA_W-1:0] MASK_SWITCH_CTRL   = 32'h0000_0009; // ENABLE + IRQ_GLOBAL_EN; STAT_CLR is pulse
  localparam logic [DATA_W-1:0] MASK_PORT_ENABLE   = 32'h0000_000F;







  localparam logic [DATA_W-1:0] MASK_FWD_ENABLE   = 32'h0000_000F;
  localparam logic [DATA_W-1:0] MASK_GEN_CTRL     = 32'h0000_0009; // ENABLE + CONTINUOUS; START/STOP pulses
  localparam logic [DATA_W-1:0] MASK_GEN_PKT_CFG = 32'h00FF_FF0F;
  localparam logic [DATA_W-1:0] MASK_GEN_INTERVAL = 32'h0000_FFFF;
  localparam logic [DATA_W-1:0] MASK_GEN_COUNT    = 32'h0000_FFFF;
  localparam logic [DATA_W-1:0] MASK_IRQ          = 32'h0000_00FF;
  localparam logic [DATA_W-1:0] MASK_ERR          = 32'h0000_00FF;

  localparam logic [1:0] GEN_IDLE = 2'd0;
  localparam logic [1:0] GEN_SEND = 2'd1;
  localparam logic [1:0] GEN_GAP = 2'd2;
  localparam logic [1:0] GEN_DONE = 2'd3;

endpackage
