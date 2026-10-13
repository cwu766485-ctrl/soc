//------------------------------------------------------------
//
// Package Description:
//
package spi_env_pkg;

// Standard UVM import & include:
import uvm_pkg::*;
`include "uvm_macros.svh"

// Any further package imports:
import apb_agent_pkg::*;
import spi_agent_pkg::*;

import spi_register_pkg::*;

// Includes:
//`include "reg_model/reg_model.sv"
//`include "reg_model/reg_block.sv"

`include "spi_env_config.sv"
`include "spi_reg_functional_coverage.sv"
`include "spi_scoreboard.sv"
`include "spi_env.sv"

endpackage: spi_env_pkg
