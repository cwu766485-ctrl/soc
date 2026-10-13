# Synopsys VC Formal FPV setup for the SPI APB wrapper.
# Run from uvm_spim/formal through: make formal

fv_app FPV
set design spi_formal_harness

set rtl_dir ../rtl
set harness spi_formal_harness.sv
set report_dir reports
if {[info exists ::env(FORMAL_RESET_CHECK)] && $::env(FORMAL_RESET_CHECK) == "1"} {
  set report_dir reports/reset
}
file mkdir $report_dir

# spi_clgen.v includes spi_defines.v and timescale.v from the RTL directory.
# VCS simulation receives this path through the file list / +incdir option;
# VC Formal invokes the VCS reader directly, so pass the same include path
# explicitly here.
set read_options "+incdir+$rtl_dir"
if {[info exists ::env(FORMAL_DEMO_FAIL)] && $::env(FORMAL_DEMO_FAIL) == "1"} {
  append read_options " +define+FORMAL_DEMO_FAIL"
}
if {[info exists ::env(FORMAL_RESET_CHECK)] && $::env(FORMAL_RESET_CHECK) == "1"} {
  append read_options " +define+FORMAL_RESET_CHECK"
}

# Do not read UVM, interfaces, testbench clocks, or the simulation-only bind.
# The formal harness is the top and supplies symbolic APB/MISO inputs.
read_file -top $design -format sverilog -sva -vcs $read_options [list \
  $rtl_dir/spi_clgen.v \
  $rtl_dir/spi_shift.v \
  $rtl_dir/spi_top.v \
  $harness \
]

create_clock PCLK -period 10

# The normal proof starts after a saved reset state.  VC Formal then fixes
# PRESETN high for the post-reset proof.  The reset-only proof instead leaves
# PRESETN to the RTL asynchronous-reset logic and constrains it low in the
# harness; calling create_reset there would conflict with that constraint.
if {![info exists ::env(FORMAL_RESET_CHECK)] || $::env(FORMAL_RESET_CHECK) != "1"} {
  create_reset PRESETN -async -sense low
  sim_run -stable
  sim_save_reset
}
set formal_max_time 600s
if {[info exists ::env(FORMAL_MAX_TIME)]} {
  set formal_max_time $::env(FORMAL_MAX_TIME)
}
set_fml_var fml_max_time $formal_max_time
fv_check -block

redirect -file $report_dir/formal_summary.rpt {fv_report -detail list}
redirect -file $report_dir/formal_assertions.rpt {
  fv_report -usage assert -detail verbose
}
redirect -file $report_dir/formal_covers.rpt {
  fv_report -usage cover -detail verbose
}
quit
