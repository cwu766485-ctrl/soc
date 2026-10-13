//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_seq.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Sequence for agent ahb
//
//=============================================================================

`ifndef AHB_SEQ_SV
`define AHB_SEQ_SV

class ahb_base_seq extends uvm_sequence #(ahb_seq_item);

  `uvm_object_utils(ahb_base_seq)

  function new(string name = "ahb_base_seq");
    super.new(name);
  endfunction

  virtual task pre_body();
    if (starting_phase != null)
    starting_phase.raise_objection(this, {"Running sequence '",
                                          get_full_name(), "'"});
  endtask

  virtual task post_body();
    if (starting_phase != null)
    starting_phase.drop_objection(this, {"Completed sequence '",
                                         get_full_name(), "'"});
  endtask

endclass : ahb_base_seq

//-------------------------------------------------------------------------
class ahb_seq extends ahb_base_seq;

  `uvm_object_utils(ahb_seq)

  extern function new(string name = "ahb_seq");
  extern task body();

endclass : ahb_seq


function ahb_seq::new(string name = "ahb_seq");
  super.new(name);
endfunction : new


task ahb_seq::body();
  `uvm_info(get_type_name(), "Default sequence starting", UVM_HIGH)

  req = ahb_seq_item::type_id::create("req");
  start_item(req); 
  if ( !req.randomize() with {
    haddr  == 32'h0000_0000;
    hwdata == 32'h1234_5678;
    direction     == WRITE;
    access_size   == WORD;
    transfer_type == NONSEQ;
    burst_type    == SINGLE;
  } )
    `uvm_error(get_type_name(), "Failed to randomize transaction")
  req.beat_addr_q.delete();
  req.beat_data_q.delete();
  req.response_q.delete();
  req.busy_before_beat_q.delete();
  req.beat_addr_q.push_back(req.haddr);
  req.beat_data_q.push_back(req.hwdata);
  req.response_q.push_back(OKAY);
  finish_item(req); 

  `uvm_info(get_type_name(), "Default sequence completed", UVM_HIGH)
endtask : body


`endif // AHB_SEQ_LIB_SV
