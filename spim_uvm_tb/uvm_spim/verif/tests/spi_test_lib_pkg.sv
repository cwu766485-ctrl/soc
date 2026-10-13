// Package Description:
//
package spi_test_lib_pkg;

// Standard UVM import & include:
import uvm_pkg::*;
`include "uvm_macros.svh"

// Any further package imports:
import spi_register_pkg::*;
import spi_env_pkg::*;
import apb_agent_pkg::*;
import spi_agent_pkg::*;
import apb_seq_lib_pkg::*;
import spi_seq_lib_pkg::*;
import spi_virtual_seq_lib_pkg::*;

// Includes:
`include "spi_test_base.sv"
`include "spi_cov_test_base.sv"
`include "spi_reg_test.sv"
`include "spi_interrupt_test.sv"
`include "spi_interrupt_mask_test.sv"
`include "spi_poll_test.sv"
`include "spi_mid_reset_test.sv"
`include "spi_transfer_cov_test.sv"
`include "spi_shift_mode_test.sv"
`include "spi_busy_write_cov_test.sv"

endpackage: spi_test_lib_pkg
