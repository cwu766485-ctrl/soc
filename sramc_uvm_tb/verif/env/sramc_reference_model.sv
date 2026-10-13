//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_reference_model.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// refm for sramc
//
//=============================================================================

`ifndef SRAMC_REFERENCE_MODEL_SV
`define SRAMC_REFERENCE_MODEL_SV

class sramc_reference_model extends uvm_component;

  `uvm_component_utils(sramc_reference_model)

  // Observed transfers arrive from the monitor. Each read gets a predicted
  // per-beat data stream which is sent to the scoreboard.
  uvm_analysis_imp #(ahb_seq_item, sramc_reference_model) observed_transfer_export;
  uvm_analysis_port #(ahb_seq_item) expected_read_port;
  // Match the RTL storage organization: two banks, each with 8K rows and
  // four 8-bit lanes per row. The valid mask keeps unread SRAM contents from
  // being treated as a known expected value.
  bit [31:0] physical_memory [bit [13:0]];
  bit [3:0]  valid_lane_mask [bit [13:0]];

  extern function new(string name, uvm_component parent);
  extern function void write(ahb_seq_item observed_transfer);
  extern function void update_expected_memory(ahb_seq_item write_transfer);
  extern function void predict_read_data(ahb_seq_item read_transfer);
  extern function void normalize_single_beat(ahb_seq_item transfer);
  extern function bit physical_bank(bit [31:0] address,
                                    ahb_beat_size_e access_size);
  extern function bit [12:0] physical_row(bit [31:0] address);
  extern function bit [13:0] physical_word_key(bit [31:0] address,
                                                ahb_beat_size_e access_size);
  extern function bit [3:0] accessed_lane_mask(bit [31:0] address,
                                                ahb_beat_size_e access_size);
  extern function void apply_write(bit [31:0] address,
                                   ahb_beat_size_e access_size,
                                   bit [31:0] write_data);
  extern function bit read_is_comparable(bit [31:0] address,
                                         ahb_beat_size_e access_size);
  extern function bit [31:0] read_expected_data(bit [31:0] address,
                                                 ahb_beat_size_e access_size);
endclass : sramc_reference_model


function sramc_reference_model::new(string name, uvm_component parent);
  super.new(name, parent);
  observed_transfer_export = new("observed_transfer_export", this);
  expected_read_port       = new("expected_read_port", this);
endfunction : new


function void sramc_reference_model::write(ahb_seq_item observed_transfer);
  ahb_seq_item transfer_clone;

  if (!$cast(transfer_clone, observed_transfer.clone())) begin
    `uvm_error("REFM_CAST", "Cannot clone observed AHB transfer")
    return;
  end
  normalize_single_beat(transfer_clone);

  if (transfer_clone.direction == WRITE)
    update_expected_memory(transfer_clone);
  else
    predict_read_data(transfer_clone);
endfunction : write


function void sramc_reference_model::normalize_single_beat(ahb_seq_item transfer);
  if (transfer.beat_addr_q.size() == 0) begin
    transfer.beat_addr_q.push_back(transfer.haddr);
    if (transfer.direction == WRITE)
      transfer.beat_data_q.push_back(transfer.hwdata);
    else
      transfer.beat_data_q.push_back(transfer.hrdata);
  end
endfunction : normalize_single_beat


function void sramc_reference_model::update_expected_memory(ahb_seq_item write_transfer);
  foreach (write_transfer.beat_addr_q[beat_index]) begin
    apply_write(write_transfer.beat_addr_q[beat_index], write_transfer.access_size,
                write_transfer.beat_data_q[beat_index]);
    `uvm_info(get_full_name(),
              $sformatf("reference write beat=%0d addr=%h size=%0d bank=%0d row=%h lanes=%b data=%h",
                        beat_index,
                        write_transfer.beat_addr_q[beat_index],
                        write_transfer.access_size,
                        physical_bank(write_transfer.beat_addr_q[beat_index],
                                      write_transfer.access_size),
                        physical_row(write_transfer.beat_addr_q[beat_index]),
                        accessed_lane_mask(write_transfer.beat_addr_q[beat_index],
                                           write_transfer.access_size),
                        write_transfer.beat_data_q[beat_index]),
              UVM_HIGH)
  end
endfunction : update_expected_memory


function void sramc_reference_model::predict_read_data(ahb_seq_item read_transfer);
  ahb_seq_item expected_transfer;
  bit all_beats_comparable;

  expected_transfer = ahb_seq_item::type_id::create("expected_read_transfer");
  expected_transfer.copy(read_transfer);
  expected_transfer.beat_data_q.delete();
  expected_transfer.compare_enabled_q.delete();
  all_beats_comparable = 1'b1;

  foreach (read_transfer.beat_addr_q[beat_index]) begin
    bit compare_enabled;
    compare_enabled = read_is_comparable(read_transfer.beat_addr_q[beat_index],
                                         read_transfer.access_size);
    all_beats_comparable &= compare_enabled;
    expected_transfer.compare_enabled_q.push_back(compare_enabled);
    if (compare_enabled)
      expected_transfer.beat_data_q.push_back(read_expected_data(
        read_transfer.beat_addr_q[beat_index], read_transfer.access_size));
    else begin
      expected_transfer.beat_data_q.push_back('0);
      `uvm_warning(get_full_name(),
                   $sformatf("read beat=%0d addr=%h size=%0d has unwritten SRAM lanes; comparison is skipped",
                             beat_index, read_transfer.beat_addr_q[beat_index],
                             read_transfer.access_size))
    end
  end

  expected_transfer.compare_enabled = all_beats_comparable;
  if (expected_transfer.beat_data_q.size() != 0)
    expected_transfer.hrdata = expected_transfer.beat_data_q[0];

  expected_read_port.write(expected_transfer);
