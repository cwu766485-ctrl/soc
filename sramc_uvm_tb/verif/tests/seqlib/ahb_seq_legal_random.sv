`ifndef AHB_SEQ_LEGAL_RANDOM_SV
`define AHB_SEQ_LEGAL_RANDOM_SV

// Stateful constrained-random regression. Legal write bursts build a history
// of initialized physical SRAM lanes; later reads choose independently from
// that history, including a different HSIZE whenever the required lanes are
// known. The reference model remains the checker of record.
class ahb_seq_legal_random extends ahb_seq_burst_base;

  `uvm_object_utils(ahb_seq_legal_random)

  int unsigned num_writes = 64;
  int unsigned cross_size_reads_per_write = 2;
  int unsigned probe_reads_per_write = 1;
  int unsigned busy_probability_pct = 20;
  int unsigned max_busy_cycles = 3;
  int unsigned max_incr_beats = 16;

  // Sequence-local state only selects meaningful reads. It deliberately does
  // not predict data; sramc_reference_model remains the functional oracle.
  bit [3:0]  known_lane_mask [bit [13:0]];
  bit [13:0] known_word_key_q[$];
  bit [31:0] write_start_addr_q[$];
  ahb_burst_type_e write_burst_q[$];
  ahb_beat_size_e  write_size_q[$];
  int unsigned     write_incr_beats_q[$];

  extern function new(string name = "ahb_seq_legal_random");
  extern task body();
  extern task send_directed_bank1_cross_size_reads();
  extern task send_random_write(int unsigned write_index);
  extern task send_random_history_burst_read();
  extern task send_random_cross_size_read();
  extern task send_random_probe_read();
  extern task choose_legal_start_address(ahb_burst_type_e burst_kind,
                                         ahb_beat_size_e access_size,
                                         int unsigned incr_beat_count,
                                         output bit [31:0] start_addr);
  extern function bit physical_bank(bit [31:0] address,
                                    ahb_beat_size_e access_size);
  extern function bit [13:0] physical_word_key(bit [31:0] address,
                                                ahb_beat_size_e access_size);
  extern function bit [3:0] accessed_lane_mask(bit [31:0] address,
                                                ahb_beat_size_e access_size);
  extern function bit [31:0] address_for_physical_read(bit [13:0] word_key,
                                                        ahb_beat_size_e access_size,
                                                        int unsigned byte_lane);
  extern function void record_written_beat(bit [31:0] address,
                                           ahb_beat_size_e access_size);
  extern task configure_from_plusargs();

endclass : ahb_seq_legal_random

function ahb_seq_legal_random::new(string name = "ahb_seq_legal_random");
  super.new(name);
endfunction : new

task ahb_seq_legal_random::body();
  configure_from_plusargs();
  `uvm_info(get_type_name(),
            $sformatf("Stateful legal random: writes=%0d cross_reads/write=%0d probe_reads/write=%0d busy=%0d%% INCR_max=%0d",
                      num_writes, cross_size_reads_per_write, probe_reads_per_write,
                      busy_probability_pct, max_incr_beats), UVM_LOW)
  // Close the bank-1 partial-write/read crosses deterministically. These
  // addresses alias the same physical row under the documented size-specific
  // bank mapping; the normal reference model and scoreboard check every beat.
  send_directed_bank1_cross_size_reads();
  for (int unsigned write_index = 0; write_index < num_writes; write_index++) begin
    send_random_write(write_index);
    send_random_history_burst_read();
    repeat (cross_size_reads_per_write)
      send_random_cross_size_read();
    repeat (probe_reads_per_write)
      send_random_probe_read();
  end
  `uvm_info(get_type_name(), "Stateful legal random sequence completed", UVM_LOW)
endtask : body

task ahb_seq_legal_random::send_directed_bank1_cross_size_reads();
  bit [31:0] byte_addr;
  bit [31:0] halfword_addr;
  bit [31:0] word_addr;
  bit [12:0] row;

  row = 13'h1234;
  word_addr = {16'h0000, 2'b00, 1'b1, row};

  // Four BYTE writes initialize every lane in physical bank 1. Follow with
  // WORD and both HALFWORD reads to hit BYTE->WORD/HALFWORD cross bins.
  for (int unsigned lane = 0; lane < 4; lane++) begin
    byte_addr = {16'h0000, 1'b1, lane[1:0], row};
    send_transfer(byte_addr, SINGLE, WRITE, BYTE,
                  32'h1020_3040 ^ (32'h0101_0101 * lane), 0, 0, 1);
  end
  send_transfer(word_addr, SINGLE, READ, WORD, '0, 0, 0, 1);
  halfword_addr = {16'h0000, 1'b0, 1'b1, 1'b0, row};
  send_transfer(halfword_addr, SINGLE, READ, HALFWORD, '0, 0, 0, 1);
  halfword_addr = {16'h0000, 1'b0, 1'b1, 1'b1, row};
  send_transfer(halfword_addr, SINGLE, READ, HALFWORD, '0, 0, 0, 1);

  // Repeat the byte-write aliases in physical bank 0. This explicitly closes
  // BYTE->HALFWORD/WORD coverage for both values of the size-dependent bank bit.
  for (int unsigned lane = 0; lane < 4; lane++) begin
    byte_addr = {16'h0000, 1'b0, lane[1:0], row};
    send_transfer(byte_addr, SINGLE, WRITE, BYTE,
                  32'h5566_7788 ^ (32'h0101_0101 * lane), 0, 0, 1);
  end
  word_addr = {16'h0000, 2'b00, 1'b0, row};
  send_transfer(word_addr, SINGLE, READ, WORD, '0, 0, 0, 1);
  halfword_addr = {16'h0000, 1'b0, 1'b0, 1'b0, row};
  send_transfer(halfword_addr, SINGLE, READ, HALFWORD, '0, 0, 0, 1);
  halfword_addr = {16'h0000, 1'b0, 1'b0, 1'b1, row};
  send_transfer(halfword_addr, SINGLE, READ, HALFWORD, '0, 0, 0, 1);

  // Two HALFWORD writes initialize the same physical bank-1 word, then a
  // WORD read closes the remaining HALFWORD->WORD bank-1 cross.
  halfword_addr = {16'h0000, 1'b0, 1'b1, 1'b0, row};
  send_transfer(halfword_addr, SINGLE, WRITE, HALFWORD, 32'h89ab_cdef, 0, 0, 1);
  halfword_addr = {16'h0000, 1'b0, 1'b1, 1'b1, row};
  send_transfer(halfword_addr, SINGLE, WRITE, HALFWORD, 32'h7654_3210, 0, 0, 1);
  word_addr = {16'h0000, 2'b00, 1'b1, row};
  send_transfer(word_addr, SINGLE, READ, WORD, '0, 0, 0, 1);
endtask : send_directed_bank1_cross_size_reads

task ahb_seq_legal_random::send_random_write(int unsigned write_index);
  bit [31:0] start_addr;
  bit [31:0] data_seed;
  bit [13:0] reuse_word_key;
  bit [3:0] reuse_lane_mask;
  int unsigned reuse_lane;
  bit reuse_known_word;
  ahb_burst_type_e burst_kind;
  ahb_beat_size_e access_size;
  int unsigned incr_beat_count;
  int unsigned beat_count;

  if (!std::randomize(data_seed, burst_kind, access_size, incr_beat_count) with {
        burst_kind inside {SINGLE, INCR, WRAP4, INCR4,
                           WRAP8, INCR8, WRAP16, INCR16};
        access_size inside {BYTE, HALFWORD, WORD};
        incr_beat_count inside {[2:max_incr_beats]};
      })
    `uvm_fatal(get_type_name(), "Failed to randomize write burst parameters")

  // Periodically overlay a known physical word with a smaller access. This is
  // still randomized traffic, but it makes meaningful BYTE/HALFWORD-to-WORD
  // interactions reachable without relying on a one-in-8192 address collision.
  reuse_known_word = (known_word_key_q.size() != 0) && ($urandom_range(99) < 35);
  if (reuse_known_word) begin
    reuse_word_key = known_word_key_q[$urandom_range(known_word_key_q.size() - 1)];
    reuse_lane_mask = known_lane_mask[reuse_word_key];
    burst_kind = SINGLE;
    incr_beat_count = 0;
    if ((reuse_lane_mask == 4'b1111) && !reuse_word_key[0] && $urandom_range(1)) begin
      access_size = HALFWORD;
      reuse_lane = $urandom_range(1) ? 2 : 0;
    end
    else begin
      access_size = BYTE;
      reuse_lane = $urandom_range(3);
    end
    start_addr = address_for_physical_read(reuse_word_key, access_size, reuse_lane);
  end
  else
    choose_legal_start_address(burst_kind, access_size, incr_beat_count, start_addr);
  beat_count = total_beat_count(burst_kind, incr_beat_count);
  send_transfer(start_addr, burst_kind, WRITE, access_size, data_seed,
                incr_beat_count, busy_probability_pct, max_busy_cycles);

  for (int unsigned beat_index = 0; beat_index < beat_count; beat_index++)
    record_written_beat(beat_address(start_addr, burst_kind, access_size, beat_index),
                        access_size);
  write_start_addr_q.push_back(start_addr);
  write_burst_q.push_back(burst_kind);
  write_size_q.push_back(access_size);
  write_incr_beats_q.push_back(incr_beat_count);
  `uvm_info(get_type_name(),
            $sformatf("random write=%0d start=%h burst=%0d size=%0d beats=%0d seed=%h",
                      write_index, start_addr, burst_kind, access_size,
                      beat_count, data_seed), UVM_HIGH)
endtask : send_random_write

task ahb_seq_legal_random::send_random_history_burst_read();
  int unsigned history_index;

  if (write_start_addr_q.size() == 0)
    return;
  history_index = $urandom_range(write_start_addr_q.size() - 1);
  // Preserve a previously generated burst's geometry so every beat is known,
  // while choosing a random historical burst rather than only the last write.
  send_transfer(write_start_addr_q[history_index], write_burst_q[history_index],
                READ, write_size_q[history_index], '0,
                write_incr_beats_q[history_index], busy_probability_pct,
                max_busy_cycles);
endtask : send_random_history_burst_read

task ahb_seq_legal_random::send_random_cross_size_read();
  bit [13:0] word_key;
  bit [3:0] lane_mask;
  bit bank;
  bit [12:0] row;
  int unsigned byte_lanes[$];
  ahb_beat_size_e eligible_sizes[$];
  ahb_beat_size_e read_size;
  int unsigned byte_lane;
  bit [31:0] read_addr;

  if (known_word_key_q.size() == 0)
    return;
  word_key = known_word_key_q[$urandom_range(known_word_key_q.size() - 1)];
  lane_mask = known_lane_mask[word_key];
  bank = word_key[13];
  row = word_key[12:0];

  foreach (lane_mask[lane_index])
    if (lane_mask[lane_index])
      byte_lanes.push_back(lane_index);
  eligible_sizes.push_back(BYTE);
  if ((row[0] == 1'b0) &&
      (((lane_mask & 4'b0011) == 4'b0011) ||
       ((lane_mask & 4'b1100) == 4'b1100)))
    eligible_sizes.push_back(HALFWORD);
  if ((row[1:0] == 2'b00) && (lane_mask == 4'b1111))
    eligible_sizes.push_back(WORD);

  read_size = eligible_sizes[$urandom_range(eligible_sizes.size() - 1)];
  byte_lane = byte_lanes[$urandom_range(byte_lanes.size() - 1)];
  if (read_size == HALFWORD) begin
    if ((lane_mask & 4'b0011) == 4'b0011 &&
        ((lane_mask & 4'b1100) != 4'b1100 || $urandom_range(1) == 0))
      byte_lane = 0;
    else
      byte_lane = 2;
  end
  else if (read_size == WORD)
    byte_lane = 0;

  read_addr = address_for_physical_read(word_key, read_size, byte_lane);
  send_transfer(read_addr, SINGLE, READ, read_size, '0, 0, 0, 1);
  `uvm_info(get_type_name(),
            $sformatf("cross-size read bank=%0d row=%h lanes=%b size=%0d addr=%h",
                      bank, row, lane_mask, read_size, read_addr), UVM_HIGH)
endtask : send_random_cross_size_read

task ahb_seq_legal_random::send_random_probe_read();
  bit [31:0] start_addr;
  ahb_burst_type_e burst_kind;
  ahb_beat_size_e access_size;
  int unsigned incr_beat_count;

  // This is intentionally unconstrained by write history. The refm compares
  // any initialized lanes and marks untouched SRAM lanes as not comparable.
  if (!std::randomize(burst_kind, access_size, incr_beat_count) with {
        burst_kind inside {SINGLE, INCR, WRAP4, INCR4,
                           WRAP8, INCR8, WRAP16, INCR16};
        access_size inside {BYTE, HALFWORD, WORD};
        incr_beat_count inside {[2:max_incr_beats]};
      })
    `uvm_fatal(get_type_name(), "Failed to randomize probe read parameters")
  choose_legal_start_address(burst_kind, access_size, incr_beat_count, start_addr);
  send_transfer(start_addr, burst_kind, READ, access_size, '0,
                incr_beat_count, busy_probability_pct, max_busy_cycles);
endtask : send_random_probe_read

task ahb_seq_legal_random::choose_legal_start_address(
  ahb_burst_type_e burst_kind, ahb_beat_size_e access_size,
  int unsigned incr_beat_count, output bit [31:0] start_addr);
  int unsigned beat_count;
  int unsigned beat_bytes;

  beat_count = total_beat_count(burst_kind, incr_beat_count);
  beat_bytes = bytes_per_beat(access_size);
  if (!std::randomize(start_addr) with {
        start_addr inside {[32'h0000_0000:32'h0000_ffff]};
        (access_size == HALFWORD) -> (start_addr[0] == 1'b0);
        (access_size == WORD) -> (start_addr[1:0] == 2'b00);
        ((burst_kind == SINGLE) || (burst_kind == WRAP4) ||
         (burst_kind == WRAP8) || (burst_kind == WRAP16)) ||
          (start_addr <= (32'h0001_0000 - beat_count * beat_bytes));
      })
    `uvm_fatal(get_type_name(), "Failed to randomize a legal write start address")
endtask : choose_legal_start_address

function bit ahb_seq_legal_random::physical_bank(
  bit [31:0] address, ahb_beat_size_e access_size);
  case (access_size)
    BYTE:     return address[15];
    HALFWORD: return address[14];
    default:  return address[13];
  endcase
endfunction : physical_bank

function bit [13:0] ahb_seq_legal_random::physical_word_key(
  bit [31:0] address, ahb_beat_size_e access_size);
  return {physical_bank(address, access_size), address[12:0]};
endfunction : physical_word_key

function bit [3:0] ahb_seq_legal_random::accessed_lane_mask(
  bit [31:0] address, ahb_beat_size_e access_size);
  case (access_size)
    BYTE: return 4'b0001 << address[14:13];
    HALFWORD: return address[13] ? 4'b1100 : 4'b0011;
    default: return 4'b1111;
  endcase
endfunction : accessed_lane_mask

function bit [31:0] ahb_seq_legal_random::address_for_physical_read(
  bit [13:0] word_key, ahb_beat_size_e access_size, int unsigned byte_lane);
  bit bank;
  bit [12:0] row;

  bank = word_key[13];
  row = word_key[12:0];
  case (access_size)
    BYTE: return {16'h0000, bank, byte_lane[1:0], row};
    HALFWORD: return {16'h0000, 1'b0, bank, byte_lane[1], row};
    default: return {16'h0000, 2'b00, bank, row};
  endcase
endfunction : address_for_physical_read

function void ahb_seq_legal_random::record_written_beat(
  bit [31:0] address, ahb_beat_size_e access_size);
  bit [13:0] word_key;

  word_key = physical_word_key(address, access_size);
  if (!known_lane_mask.exists(word_key)) begin
    known_lane_mask[word_key] = '0;
    known_word_key_q.push_back(word_key);
  end
  known_lane_mask[word_key] |= accessed_lane_mask(address, access_size);
endfunction : record_written_beat

task ahb_seq_legal_random::configure_from_plusargs();
  // LEGAL_RANDOM_PAIRS is retained for compatibility with existing scripts.
  void'($value$plusargs("LEGAL_RANDOM_PAIRS=%d", num_writes));
  void'($value$plusargs("CROSS_SIZE_READS=%d", cross_size_reads_per_write));
  void'($value$plusargs("PROBE_READS=%d", probe_reads_per_write));
  void'($value$plusargs("BUSY_PCT=%d", busy_probability_pct));
  void'($value$plusargs("MAX_BUSY_CYCLES=%d", max_busy_cycles));
  void'($value$plusargs("INCR_MAX_BEATS=%d", max_incr_beats));
  if ((cross_size_reads_per_write == 0) || (probe_reads_per_write == 0) ||
      (busy_probability_pct > 100) ||
      (max_busy_cycles == 0) || (max_incr_beats < 2))
    `uvm_fatal(get_type_name(), "Invalid legal-random plusarg configuration")
endtask : configure_from_plusargs

`endif // AHB_SEQ_LEGAL_RANDOM_SV
