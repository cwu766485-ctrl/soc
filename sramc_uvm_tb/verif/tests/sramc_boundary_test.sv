`ifndef SRAMC_BOUNDARY_TEST_SV
`define SRAMC_BOUNDARY_TEST_SV

class sramc_boundary_test extends sramc_test_base;

  `uvm_component_utils(sramc_boundary_test)

  extern function new(string name, uvm_component parent = null);
  extern task main_phase(uvm_phase phase);

endclass : sramc_boundary_test

function sramc_boundary_test::new(string name, uvm_component parent = null);
  super.new(name, parent);
endfunction : new

task sramc_boundary_test::main_phase(uvm_phase phase);
  ahb_seq_boundary boundary_sequence;
  uvm_objection objection;

  super.main_phase(phase);
  objection = phase.get_objection();
  objection.set_drain_time(this, 50us);
  boundary_sequence = ahb_seq_boundary::type_id::create("boundary_sequence");
  phase.raise_objection(this, "sramc_boundary_test started");
  boundary_sequence.start(m_env.m_ahb_agent.m_sequencer);
  phase.drop_objection(this, "sramc_boundary_test finished");
endtask : main_phase

`endif // SRAMC_BOUNDARY_TEST_SV
