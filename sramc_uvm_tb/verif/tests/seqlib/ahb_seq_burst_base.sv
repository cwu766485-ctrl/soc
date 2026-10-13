`ifndef AHB_SEQ_BURST_BASE_SV
`define AHB_SEQ_BURST_BASE_SV

// Atomic sequence layer: shared legal-AHB burst builder. Scenario sequences
// choose a bounded number of beats for INCR; the bus terminates that otherwise
// undefined-length burst by driving IDLE after the final generated SEQ beat.
class ahb_seq_burst_base extends ahb_base_seq;

  `uvm_object_utils(ahb_seq_burst_base)

  extern function new(string name = "ahb_seq_burst_base");
  extern task send_transfer(bit [31:0] start_addr,
                            ahb_burst_type_e burst_kind,
                            ahb_op_type_e access_direction,
                            ahb_beat_size_e access_size,
                            bit [31:0] data_seed,
                            int unsigned incr_beat_count,
                            int unsigned busy_probability_pct = 20,
                            int unsigned max_busy_cycles = 3);
  extern function int unsigned bytes_per_beat(ahb_beat_size_e access_size);
  extern function int unsigned fixed_beat_count(ahb_burst_type_e burst_kind);
  extern function int unsigned total_beat_count(ahb_burst_type_e burst_kind,
                                                 int unsigned incr_beat_count);
  extern function bit [31:0] beat_address(bit [31:0] start_addr,
                                          ahb_burst_type_e burst_kind,
                                          ahb_beat_size_e access_size,
                                          int unsigned beat_index);
  extern task add_random_busy_gaps(ahb_seq_item transfer,
                                   int unsigned beat_count,
                                   int unsigned busy_probability_pct,
                                   int unsigned max_busy_cycles);

endclass : ahb_seq_burst_base

function ahb_seq_burst_base::new(string name = "ahb_seq_burst_base");
  super.new(name);
endfunction : new

task ahb_seq_burst_base::send_transfer(bit [31:0] start_addr,
                                       ahb_burst_type_e burst_kind,
                                       ahb_op_type_e access_direction,
                                       ahb_beat_size_e access_size,
                                       bit [31:0] data_seed,
                                       int unsigned incr_beat_count,
                                       int unsigned busy_probability_pct = 20,
                                       int unsigned max_busy_cycles = 3);
  int unsigned beat_count;

  beat_count = total_beat_count(burst_kind, incr_beat_count);
  if (beat_count == 0)
    `uvm_fatal("BURST_LENGTH", $sformatf("Invalid burst=%0d INCR beat count=%0d",
                                          burst_kind, incr_beat_count))

  req = ahb_seq_item::type_id::create($sformatf("%s_%0d_%0d_%08h",
                                                 (access_direction == WRITE) ? "write" : "read",
                                                 burst_kind, access_size, start_addr));
  start_item(req);
  req.haddr         = start_addr;
  req.hwdata        = data_seed;
  req.direction     = access_direction;
  req.access_size   = access_size;
  req.transfer_type = NONSEQ;
  req.burst_type    = burst_kind;
  req.beat_addr_q.delete();
  req.beat_data_q.delete();
  req.response_q.delete();
  req.busy_before_beat_q.delete();
  for (int unsigned beat_index = 0; beat_index < beat_count; beat_index++) begin
    req.beat_addr_q.push_back(beat_address(start_addr, burst_kind, access_size, beat_index));
    req.beat_data_q.push_back((access_direction == WRITE) ? (data_seed + beat_index) : '0);
    req.response_q.push_back(OKAY);
  end
  add_random_busy_gaps(req, beat_count, busy_probability_pct, max_busy_cycles);
  finish_item(req);
endtask : send_transfer

function int unsigned ahb_seq_burst_base::bytes_per_beat(ahb_beat_size_e access_size);
  case (access_size)
    BYTE:     return 1;
    HALFWORD: return 2;
    WORD:     return 4;
    default:  return 0;
  endcase
endfunction : bytes_per_beat

function int unsigned ahb_seq_burst_base::fixed_beat_count(ahb_burst_type_e burst_kind);
  case (burst_kind)
    SINGLE:         return 1;
    WRAP4, INCR4:   return 4;
    WRAP8, INCR8:   return 8;
    WRAP16, INCR16: return 16;
    default:        return 0;
  endcase
endfunction : fixed_beat_count

function int unsigned ahb_seq_burst_base::total_beat_count(
  ahb_burst_type_e burst_kind, int unsigned incr_beat_count);
  if (burst_kind == INCR)
    return incr_beat_count;
  return fixed_beat_count(burst_kind);
endfunction : total_beat_count

function bit [31:0] ahb_seq_burst_base::beat_address(
  bit [31:0] start_addr, ahb_burst_type_e burst_kind,
  ahb_beat_size_e access_size, int unsigned beat_index);
  bit [31:0] wrap_mask;
  int unsigned wrap_bytes;
  int unsigned beat_bytes;
  int unsigned fixed_beats;

  beat_bytes = bytes_per_beat(access_size);
  fixed_beats = fixed_beat_count(burst_kind);
  case (burst_kind)
    WRAP4, WRAP8, WRAP16: begin
      wrap_bytes = fixed_beats * beat_bytes;
      wrap_mask = wrap_bytes - 1;
      return (start_addr & ~wrap_mask) |
             ((start_addr + beat_index * beat_bytes) & wrap_mask);
    end
    default: return start_addr + beat_index * beat_bytes;
  endcase
endfunction : beat_address

task ahb_seq_burst_base::add_random_busy_gaps(
  ahb_seq_item transfer, int unsigned beat_count,
  int unsigned busy_probability_pct, int unsigned max_busy_cycles);
  int unsigned busy_cycles;

  // BUSY is only legal between valid beats: never before the initial NONSEQ
  // and never after the final beat. Duplicate indices encode a multi-cycle gap.
  for (int unsigned beat_index = 1; beat_index < beat_count; beat_index++) begin
    if ((busy_probability_pct != 0) && ($urandom_range(99) < busy_probability_pct)) begin
      busy_cycles = $urandom_range(max_busy_cycles, 1);
      repeat (busy_cycles)
        transfer.busy_before_beat_q.push_back(beat_index);
    end
  end
endtask : add_random_busy_gaps

`endif // AHB_SEQ_BURST_BASE_SV
