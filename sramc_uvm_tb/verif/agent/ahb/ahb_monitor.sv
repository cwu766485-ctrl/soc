//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_monitor.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Monitor for ahb
//
//=============================================================================

`ifndef AHB_MONITOR_SV
`define AHB_MONITOR_SV

class ahb_monitor extends uvm_monitor;

  `uvm_component_utils(ahb_monitor)

  virtual interface  ahb_if vif;

  uvm_analysis_port #(ahb_seq_item) analysis_port;

  ahb_seq_item pending_addr_phase_q[$];
  ahb_seq_item active_burst_transfer;

  extern function new(string name, uvm_component parent);
  extern virtual function void build_phase (uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);
  extern task main_phase(uvm_phase phase);
  extern task do_mon();
  extern task complete_data_phase();
  extern task capture_addr_phase();
  extern task publish_transfer(ahb_seq_item transfer);
  extern function int unsigned expected_beat_count(ahb_burst_type_e burst_type);

endclass : ahb_monitor 


function ahb_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
  analysis_port = new("analysis_port", this);
endfunction : new


function void ahb_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction : build_phase


function void ahb_monitor::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  if (!uvm_config_db #(virtual ahb_if)::get(this, "", "vif", vif))
    `uvm_error("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"})
endfunction : connect_phase


task ahb_monitor::main_phase(uvm_phase phase);
  `uvm_info(get_type_name(), "main_phase", UVM_HIGH)
  wait (vif.hresetn == 1'b1);
  forever do_mon();
endtask : main_phase


task ahb_monitor::do_mon();
  @(vif.monCLK);
  if (vif.hresetn != 1'b1) begin
    pending_addr_phase_q.delete();
    active_burst_transfer = null;
    return;
  end

  // AHB is pipelined: complete the previous address phase before sampling the
  // current one. This accepts one valid address phase per cycle, including the
  // contiguous SEQ beats of a burst. HREADY_RESP holds both phases on a slave
  // wait state.
  if (vif.monCLK.hready_resp == 1'b1) begin
    complete_data_phase();
    capture_addr_phase();
  end
endtask : do_mon


task ahb_monitor::complete_data_phase();
  ahb_seq_item beat;
  int unsigned expected_beats;

  if (pending_addr_phase_q.size() == 0)
    return;

  beat = pending_addr_phase_q.pop_front();
  if (beat.direction == WRITE) begin
    beat.hwdata = vif.monCLK.hwdata;
    beat.beat_data_q.delete();
    beat.beat_data_q.push_back(vif.monCLK.hwdata);
  end
  else begin
    beat.hrdata = vif.monCLK.hrdata;
    beat.beat_data_q.delete();
    beat.beat_data_q.push_back(vif.monCLK.hrdata);
  end
  beat.response_q.delete();
  beat.response_q.push_back(ahb_rsp_type_e'(vif.monCLK.hresp));
  beat.beat_addr_q.delete();
  beat.beat_addr_q.push_back(beat.haddr);

  if (beat.transfer_type == NONSEQ) begin
    if (active_burst_transfer != null)
      publish_transfer(active_burst_transfer);

    active_burst_transfer = beat;
    expected_beats = expected_beat_count(beat.burst_type);
    if (expected_beats == 1) begin
      publish_transfer(active_burst_transfer);
      active_burst_transfer = null;
    end
  end
  else if (beat.transfer_type == SEQ) begin
    if (active_burst_transfer == null) begin
      `uvm_error(get_full_name(), "Received SEQ beat without a preceding NONSEQ beat")
      publish_transfer(beat);
      return;
    end

    active_burst_transfer.beat_addr_q.push_back(beat.haddr);
    active_burst_transfer.beat_data_q.push_back(beat.beat_data_q[0]);
    active_burst_transfer.response_q.push_back(beat.response_q[0]);
    expected_beats = expected_beat_count(active_burst_transfer.burst_type);
    if ((expected_beats != 0) &&
        (active_burst_transfer.beat_addr_q.size() == expected_beats)) begin
      publish_transfer(active_burst_transfer);
      active_burst_transfer = null;
    end
  end
  else begin
    publish_transfer(beat);
  end
endtask : complete_data_phase


task ahb_monitor::capture_addr_phase();
  ahb_seq_item addr_trans;

  // An undefined-length INCR ends when the master drives IDLE. Fixed bursts
  // publish as soon as their final SEQ beat is observed.
  if (vif.monCLK.hsel != 1'b1) begin
    if ((active_burst_transfer != null) &&
        (active_burst_transfer.burst_type == INCR)) begin
      publish_transfer(active_burst_transfer);
      active_burst_transfer = null;
    end
    return;
  end

  // BUSY has no address/data transfer of its own, but it is protocol-relevant
  // metadata of the active burst.  Record the index of the following beat.
  if (vif.monCLK.htrans == BUSY) begin
    if (active_burst_transfer != null)
      active_burst_transfer.busy_before_beat_q.push_back(
        active_burst_transfer.beat_addr_q.size());
    return;
  end

  if ((vif.monCLK.htrans != NONSEQ) && (vif.monCLK.htrans != SEQ))
    return;

  addr_trans = ahb_seq_item::type_id::create("observed_addr_phase");
  addr_trans.haddr  = vif.monCLK.haddr;
  addr_trans.direction     = ahb_op_type_e'(vif.monCLK.hwrite);
  addr_trans.access_size   = ahb_beat_size_e'(vif.monCLK.hsize);
  addr_trans.transfer_type = ahb_trans_type_e'(vif.monCLK.htrans);
  addr_trans.burst_type    = ahb_burst_type_e'(vif.monCLK.hburst);
  pending_addr_phase_q.push_back(addr_trans);
endtask : capture_addr_phase


task ahb_monitor::publish_transfer(ahb_seq_item transfer);
  ahb_seq_item published_transfer;

  // Analysis ports pass object handles. Publish an independent snapshot so
  // every downstream subscriber sees a stable completed transaction.
  if (!$cast(published_transfer, transfer.clone())) begin
    `uvm_error("MONCAST", "Failed to clone completed AHB transaction")
    return;
  end
  analysis_port.write(published_transfer);
  `uvm_info(get_full_name(),
            $sformatf("AHB monitor completed transfer:\n%s", published_transfer.sprint()),
            UVM_HIGH)
endtask : publish_transfer


function int unsigned ahb_monitor::expected_beat_count(ahb_burst_type_e burst_type);
  case (burst_type)
    SINGLE:         return 1;
    WRAP4, INCR4:   return 4;
    WRAP8, INCR8:   return 8;
    WRAP16, INCR16: return 16;
    default:        return 0;
  endcase
endfunction : expected_beat_count


`endif // AHB_MONITOR_SV
