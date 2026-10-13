`ifndef AHB_COVERAGE_SV
`define AHB_COVERAGE_SV

// AHB protocol functional coverage collector. It is independent from the
// monitor's sampling logic and subscribes to the monitor's observed stream.
class ahb_coverage extends uvm_subscriber #(ahb_seq_item);

  `uvm_component_utils(ahb_coverage)

  ahb_agent_config agent_cfg;
  ahb_seq_item      sampled_transfer;
  // Remember which HSIZE last initialized each physical SRAM lane. This is
  // coverage-only state; the reference model remains the data oracle.
  ahb_beat_size_e last_write_size [bit [15:0]];
  bit             written_lane [bit [15:0]];
  ahb_beat_size_e sampled_write_size;
  ahb_beat_size_e sampled_read_size;
  bit             sampled_physical_bank;
  bit [1:0]       sampled_lane;
  bit [12:0]      sampled_row;

  covergroup ahb_transfer_cg;
    TRANS_ADDR_REGION : coverpoint sampled_transfer.haddr {
      bins LOW_EDGE    = {32'h0000_0000};
      bins BANK0_LAST  = {[32'h0000_7ffc : 32'h0000_7fff]};
      bins BANK1_FIRST = {[32'h0000_8000 : 32'h0000_8003]};
      bins HIGH_EDGE   = {[32'h0000_fffc : 32'h0000_ffff]};
      bins INTERIOR    = default;
    }
    TRANS_DIRECTION : coverpoint sampled_transfer.direction {
      bins READ  = {READ};
      bins WRITE = {WRITE};
    }
    TRANS_DATA : coverpoint (sampled_transfer.direction == WRITE ?
                             sampled_transfer.hwdata : sampled_transfer.hrdata) {
      bins ZERO     = {32'h0000_0000};
      bins NON_ZERO = {[32'h0000_0001 : 32'hffff_fffe]};
      bins ALL_ONES = {32'hffff_ffff};
    }
    TRANS_SIZE : coverpoint sampled_transfer.access_size {
      bins BYTE     = {BYTE};
      bins HALFWORD = {HALFWORD};
      bins WORD     = {WORD};
    }
    TRANS_TYPE : coverpoint sampled_transfer.transfer_type {
      bins NONSEQ_BIN = {NONSEQ};
      // The collector receives a reassembled transaction. SEQ and BUSY are
      // internal beats of that transaction, not independent transactions.
      ignore_bins INTERNAL_BEATS = {IDLE, BUSY, SEQ};
    }
    TRANS_BURST : coverpoint sampled_transfer.burst_type {
      bins SINGLE_BIN = {SINGLE};
      bins INCR_BIN   = {INCR};
      bins WRAP4_BIN  = {WRAP4};
      bins INCR4_BIN  = {INCR4};
      bins WRAP8_BIN  = {WRAP8};
      bins INCR8_BIN  = {INCR8};
      bins WRAP16_BIN = {WRAP16};
      bins INCR16_BIN = {INCR16};
    }
    TRANS_BEAT_COUNT : coverpoint sampled_transfer.beat_addr_q.size() {
      bins SINGLE_BEAT   = {1};
      bins TWO_TO_THREE  = {[2:3]};
      bins FOUR_BEATS    = {4};
      bins FIVE_TO_SEVEN = {[5:7]};
      bins EIGHT_BEATS   = {8};
      bins NINE_TO_15    = {[9:15]};
      bins SIXTEEN_BEATS = {16};
    }
    TRANS_HAS_BUSY : coverpoint (sampled_transfer.busy_before_beat_q.size() != 0) {
      bins NO_BUSY  = {0};
      bins HAS_BUSY = {1};
    }
    TRANS_BUSY_CYCLES : coverpoint sampled_transfer.busy_before_beat_q.size() {
      bins NONE           = {0};
      bins ONE            = {1};
      bins TWO_TO_THREE   = {[2:3]};
      bins FOUR_OR_MORE   = {[4:$]};
    }
    TRANS_ADDR_X_TRANS_DIRECTION : cross TRANS_ADDR_REGION, TRANS_DIRECTION;
    TRANS_BURST_X_TRANS_DIRECTION : cross TRANS_BURST, TRANS_DIRECTION;
    TRANS_BURST_X_TRANS_SIZE_X_TRANS_DIRECTION :
      cross TRANS_BURST, TRANS_SIZE, TRANS_DIRECTION;
    // A BUSY transfer is represented as an insertion *between* two data beats.
    // Therefore a SINGLE transfer has no legal location for BUSY.  Do not turn
    // this protocol-impossible bin red merely to improve the coverage number.
    TRANS_BURST_X_TRANS_HAS_BUSY : cross TRANS_BURST, TRANS_HAS_BUSY {
      ignore_bins SINGLE_HAS_BUSY =
        binsof(TRANS_BURST.SINGLE_BIN) && binsof(TRANS_HAS_BUSY.HAS_BUSY);
    }
  endgroup

  // This covergroup closes the gap that transaction-level coverage cannot
  // see: an AHB read may observe lanes written by a different HSIZE/address.
  covergroup sram_mapping_cg;
    WRITE_SIZE : coverpoint sampled_write_size {
      bins BYTE_BIN = {BYTE}; bins HALFWORD_BIN = {HALFWORD}; bins WORD_BIN = {WORD};
    }
    READ_SIZE : coverpoint sampled_read_size {
      bins BYTE_BIN = {BYTE}; bins HALFWORD_BIN = {HALFWORD}; bins WORD_BIN = {WORD};
    }
    PHYSICAL_BANK : coverpoint sampled_physical_bank { bins BANK0 = {0}; bins BANK1 = {1}; }
    PHYSICAL_LANE : coverpoint sampled_lane {
      bins LANE0 = {0}; bins LANE1 = {1}; bins LANE2 = {2}; bins LANE3 = {3};
    }
    PHYSICAL_ROW : coverpoint sampled_row {
      bins LOW  = {13'h0000};
      bins HIGH = {13'h1fff};
      bins INTERIOR = default;
    }
    WRITE_SIZE_X_READ_SIZE : cross WRITE_SIZE, READ_SIZE;
    WRITE_SIZE_X_READ_SIZE_X_BANK : cross WRITE_SIZE, READ_SIZE, PHYSICAL_BANK;
  endgroup

  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void write(ahb_seq_item t);
  extern function void report_phase(uvm_phase phase);
  extern function bit physical_bank(bit [31:0] address,
                                    ahb_beat_size_e access_size);
  extern function bit [13:0] physical_word_key(bit [31:0] address,
                                                ahb_beat_size_e access_size);
  extern function bit [3:0] accessed_lane_mask(bit [31:0] address,
                                                ahb_beat_size_e access_size);
  extern function void record_write_mapping(bit [31:0] address,
                                             ahb_beat_size_e access_size);
  extern function void sample_read_mapping(bit [31:0] address,
                                            ahb_beat_size_e access_size);

endclass : ahb_coverage


function ahb_coverage::new(string name, uvm_component parent);
  super.new(name, parent);
  ahb_transfer_cg = new();
  ahb_transfer_cg.set_inst_name({get_full_name(), ".ahb_transfer_cg"});
  sram_mapping_cg = new();
  sram_mapping_cg.set_inst_name({get_full_name(), ".sram_mapping_cg"});
endfunction : new


function void ahb_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(ahb_agent_config)::get(this, "", "agent_cfg", agent_cfg))
    `uvm_warning("NOCONFIG", "Config not set for AHB coverage; sampling is disabled")
