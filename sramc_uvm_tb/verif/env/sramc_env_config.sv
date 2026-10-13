//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_env_config.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Configuration for sramc_env
//
//=============================================================================

`ifndef SRAMC_ENV_CONFIG_SV
`define SRAMC_ENV_CONFIG_SV

class sramc_env_config extends uvm_object;

  `uvm_object_utils(sramc_env_config)


  extern function new(string name = "sramc_env_config");

endclass : sramc_env_config 


function sramc_env_config::new(string name = "sramc_env_config");
  super.new(name);
endfunction : new


`endif // SRAMC_ENV_CONFIG_SV

