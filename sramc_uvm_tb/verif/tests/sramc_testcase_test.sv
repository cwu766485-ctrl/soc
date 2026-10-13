/*
BYTE/HALFWORD/WORD、双 SRAM bank、窗口边缘、BUSY
*/
`ifndef SRAMC_TESTCASE_TEST_SV
`define SRAMC_TESTCASE_TEST_SV

class sramc_testcase_test extends sramc_test_base;

  `uvm_component_utils(sramc_testcase_test)

  extern function new(string name, uvm_component parent = null);
  extern task main_phase(uvm_phase phase);

endclass : sramc_testcase_test


function sramc_testcase_test::new(string name, uvm_component parent = null);
  super.new(name, parent);
endfunction : new


task sramc_testcase_test::main_phase(uvm_phase phase);
  ahb_seq_testcase seq;
  uvm_objection objection;

  super.main_phase(phase);
  objection = phase.get_objection();
  objection.set_drain_time(this, 5us);

  seq = ahb_seq_testcase::type_id::create("seq");
  phase.raise_objection(this, "sramc_testcase_test started");
  seq.start(m_env.m_ahb_agent.m_sequencer);
  phase.drop_objection(this, "sramc_testcase_test finished");
endtask : main_phase

`endif // SRAMC_TESTCASE_TEST_SV
