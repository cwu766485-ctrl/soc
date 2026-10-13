//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_test_pkg.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Test package for sramc
//
//=============================================================================

`ifndef SRAMC_TEST_PKG_SV
`define SRAMC_TEST_PKG_SV

package sramc_test_pkg;

  `include "uvm_macros.svh"

  import uvm_pkg::*;

  import ahb_pkg::*;
  import sramc_env_pkg::*;

  `include "ahb_seq_single_access.sv"
  `include "ahb_seq_rw.sv"
  `include "ahb_seq_testcase.sv"
  `include "ahb_seq_random.sv"
  `include "ahb_seq_burst_base.sv"
  `include "ahb_seq_burst.sv"
  `include "ahb_seq_boundary.sv"
  `include "ahb_seq_legal_random.sv"
  `include "sramc_test_base.sv"
  `include "sramc_test.sv"
  `include "sramc_testcase_test.sv"
  `include "sramc_burst_test.sv"
  `include "sramc_boundary_test.sv"
  `include "sramc_legal_random_test.sv"
  `include "sramc_reset_recovery_test.sv"

endpackage : sramc_test_pkg

`endif // SRAMC_TEST_PKG_SV
