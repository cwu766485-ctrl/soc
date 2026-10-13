//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_test_base.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Test class for sramc (included in package sramc_test_pkg)
//
//=============================================================================

`ifndef SRAMC_TEST_BASE_SV
`define SRAMC_TEST_BASE_SV

class sramc_test_base extends uvm_test;

  `uvm_component_utils(sramc_test_base)

  sramc_env           m_env;
  sramc_env_config    m_env_config;

  ahb_agent_config  m_ahb_agent_config; 

  extern function new(string name, uvm_component parent=null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);
  extern task          main_phase(uvm_phase phase);

endclass : sramc_test_base


function sramc_test_base::new(string name, uvm_component parent=null);
  super.new(name, parent);
endfunction : new


function void sramc_test_base::build_phase(uvm_phase phase);
  m_env        = sramc_env::type_id::create("m_env", this);
  m_env_config    = sramc_env_config::type_id::create("m_env_config", this);
  m_ahb_agent_config = ahb_agent_config::type_id::create("m_ahb_agent_config", this);

  uvm_config_db#(sramc_env_config)::set(this, "*", "m_env_config", m_env_config);

  // This environment always drives the SRAM controller, so its AHB agent must
  // be active for every random seed. Only transaction fields belong to the
  // constrained-random stimulus space.
  m_ahb_agent_config.is_active       = UVM_ACTIVE;
  m_ahb_agent_config.coverage_enable = 1'b1;
  m_ahb_agent_config.checks_enable   = 1'b1;
  uvm_config_db#(ahb_agent_config)::set(this, "m_env.m_ahb_agent", "agent_cfg", m_ahb_agent_config);

endfunction : build_phase


function void sramc_test_base::connect_phase(uvm_phase phase);

endfunction : connect_phase

function void sramc_test_base::end_of_elaboration_phase(uvm_phase phase);
  if ((m_env.m_ahb_agent.is_active != UVM_ACTIVE) ||
      (m_env.m_ahb_agent.m_sequencer == null) ||
      (m_env.m_ahb_agent.m_driver == null))
    `uvm_fatal("AGENT_MODE",
               "This active SRAMC test requires an active AHB agent with driver and sequencer")

  uvm_top.print_topology();
  `uvm_info(get_type_name(), $sformatf("Verbosity level is set to: %d", get_report_verbosity_level()), UVM_MEDIUM)
  `uvm_info(get_type_name(), "Print all Factory overrides", UVM_MEDIUM)
  factory.print();
endfunction : end_of_elaboration_phase


task sramc_test_base::main_phase(uvm_phase phase);

endtask : main_phase

`endif // SRAMC_TEST_BASE_SV
