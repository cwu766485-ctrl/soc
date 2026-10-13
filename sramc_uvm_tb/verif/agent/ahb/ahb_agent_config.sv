//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_agent_config.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Configuration for agent ahb
//
//=============================================================================

`ifndef AHB_AGENT_CONFIG_SV
`define AHB_AGENT_CONFIG_SV

class ahb_agent_config extends uvm_object;

  `uvm_object_utils(ahb_agent_config)

  // Agent mode and verification enables are testbench configuration, not
  // stimulus. Randomizing them makes a seed occasionally create a passive
  // agent with no driver/sequencer, which breaks active sequences at time 0.
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit coverage_enable = 1'b1;
  bit checks_enable   = 1'b1;

  extern function new(string name = "ahb_agent_config");

endclass : ahb_agent_config 


function ahb_agent_config::new(string name = "ahb_agent_config");
  super.new(name);
endfunction : new


`endif // AHB_AGENT_CONFIG_SV
