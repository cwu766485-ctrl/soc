`ifndef AHB_SEQ_SINGLE_ACCESS_SV
`define AHB_SEQ_SINGLE_ACCESS_SV

// Atomic sequence: one legal AHB SINGLE transfer. Scenario sequences compose
// this class instead of duplicating item construction for every read/write.
class ahb_seq_single_access extends ahb_base_seq;

  `uvm_object_utils(ahb_seq_single_access)

  bit [31:0]       addr;
  bit [31:0]       data;
  ahb_op_type_e    direction;
  ahb_beat_size_e  access_size;

  extern function new(string name = "ahb_seq_single_access");
  extern task body();

endclass : ahb_seq_single_access

function ahb_seq_single_access::new(string name = "ahb_seq_single_access");
  super.new(name);
endfunction : new

task ahb_seq_single_access::body();
  req = ahb_seq_item::type_id::create("req");
  start_item(req);
  req.haddr         = addr;
  req.hwdata        = data;
  req.direction     = direction;
  req.access_size   = access_size;
  req.transfer_type = NONSEQ;
  req.burst_type    = SINGLE;
  req.beat_addr_q.delete();
  req.beat_data_q.delete();
  req.response_q.delete();
  req.busy_before_beat_q.delete();
  req.beat_addr_q.push_back(addr);
  req.beat_data_q.push_back(data);
  req.response_q.push_back(OKAY);
  finish_item(req);
endtask : body

`endif // AHB_SEQ_SINGLE_ACCESS_SV