endfunction : build_phase


function void ahb_coverage::write(ahb_seq_item t);
  if ((agent_cfg == null) || !agent_cfg.coverage_enable)
    return;

  if (!$cast(sampled_transfer, t.clone())) begin
    `uvm_error("COVCAST", "AHB coverage received a transaction that cannot be cast to ahb_seq_item")
    return;
  end
  ahb_transfer_cg.sample();
  foreach (sampled_transfer.beat_addr_q[beat_index]) begin
    if (sampled_transfer.direction == WRITE)
      record_write_mapping(sampled_transfer.beat_addr_q[beat_index],
                           sampled_transfer.access_size);
    else
      sample_read_mapping(sampled_transfer.beat_addr_q[beat_index],
                          sampled_transfer.access_size);
  end
endfunction : write


function void ahb_coverage::report_phase(uvm_phase phase);
  if ((agent_cfg != null) && agent_cfg.coverage_enable)
    `uvm_info("FCOV",
              $sformatf("AHB functional coverage = %.2f%%; physical SRAM mapping coverage = %.2f%%",
                        ahb_transfer_cg.get_coverage(), sram_mapping_cg.get_coverage()),
              UVM_LOW)
endfunction : report_phase


function bit ahb_coverage::physical_bank(
  bit [31:0] address, ahb_beat_size_e access_size);
  case (access_size)
    BYTE:     return address[15];
    HALFWORD: return address[14];
    default:  return address[13];
  endcase
endfunction : physical_bank


function bit [13:0] ahb_coverage::physical_word_key(
  bit [31:0] address, ahb_beat_size_e access_size);
  return {physical_bank(address, access_size), address[12:0]};
endfunction : physical_word_key


function bit [3:0] ahb_coverage::accessed_lane_mask(
  bit [31:0] address, ahb_beat_size_e access_size);
  case (access_size)
    BYTE: return 4'b0001 << address[14:13];
    HALFWORD: return address[13] ? 4'b1100 : 4'b0011;
    default: return 4'b1111;
  endcase
endfunction : accessed_lane_mask


function void ahb_coverage::record_write_mapping(
  bit [31:0] address, ahb_beat_size_e access_size);
  bit [13:0] word_key;
  bit [3:0] lane_mask;
  bit [15:0] lane_key;

  word_key = physical_word_key(address, access_size);
  lane_mask = accessed_lane_mask(address, access_size);
  foreach (lane_mask[lane_index]) begin
    if (lane_mask[lane_index]) begin
      lane_key = {word_key, lane_index[1:0]};
      written_lane[lane_key] = 1'b1;
      last_write_size[lane_key] = access_size;
    end
  end
endfunction : record_write_mapping


function void ahb_coverage::sample_read_mapping(
  bit [31:0] address, ahb_beat_size_e access_size);
  bit [13:0] word_key;
  bit [3:0] lane_mask;
  bit [15:0] lane_key;

  word_key = physical_word_key(address, access_size);
  lane_mask = accessed_lane_mask(address, access_size);
  foreach (lane_mask[lane_index]) begin
    lane_key = {word_key, lane_index[1:0]};
    if (lane_mask[lane_index] && written_lane.exists(lane_key) && written_lane[lane_key]) begin
      sampled_write_size = last_write_size[lane_key];
      sampled_read_size = access_size;
      sampled_physical_bank = word_key[13];
      sampled_lane = lane_index[1:0];
      sampled_row = word_key[12:0];
      sram_mapping_cg.sample();
    end
  end
endfunction : sample_read_mapping

`endif // AHB_COVERAGE_SV
