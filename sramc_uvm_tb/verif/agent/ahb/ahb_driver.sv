//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_driver.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Driver for ahb
//
//=============================================================================

`ifndef AHB_DRIVER_SV
`define AHB_DRIVER_SV

class ahb_driver extends uvm_driver #(ahb_seq_item);

  `uvm_component_utils(ahb_driver)

  virtual interface  ahb_if vif;

  extern function new(string name, uvm_component parent);
  extern virtual function void build_phase (uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern task reset_phase(uvm_phase phase);
  extern task main_phase(uvm_phase phase);
  extern task drive_transfer(ahb_seq_item transfer);
  extern task drive_address_phase(ahb_seq_item transfer,
                                  bit [31:0] address,
                                  ahb_trans_type_e transfer_type);
  extern function int unsigned expected_beat_count(ahb_burst_type_e burst_type);
  extern function int unsigned busy_cycles_before_beat(ahb_seq_item transfer,
                                                         int unsigned beat_index);
endclass : ahb_driver 


function ahb_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new


function void ahb_driver::build_phase(uvm_phase phase);
endfunction : build_phase


function void ahb_driver::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  if (!uvm_config_db #(virtual ahb_if)::get(this, "", "vif", vif))
    `uvm_error("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"})
endfunction : connect_phase

task ahb_driver::reset_phase(uvm_phase phase);
  phase.raise_objection(this);
  vif.hsel   <= 1'b0;
  vif.haddr  <= 32'h0;
  vif.htrans <= 2'b00;
  vif.hsize  <= 3'b010;
  vif.hburst <= 3'b000;
  vif.hwrite <= 1'b0;
  vif.hwdata <= 32'h0;
  vif.hready <= 1'b0;
  wait (vif.hresetn == 1'b1);
  vif.hready <= 1'b1;
  phase.drop_objection(this);
endtask : reset_phase


task ahb_driver::main_phase(uvm_phase phase);

  `uvm_info(get_type_name(), "main_phase", UVM_HIGH)
  wait (vif.hresetn == 1'b1);
  forever
  begin
    seq_item_port.get_next_item(req);
      `uvm_info(get_type_name(), {"transfer item\n",req.sprint}, UVM_HIGH)
    drive_transfer(req);
    seq_item_port.item_done();
  end
endtask : main_phase


task ahb_driver::drive_address_phase(ahb_seq_item transfer,
                                     bit [31:0] address,
                                     ahb_trans_type_e transfer_type);
  vif.drvCLK.hwrite <= transfer.direction;
  vif.drvCLK.hsel   <= 1'b1;
  vif.drvCLK.htrans <= transfer_type;
  vif.drvCLK.hready <= 1'b1;
  vif.drvCLK.hsize  <= transfer.access_size;
  vif.drvCLK.hburst <= transfer.burst_type;
  vif.drvCLK.haddr  <= address;
endtask : drive_address_phase


task ahb_driver::drive_transfer(ahb_seq_item transfer);
  bit [31:0] beat_addr_q[$];
  bit [31:0] beat_data_q[$];
  int unsigned beat_count;
  int unsigned declared_beat_count;

  `uvm_info("TRACE", $sformatf("%m"), UVM_HIGH)

  // A standalone BUSY/IDLE item is useful in directed protocol tests. It has
  // no data phase and must not be converted into a valid NONSEQ transfer.
  if ((transfer.transfer_type == BUSY) ||
      (transfer.transfer_type == IDLE)) begin
    @(vif.drvCLK);
    vif.drvCLK.hsel   <= (transfer.transfer_type == BUSY);
    vif.drvCLK.htrans <= transfer.transfer_type;
    vif.drvCLK.hready <= 1'b1;
    vif.drvCLK.hsize  <= transfer.access_size;
    vif.drvCLK.hburst <= transfer.burst_type;
    vif.drvCLK.haddr  <= transfer.haddr;
    vif.drvCLK.hwrite <= transfer.direction;
    @(vif.drvCLK);
    vif.drvCLK.hsel   <= 1'b0;
    vif.drvCLK.htrans <= IDLE;
    return;
  end

  beat_addr_q = transfer.beat_addr_q;
  beat_data_q = transfer.beat_data_q;
  if (beat_addr_q.size() == 0) begin
    beat_addr_q.push_back(transfer.haddr);
    beat_data_q.push_back(transfer.hwdata);
  end
  else if (beat_data_q.size() != beat_addr_q.size()) begin
    `uvm_fatal("BURST_DATA",
               $sformatf("beat address/data queue length mismatch: addr=%0d data=%0d",
                         beat_addr_q.size(), beat_data_q.size()))
  end

  beat_count = beat_addr_q.size();
  declared_beat_count = expected_beat_count(transfer.burst_type);
  if ((declared_beat_count != 0) && (beat_count != declared_beat_count))
    `uvm_fatal("BURST_LENGTH",
               $sformatf("burst type %0d requires %0d beats, sequence supplied %0d",
                         transfer.burst_type, declared_beat_count, beat_count))

  // Address/control is pipelined one cycle ahead of write data. Beat 0 is
  // NONSEQ and later beats are SEQ. An INCR item has a sequence-selected,
  // bounded length; driving IDLE after its last beat terminates that burst.
  @(vif.drvCLK);
  drive_address_phase(transfer, beat_addr_q[0], NONSEQ);

  for (int unsigned beat_index = 1; beat_index < beat_count; beat_index++) begin
    @(vif.drvCLK);
    vif.drvCLK.hwdata <= beat_data_q[beat_index - 1];
    repeat (busy_cycles_before_beat(transfer, beat_index)) begin
      vif.drvCLK.hsel   <= 1'b1;
      vif.drvCLK.htrans <= BUSY;
      vif.drvCLK.hready <= 1'b1;
      @(vif.drvCLK);
    end
    drive_address_phase(transfer, beat_addr_q[beat_index], SEQ);
  end

  @(vif.drvCLK);
  vif.drvCLK.hwdata <= beat_data_q[beat_count - 1];
  vif.drvCLK.hsel   <= 1'b0;
  vif.drvCLK.htrans <= IDLE;
endtask : drive_transfer


function int unsigned ahb_driver::expected_beat_count(ahb_burst_type_e burst_type);
  case (burst_type)
    SINGLE:         return 1;
    WRAP4, INCR4:   return 4;
    WRAP8, INCR8:   return 8;
    WRAP16, INCR16: return 16;
    default:        return 0;
  endcase
endfunction : expected_beat_count


function int unsigned ahb_driver::busy_cycles_before_beat(ahb_seq_item transfer,
                                                            int unsigned beat_index);
  int unsigned busy_cycles;
  foreach (transfer.busy_before_beat_q[index])
    if (transfer.busy_before_beat_q[index] == beat_index)
      busy_cycles++;
  return busy_cycles;
endfunction : busy_cycles_before_beat

`endif // AHB_DRIVER_SV
