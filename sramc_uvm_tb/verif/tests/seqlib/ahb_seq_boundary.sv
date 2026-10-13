`ifndef AHB_SEQ_BOUNDARY_SV
`define AHB_SEQ_BOUNDARY_SV

// Directed boundary plan: every supported HSIZE and HBURST is exercised at
// the lower/upper end of the 64-KiB SRAMC window with deterministic data.
class ahb_seq_boundary extends ahb_seq_burst_base;

  `uvm_object_utils(ahb_seq_boundary)

  extern function new(string name = "ahb_seq_boundary");
  extern task body();
  extern function bit [31:0] boundary_start_address(
    ahb_burst_type_e burst_kind, ahb_beat_size_e access_size,
    int unsigned incr_beat_count);

endclass : ahb_seq_boundary

function ahb_seq_boundary::new(string name = "ahb_seq_boundary");
  super.new(name);
endfunction : new

task ahb_seq_boundary::body();
  ahb_burst_type_e burst_kinds[] = '{SINGLE, INCR, WRAP4, INCR4,
                                    WRAP8, INCR8, WRAP16, INCR16};
  ahb_beat_size_e sizes[] = '{BYTE, HALFWORD, WORD};
  bit [31:0] data_patterns[] = '{32'h0000_0000, 32'hffff_ffff};
  int unsigned incr_beat_count = 5;
  bit [31:0] high_address;

  `uvm_info(get_type_name(), "AHB boundary sequence starting", UVM_LOW)
  foreach (sizes[size_index]) begin
    foreach (burst_kinds[burst_index]) begin
      high_address = boundary_start_address(burst_kinds[burst_index],
                                            sizes[size_index], incr_beat_count);
      foreach (data_patterns[data_index]) begin
        send_transfer(32'h0000_0000, burst_kinds[burst_index], WRITE,
                      sizes[size_index], data_patterns[data_index], incr_beat_count, 0, 1);
        send_transfer(32'h0000_0000, burst_kinds[burst_index], READ,
                      sizes[size_index], '0, incr_beat_count, 0, 1);
        send_transfer(high_address, burst_kinds[burst_index], WRITE,
                      sizes[size_index], data_patterns[data_index], incr_beat_count, 0, 1);
        send_transfer(high_address, burst_kinds[burst_index], READ,
                      sizes[size_index], '0, incr_beat_count, 0, 1);
      end
    end
  end
  `uvm_info(get_type_name(), "AHB boundary sequence completed", UVM_LOW)
endtask : body

function bit [31:0] ahb_seq_boundary::boundary_start_address(
  ahb_burst_type_e burst_kind, ahb_beat_size_e access_size,
  int unsigned incr_beat_count);
  int unsigned beat_bytes;
  int unsigned beat_count;

  beat_bytes = bytes_per_beat(access_size);
  beat_count = total_beat_count(burst_kind, incr_beat_count);
  if ((burst_kind == WRAP4) || (burst_kind == WRAP8) || (burst_kind == WRAP16))
    return 32'h0001_0000 - beat_bytes;
  return 32'h0001_0000 - beat_count * beat_bytes;
endfunction : boundary_start_address

`endif // AHB_SEQ_BOUNDARY_SV
