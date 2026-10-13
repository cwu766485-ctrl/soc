//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_pkg.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Package for agent ahb
//
//=============================================================================

`ifndef AHB_PKG_SV
`define AHB_PKG_SV

package ahb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "ahb_seq_item.sv"
  `include "ahb_agent_config.sv"
  `include "ahb_monitor.sv"
  `include "ahb_coverage.sv"
  `include "ahb_driver.sv"
  `include "ahb_sequencer.sv"
  `include "ahb_seq.sv"
  `include "ahb_agent.sv"

endpackage : ahb_pkg

`endif // AHB_PKG_SV
