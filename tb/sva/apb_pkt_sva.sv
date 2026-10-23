//-----------------------------------------------------------------------------
// Cycle-accurate checks bound into the DUT (spec 3.2-3.6, 5.7, 5.9, 5.16-5.19, 5.24-5.25).
// Sampling rule: a property evaluates sampled (pre-edge) values. For "|=>" the antecedent is
// sampled at the ACCESS edge (what the DUT sees), the consequent one edge later (new flop values).
// Every implication has a paired cover so a vacuous pass is visible in the coverage report.
//-----------------------------------------------------------------------------
`define IMPL1(n, ant, cons) \
  a_``n : assert property ((ant) |->  (cons)); \
  c_``n : cover  property (ant);
`define IMPL2(n, ant, cons) \
  a_``n : assert property ((ant) |=>  (cons)); \
  c_``n : cover  property (ant);
`define LK_IGN(n, a, r) \
  a_lk_ign_``n : assert property ((acc && pwrite && locked && paddr == a) |=> $stable(r)); \
  c_lk_ign_``n : cover  property (acc && pwrite && locked && paddr == a);
`define WR_LANDS(n, a, r, e) \
  a_wr_``n : assert property ((acc && pwrite && !locked && paddr == a) |=> (r == (e))); \
  c_wr_``n : cover  property (acc && pwrite && !locked && paddr == a);

