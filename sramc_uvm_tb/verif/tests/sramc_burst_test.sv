`ifndef SRAMC_BURST_TEST_SV
`define SRAMC_BURST_TEST_SV

class sramc_burst_test extends sramc_test_base;

  `uvm_component_utils(sramc_burst_test)

  extern function new(string name, uvm_component parent = null);
  extern task main_phase(uvm_phase phase);

endclass : sramc_burst_test


function sramc_burst_test::new(string name, uvm_component parent = null);
  super.new(name, parent);
endfunction : new


task sramc_burst_test::main_phase(uvm_phase phase);
  ahb_seq_burst burst_sequence;
  uvm_objection objection;

  super.main_phase(phase);
  objection = phase.get_objection();
  objection.set_drain_time(this, 10us);

  burst_sequence = ahb_seq_burst::type_id::create("burst_sequence");
  phase.raise_objection(this, "sramc_burst_test started");
  burst_sequence.start(m_env.m_ahb_agent.m_sequencer);
  phase.drop_objection(this, "sramc_burst_test finished");
endtask : main_phase

`endif // SRAMC_BURST_TEST_SV
