`ifndef SRAMC_RESET_IF_SV
`define SRAMC_RESET_IF_SV

// Testbench-owned reset control.  It deliberately sits outside ahb_if:
// ahb_if observes the DUT reset as an input, whereas a reset test needs one
// explicit and controlled place that is allowed to drive it.
interface sramc_reset_if(input bit hclk);

  logic hresetn;

  task automatic pulse_reset(int unsigned low_cycles = 2);
    // Change reset away from a sampling edge, keep it active for whole AHB
    // cycles, then release it away from the next sampling edge.
    @(negedge hclk);
    hresetn = 1'b0;
    repeat (low_cycles) @(posedge hclk);
    @(negedge hclk);
    hresetn = 1'b1;
  endtask : pulse_reset

endinterface : sramc_reset_if

`endif // SRAMC_RESET_IF_SV