module apb_pkt_sva (
  input logic        pclk, presetn, psel, penable, pwrite,
  input logic [15:0] paddr,
  input logic [31:0] pwdata, prdata,
  input logic        pready, pslverr, irq, locked,
  input logic [31:0] switch_ctrl_q, gen_ctrl_q, gen_pkt_cfg_q,
  input logic [3:0]  port_enable_q, fwd_enable_q,
  input logic [15:0] gen_interval_q, gen_count_q, stat_rx, stat_tx, stat_drop,
  input logic [7:0]  irq_status_q, irq_enable_q, err_status_q, err_enable_q
);
  default clocking cb @(posedge pclk); endclocking
  default disable iff (!presetn);

  wire acc    = psel && penable;                                        // access phase (pready is always 1)
  wire bad    = (|paddr[1:0]) || (paddr > 16'h0060);                    // unaligned or out of range
  wire clr_wr = acc && pwrite && ((paddr == 16'h0020 && !locked && pwdata[1]) ||   // STAT_CLEAR
                                  (paddr == 16'h0060 && pwdata[0]));               // SOFT_RESET

  function automatic logic [31:0] cfg_exp(logic [31:0] w);              // GEN_PKT_CFG write: mask, LENGTH 0 -> 1
    logic [31:0] e = w & 32'h00FF_FF0F;
    if (e[15:8] == 8'd0) e[15:8] = 8'd1;
    return e;
  endfunction

  // ---- 1. APB slave response rules (spec 3.2, 3.5)
  a_pready       : assert property (pready);
  a_slverr_phase : assert property (pslverr |-> acc);
  a_slverr_exact : assert property (acc |-> (pslverr == bad));
  `IMPL1(rd_bad_zero, psel && !pwrite && bad, prdata == 32'h0)

  // ---- 2. Master-side protocol: checks OUR driver (spec 3.3)
  `IMPL1(penable_needs_psel, penable, psel)
  `IMPL2(setup_to_access, psel && !penable, psel && penable && $stable(paddr) && $stable(pwrite) && $stable(pwdata))
  `IMPL2(access_ends, psel && penable && pready, !penable)

  // ---- 3. Reset and soft reset (spec 3.6, 5.25)
  `IMPL1(rst_vals, $rose(presetn),
         locked && switch_ctrl_q == 32'h0 && gen_ctrl_q == 32'h0 && port_enable_q == 4'hF && fwd_enable_q == 4'hF &&
         gen_pkt_cfg_q == 32'h401 && gen_interval_q == 16'd2 && gen_count_q == 16'd4 &&
         irq_status_q == 8'h0 && irq_enable_q == 8'h0 && err_status_q == 8'h0 && err_enable_q == 8'h0)
  `IMPL2(srst_restores, acc && pwrite && paddr == 16'h0060 && pwdata[0],
         locked && switch_ctrl_q == 32'h0 && gen_ctrl_q == 32'h0 && port_enable_q == 4'hF && fwd_enable_q == 4'hF &&
         gen_pkt_cfg_q == 32'h401 && gen_interval_q == 16'd2 && gen_count_q == 16'd4 &&
         irq_status_q == 8'h0 && irq_enable_q == 8'h0 && err_status_q == 8'h0 && err_enable_q == 8'h0 &&
         stat_rx == 16'h0 && stat_tx == 16'h0 && stat_drop == 16'h0)
  a_locked_rst   : assert property ($rose(presetn) |-> locked);

  // ---- 4. Lock: a locked write to ANY of the 9 lockable registers is ignored (spec 3.6)
  `LK_IGN(sw,   16'h0020, switch_ctrl_q)
  `LK_IGN(pe,   16'h0024, port_enable_q)
  `LK_IGN(fe,   16'h0028, fwd_enable_q)
  `LK_IGN(gctl, 16'h002C, gen_ctrl_q)
  `LK_IGN(gpc,  16'h0030, gen_pkt_cfg_q)
  `LK_IGN(gi,   16'h0034, gen_interval_q)
  `LK_IGN(gc,   16'h0038, gen_count_q)
  `LK_IGN(ie,   16'h0040, irq_enable_q)
  `LK_IGN(ee,   16'h004C, err_enable_q)

  // ---- 5. Unlocked write lands, with the spec masks (5.9, 5.12, 5.13)
  `WR_LANDS(sw,   16'h0020, switch_ctrl_q,  $past(pwdata) & 32'h9)
  `WR_LANDS(pe,   16'h0024, port_enable_q,  $past(pwdata[3:0]))
  `WR_LANDS(fe,   16'h0028, fwd_enable_q,   $past(pwdata[3:0]))
  `WR_LANDS(gctl, 16'h002C, gen_ctrl_q,     $past(pwdata) & 32'h9)
  `WR_LANDS(gpc,  16'h0030, gen_pkt_cfg_q,  cfg_exp($past(pwdata)))
  `WR_LANDS(gi,   16'h0034, gen_interval_q, $past(pwdata[15:0]))
  `WR_LANDS(gc,   16'h0038, gen_count_q,    $past(pwdata[15:0]))
  `WR_LANDS(ie,   16'h0040, irq_enable_q,   $past(pwdata[7:0]))
  `WR_LANDS(ee,   16'h004C, err_enable_q,   $past(pwdata[7:0]))

  // ---- 6. Interrupts, errors, statistics
  a_irq_eq       : assert property (irq == (switch_ctrl_q[3] && |(irq_status_q & irq_enable_q)));          // 5.17
  `IMPL2(irq_w1c,   acc && pwrite && paddr == 16'h003C, (irq_status_q & $past(pwdata[7:0])) == 8'h0)      // clear beats hw set
  `IMPL2(err_w1c,   acc && pwrite && paddr == 16'h0048, (err_status_q & $past(pwdata[7:0])) == 8'h0)
  `IMPL2(irq_force, acc && pwrite && paddr == 16'h0044,
         (irq_status_q & $past(pwdata[7:0])) == $past(pwdata[7:0]))                                      // 5.18
  `IMPL2(stat_clear, acc && pwrite && !locked && paddr == 16'h0020 && pwdata[1],
         stat_rx == 16'h0 && stat_tx == 16'h0 && stat_drop == 16'h0)                                      // 5.9
  a_rx_eq_tx     : assert property (stat_rx == stat_tx);                                                  // 5.7
  a_rx_mono      : assert property (stat_rx   >= $past(stat_rx)   || $past(clr_wr));                      // never wraps
  a_tx_mono      : assert property (stat_tx   >= $past(stat_tx)   || $past(clr_wr));
  a_drop_mono    : assert property (stat_drop >= $past(stat_drop) || $past(clr_wr));

  c_unlock : cover property (acc && pwrite && paddr == 16'h005C && pwdata == 32'hA5A5_C3C3);
  c_slverr : cover property (pslverr);
  c_rx_sat : cover property (stat_rx == 16'hFFFF);
endmodule

// Queue/accounting checks inside pkt_switch (spec 7)
module pkt_switch_sva (
  input logic       clk, rst_n, in_valid, in_sop, in_eop,
  input logic       fwd_eop_evt, drop_evt, ovf_evt, dest_err_evt,
  input logic [7:0] q0, q1, q2, q3
);
  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);
  a_q_depth     : assert property (q0 <= 8'd16 && q1 <= 8'd16 && q2 <= 8'd16 && q3 <= 8'd16);
  a_one_outcome : assert property ((in_valid && in_eop) |-> (fwd_eop_evt ^ drop_evt));   // forwarded XOR dropped
  a_no_outcome  : assert property (!(in_valid && in_eop) |-> !(fwd_eop_evt || drop_evt));
  a_sop_events  : assert property ((ovf_evt || dest_err_evt) |-> (in_valid && in_sop));
  a_ovf_xor_dest: assert property (!(ovf_evt && dest_err_evt));
  c_overflow    : cover property (ovf_evt);
  c_queue_full  : cover property (q0 == 8'd16 || q1 == 8'd16 || q2 == 8'd16 || q3 == 8'd16);
endmodule

bind apb_pkt_switch apb_pkt_sva u_sva (.*);
bind pkt_switch pkt_switch_sva u_sva (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_sop(in_sop), .in_eop(in_eop),
  .fwd_eop_evt(fwd_eop_evt), .drop_evt(drop_evt), .ovf_evt(ovf_evt), .dest_err_evt(dest_err_evt),
  .q0(q_q[0]), .q1(q_q[1]), .q2(q_q[2]), .q3(q_q[3]));

`undef IMPL1
`undef IMPL2
`undef LK_IGN
`undef WR_LANDS
