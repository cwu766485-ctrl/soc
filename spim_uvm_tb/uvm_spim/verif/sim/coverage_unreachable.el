// Reviewed, instance-specific coverage exclusions.
// Reviewed against current URG -dump full_exclusions output (2026-10-09).
// Each exclusion below is unreachable by the APB/SPI specification or by a
// hard connection in top_tb. Do not add functional coverage holes here.
// Format Version: 2

CHECKSUM: "571119265 249788382"
// ANNOTATION: "ModuleName: spi_top"
INSTANCE: top_tb.DUT
// ANNOTATION: "APB byte address is word aligned; PADDR[1:0] is not decoded."
Toggle PADDR [1:0] "net PADDR[4:0]"
// ANNOTATION: "This SPI implementation has no error-response feature; PSLVERR is tied low."
Toggle PSLVERR "net PSLVERR"
// ANNOTATION: "CTRL[7] is the defined reserved bit (SPI_CTRL_RES_1); spi_top neither implements nor exposes a functional state for it."
Toggle ctrl [7] "reg ctrl[13:0]"

CHECKSUM: "1708306018 2829352767"
// ANNOTATION: "ModuleName: spi_shift"
INSTANCE: top_tb.DUT.shift
// ANNOTATION: "spi_top hard-connects byte_sel to 4'hF; no design input can toggle it."
Toggle byte_sel "net byte_sel[3:0]"

CHECKSUM: "3105871884 2217972182"
// ANNOTATION: "ModuleName: spi_clgen"
INSTANCE: top_tb.DUT.clgen
// ANNOTATION: "When enable is 0 the counter reloads, so enable=0/clk_out=1/cnt_one=1 is unreachable."
Condition 10 "2766187279" "(enable && clk_out && cnt_one) 1 -1" (1 "011")

CHECKSUM: "571119265 1042045574"
// ANNOTATION: "ModuleName: spi_top"
INSTANCE: top_tb.DUT
// ANNOTATION: "APB ACCESS is illegal with PSEL=0 and PENABLE=1."
Condition 1 "1039462314" "(PSEL & PENABLE & ((~PREADY))) 1 -1" (1 "011")
// ANNOTATION: "At the transfer-complete edge tip is sampled high; tip=0/last_bit=1/pos_edge=1 is unreachable."
Condition 6 "4162065954" "(ie && tip && last_bit && pos_edge) 1 -1" (2 "1011")
Condition 4 "257525319" "(tip && last_bit && pos_edge) 1 -1" (1 "011")
// ANNOTATION: "APB ACCESS is illegal with PSEL=0 and PENABLE=1, for every decoded register address."
Condition 7 "821177212" "(PSEL & PENABLE & (PADDR[4:2] == 3'h5)) 1 -1" (1 "011")
Condition 9 "3109061398" "(PSEL & PENABLE & (PADDR[4:2] == 3'h4)) 1 -1" (1 "011")
Condition 11 "2507409294" "(PSEL & PENABLE & (PADDR[4:2] == 3'b0)) 1 -1" (1 "011")
Condition 13 "1484889857" "(PSEL & PENABLE & (PADDR[4:2] == 3'b1)) 1 -1" (1 "011")
Condition 15 "2499488349" "(PSEL & PENABLE & (PADDR[4:2] == 3'h2)) 1 -1" (1 "011")
Condition 17 "1494135506" "(PSEL & PENABLE & (PADDR[4:2] == 3'h3)) 1 -1" (1 "011")
Condition 19 "241181962" "(PSEL & PENABLE & (PADDR[4:2] == 3'h6)) 1 -1" (1 "011")

CHECKSUM: "1708306018 476285277"
// ANNOTATION: "ModuleName: spi_shift"
INSTANCE: top_tb.DUT.shift
// ANNOTATION: "At the transfer-complete edge tip is sampled high; this vector is unreachable."
Condition 5 "2441462440" "(tip && last && pos_edge) 1 -1" (1 "011")

CHECKSUM: "1879486070"
// ANNOTATION: "ModuleName: uvm_pkg"
INSTANCE: uvm_pkg
// ANNOTATION: "UVM library internal RAL checks are verification-framework code, not DUT assertions."
Assert \uvm_reg_map::do_read .unnamed$$_0.unnamed$$_1 "assertion"
Assert \uvm_reg_map::do_write .unnamed$$_0.unnamed$$_1 "assertion"
