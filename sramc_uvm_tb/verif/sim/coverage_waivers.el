// ============================================================================
// sramc UVM code-coverage waivers
//
// This file is deliberately small and version controlled.  It is loaded by
// URG/Verdi at report time; it does not disable simulation or SVA checking.
// Every exclusion below is outside the current normal-AHB verification scope.
// ============================================================================
// ExclMode: default

// Normal functional DV keeps these DFT/BIST controls inactive.  BIST has a
// separate verification plan, and its implementation modules are also
// excluded in coverage_hierarchy.cfg.
INSTANCE: sramc_tb.u_sramc_top
Toggle dft_en
Toggle bist_en
Toggle bist_done
Toggle bist_fail

INSTANCE: sramc_tb.u_sramc_top.sram_core_u
Toggle dft_en
Toggle bist_en
Toggle bist_done
Toggle bist_fail

// RTL contract: this controller is zero-wait-state and always returns OKAY.
// The SVA module still proves these values every clock; their unavailable
// toggle transitions are not normal-mode code-coverage goals.
INSTANCE: sramc_tb.u_sramc_top
Toggle hready_resp
Toggle hresp

INSTANCE: sramc_tb.u_sramc_top.ahb_slave_if_u
Toggle hready_resp
Toggle hresp

// Normal-AHB DV in this project assumes an always-ready upstream bus.  The
// RTL still gates acceptance with HREADY, but wait-state protocol verification
// is explicitly outside this signoff scope until a holding-capable driver and
// a dedicated HREADY wait-state test are added.
INSTANCE: sramc_tb.u_sramc_top
Toggle hready

INSTANCE: sramc_tb.u_sramc_top.ahb_slave_if_u
Toggle hready
Condition 23 "940592074" "(hsel && hready) 1 -1" (2 "10")

// This project only supports AHB HSIZE=000/001/010 (byte/halfword/word), so
// HSIZE[2] never toggles in legal normal-mode traffic.  The upper address
// bits are constrained to the documented 64 KiB AHB address window.
INSTANCE: sramc_tb.u_sramc_top
Toggle hsize [2]
Toggle haddr [31:16]

INSTANCE: sramc_tb.u_sramc_top.ahb_slave_if_u
Toggle hsize [2]
Toggle haddr [31:16]
Toggle hsize_r [2]
Toggle haddr_r [31:16]

// The final HSIZE comparison is reached only after WORD and HALFWORD have
// already been rejected. Its false outcome therefore means HSIZE=2'b11,
// which is outside this controller's BYTE/HALFWORD/WORD interface contract.
// Exclude only that false condition bin; BYTE's true bin remains a goal.
Condition 22 "2790167165" "(hsize_sel == 2'b0) 1 -1" (1 "0")

// These five case-default branches correspond only to X/Z on haddr_sel or
// haddr_sel[0]. All legal 2-state byte lanes and halfword lanes are covered
// by boundary/random tests. Do not inject unknown values merely for coverage.
Branch 1 "520310529" "(!hresetn)" (5)  "(!hresetn) 0,1,1,2'b00 ,MISSING_DEFAULT,-,-,-,-"
Branch 1 "520310529" "(!hresetn)" (8)  "(!hresetn) 0,1,1,2'b01 ,-,MISSING_DEFAULT,-,-,-"
Branch 1 "520310529" "(!hresetn)" (14) "(!hresetn) 0,1,0,-,-,-,2'b00 ,MISSING_DEFAULT,-"
Branch 1 "520310529" "(!hresetn)" (17) "(!hresetn) 0,1,0,-,-,-,2'b01 ,-,MISSING_DEFAULT"
Branch 2 "4010427668" "(hsize_sel == 2'b10)" (7) "(hsize_sel == 2'b10) 0,0,-,1,MISSING_DEFAULT"

// BIST implementation modules are excluded by coverage_hierarchy.cfg. These
// remaining signals are only their top/core aggregation wiring, so remove all
// BIST-related toggle goals from the normal-AHB DV report as well.
INSTANCE: sramc_tb.u_sramc_top.sram_core_u
Toggle bist_done0
Toggle bist_done1
Toggle bist_done2
Toggle bist_done3
Toggle bist_done4
Toggle bist_done5
Toggle bist_done6
Toggle bist_done7
Toggle bist_fail0
Toggle bist_fail1
Toggle bist_fail2
Toggle bist_fail3
Toggle bist_fail4
Toggle bist_fail5
Toggle bist_fail6
Toggle bist_fail7
Toggle bank0_bistdone
Toggle bank1_bistdone
Toggle bank0_bistfail
Toggle bank1_bistfail
