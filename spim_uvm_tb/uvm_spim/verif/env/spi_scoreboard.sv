//------------------------------------------------------------
class spi_scoreboard extends uvm_component;

`uvm_component_utils(spi_scoreboard)

uvm_tlm_analysis_fifo #(spi_seq_item) spi; // Both mosi & miso come in together
uvm_tlm_analysis_fifo #(spi_seq_item) expected_spi; // SPI slave response requested by the sequence

// Register Model Handle - assigned by the env code from the contents
// of its configuration object
reg_block spi_rm;

// Data buffers:
logic[31:0] mosi[3:0];
logic[31:0] miso[3:0];
logic[127:0] mosi_regs = 0;
// Bit count:
logic[7:0] bit_cnt;
//
// Statistics:
//
int no_transfers;
int no_tx_errors;
int no_rx_errors;
int no_cs_errors;
int no_miso_drive_errors;

function new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void build_phase(uvm_phase phase);
  spi = new("miso", this);
  expected_spi = new("expected_spi", this);
endfunction: build_phase

// What this scoreboard does:
//
// It relies on the fact that the register model is kept updated by the
// predictor in the test bench and that there are no accesses to the
// rxtx registers during the SPI data transfer
//
//
// When it receives a SPI transaction it compares the current version of
// the rxtx register models - i.e. the tx data - against the SPI MOSI data observed
// It then processes the rx data, according to the configured format, and peeks the
// SPI DUT rx data register to make sure it matches before
// updating the rxtx register models with the expected values for the
// SPI MISO data. An sequence is expected to read back from these registers using
// the mirror() method in order to detect any data errors.
//

task run_phase(uvm_phase phase);
  no_transfers = 0;
  no_tx_errors = 0;
  no_rx_errors = 0;
  no_cs_errors = 0;
  no_miso_drive_errors = 0;

  track_spi;

endtask: run_phase

task track_spi;
  spi_seq_item item;
  spi_seq_item expected_item;

  logic[127:0] tx_data;
  logic[127:0] mosi_data;
  logic[127:0] miso_data;
  logic[127:0] rev_miso;
  logic[127:0] bit_mask;
  logic[127:0] observed_miso;
  int expected_bits;
  logic[31:0] rx_data;
  uvm_reg_data_t spi_peek_data;
  uvm_status_e status;

  bit error;

  forever begin
    error = 0;
    spi.get(item);
    expected_spi.get(expected_item);
    no_transfers++;
    bit_cnt = spi_rm.ctrl.char_len.get();
    // Corner case for bit count equal to zero:
    if(bit_cnt == 8'b0) begin
      bit_cnt = 128;
    end

    // Check that the slave BFM put the sequence-requested data on MISO.
    // Use the same monitor edge selection as the DUT RX-data check below.
    expected_bits = expected_item.no_bits;
    if (expected_bits == 0)
      expected_bits = 128;
    observed_miso = expected_item.RX_NEG ? item.nedge_miso : item.pedge_miso;
    if (expected_item.RX_NEG != spi_rm.ctrl.rx_neg.get()) begin
      `uvm_error("SPI_SB_MISO_CFG:",
                 $sformatf("SPI sequence RX_NEG=%0b differs from CTRL.RX_NEG=%0b",
                           expected_item.RX_NEG, spi_rm.ctrl.rx_neg.get()))
      no_miso_drive_errors++;
    end
    else begin
      error = 0;
      for (int i = 0; i < expected_bits; i++) begin
        if (observed_miso[i] != expected_item.spi_data[i])
          error = 1;
      end
      if (error) begin
        `uvm_error("SPI_SB_MISO_DRV:",
                   $sformatf("Expected MISO %0h, observed MISO %0h",
                             expected_item.spi_data, observed_miso))
        no_miso_drive_errors++;
      end
    end

    //step1: TX path get predicted data 

    // Deal with the mosi data (TX)
    tx_data[31:0] = spi_rm.rxtx0.get();
    tx_data[63:32] = spi_rm.rxtx1.get();
    tx_data[95:64] = spi_rm.rxtx2.get();
    tx_data[127:96] = spi_rm.rxtx3.get();
    $display("scb: exp.tx_data[31:0] %0h", spi_rm.rxtx0.get());

    // Fix the data comparison mask for the number of bits
    bit_mask = 0;
    for(int i = 0; i < bit_cnt; i++) begin
      bit_mask[i] = 1;
    end

    //step2: TX path get response data 

    if(spi_rm.ctrl.tx_neg.get() == 1) begin
      mosi_data = item.pedge_mosi; // To be compared against write data
    end
    else begin
      mosi_data = item.nedge_mosi;
    end


    //step3: TX path  compare logic
    //predict vs response
    
    if(spi_rm.ctrl.lsb.get() == 1) begin
      for(int i = 0; i < bit_cnt; i++) begin
        if(tx_data[i] != mosi_data[i]) begin
          error = 1;
        end
      end
      if(error == 1) begin
        `uvm_error("SPI_SB_MOSI_LSB:", $sformatf("Expected mosi value %0h actual %0h", tx_data, mosi_data))
      end
    end
    else begin
      for(int i = 0; i < bit_cnt; i++) begin
        if(tx_data[i] != mosi_data[(bit_cnt-1) - i]) begin
          error = 1;
        end
      end
      if(error == 1) begin // Need to reverse the mosi_data bits
        rev_miso = 0;
        for(int i = 0; i < bit_cnt; i++) begin
          rev_miso[(bit_cnt-1) - i] = mosi_data[i];
        end
        `uvm_error("SPI_SB_MOSI_MSB:", $sformatf("Expected mosi value %0h actual %0h", tx_data, rev_miso))
      end
    end
    if(error == 1) begin
      no_tx_errors++;
    end

    // Reset the error bit
    error = 0;

    //step1: get rx predict data from spi_bus signals

    // Check the miso data (RX)
    if(spi_rm.ctrl.rx_neg.get() == 1) begin
      miso_data = item.nedge_miso;
    end
    else begin
      miso_data = item.pedge_miso;
    end
    if(spi_rm.ctrl.lsb.get() == 0) begin
      // reverse the bits lsb -> msb, and so on
      rev_miso = 0;
      for(int i = 0; i < bit_cnt; i++) begin
        rev_miso[(bit_cnt-1) - i] = miso_data[i];
      end
      miso_data = rev_miso;
    end

    // The following sets up the rx data so that it is
    // bit masked according to the no of bits
    rx_data = spi_rm.rxtx0.get();
    // Peek the received data
    spi_rm.rxtx0.peek(status, spi_peek_data);
    for(int i = 0; ((i < 32) && (i < bit_cnt)); i++) begin
      rx_data[i] = miso_data[i];
      if(spi_peek_data[i] != miso_data[i]) begin
        error = 1;
        `uvm_error("SPI_SB_RXD:", $sformatf("Bit%0d Expected RX data value %0h actual %0h", i, spi_peek_data[31:0], miso_data))
      end
    end
    // Get the register model to check that the data it next reads back from this
    // register is as predicted
    // This is somewhat redundant given the earlier peek check, but it does check the
    // read back path
    assert(spi_rm.rxtx0.predict(rx_data));

    rx_data = spi_rm.rxtx1.get();
    spi_rm.rxtx1.peek(status, spi_peek_data);
    for(int i = 32; ((i < 64) && (i < bit_cnt)); i++) begin
      rx_data[i-32] = miso_data[i];
      if(spi_peek_data[i-32] != miso_data[i]) begin
        error = 1;
        `uvm_error("SPI_SB_RXD:", $sformatf("Bit%0d Expected RX data value %0h actual %0h", i, spi_peek_data[31:0], miso_data))
      end
    end
    assert(spi_rm.rxtx1.predict(rx_data));

    rx_data = spi_rm.rxtx2.get();
    spi_rm.rxtx2.peek(status, spi_peek_data);
    for(int i = 64; ((i < 96) && (i < bit_cnt)); i++) begin
      rx_data[i-64] = miso_data[i];
      if(spi_peek_data[i-64] != miso_data[i]) begin
        error = 1;
        `uvm_error("SPI_SB_RXD:", $sformatf("Bit%0d Expected RX data value %0h actual %0h", i, spi_peek_data[31:0], miso_data))
      end
    end

    assert(spi_rm.rxtx2.predict(rx_data));
    $display("hfu scb predict rxtx2: %t", $time);

    rx_data = spi_rm.rxtx3.get();
    spi_rm.rxtx3.peek(status, spi_peek_data);
    for(int i = 96; ((i < 128) && (i < bit_cnt)); i++) begin
      rx_data[i-96] = miso_data[i];
      if(spi_peek_data[i-96] != miso_data[i]) begin
        error = 1;
        `uvm_error("SPI_SB_RXD:", $sformatf("Bit%0d Expected RX data value %0h actual %0h", i, spi_peek_data[31:0], miso_data))
      end
    end
    assert(spi_rm.rxtx3.predict(rx_data));
    $display("hfu scb predict rxtx3: %t", $time);

    if(error == 1) begin
      no_rx_errors++;
    end

    // Check the chip select lines
    // //if ass==1 -- keep the original checker 
    if (spi_rm.ctrl.ass.get() == 1) begin
    if(spi_rm.ss.ss.get() != {56'h0, ~item.cs}) begin
      `uvm_error("SPI_SB_CS:", $sformatf("Expected cs value %b actual %b", spi_rm.ss.ss.get(), ~item.cs))
      no_cs_errors++;
    end
    end

    // if(spi_rm.ss.ss.get() != {56'h0, ~item.cs}) begin
    //   `uvm_error("SPI_SB_CS:", $sformatf("Expected cs value %b actual %b", spi_rm.ss.ss.get(), ~item.cs))
    //   no_cs_errors++;
    // end

  end

