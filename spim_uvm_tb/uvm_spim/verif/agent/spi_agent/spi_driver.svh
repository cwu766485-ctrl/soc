//------------------------------------------------------------
//   Copyright 2010 Mentor Graphics Corporation
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------
//
// Class Description:
//
//
class spi_driver extends uvm_driver #(spi_seq_item, spi_seq_item);

// UVM Factory Registration Macro
//
`uvm_component_utils(spi_driver)

// Virtual Interface
virtual spi_if SPI;
// Publish the requested slave response so checking does not rely only on
// the value that happens to be observed on the MISO pin.
uvm_analysis_port #(spi_seq_item) expected_ap;

//------------------------------------------
// Data Members
//------------------------------------------

//------------------------------------------
// Methods
//------------------------------------------

// Standard UVM Methods:
extern function new(string name = "spi_driver", uvm_component parent = null);
extern task run_phase(uvm_phase phase);

endclass: spi_driver

function spi_driver::new(string name = "spi_driver", uvm_component parent = null);
  super.new(name, parent);
  expected_ap = new("expected_ap", this);
endfunction

// This driver is really an SPI slave responder
task spi_driver::run_phase(uvm_phase phase);
  spi_seq_item req;
  spi_seq_item rsp;
  int no_bits;

  SPI.miso <= 1;
  while(SPI.cs === 8'hxx) begin
    #1;
  end

  forever begin
    seq_item_port.get_next_item(req);
    // Preserve the sequence intent before this driver turns it into pin wiggles.
    $cast(rsp, req.clone());
    expected_ap.write(rsp);
    no_bits = req.no_bits;
    if(no_bits == 0) begin
      no_bits = 128;
    end
    // Preload the first response bit while chip select is still inactive.
    // This gives the DUT a valid MISO value if SCLK starts immediately when
    // CS is asserted (for example, with a zero divider).
    SPI.miso <= req.spi_data[0];
    while(SPI.cs == 8'hff) begin
      @(SPI.cs);
    end
    `uvm_info("SPI_DRV_RUN:", $sformatf("Starting transmission: %0h RX_NEG State %b, no of bits %0d", req.spi_data, req.RX_NEG, req.no_bits), UVM_LOW)
    for(int i = 1; i < no_bits; i++) begin
      if(req.RX_NEG == 1) begin
        // The master samples on falling edges. Keep bit 0 through the first
        // falling edge, then advance MISO on the following rising edge.
        @(negedge SPI.clk);
        @(posedge SPI.clk);
      end
      else begin
        // The master samples on rising edges. Advance after that sample at
        // the following falling edge.
        @(posedge SPI.clk);
        @(negedge SPI.clk);
      end
      SPI.miso <= req.spi_data[i];
      `uvm_info("SPI_DRV_RUN:", $sformatf("Driver: %0b(%0d).", req.spi_data[i], i), UVM_LOW)
      if(SPI.cs == 8'hff) begin
        break;
      end
    end
    seq_item_port.item_done();
  end
endtask: run_phase
