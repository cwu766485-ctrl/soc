`timescale 1ns/1ps

// Formal harness for the AHB-to-SRAM control decoder. SRAM read-data inputs
// are intentionally unconstrained: these properties prove control behavior,
// not storage data retention, which remains covered by UVM/refm simulation.
module sramc_ahb_formal_harness;

  (* gclk *) logic hclk;
  logic hresetn;
  logic hsel;
  logic hready;
  logic hwrite;
  logic [1:0] htrans;
  logic [2:0] hsize;
  logic [2:0] hburst;
  logic [31:0] haddr;
  logic [31:0] hwdata;
  logic [7:0] sram_q0, sram_q1, sram_q2, sram_q3;
  logic [7:0] sram_q4, sram_q5, sram_q6, sram_q7;
  logic [1:0] hresp;
  logic hready_resp;
  logic [31:0] hrdata;
  logic sram_w_en;
  logic bank_sel;
  logic [3:0] bank0_csn;
  logic [3:0] bank1_csn;
  logic [12:0] sram_addr_out;
  logic [31:0] sram_wdata;

  ahb_slave_if dut (
    .hclk(hclk), .hresetn(hresetn),
    .hsel(hsel), .hready(hready), .hwrite(hwrite),
    .htrans(htrans), .hsize(hsize), .hburst(hburst),
    .haddr(haddr), .hwdata(hwdata),
    .sram_q0(sram_q0), .sram_q1(sram_q1), .sram_q2(sram_q2), .sram_q3(sram_q3),
    .sram_q4(sram_q4), .sram_q5(sram_q5), .sram_q6(sram_q6), .sram_q7(sram_q7),
    .hresp(hresp), .hready_resp(hready_resp), .hrdata(hrdata),
    .sram_w_en(sram_w_en), .bank_sel(bank_sel),
    .bank0_csn(bank0_csn), .bank1_csn(bank1_csn),
    .sram_addr_out(sram_addr_out), .sram_wdata(sram_wdata)
  );

  default clocking cb @(posedge hclk); endclocking

  // Formal inputs are otherwise arbitrary. These assumptions define the
  // normal AHB functional scope used by the UVM platform and exclude BIST/DFT.
  initial assume (!hresetn);
  always @(posedge hclk) assume (hresetn);
  assume property (hready == 1'b1);
  assume property ((hsel && htrans[1]) |->
                   (hsize inside {3'b000, 3'b001, 3'b010}));
  assume property ((hsel && htrans[1]) |-> haddr[31:16] == 16'h0000);
  assume property ((hsel && htrans[1] && hsize == 3'b001) |-> haddr[0] == 1'b0);
  assume property ((hsel && htrans[1] && hsize == 3'b010) |-> haddr[1:0] == 2'b00);

  wire valid_transfer = hsel && hready && htrans[1];
  wire one_bank_selected = ((bank0_csn != 4'hf) ^ (bank1_csn != 4'hf));
  wire legal_csn = (bank0_csn inside {4'b1111, 4'b1110, 4'b1101, 4'b1011,
                                       4'b0111, 4'b1100, 4'b0011, 4'b0000}) &&
                   (bank1_csn inside {4'b1111, 4'b1110, 4'b1101, 4'b1011,
                                       4'b0111, 4'b1100, 4'b0011, 4'b0000});

  // These assertions are proof obligations: VC Formal must prove them for all
  // traces that satisfy the assumptions, or produce a counterexample trace.
  a_zero_wait: assert property (hready_resp == 1'b1);
  a_okay_response: assert property (hresp == 2'b00);
  a_one_bank_after_request: assert property (valid_transfer |=> one_bank_selected);
  a_legal_chip_select_encoding: assert property (legal_csn);
  a_bank_mutual_exclusion: assert property ((bank0_csn != 4'hf) |-> bank1_csn == 4'hf);

  // Formal cover is a reachability request. A PASS returns a witness waveform,
  // not an assertion-coverage count from a random simulation.
  c_byte_lane3: cover property (valid_transfer && hsize == 3'b000 &&
                                haddr[15] == 1'b0 && haddr[14:13] == 2'b11);
  c_halfword_high: cover property (valid_transfer && hsize == 3'b001 &&
                                   haddr[14] == 1'b0 && haddr[13] == 1'b1);
  c_word_bank1: cover property (valid_transfer && hsize == 3'b010 &&
                                haddr[13] == 1'b1);

endmodule : sramc_ahb_formal_harness
