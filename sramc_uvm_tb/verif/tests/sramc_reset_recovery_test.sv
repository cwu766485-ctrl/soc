`ifndef SRAMC_RESET_RECOVERY_TEST_SV
`define SRAMC_RESET_RECOVERY_TEST_SV

// This is a recovery test, not a memory-retention test: it proves that the
// normal AHB write/read path works before reset and can start working again
// after reset is released.  The second sequence rewrites every location it
// reads, so the test makes no unverified assumption about SRAM reset contents.
class sramc_reset_recovery_test extends sramc_test_base;

  `uvm_component_utils(sramc_reset_recovery_test)

  virtual sramc_reset_if reset_vif;

  extern function new(string name, uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task main_phase(uvm_phase phase);

endclass : sramc_reset_recovery_test

function sramc_reset_recovery_test::new(string name,
                                        uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void sramc_reset_recovery_test::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(virtual sramc_reset_if)::get(this, "", "reset_vif", reset_vif))
    `uvm_fatal("NORESETVIF", "reset_vif was not configured by sramc_tb")
endfunction : build_phase

task sramc_reset_recovery_test::main_phase(uvm_phase phase);
  ahb_seq_rw pre_reset_sequence;
  ahb_seq_rw post_reset_sequence;
  uvm_objection objection;

  super.main_phase(phase);
  objection = phase.get_objection();
  objection.set_drain_time(this, 5us);

  pre_reset_sequence  = ahb_seq_rw::type_id::create("pre_reset_sequence");
  post_reset_sequence = ahb_seq_rw::type_id::create("post_reset_sequence");

  phase.raise_objection(this, "reset recovery test started");
  pre_reset_sequence.start(m_env.m_ahb_agent.m_sequencer);

  // Wait until the driver's final data phase has passed the monitor before
  // clearing monitor state with reset.  No transaction is in flight here.
  repeat (4) @(posedge reset_vif.hclk);
  `uvm_info(get_type_name(), "Asserting mid-test reset for two AHB cycles", UVM_LOW)
  reset_vif.pulse_reset(2);
  repeat (2) @(posedge reset_vif.hclk);

  `uvm_info(get_type_name(), "Reset released; starting post-reset write/read recovery", UVM_LOW)
  post_reset_sequence.start(m_env.m_ahb_agent.m_sequencer);
  phase.drop_objection(this, "reset recovery test finished");
endtask : main_phase

`endif // SRAMC_RESET_RECOVERY_TEST_SV
