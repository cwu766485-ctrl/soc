//=============================================================================
// Copyright (c) 2015 by Preston Ltd
//=============================================================================
// Project  : sramc
//
// File Name: sramc_tb.sv
//
// Author   : Name   : Preston
//            Email  : cwu766485@gmail.com
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Testbench
//
//=============================================================================

`timescale 1ns/1ns
module sramc_tb;


  `include "uvm_macros.svh"

  import uvm_pkg::*;

  import ahb_pkg::*;
  import sramc_test_pkg::*;
  import sramc_env_pkg::*;

  bit hclk;
  bit sram_clk;
  bit dft_en;
  bit bist_en;
  logic bist_done;
  logic [7:0] bist_fail;

  sramc_reset_if m_reset_if(hclk);
  ahb_if         m_ahb_if(hclk, m_reset_if.hresetn);

  initial begin
    hclk = 0;
    forever #10 hclk = ~hclk;
  end

  initial begin
    sram_clk = 1;
    forever #10 sram_clk = ~sram_clk;
  end

  initial begin
    m_reset_if.hresetn = 0;
    #200;
    m_reset_if.hresetn = 1;
  end

  initial begin
    dft_en  = 1'b0;
    bist_en = 1'b0;
  end

  sramc_top u_sramc_top (
    .hclk        (hclk),
    .sram_clk    (sram_clk),
    .hresetn     (m_reset_if.hresetn),
    .hsel        (m_ahb_if.hsel),
    .hwrite      (m_ahb_if.hwrite),
    .hready      (m_ahb_if.hready),
    .hsize       (m_ahb_if.hsize),
    .hburst      (m_ahb_if.hburst),
    .htrans      (m_ahb_if.htrans),
    .hwdata      (m_ahb_if.hwdata),
    .haddr       (m_ahb_if.haddr),
    .dft_en      (dft_en),
    .bist_en     (bist_en),
    .hready_resp (m_ahb_if.hready_resp),
    .hresp       (m_ahb_if.hresp),
    .hrdata      (m_ahb_if.hrdata),
    .bist_done   (bist_done),
    .bist_fail   (bist_fail)
  );

  sramc_assertions u_sramc_assertions (
    .hclk        (hclk),
    .hresetn     (m_reset_if.hresetn),
    .hsel        (m_ahb_if.hsel),
    .haddr       (m_ahb_if.haddr),
    .htrans      (m_ahb_if.htrans),
    .hsize       (m_ahb_if.hsize),
    .hwrite      (m_ahb_if.hwrite),
    .hready      (m_ahb_if.hready),
    .hready_resp (m_ahb_if.hready_resp),
    .hresp       (m_ahb_if.hresp),
    .bank0_csn   (u_sramc_top.ahb_slave_if_u.bank0_csn),
    .bank1_csn   (u_sramc_top.ahb_slave_if_u.bank1_csn)
  );

  initial
  begin
    uvm_config_db #(virtual ahb_if)::set(null, "*", "vif", m_ahb_if);
    uvm_config_db #(virtual sramc_reset_if)::set(null, "*", "reset_vif", m_reset_if);

    run_test();
  end

  initial begin
    `ifdef FSDB
      $fsdbDumpfile("sramc_uvm.fsdb");
      $fsdbDumpvars(0, sramc_tb);
    `endif
  end

endmodule
