`ifndef AHB_SEQ_BURST_SV
`define AHB_SEQ_BURST_SV

// Directed scenario layer. Exercise every burst encoding supported by the
// driver with BYTE/HALFWORD/WORD write-read pairs. One non-SINGLE burst of
// each family contains BUSY cycles so the protocol path is deterministic.
class ahb_seq_burst extends ahb_seq_burst_base;

  `uvm_object_utils(ahb_seq_burst)

  extern function new(string name = "ahb_seq_burst");
  extern task body();

endclass : ahb_seq_burst

function ahb_seq_burst::new(string name = "ahb_seq_burst");
  super.new(name);
endfunction : new

task ahb_seq_burst::body();
  ahb_burst_type_e burst_kinds[] = '{SINGLE, INCR, WRAP4, INCR4,
                                    WRAP8, INCR8, WRAP16, INCR16};
  ahb_beat_size_e access_sizes[] = '{BYTE, HALFWORD, WORD};
  int unsigned incr_beats;
  int unsigned busy_pct;
  bit [31:0] start_addr;
  bit [31:0] data_seed;

  `uvm_info(get_type_name(), "Directed burst scenario starting: all burst types and HSIZE values", UVM_LOW)
  foreach (access_sizes[size_index]) begin
    foreach (burst_kinds[burst_index]) begin
      // Keep every maximum-length word burst inside the 64 KiB controller window.
      start_addr = 32'h0000_1000 + (size_index * 32'h2000) + (burst_index * 32'h100);
      incr_beats = (burst_kinds[burst_index] == INCR) ? 5 : 0;
      // Start WRAP bursts at their final aligned beat so the address sequence
      // must cross the wrap boundary, rather than looking like INCR traffic.
      if ((burst_kinds[burst_index] == WRAP4) ||
          (burst_kinds[burst_index] == WRAP8) ||
          (burst_kinds[burst_index] == WRAP16))
        start_addr += (total_beat_count(burst_kinds[burst_index], 0) - 1) *
                      bytes_per_beat(access_sizes[size_index]);
      // SINGLE has no legal BUSY insertion point. For all other burst forms,
      // force BUSY gaps in the write leg and verify the corresponding read leg.
      busy_pct = (burst_kinds[burst_index] == SINGLE) ? 0 : 100;
      data_seed = 32'hb000_0000 + (size_index << 12) + (burst_index << 4);
      send_transfer(start_addr, burst_kinds[burst_index], WRITE,
                    access_sizes[size_index], data_seed, incr_beats, busy_pct, 1);
      send_transfer(start_addr, burst_kinds[burst_index], READ,
                    access_sizes[size_index], '0, incr_beats, 0, 1);
    end
  end
  `uvm_info(get_type_name(), "Directed burst scenario completed", UVM_LOW)
endtask : body

`endif // AHB_SEQ_BURST_SV
