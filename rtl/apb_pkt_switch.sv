// -----------------------------------------------------------------------------
// apb_pkt_switch.sv
// AMBA APB3 CSR front-end for a 4-port packet switch + packet generator.
// -----------------------------------------------------------------------------
module apb_pkt_switch
   import apb_pkt_pkg::*;
(
   input logic               pclk,
   input logic               presetn,
   input logic               psel,
   input logic               penable,
   input logic               pwrite,
   input logic [ADDR_W-1:0] paddr,
   input logic [DATA_W-1:0] pwdata,
   output logic [DATA_W-1:0] prdata,
   output logic              pready,
   output logic              pslverr,
   output logic              irq
);

  assign pready = 1'b1;

  logic acc, wr, rd, unaligned, unmapped;
  logic [15:0] word_addr;
  assign acc       = psel & penable & pready;
  assign wr        = acc & pwrite;
  assign rd        = acc & ~pwrite;
  assign unaligned = |paddr[1:0];
  assign unmapped = paddr > ADDR_MAX;
  assign word_addr = {paddr[15:2], 2'b00};

  logic wr_ok, rd_ok;
  assign wr_ok = wr & ~unaligned & ~unmapped;
  assign rd_ok = rd & ~unaligned & ~unmapped;
  assign pslverr = acc & (unaligned | unmapped);







  logic locked;
  logic [31:0] switch_ctrl_q;
  logic [3:0] port_enable_q;
  logic [3:0] fwd_enable_q;
  logic [31:0] gen_ctrl_q;
  logic [31:0] gen_pkt_cfg_q;
  logic [15:0] gen_interval_q;
  logic [15:0] gen_count_q;
  logic [7:0] irq_status_q;
  logic [7:0] irq_enable_q;
  logic [7:0] err_status_q;
  logic [7:0] err_enable_q;
  logic [15:0] err_count_q;
  logic [31:0] err_info_q;

  logic wr_switch_ctrl, wr_port_en, wr_fwd_en, wr_gen_ctrl;
  logic wr_gen_pkt, wr_gen_int, wr_gen_cnt;
  logic wr_irq_status, wr_irq_enable, wr_irq_force;
  logic wr_err_status, wr_err_enable, wr_err_inject;
  logic wr_lock, wr_soft_reset;

  always_comb begin
    wr_switch_ctrl = 1'b0; wr_port_en = 1'b0; wr_fwd_en = 1'b0;
    wr_gen_ctrl = 1'b0; wr_gen_pkt = 1'b0; wr_gen_int = 1'b0; wr_gen_cnt = 1'b0;
    wr_irq_status = 1'b0; wr_irq_enable = 1'b0; wr_irq_force = 1'b0;
    wr_err_status = 1'b0; wr_err_enable = 1'b0; wr_err_inject = 1'b0;
    wr_lock = 1'b0; wr_soft_reset = 1'b0;
    if (wr_ok) begin
      unique case (word_addr)
        ADDR_SWITCH_CTRL: wr_switch_ctrl = 1'b1;
        ADDR_PORT_ENABLE: wr_port_en      = 1'b1;
        ADDR_FWD_ENABLE: wr_fwd_en        = 1'b1;
        ADDR_GEN_CTRL:    wr_gen_ctrl     = 1'b1;
        ADDR_GEN_PKT_CFG: wr_gen_pkt      = 1'b1;
        ADDR_GEN_INTERVAL:wr_gen_int      = 1'b1;
        ADDR_GEN_COUNT:   wr_gen_cnt      = 1'b1;
        ADDR_IRQ_STATUS: wr_irq_status = 1'b1;
        ADDR_IRQ_ENABLE: wr_irq_enable = 1'b1;
        ADDR_IRQ_FORCE:   wr_irq_force    = 1'b1;
        ADDR_ERR_STATUS: wr_err_status = 1'b1;
        ADDR_ERR_ENABLE: wr_err_enable = 1'b1;
        ADDR_ERR_INJECT: wr_err_inject = 1'b1;
        ADDR_LOCK:        wr_lock         = 1'b1;
        ADDR_SOFT_RESET: wr_soft_reset = 1'b1;
        default: ;
      endcase
    end
  end

  logic cfg_wr_ok;
  assign cfg_wr_ok = wr_ok & ~locked;

  logic srst_pulse, stat_clr_pulse, start_pulse, stop_pulse;
  assign srst_pulse     = wr_soft_reset & pwdata[0];
  assign stat_clr_pulse = wr_switch_ctrl & cfg_wr_ok & pwdata[1];
  assign start_pulse    = wr_gen_ctrl & cfg_wr_ok & pwdata[1];
  assign stop_pulse     = wr_gen_ctrl & cfg_wr_ok & pwdata[2];

  logic [7:0] irq_force_w, err_inject_w;
  logic err_clr_count;
  assign irq_force_w   = wr_irq_force ? pwdata[7:0] : 8'h00;
  assign err_inject_w = wr_err_inject ? pwdata[7:0] : 8'h00;
  assign err_clr_count = wr_err_inject & pwdata[31];

  logic switch_en, irq_gen_en, gen_en, gen_cont;
  assign switch_en = switch_ctrl_q[0];
  assign irq_gen_en = switch_ctrl_q[3];
  assign gen_en     = gen_ctrl_q[0];
  assign gen_cont   = gen_ctrl_q[3];

  logic        gen_valid, gen_sop, gen_eop, gen_ready;
  logic [1:0] gen_dst, gen_src, gen_fsm;
  logic [7:0] gen_len;
  logic [31:0] gen_data;
  logic        gen_running, gen_done_pulse, gen_start_ack;
  logic [15:0] gen_left;

  logic gen_en_eff;
  assign gen_en_eff = (cfg_wr_ok && wr_gen_ctrl) ? pwdata[0] : gen_en;

  pkt_generator u_gen (
    .clk         (pclk),







       .rst_n       (presetn),
       .enable      (gen_en_eff),
       .start_pulse (start_pulse),
       .stop_pulse (stop_pulse | srst_pulse),
       .continuous (gen_cont),
       .cfg_dst     (gen_pkt_cfg_q[1:0]),
       .cfg_src     (gen_pkt_cfg_q[3:2]),
       .cfg_len     (gen_pkt_cfg_q[15:8]),
       .cfg_seed    (gen_pkt_cfg_q[23:16]),
       .cfg_interval(gen_interval_q),
       .cfg_count   (gen_count_q),
       .out_ready   (gen_ready),
       .out_valid   (gen_valid),
       .out_sop     (gen_sop),
       .out_eop     (gen_eop),
       .out_dst     (gen_dst),
       .out_src     (gen_src),
       .out_len     (gen_len),
       .out_data    (gen_data),
       .running     (gen_running),
       .remaining   (gen_left),
       .fsm         (gen_fsm),
       .done_pulse (gen_done_pulse),
       .start_ack   (gen_start_ack)
  );

  logic [7:0] q_level [N_PORTS];
  logic [15:0] stat_rx, stat_tx, stat_drop;
  logic        ovf_evt, dest_err_evt, drop_evt, fwd_eop_evt;

  pkt_switch u_sw (
     .clk          (pclk),
     .rst_n        (presetn),
     .switch_en    (switch_en),
     .port_en      (port_enable_q),
     .fwd_en       (fwd_enable_q),
     .stat_clr     (stat_clr_pulse | srst_pulse),
     .in_valid     (gen_valid),
     .in_sop       (gen_sop),
     .in_eop       (gen_eop),
     .in_dst       (gen_dst),
     .in_src       (gen_src),
     .in_len       (gen_len),
     .in_data      (gen_data),
     .in_ready     (gen_ready),
     .q_level      (q_level),
     .stat_rx      (stat_rx),
     .stat_tx      (stat_tx),
     .stat_drop    (stat_drop),
     .ovf_evt      (ovf_evt),
     .dest_err_evt (dest_err_evt),
     .drop_evt     (drop_evt),
     .fwd_eop_evt (fwd_eop_evt)
  );

  logic busy;
  assign busy = gen_running || (q_level[0] != 8'd0) || (q_level[1] != 8'd0) ||
                (q_level[2] != 8'd0) || (q_level[3] != 8'd0);

  logic [31:0] switch_status_r;
  always_comb begin
    switch_status_r = 32'h0;
    switch_status_r[0]    = ~gen_running;
    switch_status_r[1]    = busy;
    switch_status_r[2]    = switch_en;
    switch_status_r[3]    = locked;
    switch_status_r[7:4] = port_enable_q;
    switch_status_r[8]    = gen_running;
    switch_status_r[9]    = |err_status_q;
    switch_status_r[17:16]= gen_fsm;
  end

  logic [31:0] port_status_r;
  always_comb begin
    port_status_r = 32'h0;
    port_status_r[7:0]   = q_level[0];
    port_status_r[15:8] = q_level[1];
    port_status_r[23:16] = q_level[2];
    port_status_r[31:24] = q_level[3];
  end

  logic [31:0] gen_status_r;
  always_comb begin







    gen_status_r = 32'h0;
    gen_status_r[0]     = gen_running;
    gen_status_r[1]     = (gen_fsm == GEN_DONE);
    gen_status_r[3:2]   = gen_fsm;
    gen_status_r[23:8] = gen_left;
  end

  logic [7:0] irq_w1c, err_w1c, err_set, irq_set;
  assign irq_w1c = wr_irq_status ? pwdata[7:0] : 8'h00;
  assign err_w1c = wr_err_status ? pwdata[7:0] : 8'h00;

  always_comb begin
    err_set = 8'h00;
    if (dest_err_evt) err_set[1] = 1'b1;
    if (ovf_evt)      err_set[2] = 1'b1;
    if (|err_inject_w[6:0]) begin
      err_set = err_set | err_inject_w;
      err_set[7] = 1'b1;
    end else if (err_inject_w[7]) begin
      err_set[7] = 1'b1;
    end
  end

  logic [7:0] err_next;
  assign err_next = (err_status_q | err_set) & ~err_w1c;
  logic err_promote;
  assign err_promote = |((err_status_q | err_set) & err_enable_q);

  always_comb begin
    irq_set = irq_force_w;
    if (gen_done_pulse) irq_set[0] = 1'b1;
    if (err_promote)     irq_set[1] = 1'b1;
    if (ovf_evt)         irq_set[2] = 1'b1;
    if (drop_evt)        irq_set[3] = 1'b1;
    if (fwd_eop_evt)     irq_set[4] = 1'b1;
    if (gen_start_ack) irq_set[6] = 1'b1;
    if ((q_level[0] >= 8'd8) || (q_level[1] >= 8'd8) ||
        (q_level[2] >= 8'd8) || (q_level[3] >= 8'd8))
      irq_set[5] = 1'b1;
  end

  logic [7:0] irq_next;
  assign irq_next = (irq_status_q | irq_set) & ~irq_w1c;

  int unsigned inj_i, code_i;
  logic [15:0] inject_pop;
  logic [7:0] last_code;
  always_comb begin
    inject_pop = 16'd0;
    for (inj_i = 0; inj_i < 7; inj_i++)
      inject_pop = inject_pop + {15'd0, err_inject_w[inj_i]};
  end
  always_comb begin
    last_code = 8'hFF;
    for (code_i = 0; code_i < 8; code_i++)
      if (err_set[code_i] && last_code == 8'hFF)
        last_code = code_i[7:0];
  end

  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      locked         <= 1'b1;
      switch_ctrl_q <= 32'h0;
      port_enable_q <= RST_PORT_ENABLE[3:0];
      fwd_enable_q   <= RST_FWD_ENABLE[3:0];
      gen_ctrl_q     <= 32'h0;
      gen_pkt_cfg_q <= RST_GEN_PKT_CFG;
      gen_interval_q <= RST_GEN_INTERVAL[15:0];
      gen_count_q    <= RST_GEN_COUNT[15:0];
      irq_status_q   <= 8'h0;
      irq_enable_q   <= 8'h0;
      err_status_q   <= 8'h0;
      err_enable_q   <= 8'h0;
      err_count_q    <= 16'h0;
      err_info_q     <= 32'h0;
    end else if (srst_pulse) begin
      locked         <= 1'b1;
      switch_ctrl_q <= 32'h0;
      port_enable_q <= RST_PORT_ENABLE[3:0];
      fwd_enable_q   <= RST_FWD_ENABLE[3:0];
      gen_ctrl_q     <= 32'h0;
      gen_pkt_cfg_q <= RST_GEN_PKT_CFG;
      gen_interval_q <= RST_GEN_INTERVAL[15:0];







      gen_count_q    <= RST_GEN_COUNT[15:0];
      irq_status_q   <= 8'h0;
      irq_enable_q   <= 8'h0;
      err_status_q   <= 8'h0;
      err_enable_q   <= 8'h0;
      err_count_q    <= 16'h0;
      err_info_q     <= 32'h0;
    end else begin
      if (wr_lock)
        locked <= (pwdata != UNLOCK_KEY);

      if (cfg_wr_ok) begin
        if (wr_switch_ctrl) begin
          switch_ctrl_q <= pwdata & MASK_SWITCH_CTRL;
        end
        if (wr_port_en)
          port_enable_q <= pwdata[3:0];
        if (wr_fwd_en)
          fwd_enable_q <= pwdata[3:0];
        if (wr_gen_ctrl) begin
          gen_ctrl_q <= pwdata & MASK_GEN_CTRL;
        end
        if (wr_gen_pkt) begin
          gen_pkt_cfg_q <= pwdata & MASK_GEN_PKT_CFG;
          if (pwdata[15:8] == 8'd0)
            gen_pkt_cfg_q[15:8] <= 8'd1;
        end
        if (wr_gen_int)
          gen_interval_q <= pwdata[15:0];
        if (wr_gen_cnt)
          gen_count_q <= pwdata[15:0];
        if (wr_irq_enable)
          irq_enable_q <= pwdata[7:0];
        if (wr_err_enable)
          err_enable_q <= pwdata[7:0];
      end

      irq_status_q <= irq_next;
      err_status_q <= err_next;

      if (err_clr_count) begin
        err_count_q <= 16'h0;
        err_info_q <= 32'h0;
      end else if (|err_set) begin
        if (|err_inject_w[6:0]) begin
          if (err_count_q > (16'hFFFF - inject_pop))
            err_count_q <= 16'hFFFF;
          else
            err_count_q <= err_count_q + inject_pop;
        end else if (err_count_q != 16'hFFFF) begin
          err_count_q <= err_count_q + 16'd1;
        end
        err_info_q[7:0]   <= last_code;
        err_info_q[15:8] <= (|err_inject_w) ? 8'd1 : 8'd0;
        err_info_q[17:16] <= gen_dst;
        err_info_q[31:20] <= stat_tx[11:0];
      end
    end
  end

  assign irq = irq_gen_en & |(irq_status_q & irq_enable_q);

  logic [31:0] rdata_mux;
  always_comb begin
    rdata_mux = 32'h0;
    unique case (word_addr)
      ADDR_DEVICE_ID:     rdata_mux = RST_DEVICE_ID;
      ADDR_VERSION:       rdata_mux = RST_VERSION;
      ADDR_SWITCH_STATUS: rdata_mux = switch_status_r;
      ADDR_PORT_STATUS:   rdata_mux = port_status_r;
      ADDR_GEN_STATUS:    rdata_mux = gen_status_r;
      ADDR_STAT_RX:       rdata_mux = {16'h0, stat_rx};
      ADDR_STAT_TX:       rdata_mux = {16'h0, stat_tx};
      ADDR_STAT_DROP:     rdata_mux = {16'h0, stat_drop};
      ADDR_SWITCH_CTRL:   rdata_mux = switch_ctrl_q;
      ADDR_PORT_ENABLE:   rdata_mux = {28'h0, port_enable_q};
      ADDR_FWD_ENABLE:    rdata_mux = {28'h0, fwd_enable_q};
      ADDR_GEN_CTRL:      rdata_mux = gen_ctrl_q;
      ADDR_GEN_PKT_CFG:   rdata_mux = gen_pkt_cfg_q;
      ADDR_GEN_INTERVAL: rdata_mux = {16'h0, gen_interval_q};
      ADDR_GEN_COUNT:     rdata_mux = {16'h0, gen_count_q};
      ADDR_IRQ_STATUS:    rdata_mux = {24'h0, irq_status_q};
      ADDR_IRQ_ENABLE:    rdata_mux = {24'h0, irq_enable_q};







      ADDR_IRQ_FORCE:      rdata_mux = 32'h0;
      ADDR_ERR_STATUS:     rdata_mux = {24'h0, err_status_q};
      ADDR_ERR_ENABLE:     rdata_mux = {24'h0, err_enable_q};
      ADDR_ERR_INJECT:     rdata_mux = 32'h0;
      ADDR_ERR_COUNT:      rdata_mux = {16'h0, err_count_q};
      ADDR_ERR_INFO:       rdata_mux = err_info_q;
      ADDR_LOCK:           rdata_mux = {31'h0, locked};
      ADDR_SOFT_RESET:     rdata_mux = 32'h0;
      default:             rdata_mux = 32'h0;
    endcase
  end

  always_comb begin
    if (psel && !pwrite) begin
      if (unaligned || unmapped) prdata = 32'h0;
      else                       prdata = rdata_mux;
    end else begin
      prdata = 32'h0;
    end
  end

endmodule
