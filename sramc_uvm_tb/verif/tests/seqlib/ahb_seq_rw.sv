`ifndef AHB_SEQ_RW_SV
`define AHB_SEQ_RW_SV

class ahb_seq_rw extends ahb_base_seq;

  `uvm_object_utils(ahb_seq_rw)

  extern function new(string name = "ahb_seq_rw");
  extern task body();
  extern task send_single(bit [31:0] addr, bit [31:0] data,
                          ahb_op_type_e direction);

endclass : ahb_seq_rw


function ahb_seq_rw::new(string name = "ahb_seq_rw");
  super.new(name);
endfunction : new


task ahb_seq_rw::body();
  `uvm_info(get_type_name(), "Default sequence starting", UVM_HIGH)

  for (int i = 0; i < 20; i++) begin
    send_single(i * 4, i, WRITE);
  end

  for (int i = 0; i < 20; i++) begin
    send_single(i * 4, '0, READ);
  end

  send_single(400, 32'hffff_ffff, WRITE);
  send_single(400, '0, READ);

  `uvm_info(get_type_name(), "Default sequence completed", UVM_HIGH)
endtask : body

task ahb_seq_rw::send_single(bit [31:0] addr, bit [31:0] data,
                             ahb_op_type_e direction);
  ahb_seq_single_access single_access;
  single_access = ahb_seq_single_access::type_id::create("single_access");
  single_access.addr = addr;
  single_access.data = data;
  single_access.direction = direction;
  single_access.access_size = WORD;
  single_access.start(m_sequencer, this);
endtask : send_single

`endif // AHB_SEQ_RW_SV
