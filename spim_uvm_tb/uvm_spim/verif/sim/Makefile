RTL_PATH=../../rtl
TB_PATH=../../verif
VERB=UVM_LOW
SEED=1
TEST=spi_test_base
# Default to the local WSL EDA installation. Override these variables for a
# different EDA installation, for example: make VCS_HOME=/path/to/vcs all
VCS_HOME = /opt/Synopsys/vcs/V-2023.12-SP1
VERDI_HOME = /opt/Synopsys/verdi/V-2023.12-SP2
export VCS_HOME
export VERDI_HOME
VCS = $(VCS_HOME)/bin/vcs
URG = $(VCS_HOME)/bin/urg
VERDI = $(VERDI_HOME)/bin/verdi
VPD2VCD = $(VCS_HOME)/bin/vpd2vcd
VC_FORMAL_HOME ?= $(VCS_HOME)/vcfca
VCF = $(VC_FORMAL_HOME)/bin/vcf

TESTS ?= spi_reg_test spi_poll_test spi_interrupt_test spi_interrupt_mask_test spi_mid_reset_test spi_transfer_cov_test spi_shift_mode_test spi_busy_write_cov_test
# The full suite includes the register test. Its generic access sequence skips
# CTRL/DIVIDER stateful registers and TX/RX address aliases; those are checked
# by their dedicated sequence and end-to-end serial scoreboard tests.
COV_TESTS ?= spi_transfer_cov_test spi_shift_mode_test spi_busy_write_cov_test spi_interrupt_test spi_interrupt_mask_test spi_poll_test spi_mid_reset_test
MERGE_TESTS ?= $(COV_TESTS)
OUTPUT_DIR = ./logs
COV_ROOT = $(OUTPUT_DIR)/COV
# A separate VDB per test preserves all coverage data for a later merge.
COV_DIR = $(COV_ROOT)/$(TEST).vdb
# URG V-2023.12 only creates the output VDB reliably when -dbname is passed
# without a leading './'.  Inputs may retain their normal relative paths.
MERGED_VDB = logs/COV/merged.vdb
MERGE_VDBS = $(addprefix $(COV_ROOT)/,$(addsuffix .vdb,$(MERGE_TESTS)))
EXCL_FILE ?= coverage_unreachable.el
URG_EXCL_OPT = $(if $(wildcard $(EXCL_FILE)),-elfile $(EXCL_FILE) -excl_strict,)
VERDI_EXCL_OPT = $(if $(wildcard $(EXCL_FILE)),-elfile $(EXCL_FILE),)
# Verdi displays one selected test VDB at a time.  Passing multiple -covdir
# arguments does not create a merged view; it only makes the last one visible.
VDB ?= $(COV_DIR)
# Restrict code coverage to top_tb.DUT; UVM and agent sources are verification
# infrastructure and must not contribute to DUT code-coverage metrics.
COV = -cm line+cond+fsm+tgl+assert -cm_dir $(COV_DIR)
COV_COMPILE = $(COV) -cm_hier cm_hier.cfg
# Keep the sign-off code metrics separate from the merge metrics.  The merged
# VDB must include group data, otherwise Verdi's Groups tab is empty even
# though every individual test VDB contains functional coverage.
URG_METRICS = line+cond+tgl+assert
MERGE_METRICS = $(URG_METRICS)+group
OUTPUT_DIR = ./logs
TB_TEST_ID = $(TEST)
VPD = +vpdfile+$(TEST_LOG)/$(TB_TEST_ID).vpd
VPD_FILE = $(TEST_LOG)/$(TB_TEST_ID).vpd
VCD_FILE = $(TEST_LOG)/$(TB_TEST_ID).vcd
TEST_LOG = $(OUTPUT_DIR)/$(TB_TEST_ID)
UVM_DBG  = +UVM_CONFIG_DB_TRACE
EXTRA_ARGS ?=

.PHONY: help regr cov_regr all prep comp run ral xls2csv csv2sv vcd verdi \
        urg func_urg merge_cov verdi_cov_single verdi_cov verdi_cov_merged \
        formal formal_demo_fail formal_clean clean clean_logs

help:
	@echo "Common commands:"
	@echo "  make all TEST=spi_shift_mode_test SEED=1  Run one testcase"
	@echo "  make regr SEED=1                         Run the Makefile regression list"
	@echo "  make cov_regr SEED=1                     Run coverage-focused tests"
	@echo "  make verdi TEST=spi_shift_mode_test      Open one waveform"
	@echo "  make merge_cov && make func_urg          Merge/report coverage"
	@echo "  make formal                              Prove SPI safety properties with VC Formal"
	@echo "  make formal_demo_fail                    Run an intentional failing property demo"
	@echo "  make clean                               Remove all generated simulation artifacts"
	@echo "  make clean_logs                          Remove only logs/waves/coverage reports"

regr:
	@for test in $(TESTS); do \
		$(MAKE) all TEST=$$test SEED=$(SEED) || exit $$?; \
	done

cov_regr:
	@for test in $(COV_TESTS); do \
		$(MAKE) all TEST=$$test SEED=$(SEED) || exit $$?; \
	done


all: prep comp run

prep:
	rm -rf $(TEST_LOG) $(COV_DIR)
	mkdir -p $(TEST_LOG) $(COV_ROOT)

