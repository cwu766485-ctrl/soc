// seqlib 放各种可复用的激励场景 sequence。
`ifndef AHB_SEQ_TESTCASE_SV
`define AHB_SEQ_TESTCASE_SV

class ahb_seq_testcase extends ahb_base_seq;

  `uvm_object_utils(ahb_seq_testcase)

  extern function new(string name = "ahb_seq_testcase");
  extern task body();
  extern task send_transfer(bit [31:0] addr,
                            bit [31:0] data,
                            ahb_op_type_e access_op,
                            ahb_beat_size_e requested_size);
  extern task send_busy_gap(bit [31:0] addr);

endclass : ahb_seq_testcase


function ahb_seq_testcase::new(string name = "ahb_seq_testcase");
  super.new(name);
endfunction : new


task ahb_seq_testcase::body();
  bit [31:0] patterns[4];
  bit [31:0] word_addr[4];
  bit [31:0] byte_addr[4];
  bit [31:0] halfword_addr[4];

  // prepare test data
  patterns[0] = 32'h0101_0101;
  patterns[1] = 32'h1010_1010;
  patterns[2] = 32'h1111_1111;
  patterns[3] = 32'h0000_0000;

  // Cover both SRAM banks and the low/high ends of the 64KB AHB window.
  word_addr[0] = 32'h0000_0000;
  word_addr[1] = 32'h0000_7ffc;
  word_addr[2] = 32'h0000_8000;
  word_addr[3] = 32'h0000_fffc;

  byte_addr[0] = 32'h0000_1fff;
  byte_addr[1] = 32'h0000_2000;
  byte_addr[2] = 32'h0000_dfff;
  byte_addr[3] = 32'h0000_e000;

  halfword_addr[0] = 32'h0000_3ffe;
  halfword_addr[1] = 32'h0000_4000;
  halfword_addr[2] = 32'h0000_bffe;
  halfword_addr[3] = 32'h0000_c000;

  `uvm_info(get_type_name(), "Testcase sequence starting", UVM_LOW)

  // Read each access back immediately. This RTL uses address high bits for
  // bank/lane selection, so accesses of different widths can physically alias.
  foreach (patterns[i]) begin
    send_transfer(word_addr[i], patterns[i], WRITE, WORD);
    send_busy_gap(word_addr[i]);
    send_transfer(word_addr[i], patterns[i], READ, WORD);

    send_transfer(byte_addr[i], patterns[i], WRITE, BYTE);
    send_transfer(byte_addr[i], patterns[i], READ, BYTE);

    send_transfer(halfword_addr[i], patterns[i], WRITE, HALFWORD);
    send_transfer(halfword_addr[i], patterns[i], READ, HALFWORD);
  end

  `uvm_info(get_type_name(), "Testcase sequence completed", UVM_LOW)
endtask : body


task ahb_seq_testcase::send_transfer(bit [31:0] addr,
                                     bit [31:0] data,
                                     ahb_op_type_e access_op,
                                     ahb_beat_size_e requested_size);
  req = ahb_seq_item::type_id::create($sformatf("req_%08h", addr));
  start_item(req); // 向 sequencer 申请发送这个 transaction 的权限
  if (!req.randomize() with {
    haddr  == addr;
    hwdata == data;
    transfer_type == NONSEQ;
    direction     == access_op;
    access_size   == requested_size;
    burst_type    == SINGLE;
  })
    `uvm_error(get_type_name(), "Failed to randomize testcase transaction")
  finish_item(req); // 把准备好的 transaction 交给 sequencer/driver
endtask : send_transfer


task ahb_seq_testcase::send_busy_gap(bit [31:0] addr);
  req = ahb_seq_item::type_id::create($sformatf("busy_%08h", addr));
  req.c_default_transfer.constraint_mode(0); // Disable the default constraints for this transaction; constraint_mode(1) enables constraints
  start_item(req);
  if (!req.randomize() with {
    haddr  == addr;
    transfer_type == BUSY;
    direction     == READ;
    access_size   == WORD;
    burst_type    == SINGLE;
  })
    `uvm_error(get_type_name(), "Failed to randomize BUSY transaction")
  finish_item(req);
endtask : send_busy_gap

`endif // AHB_SEQ_TESTCASE_SV
