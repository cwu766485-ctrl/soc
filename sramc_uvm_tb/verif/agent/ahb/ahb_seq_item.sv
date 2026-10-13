//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_seq_item.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Sequence item for ahb_sequencer
//
//=============================================================================

`ifndef AHB_SEQ_ITEM_SV
`define AHB_SEQ_ITEM_SV

typedef enum bit [1:0] {
  IDLE   = 2'b00,
  BUSY   = 2'b01,
  NONSEQ = 2'b10,
  SEQ    = 2'b11
} ahb_trans_type_e;

typedef enum bit {
  READ  = 1'b0,
  WRITE = 1'b1
} ahb_op_type_e;

typedef enum bit [2:0] {
  BYTE     = 3'b000,
  HALFWORD = 3'b001,
  WORD     = 3'b010
} ahb_beat_size_e;

typedef enum bit [2:0] {
  SINGLE = 3'b000,
  INCR   = 3'b001,
  WRAP4  = 3'b010,
  INCR4  = 3'b011,
  WRAP8  = 3'b100,
  INCR8  = 3'b101,
  WRAP16 = 3'b110,
  INCR16 = 3'b111
} ahb_burst_type_e;

typedef enum bit [1:0] {
  OKAY  = 2'b00,
  ERROR = 2'b01,
  RETRY = 2'b10,
  SPLIT = 2'b11
} ahb_rsp_type_e;

class ahb_seq_item extends uvm_sequence_item; 

  rand bit [31:0] haddr;
  rand bit [31:0] hwdata;
  rand bit [31:0] hrdata;

  // Typed transaction fields are the single source of truth. Their packed
  // encodings match the AHB pins, so the driver can assign them directly.
  rand ahb_trans_type_e transfer_type;
  rand ahb_op_type_e    direction;
  rand ahb_beat_size_e  access_size;
  rand ahb_burst_type_e burst_type;
       ahb_rsp_type_e   response_q[$];
  // Reference-model metadata. It is set only on the expected-read stream.
  bit                   compare_enabled;
  bit                   compare_enabled_q[$];

  logic [31:0] beat_addr_q[$];
  // Burst payload and BUSY insertion are constructed explicitly by a sequence;
  // they are not independently randomized by the item solver.
  bit [31:0] beat_data_q[$];
  int unsigned busy_before_beat_q[$];

  constraint c_default_transfer {
    transfer_type == NONSEQ;
    access_size inside {BYTE, HALFWORD, WORD};
    burst_type == SINGLE;
  }

  `uvm_object_utils_begin(ahb_seq_item)
    `uvm_field_int(haddr, UVM_ALL_ON)
    `uvm_field_int(hwdata, UVM_ALL_ON)
    `uvm_field_int(hrdata, UVM_ALL_ON)
    `uvm_field_enum(ahb_trans_type_e, transfer_type, UVM_ALL_ON)
    `uvm_field_enum(ahb_op_type_e, direction, UVM_ALL_ON)
    `uvm_field_enum(ahb_beat_size_e, access_size, UVM_ALL_ON)
    `uvm_field_enum(ahb_burst_type_e, burst_type, UVM_ALL_ON)
    `uvm_field_queue_enum(ahb_rsp_type_e, response_q, UVM_ALL_ON)
    `uvm_field_int(compare_enabled, UVM_ALL_ON)
    `uvm_field_queue_int(compare_enabled_q, UVM_ALL_ON)
    `uvm_field_queue_int(beat_addr_q, UVM_ALL_ON)
    `uvm_field_queue_int(beat_data_q, UVM_ALL_ON)
    `uvm_field_queue_int(busy_before_beat_q, UVM_ALL_ON)
  `uvm_object_utils_end


  extern function new(string name = "ahb_seq_item");
endclass : ahb_seq_item 


function ahb_seq_item::new(string name = "ahb_seq_item");
  super.new(name);
  transfer_type = NONSEQ;
  direction = WRITE;
  access_size = WORD;
  burst_type = SINGLE;
  response_q.push_back(OKAY);
endfunction : new


`endif // AHB_SEQ_ITEM_SV
