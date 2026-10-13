// Covers every ASS/LSB/TX_NEG/RX_NEG serial-transfer mode with data patterns.
// ASS/LSB/TX_NEG/RX_NEG 的 16 种组合，且端到端检查
class spi_shift_mode_test extends spi_cov_test_base;

  `uvm_component_utils(spi_shift_mode_test)

  function new(string name = "spi_shift_mode_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Unlike the coverage-only base configuration, this test deliberately
  // keeps the SPI responder, monitor, and scoreboard for end-to-end checks.
  function void configure_env(spi_env_config cfg);
    cfg.has_spi_agent = 1;
    cfg.has_spi_scoreboard = 1;
  endfunction

  task run_phase(uvm_phase phase);
    logic [6:0] lengths [0:9];
    logic [127:0] patterns [0:3];
    lengths = '{7'd0, 7'd1, 7'd31, 7'd32, 7'd63, 7'd64, 7'd95, 7'd96, 7'd126, 7'd127};
    patterns = '{128'h0, {16{8'hff}}, {16{8'ha5}}, {16{8'h3c}}};

    phase.raise_objection(this, "Exercise all serial bit-order and edge modes");
    for (int mode = 0; mode < 16; mode++)
      run_directed_transfer(16'h2, lengths[mode % 10], mode[0], mode[0], mode[1],
                            mode[2], mode[3], patterns[mode % 4], 1'b0, 1'b1);
    phase.drop_objection(this, "Shift-mode coverage complete");
  endtask

endclass
