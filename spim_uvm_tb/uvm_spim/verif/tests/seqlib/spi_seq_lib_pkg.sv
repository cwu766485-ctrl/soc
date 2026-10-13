//------------------------------------------------------------
package spi_seq_lib_pkg;

import uvm_pkg::*;
`include "uvm_macros.svh"

import spi_agent_pkg::*;

// This sequence is used to generate slave traffic
// which matches the configuration of the master SPI
// interface
//
// It has two configuration properties:
//
// BITS - Determining the number of bits transmitted
// rx_edge - Determining the sample edge used by the master
//
class spi_tfer_seq extends uvm_sequence #(spi_seq_item);

`uvm_object_utils(spi_tfer_seq)

function new(string name = "spi_tfer_seq");
  super.new(name);
endfunction

rand logic[6:0] BITS;
rand logic rx_edge;

task body;
  spi_seq_item req = spi_seq_item::type_id::create("req");

  start_item(req);
  if(!req.randomize() with {no_bits == BITS; RX_NEG == rx_edge;}) begin
    `uvm_error("body", "Randomization failure for req")
  end
  finish_item(req);

endtask:body

endclass: spi_tfer_seq

endpackage: spi_seq_lib_pkg
