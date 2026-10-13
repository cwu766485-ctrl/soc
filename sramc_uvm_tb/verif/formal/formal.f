# VC Formal reads -f files as Tcl scripts, not as VCS file lists.
# V-2023.12-SP2 does not import source SVA through -sva. Register the proof
# obligations explicitly with the native fv* commands after elaboration.
analyze -format sverilog -vcs {../../rtl/ahb_slave_if.v sramc_ahb_formal_harness.sv}
elaborate sramc_ahb_formal_harness

# Constrain the legal normal-AHB environment used by this proof scope.
fvassume -clock hclk -expr {hresetn == 1'b1} a_reset_released
fvassume -clock hclk -expr {hready == 1'b1} a_hready
fvassume -clock hclk -expr {(hsel && htrans[1]) |-> (hsize inside {3'b000, 3'b001, 3'b010})} a_supported_hsize
fvassume -clock hclk -expr {(hsel && htrans[1]) |-> (haddr[31:16] == 16'h0000)} a_address_window
fvassume -clock hclk -expr {(hsel && htrans[1] && hsize == 3'b001) |-> (haddr[0] == 1'b0)} a_halfword_alignment
fvassume -clock hclk -expr {(hsel && htrans[1] && hsize == 3'b010) |-> (haddr[1:0] == 2'b00)} a_word_alignment

# Prove the AHB response and SRAM-bank decoder properties.
fvassert -clock hclk -expr {hready_resp == 1'b1} p_zero_wait
fvassert -clock hclk -expr {hresp == 2'b00} p_okay_response
# ahb_slave_if decodes its registered address/control stage. Check that actual
# decode stage directly instead of relying on native fvassert cross-cycle
# sampling of the AHB input stage.
fvassert -clock hclk -expr {(hresetn && dut.htrans_r[1]) |-> ((bank0_csn != 4'hf) ^ (bank1_csn != 4'hf))} p_one_bank_after_request
fvassert -clock hclk -expr {(bank0_csn != 4'hf) |-> (bank1_csn == 4'hf)} p_bank_mutual_exclusion
fvassert -clock hclk -expr {(bank0_csn inside {4'b1111, 4'b1110, 4'b1101, 4'b1011, 4'b0111, 4'b1100, 4'b0011, 4'b0000}) && (bank1_csn inside {4'b1111, 4'b1110, 4'b1101, 4'b1011, 4'b0111, 4'b1100, 4'b0011, 4'b0000})} p_legal_chip_select

# Reachability goals are separate from proof obligations.
fvcover -clock hclk -expr {hsel && htrans[1] && hsize == 3'b000 && haddr[15] == 1'b0 && haddr[14:13] == 2'b11} c_byte_lane3
fvcover -clock hclk -expr {hsel && htrans[1] && hsize == 3'b001 && haddr[14] == 1'b0 && haddr[13] == 1'b1} c_halfword_high
fvcover -clock hclk -expr {hsel && htrans[1] && hsize == 3'b010 && haddr[13] == 1'b1} c_word_bank1

# Run synchronously so the following exit happens only after all goals finish.
check_fv -block
exit
