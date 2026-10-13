// DUT-level protocol assertions.  These are bound into spi_top so that they
// are checked and covered as part of the DUT hierarchy.
module spi_assertions (
  input logic PCLK,
  input logic PRESETN,
  input logic go,
  input logic tip,
  input logic sclk_pad_o,
  input logic pos_edge,
  input logic neg_edge
);
  default clocking cb @(posedge PCLK); endclocking

  // A generated SPI clock cannot report both edge pulses in one PCLK cycle.
  a_edges_mutually_exclusive:
    assert property (disable iff (!PRESETN) !(pos_edge && neg_edge));

  // While reset is asserted, the clock generator and transfer state are idle.
  a_reset_clears_transfer_state:
    assert property (!PRESETN |-> (!tip && !sclk_pad_o && !pos_edge && !neg_edge));

  // GO and tip are updated on the same PCLK edge, so sample the GO transition
  // and require tip to be observed high on the following sampled cycle.
  a_go_starts_transfer:
    assert property (disable iff (!PRESETN) $rose(go) |-> tip);

  // Cover the reset assertion and release; these are useful reset-quality bins.
  c_reset_assertion: cover property ($fell(PRESETN));
  c_reset_release:   cover property ($rose(PRESETN));
  c_reset_while_busy: cover property (@(negedge PRESETN) tip);
endmodule

bind spi_top spi_assertions spi_assertions_i (
  .PCLK       (PCLK),
  .PRESETN    (PRESETN),
  .go         (go),
  .tip        (tip),
  .sclk_pad_o (sclk_pad_o),
  .pos_edge   (pos_edge),
  .neg_edge   (neg_edge)
);
