// Confirms that writes to protected registers are ignored while TIP is high.
// tip=1 时写 TX/DIVIDER/SS 是否被保护
class spi_busy_write_cov_test extends spi_cov_test_base;

  `uvm_component_utils(spi_busy_write_cov_test)

  function new(string name = "spi_busy_write_cov_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Keep the slave responder and scoreboard enabled so the TX busy-write
  // protection is checked against the actual MOSI stream, not coverage alone.
  function void configure_env(spi_env_config cfg);
    cfg.has_spi_agent = 1;
    cfg.has_spi_scoreboard = 1;
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Exercise register-write guards while SPI is busy");
    // Longest transfer/divider leaves ample time for the attempted writes.
    // The helper also checks CTRL/DIVIDER/SS readback after transfer completion;
    // the scoreboard verifies the protected TX data through the MOSI pins.
    run_directed_transfer(16'h80, 7'd127, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
                          {16{8'ha5}}, 1'b1, 1'b1);
    phase.drop_objection(this, "Busy-write coverage complete");
  endtask

endclass
