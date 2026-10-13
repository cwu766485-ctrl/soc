`timescale 1ns/1ns

// Formal-only wrapper.  Unlike top_tb, PCLK and APB inputs are symbolic:
// VC Formal explores every legal value sequence constrained below.
module spi_formal_harness;

  logic        PCLK;
  logic        PRESETN;
  logic [4:0]  PADDR;
  logic [31:0] PWDATA;
  logic        PSEL;
  logic        PWRITE;
  logic        PENABLE;
  logic        miso_pad_i;

  logic [31:0] PRDATA;
  logic        PREADY;
  logic        PSLVERR;
  logic        IRQ;
  logic [7:0]  ss_pad_o;
  logic        sclk_pad_o;
  logic        mosi_pad_o;

  spi_top DUT (
    .PCLK       (PCLK),
    .PRESETN    (PRESETN),
    .PADDR      (PADDR),
    .PWDATA     (PWDATA),
    .PRDATA     (PRDATA),
    .PSEL       (PSEL),
    .PWRITE     (PWRITE),
    .PENABLE    (PENABLE),
    .PREADY     (PREADY),
    .PSLVERR    (PSLVERR),
    .IRQ        (IRQ),
    .ss_pad_o   (ss_pad_o),
    .sclk_pad_o (sclk_pad_o),
    .mosi_pad_o (mosi_pad_o),
    .miso_pad_i (miso_pad_i)
  );

  default clocking cb @(posedge PCLK); endclocking

  // Formal environment assumptions: model APB protocol shape, not DUT output.
  // PADDR is word-aligned in this APB integration, matching the real APB agent.
  apb_address_aligned: assume property (PADDR[1:0] == 2'b00);
  apb_enable_requires_select: assume property (PENABLE |-> PSEL);
  apb_setup_to_access: assume property (
    (PSEL && !PENABLE) |=> (PSEL && PENABLE)
  );
  // A completed APB access must return to a setup phase before another access.
  // Without this, Formal may invent two adjacent PENABLE cycles and treat a
  // later legal CTRL write as if it belonged to the earlier busy write.
  apb_access_returns_to_setup: assume property (
    (PSEL && PENABLE && PREADY) |=> !PENABLE
  );
  apb_setup_fields_hold_to_access: assume property (
    (PSEL && !PENABLE) |=>
      $stable({PADDR, PWDATA, PWRITE})
  );
  apb_access_holds_until_ready: assume property (
    (PSEL && PENABLE && !PREADY) |=>
      (PSEL && PENABLE && $stable({PADDR, PWDATA, PWRITE}))
  );

  // Do not use $initstate here.  This VC Formal flow parses the harness with
  // the VCS front end, which rejects $initstate in an SVA expression.  The
  // normal proof run starts from the saved post-reset state in Tcl.  A
  // separate FORMAL_RESET_CHECK run holds reset low and proves reset behavior.

`ifdef FORMAL_RESET_CHECK
  // Reset-only proof environment.  This is deliberately separate from the
  // normal post-reset proof, where sim_save_reset fixes PRESETN high.
  formal_reset_held_low: assume property (!PRESETN);
`endif

`ifndef FORMAL_RESET_CHECK
  // These properties are local design invariants and should be true for every
  // APB/MISO input sequence satisfying the assumptions above.
  a_no_two_sclk_edge_pulses:
    assert property (disable iff (!PRESETN) !(DUT.pos_edge && DUT.neg_edge));
`endif

`ifdef FORMAL_RESET_CHECK
  a_reset_forces_idle_outputs:
    // Check one PCLK after reset is sampled.  The asynchronous reset blocks
    // update in the active/NBA regions of that sampling edge.
    assert property (!PRESETN |=>
      (!DUT.tip && !sclk_pad_o && !DUT.pos_edge && !DUT.neg_edge && !IRQ));
`endif

`ifndef FORMAL_RESET_CHECK
  a_pslverr_is_tied_low:
    assert property (PSLVERR == 1'b0);

  // Writes during transfer cannot alter  or SS. Formal explores every
  // PWDATA value and every legal APB timing point, not just a directed value.
  a_busy_divider_write_is_ignored:
    assert property (disable iff (!PRESETN)
      (DUT.tip && PSEL && PENABLE && PWRITE && (PADDR[4:2] == 3'd5)) |=>
      $stable(DUT.divider)
    );
  a_busy_ss_write_is_ignored:
    assert property (disable iff (!PRESETN)
      (DUT.tip && PSEL && PENABLE && PWRITE && (PADDR[4:2] == 3'd6)) |=>
      $stable(DUT.ss)
    );
  // GO clears legitimately on completion, so only prove the fields that never
  // change during a busy transfer. This avoids masking a valid GO clear.
  a_busy_ctrl_write_is_ignored:
    assert property (disable iff (!PRESETN)
      (DUT.tip && PSEL && PENABLE && PWRITE && (PADDR[4:2] == 3'd4)) |=>
      // CTRL[7] is a reserved, unimplemented bit and is intentionally
      // excluded from the implemented-field stability check.
      $stable({DUT.ctrl[13:9], DUT.ctrl[6:0]})
    );

  // Automatic CS has a simple, exact truth table.  Prove both directions so a
  // vacuous "only when" proof cannot hide an incorrect output.
  a_auto_cs_idle_is_high:
    assert property (disable iff (!PRESETN)
      (DUT.ass && !DUT.tip) |-> (ss_pad_o == 8'hff)
    );
  a_auto_cs_active_matches_selection:
    assert property (disable iff (!PRESETN)
      (DUT.ass && DUT.tip) |-> (ss_pad_o == ~DUT.ss)
    );
  a_manual_cs_matches_selection:
    assert property (disable iff (!PRESETN)
      !DUT.ass |-> (ss_pad_o == ~DUT.ss)
    );
`endif

`ifndef FORMAL_RESET_CHECK
  // Formal cover asks "does a legal trace exist?". These are not assertions;
  // VC Formal returns a witness trace for each reachable scenario.
  c_apb_write_then_spi_busy:
    cover property (PSEL && PENABLE && PWRITE && (PADDR[4:2] == 3'd4)
                    ##1 DUT.tip);
  c_busy_write_attempt:
    cover property (DUT.tip ##1 (PSEL && PENABLE && PWRITE &&
                    (PADDR[4:2] == 3'd5)));
  c_auto_cs_active:
    cover property (DUT.ass && DUT.tip && (DUT.ss != 8'h00));
`endif
`ifdef FORMAL_RESET_CHECK
  c_reset_asserted:
    cover property (!PRESETN);
  c_reset_reaches_idle:
    cover property (!PRESETN ##1
                   (!DUT.tip && !sclk_pad_o && !DUT.pos_edge &&
                    !DUT.neg_edge && !IRQ));
`endif

`ifdef FORMAL_DEMO_FAIL
  // Intentional false property for training. With ASS=1 and TIP=1, a selected
  // slave-select is low, so VC Formal must falsify this and produce a trace.
  a_demo_wrong_auto_cs_is_high:
    assert property (disable iff (!PRESETN)
      (DUT.ass && DUT.tip && (DUT.ss != 8'h00)) |-> (ss_pad_o == 8'hff)
    );
`endif

endmodule