endfunction : predict_read_data


function bit sramc_reference_model::physical_bank(
  bit [31:0] address, ahb_beat_size_e access_size);
  // This is deliberately the same unusual mapping as ahb_slave_if.v.
  case (access_size)
    BYTE:     return address[15];
    HALFWORD: return address[14];
    default:  return address[13];
  endcase
endfunction : physical_bank


function bit [12:0] sramc_reference_model::physical_row(bit [31:0] address);
  return address[12:0];
endfunction : physical_row


function bit [13:0] sramc_reference_model::physical_word_key(
  bit [31:0] address, ahb_beat_size_e access_size);
  return {physical_bank(address, access_size), physical_row(address)};
endfunction : physical_word_key


function bit [3:0] sramc_reference_model::accessed_lane_mask(
  bit [31:0] address, ahb_beat_size_e access_size);
  case (access_size)
    BYTE: begin
      case (address[14:13])
        2'b00: return 4'b0001;
        2'b01: return 4'b0010;
        2'b10: return 4'b0100;
        default: return 4'b1000;
      endcase
    end
    HALFWORD: return address[13] ? 4'b1100 : 4'b0011;
    default:  return 4'b1111;
  endcase
endfunction : accessed_lane_mask


function void sramc_reference_model::apply_write(
  bit [31:0] address, ahb_beat_size_e access_size, bit [31:0] write_data);
  bit [13:0] word_key;
  bit [31:0] word_data;
  bit [3:0] valid_mask;

  word_key = physical_word_key(address, access_size);
  word_data = physical_memory.exists(word_key) ? physical_memory[word_key] : '0;
  valid_mask = valid_lane_mask.exists(word_key) ? valid_lane_mask[word_key] : '0;

  case (access_size)
    BYTE: begin
      case (address[14:13])
        2'b00: word_data[7:0]   = write_data[7:0];
        2'b01: word_data[15:8]  = write_data[7:0];
        2'b10: word_data[23:16] = write_data[7:0];
        default: word_data[31:24] = write_data[7:0];
      endcase
    end
    HALFWORD: begin
      if (address[13])
        word_data[31:16] = write_data[15:0];
      else
        word_data[15:0] = write_data[15:0];
    end
    default: word_data = write_data;
  endcase

  valid_mask |= accessed_lane_mask(address, access_size);
  physical_memory[word_key] = word_data;
  valid_lane_mask[word_key] = valid_mask;
endfunction : apply_write


function bit sramc_reference_model::read_is_comparable(
  bit [31:0] address, ahb_beat_size_e access_size);
  bit [13:0] word_key;
  bit [3:0] required_lanes;

  word_key = physical_word_key(address, access_size);
  required_lanes = accessed_lane_mask(address, access_size);
  return valid_lane_mask.exists(word_key) &&
         ((valid_lane_mask[word_key] & required_lanes) == required_lanes);
endfunction : read_is_comparable


function bit [31:0] sramc_reference_model::read_expected_data(
  bit [31:0] address, ahb_beat_size_e access_size);
  bit [31:0] word_data;
  bit [13:0] word_key;

  word_key = physical_word_key(address, access_size);
  word_data = physical_memory[word_key];
  case (access_size)
    BYTE: begin
      case (address[14:13])
        2'b00: return {24'h0, word_data[7:0]};
        2'b01: return {24'h0, word_data[15:8]};
        2'b10: return {24'h0, word_data[23:16]};
        default: return {24'h0, word_data[31:24]};
      endcase
    end
    HALFWORD: return address[13] ? {16'h0, word_data[31:16]} :
                                    {16'h0, word_data[15:0]};
    default:  return word_data;
  endcase
endfunction : read_expected_data

`endif // SRAMC_REFERENCE_MODEL_SV
