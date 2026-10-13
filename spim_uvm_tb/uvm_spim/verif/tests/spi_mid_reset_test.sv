// Directed reset-while-busy test used for reset toggle and assertion coverage.
// 测试传输途中复位的行为
class spi_mid_reset_test extends spi_test_base;

  `uvm_component_utils(spi_mid_reset_test)

  function new(string name = "spi_mid_reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // No SPI slave transaction is generated in this reset-only test. Disable
  // the SPI monitor/scoreboard so it does not interpret the aborted transfer
  // as a data-path failure.
  function void configure_env(spi_env_config cfg);
    cfg.has_spi_agent = 0;
    cfg.has_spi_scoreboard = 0;
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_seq div_write;
    apb_write_seq ss_write;
    apb_write_seq ctrl_write;

    phase.raise_objection(this, "Start a long transfer before directed reset");

    // Program the real APB byte addresses directly.  This deliberately avoids
    // RAL mirror state, which is reset asynchronously during this test.
    div_write = apb_write_seq::type_id::create("div_write");
    div_write.addr = 32'h14;
    div_write.data = 32'h0000_0080;
    div_write.start(m_env.m_apb_agent.m_sequencer);

    ss_write = apb_write_seq::type_id::create("ss_write");
    ss_write.addr = 32'h18;
    ss_write.data = 32'h0000_0001;
    ss_write.start(m_env.m_apb_agent.m_sequencer);

    // ASS=1, GO=1 and CHAR_LEN=127: a long transaction remains busy until
    // the directed reset aborts it.
    ctrl_write = apb_write_seq::type_id::create("ctrl_write");
    ctrl_write.addr = 32'h10;
    ctrl_write.data = 32'h0000_217f;
    ctrl_write.start(m_env.m_apb_agent.m_sequencer);

    // Raw APB writes bypass the RAL predictor. Keep its mirror coherent so
    // the existing monitor/scoreboard does not report a false configuration
    // mismatch during this coverage-only directed test.
    void'(spi_rm.divider.predict(16'h0080));
    void'(spi_rm.ss.predict(32'h0000_0001));
    void'(spi_rm.ctrl.predict(32'h0000_217f));

    // top_tb asserts reset near 0.9 us when +MID_RESET is supplied.
    #1200ns;
    phase.drop_objection(this, "Directed reset coverage complete");
  endtask
endclass
