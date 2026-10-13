//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_sequencer.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Sequencer for ahb
//
//=============================================================================

`ifndef AHB_SEQUENCER_SV
`define AHB_SEQUENCER_SV

class ahb_sequencer extends uvm_sequencer #(ahb_seq_item);

  `uvm_component_utils(ahb_sequencer)

  extern function new(string name, uvm_component parent);

endclass : ahb_sequencer 


function ahb_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new


`endif // AHB_SEQUENCER_SV

