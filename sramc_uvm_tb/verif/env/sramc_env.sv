//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_env.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Environment for sramc
//
//=============================================================================

`ifndef SRAMC_ENV_SV
`define SRAMC_ENV_SV

class sramc_env extends uvm_env;

  `uvm_component_utils(sramc_env)

  ahb_agent             m_ahb_agent;
  sramc_reference_model m_reference_model;
  sramc_scoreboard      m_scoreboard;
  sramc_env_config  m_env_config;

  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);

endclass : sramc_env 


function sramc_env::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new


function void sramc_env::build_phase(uvm_phase phase);
  `uvm_info(get_type_name(), "In build_phase", UVM_HIGH)
  if (!uvm_config_db #(sramc_env_config)::get(this, "", "m_env_config", m_env_config)) 
    `uvm_error(get_type_name(), "Unable to get sramc_env_config")
  m_reference_model = sramc_reference_model::type_id::create("m_reference_model", this);
  m_scoreboard      = sramc_scoreboard::type_id::create("m_scoreboard", this);

  m_ahb_agent  =  ahb_agent::type_id::create("m_ahb_agent", this);

endfunction : build_phase


function void sramc_env::connect_phase(uvm_phase phase);
  `uvm_info(get_type_name(), "In connect_phase", UVM_HIGH)
  // Broadcast each observed transfer to the reference model and scoreboard.
  // The reference model creates an expected item for every read, which the scoreboard
  // matches with the corresponding actual read.
  m_ahb_agent.observed_transfer_port.connect(
    m_reference_model.observed_transfer_export);
  m_ahb_agent.observed_transfer_port.connect(
    m_scoreboard.observed_transfer_fifo.analysis_export);
  m_reference_model.expected_read_port.connect(
    m_scoreboard.expected_read_fifo.analysis_export);

endfunction : connect_phase


// Could print out diagnostic information, for example
function void sramc_env::end_of_elaboration_phase(uvm_phase phase);
  //uvm_top.print_topology();
  //`uvm_info(get_type_name(), $sformatf("Verbosity level is set to: %d", get_report_verbosity_level()), UVM_MEDIUM)
  //`uvm_info(get_type_name(), "Print all Factory overrides", UVM_MEDIUM)
  //factory.print();
endfunction : end_of_elaboration_phase


`endif // SRAMC_ENV_SV
