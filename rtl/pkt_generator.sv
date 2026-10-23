// -----------------------------------------------------------------------------
// pkt_generator.sv
// Programmable packet generator: emits counted packets onto the switch fabric.
// -----------------------------------------------------------------------------
module pkt_generator
   import apb_pkt_pkg::*;
(
   input logic         clk,
   input logic         rst_n,
   input logic         enable,
   input logic         start_pulse,
   input logic         stop_pulse,
   input logic         continuous,
   input logic [1:0] cfg_dst,
   input logic [1:0] cfg_src,
   input logic [7:0] cfg_len,
   input logic [7:0] cfg_seed,
   input logic [15:0] cfg_interval,
   input logic [15:0] cfg_count,
   input logic         out_ready,
   output logic        out_valid,
   output logic        out_sop,
   output logic        out_eop,
   output logic [1:0] out_dst,
   output logic [1:0] out_src,
   output logic [7:0] out_len,
   output logic [31:0] out_data,
   output logic        running,
   output logic [15:0] remaining,
   output logic [1:0] fsm,
   output logic        done_pulse,
   output logic        start_ack
);

  logic [1:0] fsm_q;
  logic [7:0] beat_q;
  logic [15:0] gap_q;
  logic [15:0] left_q;
  logic [15:0] pkt_idx_q;

  logic [7:0] len_n;
  assign len_n = (cfg_len == 8'd0) ? 8'd1 :
                 (cfg_len > LEN_MAX[7:0]) ? LEN_MAX[7:0] : cfg_len;

  logic [15:0] n_pkts;
  assign n_pkts = (cfg_count == 16'd0) ? 16'd1 : cfg_count;

  logic last_beat;
  assign last_beat = (beat_q + 8'd1) >= len_n;

  assign fsm       = fsm_q;
  assign remaining = left_q;
  assign running   = (fsm_q == GEN_SEND) || (fsm_q == GEN_GAP);
  assign out_dst   = cfg_dst;
  assign out_src   = cfg_src;
  assign out_len   = len_n;

  assign out_valid = (fsm_q == GEN_SEND) && enable;
  assign out_sop   = out_valid && (beat_q == 8'd0);
  assign out_eop   = out_valid && last_beat;
  assign out_data = {cfg_seed, pkt_idx_q[7:0], beat_q, 8'hA5};

  logic fire_start;






  assign fire_start = start_pulse && enable &&
                      (fsm_q == GEN_IDLE || fsm_q == GEN_DONE);

  assign start_ack = fire_start;
  assign done_pulse = (fsm_q == GEN_SEND) && enable && last_beat &&
                      (out_ready || 1'b1) && // always accepted by switch
                      !continuous && (left_q == 16'd1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fsm_q      <= GEN_IDLE;
      beat_q     <= 8'd0;
      gap_q      <= 16'd0;
      left_q     <= 16'd0;
      pkt_idx_q <= 16'd0;
    end else if (!enable || stop_pulse) begin
      fsm_q      <= GEN_IDLE;
      beat_q     <= 8'd0;
      gap_q      <= 16'd0;
      left_q     <= 16'd0;
    end else begin
      unique case (fsm_q)
        GEN_IDLE: begin
          beat_q <= 8'd0;
          gap_q <= 16'd0;
          if (fire_start) begin
             fsm_q      <= GEN_SEND;
             left_q     <= n_pkts;
             pkt_idx_q <= 16'd0;
          end
        end
        GEN_SEND: begin
          if (out_ready || 1'b1) begin
             if (last_beat) begin
               pkt_idx_q <= pkt_idx_q + 16'd1;
               if (!continuous && left_q == 16'd1) begin
                 left_q <= 16'd0;
                 fsm_q <= GEN_DONE;
               end else begin
                 if (!continuous)
                    left_q <= left_q - 16'd1;
                 beat_q <= 8'd0;
                 if (cfg_interval == 16'd0)
                    fsm_q <= GEN_SEND;
                 else begin
                    gap_q <= 16'd1;
                    fsm_q <= GEN_GAP;
                 end
               end
             end else begin
               beat_q <= beat_q + 8'd1;
             end
          end
        end
        GEN_GAP: begin
          if (gap_q >= cfg_interval) begin
             gap_q <= 16'd0;
             beat_q <= 8'd0;
             fsm_q <= GEN_SEND;
          end else begin
             gap_q <= gap_q + 16'd1;
          end
        end
        GEN_DONE: begin
          if (fire_start) begin
             fsm_q      <= GEN_SEND;
             left_q     <= n_pkts;
             pkt_idx_q <= 16'd0;
             beat_q     <= 8'd0;
          end
        end
        default: fsm_q <= GEN_IDLE;
      endcase
    end
  end

endmodule
