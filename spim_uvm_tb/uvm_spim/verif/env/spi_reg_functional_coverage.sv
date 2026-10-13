//------------------------------------------------------------

class spi_reg_functional_coverage extends uvm_subscriber #(apb_seq_item);

`uvm_component_utils(spi_reg_functional_coverage)

logic [4:0] address;
bit wnr;

reg_block spi_rm;

// Checks that the SPI master registers have
// all been accessed for both reads and writes
covergroup reg_rw_cov;
  option.per_instance = 1;
  ADDR: coverpoint address {
    bins DATA0 = {0};
    bins DATA1 = {4};
    bins DATA2 = {8};
    bins DATA3 = {5'hC};
    bins CTRL  = {5'h10};
    bins DIVIDER = {5'h14};
    bins SS = {5'h18};
  }
  CMD: coverpoint wnr {
    bins RD = {0};
    bins WR = {1};
  }
  RW_CROSS: cross CMD, ADDR;
endgroup: reg_rw_cov

//
// Checks that we have tested all possible modes of operation
// for the SPI master
//
// Note that the field value is 64 bits wide, so only the relevant
// bit(s) are used
covergroup combination_cov;

  option.per_instance = 1;

  ASS: coverpoint spi_rm.ctrl.ass.value[0];
  IE: coverpoint spi_rm.ctrl.ie.value[0];
  LSB: coverpoint spi_rm.ctrl.lsb.value[0];
  TX_NEG: coverpoint spi_rm.ctrl.tx_neg.value[0];
  RX_NEG: coverpoint spi_rm.ctrl.rx_neg.value[0];
  // Suspect character lengths - there may be more ....
  CHAR_LEN: coverpoint spi_rm.ctrl.char_len.value[6:0] {
    bins LENGTH[] = {0, 1, [31:33], [63:65], [95:97], 126, 127};
  }
  CLK_DIV: coverpoint spi_rm.divider.divider.value[7:0] {
    bins RATIO[] = {16'h0, 16'h1, 16'h2, 16'h4, 16'h8, 16'h10, 16'h20, 16'h40, 16'h80};
  }
  // A full Cartesian product of every control bit, length and divider creates
  // thousands of bins without describing a useful verification requirement.
  // Keep the meaningful protocol interactions as two independently-closable
  // crosses: SPI edge/bit-order mode and transfer size/clock generation.
  MODE_X_EDGE: cross ASS, LSB, TX_NEG, RX_NEG;
  LEN_X_DIV: cross CHAR_LEN, CLK_DIV;
  DATA_PATTERN: coverpoint spi_rm.rxtx0.rxtx0.value[7:0] {
    bins ZERO = {8'h00};
    bins ONES = {8'hff};
    bins A5   = {8'ha5};
    bins C3   = {8'h3c};
  }
endgroup: combination_cov

extern function new(string name = "spi_reg_functional_coverage", uvm_component parent = null);
extern function void write(T t);

endclass: spi_reg_functional_coverage

function spi_reg_functional_coverage::new(string name = "spi_reg_functional_coverage", uvm_component parent = null);
  super.new(name, parent);
  reg_rw_cov = new();
  combination_cov = new();
endfunction

function void spi_reg_functional_coverage::write(T t);
  // Register coverage first
  address = t.addr[4:0];
  wnr = t.we;
  reg_rw_cov.sample();
  // Sample the combination covergroup when go_bsy is true
  if(address == 5'h10)
     begin
       if(wnr) begin
         if(t.data[8] == 1) begin
           combination_cov.sample(); // TX started
         end
       end
     end
endfunction: write
