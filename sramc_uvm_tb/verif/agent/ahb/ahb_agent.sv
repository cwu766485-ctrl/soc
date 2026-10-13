//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_agent.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Agent for ahb
//
//=============================================================================

`ifndef AHB_AGENT_SV
`define AHB_AGENT_SV

class ahb_agent extends uvm_agent;

  ahb_agent_config       agent_cfg;
  ahb_sequencer          m_sequencer;
  ahb_driver             m_driver;
  ahb_monitor            m_monitor;
  ahb_coverage           coverage_collector;

  uvm_analysis_port #(ahb_seq_item) observed_transfer_port;

  `uvm_component_utils_begin(ahb_agent)
     `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
     `uvm_field_object(agent_cfg, UVM_DEFAULT | UVM_REFERENCE)
  `uvm_component_utils_end


  extern function new(string name, uvm_component parent);

  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

endclass : ahb_agent 


function  ahb_agent::new(string name, uvm_component parent);
  super.new(name, parent);
  observed_transfer_port = new("observed_transfer_port", this);
endfunction : new


function void ahb_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if(agent_cfg == null) begin
    if (!uvm_config_db#(ahb_agent_config)::get(this, "", "agent_cfg", agent_cfg))
    begin
      `uvm_warning("NOCONFIG", "AHB agent config not set; using active defaults")
      agent_cfg = ahb_agent_config::type_id::create("agent_cfg", this);
    end
  end
  is_active = agent_cfg.is_active;

  // The functional-coverage collector uses the same per-agent enable.
  uvm_config_db#(ahb_agent_config)::set(this, "coverage_collector", "agent_cfg", agent_cfg);
  m_monitor     = ahb_monitor    ::type_id::create("m_monitor", this);
  coverage_collector = ahb_coverage::type_id::create("coverage_collector", this);
  if (is_active == UVM_ACTIVE)
  begin
    m_driver    = ahb_driver     ::type_id::create("m_driver", this);
    m_sequencer = ahb_sequencer  ::type_id::create("m_sequencer", this);
  end

endfunction : build_phase


function void ahb_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  m_monitor.analysis_port.connect(observed_transfer_port);
  m_monitor.analysis_port.connect(coverage_collector.analysis_export);
  if (is_active == UVM_ACTIVE)
  begin
    m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  end

endfunction : connect_phase


`endif // AHB_AGENT_SV
