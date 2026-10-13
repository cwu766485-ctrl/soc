// Shared base for deterministic DUT-coverage tests.
// These tests intentionally do not create the SPI responder/scoreboard: they
// exercise RTL control/data paths and use the APB monitor for functional
// coverage, while the interrupt/poll tests retain full end-to-end checking.
class spi_cov_test_base extends spi_test_base;

  `uvm_component_utils(spi_cov_test_base)

  function new(string name = "spi_cov_test_base", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void configure_env(spi_env_config cfg);
    cfg.has_spi_agent = 0;
    cfg.has_spi_scoreboard = 0;
  endfunction

  task automatic raw_write(logic [31:0] addr, logic [31:0] data);
    apb_write_seq seq;
    seq = apb_write_seq::type_id::create($sformatf("wr_%0h", addr));
    seq.addr = addr;
    seq.data = data;
    seq.start(m_env.m_apb_agent.m_sequencer);
  endtask

  task automatic raw_read(logic [31:0] addr, output logic [31:0] data);
    apb_read_seq seq;
    seq = apb_read_seq::type_id::create($sformatf("rd_%0h", addr));
    seq.addr = addr;
    seq.start(m_env.m_apb_agent.m_sequencer);
    data = seq.data;
  endtask

  // Program all hardware-visible registers, start a transfer, and poll until
  // GO/BSY clears. CHAR_LEN is the bit count; zero means 128 bits.
  task automatic run_directed_transfer(
    input logic [15:0] divider,
    input logic [6:0]  char_len,
    input bit ass,
    input bit ie,
    input bit lsb,
    input bit tx_neg,
    input bit rx_neg,
    input logic [127:0] tx_data,
    input bit issue_busy_writes = 0,
    input bit enable_spi_responder = 0
  );
    logic [31:0] ctrl_data;
    logic [31:0] read_data;
    int polls;

    raw_write(32'h00, tx_data[31:0]);
    raw_write(32'h04, tx_data[63:32]);
    raw_write(32'h08, tx_data[95:64]);
    raw_write(32'h0c, tx_data[127:96]);
    raw_write(32'h14, {16'h0, divider});
    // Coverage-only tests can program SS immediately because no SPI monitor
    // is active. End-to-end tests defer it until CTRL.ASS is configured and
    // the responder is waiting; otherwise reset ASS=0 can assert CS early.
    if (!enable_spi_responder)
      raw_write(32'h18, 32'h1);

    // Raw APB sequences bypass the RAL frontdoor. Keep the model coherent
    // before the GO write, because the functional subscriber samples its RAL
    // fields at that write transaction.
    void'(spi_rm.rxtx0.predict(tx_data[31:0]));
    void'(spi_rm.rxtx1.predict(tx_data[63:32]));
    void'(spi_rm.rxtx2.predict(tx_data[95:64]));
    void'(spi_rm.rxtx3.predict(tx_data[127:96]));
    void'(spi_rm.divider.predict({16'h0, divider}));
    void'(spi_rm.ss.predict(32'h1));

    ctrl_data = 32'h0;
    ctrl_data[13] = ass;
    ctrl_data[12] = ie;
    ctrl_data[11] = lsb;
    ctrl_data[10] = tx_neg;
    ctrl_data[9]  = rx_neg;
    ctrl_data[6:0] = char_len;
    void'(spi_rm.ctrl.predict(ctrl_data));
    raw_write(32'h10, ctrl_data);

    // GO is written separately so every sample has stable configuration
    // fields when the functional coverage subscriber samples it.
    // The SPI slave BFM must be waiting before GO asserts chip select.
    // Coverage-only tests can omit it; end-to-end tests enable it so the
    // monitor and scoreboard check the serial data path as well.
    if (enable_spi_responder) begin
      spi_tfer_seq spi_response;
      spi_response = spi_tfer_seq::type_id::create("spi_response");
      spi_response.BITS = char_len;
      spi_response.rx_edge = rx_neg;
      fork
        spi_response.start(m_env.m_spi_agent.m_sequencer);
      join_none
      #1ns;
    end

    // Program SS only after the responder is waiting. For manual SS this
    // asserts CS now; for automatic SS, TIP keeps CS inactive until GO.
    if (enable_spi_responder)
      raw_write(32'h18, 32'h1);

    ctrl_data[8] = 1'b1;
    void'(spi_rm.ctrl.predict(ctrl_data));
    raw_write(32'h10, ctrl_data);

    // Legal APB accesses during an active transfer must not corrupt the
    // protected TX/DIVIDER/SS state. Besides testing that behaviour, these
    // writes cover the RTL's !tip=false guards.
    if (issue_busy_writes) begin
      raw_read(32'h10, read_data);
      if (read_data[8] !== 1'b1)
        `uvm_error("BUSY_WRITE_NOT_ACTIVE",
                   $sformatf("Expected GO/TIP busy before protected writes, CTRL=%08h", read_data))
      raw_write(32'h00, 32'hdead_beef);
      raw_write(32'h04, 32'hcafe_babe);
      raw_write(32'h08, 32'h1234_5678);
      raw_write(32'h0c, 32'h8765_4321);
      raw_write(32'h14, 32'h0000_0001);
      raw_write(32'h18, 32'h0000_0002);
    end

    polls = 0;
    do begin
      raw_read(32'h10, read_data);
      polls++;
    end while (read_data[8] && (polls < 100000));
    if (polls >= 100000)
      `uvm_error("COV_TIMEOUT", "SPI transfer did not complete while collecting coverage")

    // Manual SS does not deassert automatically when TIP clears.  Release it
    // so the SPI monitor can close this transaction before the next one.
    if (!ass && enable_spi_responder)
      raw_write(32'h18, 32'h0);

    // Once the transfer has completed, GO is expected to clear naturally.
    // Check that busy-time writes did not alter the other protected settings.
    // The shared TX/RX shift register is checked end-to-end by the SPI
    // scoreboard: its MOSI comparison proves the attempted TX writes did not
    // replace the data being shifted out.
    if (issue_busy_writes) begin
      raw_read(32'h10, read_data);
      if ((read_data[13:9] !== ctrl_data[13:9]) ||
          (read_data[7:0]  !== ctrl_data[7:0])  ||
          (read_data[8]   !== 1'b0))
        `uvm_error("BUSY_CTRL_READBACK",
                   $sformatf("CTRL changed after busy write attempts: expected fields=%08h actual=%08h",
                             ctrl_data & 32'h0000_3f7f, read_data))
      void'(spi_rm.ctrl.predict(read_data));

      raw_read(32'h14, read_data);
      if (read_data[15:0] !== divider)
        `uvm_error("BUSY_DIVIDER_READBACK",
                   $sformatf("DIVIDER changed after busy write attempt: expected=%04h actual=%04h",
                             divider, read_data[15:0]))
      void'(spi_rm.divider.predict(read_data));

      raw_read(32'h18, read_data);
      if (read_data[7:0] !== 8'h01)
        `uvm_error("BUSY_SS_READBACK",
                   $sformatf("SS changed after busy write attempt: expected=01 actual=%02h",
                             read_data[7:0]))
      void'(spi_rm.ss.predict(read_data));
    end
  endtask

  task automatic access_every_register();
    logic [31:0] addresses [0:6];
    logic [31:0] read_data;
    addresses = '{32'h00, 32'h04, 32'h08, 32'h0c, 32'h10, 32'h14, 32'h18};
    foreach (addresses[i]) raw_read(addresses[i], read_data);
  endtask

endclass
