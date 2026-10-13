`ifndef AHB_SEQ_RANDOM_SV
`define AHB_SEQ_RANDOM_SV

class ahb_seq_random extends ahb_base_seq;

  `uvm_object_utils(ahb_seq_random)

  int unsigned num_pairs = 32;

  extern function new(string name = "ahb_seq_random");
  extern task body();
  extern task send_write_read_pair(int unsigned index);

endclass : ahb_seq_random


function ahb_seq_random::new(string name = "ahb_seq_random");
  super.new(name);
endfunction : new


task ahb_seq_random::body();
  `uvm_info(get_type_name(),
            $sformatf("Random single-beat write/read sequence starting: pairs=%0d", num_pairs),
            UVM_LOW)

  for (int unsigned i = 0; i < num_pairs; i++)
    send_write_read_pair(i);

  `uvm_info(get_type_name(), "Random single-beat write/read sequence completed", UVM_LOW)
endtask : body


task ahb_seq_random::send_write_read_pair(int unsigned index);
  bit [31:0] addr;
  bit [31:0] data;

  req = ahb_seq_item::type_id::create($sformatf("write_%0d", index));
  start_item(req);
  if (!req.randomize() with {
    haddr inside {[32'h0000_0000 : 32'h0000_fffc]};
    haddr[1:0] == 2'b00;
    transfer_type == NONSEQ;
    direction == WRITE;
    access_size == WORD;
    burst_type == SINGLE;
  })
    `uvm_error(get_type_name(), "Failed to randomize write transaction")
  addr = req.haddr;
  data = req.hwdata;
  finish_item(req);

  req = ahb_seq_item::type_id::create($sformatf("read_%0d", index));
  start_item(req);
  if (!req.randomize() with {
    haddr == addr;
    transfer_type == NONSEQ;
    direction == READ;
    access_size == WORD;
    burst_type == SINGLE;
  })
    `uvm_error(get_type_name(), "Failed to randomize read transaction")
  finish_item(req);

  `uvm_info(get_type_name(),
            $sformatf("random pair=%0d addr=%h data=%h", index, addr, data),
            UVM_HIGH)
endtask : send_write_read_pair

`endif // AHB_SEQ_RANDOM_SV