comp:
	@mkdir -p $(COV_ROOT)
	$(VCS) -full64 -sverilog -assert enable_diag -ntb_opts uvm -debug_pp -timescale=1ns/1ns \
	+incdir+${RTL_PATH} -f ${RTL_PATH}/filelist.f \
	+incdir+../agent/spi_agent \
  +incdir+../agent/apb_agent \
  +incdir+../tb \
  +incdir+../tests \
  +incdir+../tests/seqlib \
  +incdir+../env \
  +incdir+../env/reg_model \
	../env/reg_model/spi_register_pkg.sv \
	../agent/spi_agent/spi_agent_pkg.sv \
  ../agent/spi_agent/spi_if.sv \
  ../agent/apb_agent/apb_agent_pkg.sv \
  ../env/spi_env_pkg.sv \
  ../tests/seqlib/apb_seq_lib_pkg.sv \
  ../tests/seqlib/spi_seq_lib_pkg.sv \
	../tests/seqlib/spi_virtual_seq_lib_pkg.sv \
  ../tests/spi_test_lib_pkg.sv \
  ../tb/intr_if.sv \
  ../tb/spi_assertions.sv \
  ../tb/top_tb.sv \
	${COV_COMPILE} -l comp.log

run:
	./simv +UVM_TESTNAME=${TEST} +UVM_VERBOSITY=${VERB} ${COV} ${VPD} ${UVM_DBG} ${EXTRA_ARGS} $(TEST_EXTRA_ARGS_$(TEST)) +ntb_random_seed=${SEED} -cm_name ${TEST} -l ${TEST_LOG}/${TEST}.log

TEST_EXTRA_ARGS_spi_mid_reset_test = +MID_RESET

ral: xls2csv csv2sv

xls2csv:
	./scripts/xlsx2csv.py -s1 ../../doc/register_map.xlsx > ./reg_map.csv

csv2sv:
	./scripts/uvm_ral_gen.pl -reg_map_tbl ./reg_map.csv -module_name apb
	mv ./apb_*.sv ../env/reg_model/

# This Verdi version does not accept VPD directly.  Convert the VCS-native
# VPD to VCD, then load the VCD via Verdi's supported -ssf waveform option.
vcd: $(VPD_FILE)
	$(VPD2VCD) $(VPD_FILE) $(VCD_FILE)

verdi: vcd
	$(VERDI) -ssf $(VCD_FILE) &

urg:
	$(URG) -full64 -dir $(MERGE_VDBS) $(URG_EXCL_OPT) -metric $(URG_METRICS) -format both -report $(COV_ROOT)/report

# Functional coverage is stored as covergroups.  Keep it as a separate
# report so the code report above can retain instance-specific exclusions.
func_urg: merge_cov
	$(URG) -full64 -dir $(MERGED_VDB) -metric group -format both -report $(COV_ROOT)/func_report

# A real merged VDB is required for a whole-regression Verdi view.  Do not
# pass a list of VDBs to Verdi: only the last one is displayed in that case.
merge_cov:
	@missing=0; \
	for vdb in $(MERGE_VDBS); do \
		if [ ! -d "$$vdb" ]; then \
			echo "Missing coverage database: $$vdb"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
		echo "Coverage merge aborted. Run 'make cov_regr SEED=<seed>' to generate every required VDB."; \
		exit 1; \
	fi
	rm -rf $(MERGED_VDB)
	$(URG) -full64 -dir $(MERGE_VDBS) -metric $(MERGE_METRICS) -dbname $(MERGED_VDB) -report $(COV_ROOT)/merged_report
	@test -d "$(MERGED_VDB)" || (echo "Merged VDB was not created: $(MERGED_VDB)"; exit 1)

verdi_cov_single:
	@test -d "$(VDB)" || (echo "VDB not found: $(VDB)"; exit 1)
	$(VERDI) -full64 -cov -covdir $(VDB) $(VERDI_EXCL_OPT) &

verdi_cov: merge_cov
	$(VERDI) -full64 -cov -covdir $(MERGED_VDB) $(VERDI_EXCL_OPT) &

verdi_cov_merged: verdi_cov

# VC Formal has its own wrapper/harness and does not use UVM/top_tb.
formal:
	@mkdir -p ../../formal/reports
	cd ../../formal && VC_STATIC_HOME=$(VC_FORMAL_HOME) $(VCF) -batch -no_ui -fmode FPV -f spi_formal.tcl -session formal_session -output_log_file reports/vcf.log

formal_demo_fail:
	@mkdir -p ../../formal/reports
	cd ../../formal && FORMAL_DEMO_FAIL=1 VC_STATIC_HOME=$(VC_FORMAL_HOME) $(VCF) -batch -no_ui -fmode FPV -f spi_formal.tcl -session formal_demo_fail_session -output_log_file reports/vcf_demo_fail.log

formal_reset:
	@mkdir -p ../../formal/reports
	cd ../../formal && FORMAL_RESET_CHECK=1 VC_STATIC_HOME=$(VC_FORMAL_HOME) $(VCF) -batch -no_ui -fmode FPV -f spi_formal.tcl -session formal_reset_session -output_log_file reports/vcf_reset.log

formal_clean:
	rm -rf ../../formal/formal_session ../../formal/formal_session_rtdb \
	       ../../formal/formal_demo_fail_session ../../formal/formal_demo_fail_session_rtdb \
	       ../../formal/formal_reset_session ../../formal/formal_reset_session_rtdb \
	       ../../formal/reports ../../formal/vcst_command.log

clean:
	python3 ./scripts/clean_sim.py --apply

clean_logs:
	python3 ./scripts/clean_sim.py --scope logs --apply
