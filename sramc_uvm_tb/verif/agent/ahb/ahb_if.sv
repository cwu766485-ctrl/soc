//=============================================================================
// Copyright (c) 2015 by ... Ltd
//=============================================================================
// Project  : sramc
//
// File Name: ahb_if.sv
//
// Author   : Name   :  
//            Email  :    
//            Dept   : RD
//
// Version  : v1
//=============================================================================
// Description:
//
// Signal interface for agent ahb
//
//=============================================================================

`ifndef AHB_IF_SV
`define AHB_IF_SV

interface ahb_if(
  input bit hclk,
  input bit hresetn
);

  logic        hsel;
  logic [31:0] haddr;
  logic [1:0]  htrans;
  logic [2:0]  hsize;
  logic [2:0]  hburst;
  logic        hwrite;
  logic [31:0] hwdata;
  logic        hready;

  logic        hready_resp;
  logic [1:0]  hresp;
  logic [31:0] hrdata;

  clocking drvCLK @(posedge hclk);
    default input #1step output #0;
    output hsel;
    output haddr;
    output htrans;
    output hsize;
    output hburst;
    output hwrite;
    output hwdata;
    output hready;
    input  hready_resp;
    input  hresp;
    input  hrdata;
    input  hresetn;
  endclocking

  clocking monCLK @(posedge hclk);
    default input #1step output #0;
    input hsel;
    input haddr;
    input htrans;
    input hsize;
    input hburst;
    input hwrite;
    input hwdata;
    input hready;
    input hready_resp;
    input hresp;
    input hrdata;
  endclocking

  modport driver(clocking drvCLK);
  modport monitor(clocking monCLK);


  // You could add properties and assertions, for example
  // property name;
  // ...
  // endproperty : name
  // label: assert property(name);

endinterface : ahb_if

`endif // AHB_IF_SV
