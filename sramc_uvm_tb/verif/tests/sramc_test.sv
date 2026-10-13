/*
基础AHB读写、全1数据读写
*/
`ifndef SRAMC_TEST_SV
`define SRAMC_TEST_SV

class sramc_test extends sramc_test_base;

  `uvm_component_utils(sramc_test)

  extern function new(string name, uvm_component parent = null);
  extern task main_phase(uvm_phase phase);

endclass : sramc_test


function sramc_test::new(string name, uvm_component parent = null);
  super.new(name, parent);
endfunction : new


task sramc_test::main_phase(uvm_phase phase);
  ahb_seq_rw seq1;
  uvm_objection objection;

  super.main_phase(phase);
  objection = phase.get_objection();
  objection.set_drain_time(this, 3us);

  seq1 = ahb_seq_rw::type_id::create("seq1");
  phase.raise_objection(this, "TEST Started!");
  seq1.start(m_env.m_ahb_agent.m_sequencer);
  phase.drop_objection(this, "TEST Finished!");
endtask : main_phase

`endif // SRAMC_TEST_SV
