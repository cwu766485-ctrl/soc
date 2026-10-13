//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_env_pkg.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Package for sramc
//
//=============================================================================

package sramc_env_pkg;

  `include "uvm_macros.svh"

  import uvm_pkg::*;

  import ahb_pkg::*;

  `include "sramc_env_config.sv"
  `include "sramc_reference_model.sv"
  `include "sramc_scoreboard.sv"
  `include "sramc_env.sv"

endpackage : sramc_env_pkg
