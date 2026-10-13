// Verifies that a transfer completes normally while IE=0 and never raises IRQ.
class spi_interrupt_mask_test extends spi_cov_test_base;

  `uvm_component_utils(spi_interrupt_mask_test)

  function new(string name = "spi_interrupt_mask_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // This is an end-to-end data-path test in addition to an IRQ-mask check.
  function void configure_env(spi_env_config cfg);
    cfg.has_spi_agent = 1;
    cfg.has_spi_scoreboard = 1;
  endfunction

  task run_phase(uvm_phase phase);
    bit transfer_done;
    bit irq_seen;

    transfer_done = 1'b0;
    irq_seen = 1'b0;

    phase.raise_objection(this, "Verify IE=0 completes a checked SPI transfer without IRQ");
    wait (m_apb_cfg.APB.PRESETn === 1'b1);

    fork
      begin
        run_directed_transfer(16'h4, 7'd31, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0,
                              {16{8'ha5}}, 1'b0, 1'b1);
        transfer_done = 1'b1;
      end
      begin
        while (!transfer_done) begin
          @(negedge m_apb_cfg.APB.PCLK);
          if (m_env_cfg.INTR.IRQ !== 1'b0)
            irq_seen = 1'b1;
        end
      end
    join

    if (irq_seen || (m_env_cfg.INTR.IRQ !== 1'b0))
      `uvm_error("IRQ_MASK_ERROR",
                 "IRQ asserted during or after an SPI transfer with IE=0")

    repeat (2) @(posedge m_apb_cfg.APB.PCLK);
    phase.drop_objection(this, "IE=0 interrupt-mask check complete");
  endtask

endclass
