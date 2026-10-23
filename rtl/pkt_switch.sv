// -----------------------------------------------------------------------------
// pkt_switch.sv
// Four-port packet switch: dest-port lookup, per-port queues, RX/TX/drop stats.
// -----------------------------------------------------------------------------
module pkt_switch
   import apb_pkt_pkg::*;
(
   input logic             clk,
   input logic             rst_n,
   input logic             switch_en,
   input logic [N_PORTS-1:0] port_en,
   input logic [N_PORTS-1:0] fwd_en,
   input logic             stat_clr,
   input logic             in_valid,
   input logic             in_sop,
   input logic             in_eop,
   input logic [1:0]       in_dst,
   input logic [1:0]       in_src,
   input logic [7:0]       in_len,
   input logic [31:0]      in_data,
   output logic            in_ready,
   output logic [7:0]      q_level [N_PORTS],
   output logic [15:0]     stat_rx,
   output logic [15:0]     stat_tx,
   output logic [15:0]     stat_drop,
   output logic            ovf_evt,
   output logic            dest_err_evt,
   output logic            drop_evt,
   output logic            fwd_eop_evt
);

  logic dropping_q;
  logic [7:0] q_q [N_PORTS];
  logic [15:0] rx_q, tx_q, drop_q;

  assign in_ready = 1'b1;
  assign stat_rx   = rx_q;
  assign stat_tx   = tx_q;
  assign stat_drop = drop_q;

  genvar gi;
  generate
    for (gi = 0; gi < N_PORTS; gi++) begin : g_ql
      assign q_level[gi] = q_q[gi];
    end
  endgenerate

  logic dest_ok;
  logic queue_ok;
  logic accept;
  logic [1:0] d;
  assign d = in_dst;
  assign dest_ok = port_en[d] && fwd_en[d] && switch_en;
  assign queue_ok = (q_q[d] < Q_DEPTH[7:0]);
  assign accept   = in_valid && dest_ok && queue_ok && !dropping_q;

  always_comb begin
    ovf_evt       = 1'b0;
    dest_err_evt = 1'b0;
    drop_evt      = 1'b0;
    fwd_eop_evt = 1'b0;
    if (in_valid && in_sop) begin
      if (!dest_ok)
        dest_err_evt = 1'b1;
      else if (!queue_ok)
        ovf_evt = 1'b1;
    end
    if (in_valid && in_eop) begin
      if (accept)
        fwd_eop_evt = 1'b1;
      else
        drop_evt = 1'b1;
    end
  end

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dropping_q <= 1'b0;
      rx_q       <= 16'd0;
      tx_q       <= 16'd0;
      drop_q     <= 16'd0;
      for (i = 0; i < N_PORTS; i++)






        q_q[i] <= 8'd0;
    end else if (stat_clr) begin
      dropping_q <= 1'b0;
      rx_q       <= 16'd0;
      tx_q       <= 16'd0;
      drop_q     <= 16'd0;
      for (i = 0; i < N_PORTS; i++)
        q_q[i] <= 8'd0;
    end else begin
      if (in_valid && in_sop)
        dropping_q <= !(dest_ok && queue_ok);
      else if (in_valid && in_eop)
        dropping_q <= 1'b0;

      if (accept) begin
        if (in_eop) begin
          if (rx_q != 16'hFFFF) rx_q <= rx_q + 16'd1;
          if (tx_q != 16'hFFFF) tx_q <= tx_q + 16'd1;
        end
      end else if (in_valid && in_eop) begin
        if (drop_q != 16'hFFFF) drop_q <= drop_q + 16'd1;
      end

      for (i = 0; i < N_PORTS; i++) begin
        if (accept && (d == i[1:0])) begin
          if (q_q[i] < Q_DEPTH[7:0])
            q_q[i] <= q_q[i] + 8'd1;
        end else if (q_q[i] > 8'd0) begin
          q_q[i] <= q_q[i] - 8'd1;
        end
      end
    end
  end

  logic _unused_src;
  logic [7:0] _unused_len;
  logic [31:0] _unused_data;
  assign _unused_src = in_src[0];
  assign _unused_len = in_len;
  assign _unused_data = in_data;

endmodule
