`ifndef SRAMC_LEGAL_RANDOM_TEST_SV
`define SRAMC_LEGAL_RANDOM_TEST_SV

class sramc_legal_random_test extends sramc_test_base;

  `uvm_component_utils(sramc_legal_random_test)

  extern function new(string name, uvm_component parent = null);
  extern task main_phase(uvm_phase phase);

endclass : sramc_legal_random_test


function sramc_legal_random_test::new(string name, uvm_component parent = null);
  super.new(name, parent);
endfunction : new


task sramc_legal_random_test::main_phase(uvm_phase phase);
  ahb_seq_legal_random legal_random_sequence;
  uvm_objection objection;

  super.main_phase(phase);
  objection = phase.get_objection();
  objection.set_drain_time(this, 20us);

  legal_random_sequence = ahb_seq_legal_random::type_id::create("legal_random_sequence");
  phase.raise_objection(this, "sramc_legal_random_test started");
  legal_random_sequence.start(m_env.m_ahb_agent.m_sequencer);
  phase.drop_objection(this, "sramc_legal_random_test finished");
endtask : main_phase

`endif // SRAMC_LEGAL_RANDOM_TEST_SV