endtask: track_spi

function void report_phase(uvm_phase phase);

  if(no_transfers == 0) begin
    `uvm_info("SPI_SB_REPORT:", "No SPI transfers took place", UVM_LOW)
  end
  if((no_cs_errors == 0) && (no_tx_errors == 0) && (no_rx_errors == 0) && (no_transfers > 0)) begin
    `uvm_info("SPI_SB_REPORT:", $sformatf("Test Passed - %0d transfers occured with no errors", no_transfers), UVM_LOW)
  end
  if(no_miso_drive_errors > 0) begin
    `uvm_error("SPI_SB_REPORT:", $sformatf("Test Failed - %0d SPI slave MISO drive errors occured", no_miso_drive_errors))
  end
  if(no_tx_errors > 0) begin
    `uvm_error("SPI_SB_REPORT:", $sformatf("Test Failed - %0d TX errors occured during %0d transfers", no_tx_errors, no_transfers))
  end
  if(no_rx_errors > 0) begin
    `uvm_error("SPI_SB_REPORT:", $sformatf("Test Failed - %0d RX errors occured during %0d transfers", no_rx_errors, no_transfers))
  end
  if(no_cs_errors > 0) begin
    `uvm_error("SPI_SB_REPORT:", $sformatf("Test Failed - %0d CS errors occured during %0d transfers", no_cs_errors, no_transfers))
  end

endfunction: report_phase


endclass: spi_scoreboard
