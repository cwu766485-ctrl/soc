#!/bin/sh


RTL_PATH=../../rtl
TB_PATH=../../verif
VERB ?= UVM_MEDIUM
SEED ?= 1
TEST ?= sramc_test
DEBUG ?= -debug_access+all -kdb
# Extra simulation plusargs, for example:
# make legal_random RUN_ARGS='+LEGAL_RANDOM_PAIRS=200 +CROSS_SIZE_READS=3 +PROBE_READS=2 +BUSY_PCT=20'
RUN_ARGS ?=
# Use the user's installed WSL tools when they are available.  The original
# course-server default remains 2023 when no local /opt/Synopsys VCS exists.
LOCAL_VCS_BIN := $(firstword $(wildcard /opt/Synopsys/vcs/*/bin/vcs))
TOOLCHAIN ?= $(if $(LOCAL_VCS_BIN),local,2023)

# TOOLCHAIN=2023 pins VCS/URG/Verdi to the course-server release.
# TOOLCHAIN=local (or legacy for compatibility) uses vcs/urg/verdi selected
# by the current Linux shell, for example a user's own WSL EDA setup script.
VCS2023_HOME ?= /eda/synopsys_2021/vcs/V-2023.12-SP2
VERDI2023_HOME ?= /eda/synopsys_2021/verdi/V-2023.12-SP2
VCS2023 ?= $(VCS2023_HOME)/bin/vcs
URG2023 ?= $(VCS2023_HOME)/bin/urg
VERDI2023 ?= $(VERDI2023_HOME)/bin/verdi

ifeq ($(TOOLCHAIN),2023)
VCS_CMD   = env -u NOVAS_HOME VCS_HOME=$(VCS2023_HOME) VERDI_HOME=$(VERDI2023_HOME) $(VCS2023)
URG_CMD   = env -u NOVAS_HOME VCS_HOME=$(VCS2023_HOME) $(URG2023)
VERDI_CMD = env -u NOVAS_HOME VERDI_HOME=$(VERDI2023_HOME) $(VERDI2023)
else ifeq ($(TOOLCHAIN),legacy)
# Use exactly the login-shell tools selected by select_toolchain.sh.  Do not
# clear VCS_HOME here: legacy urg may require it to locate its installation.
VCS_CMD   = vcs
URG_CMD   = urg
VERDI_CMD = verdi
else ifeq ($(TOOLCHAIN),local)
# WSL's interactive shell aliases vcs to "vcs -full64", but make recipes run
# in a non-interactive shell where aliases are unavailable. Keep this explicit
# so VCS selects its installed linux64 compiler instead of unsupported linux.
VCS_CMD   = vcs -full64
URG_CMD   = urg
VERDI_CMD = verdi
else
$(error Unsupported TOOLCHAIN='$(TOOLCHAIN)'; use 2023, local, or legacy)
endif

# VCS code-coverage and assertion metrics. SystemVerilog covergroups are
# sampled by ahb_coverage during simulation; fcover is not a legal VCS -cm
# metric for the installed V-2023.12-SP2 release.
# The remaining AHB-to-SRAMC functional scope has no RTL FSM. BIST's FSM is
# intentionally excluded by coverage_hierarchy.cfg, so do not request an empty
# FSM metric that would make Verdi warn about a missing FSM coverage shape.
COV_TYPES ?= line+cond+tgl+branch+assert
# Code coverage is limited to the DUT tree, excluding the SRAM macro model.
# This prevents UVM/TB/library source from diluting RTL code-coverage metrics.
COV_HIER ?= coverage_hierarchy.cfg
COV_HIER_OPT := $(if $(strip $(COV_HIER)),-cm_hier $(COV_HIER),)
COMPILE_COV_DIR ?= simv.vdb
COV_DIR ?= results/$(TEST)/seed$(SEED)/$(TEST)_seed$(SEED).vdb
RESULT_DIR ?= results/$(TEST)/seed$(SEED)
LOG ?= $(RESULT_DIR)/$(TEST)_seed$(SEED).log

REGRESS_TESTS ?= sramc_test sramc_testcase_test sramc_burst_test sramc_boundary_test sramc_legal_random_test sramc_reset_recovery_test
# Use a space-separated list, e.g. REGRESS_SEEDS="$(seq -s ' ' 1 20)".
# REGRESS_SEEDS ?= 1 2 3
REGRESS_SEEDS ?= $(shell seq 1 20)
# A complete coverage campaign combines directed corner tests with the two
# constrained-random tests.  Random seed count increases sampling, but cannot
# replace boundary scenarios that deliberately hit protocol/address corners.
COVERAGE_DIRECTED_TESTS ?= sramc_test sramc_testcase_test sramc_burst_test sramc_boundary_test sramc_reset_recovery_test
COVERAGE_RANDOM_TESTS ?= sramc_legal_random_test
# Set to 0 only when appending a second regression phase to the same campaign.
REGRESS_SUMMARY_RESET ?= 1
RESULTS_DIR ?= results
COV_MERGE_DIR ?= merge_coverage.vdb
COV_REPORT_DIR ?= urgReport
COV_INPUTS = $(wildcard $(RESULTS_DIR)/*/seed*/*.vdb)
# Verdi/URG exclusion file.  This is applied only while reporting coverage:
# simulations still execute and assertions still check these signals.  The
# waiver file is maintained by hand (rather than emitted by a path-specific
# GUI session), so do not reject it solely because a copied workspace has a
# different VDB checksum; review every waiver in source control instead.
COV_ELFILE ?= coverage_waivers.el
COV_ELFILE_OPT := $(if $(strip $(COV_ELFILE)),-elfile $(COV_ELFILE) -excl_bypass_checks,)

.PHONY: all testcase legal_random burst boundary reset_recovery comp run regression coverage_full \
        merge cov cov_txt verdi py_run py_regression py_coverage formal formal_clean clean

all: comp run

testcase: TEST=sramc_testcase_test
testcase: comp run

legal_random: TEST=sramc_legal_random_test
legal_random: comp run

burst: TEST=sramc_burst_test
burst: comp run

boundary: TEST=sramc_boundary_test
boundary: comp run

reset_recovery: TEST=sramc_reset_recovery_test
reset_recovery: comp run

# 编译 RTL + UVM TB，生成 simv、simv.vdb
comp:
	$(VCS_CMD) \
  -sverilog -ntb_opts uvm $(DEBUG) -timescale=1ns/1ns \
  -cm $(COV_TYPES) $(COV_HIER_OPT) -cm_dir $(COMPILE_COV_DIR) \
  -f ${RTL_PATH}/rtl.f \
  +incdir+../tb \
  +incdir+../agent/ahb \
  +incdir+../tests \
  +incdir+../tests/seqlib \
  +incdir+../env \
  ../agent/ahb/ahb_if.sv \
  ../tb/sramc_reset_if.sv \
  ../agent/ahb/ahb_pkg.sv \
  ../env/sramc_env_pkg.sv \
  ../tests/sramc_test_pkg.sv \
  ../tb/sramc_assertions.sv \
  ../tb/sramc_tb.sv \
  -l comp.log

# 执行 simv，运行指定测试
run:
	@mkdir -p $(RESULT_DIR)
	./simv +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERB) +ntb_random_seed=$(SEED) \
	  $(RUN_ARGS) -cm $(COV_TYPES) -cm_dir $(COV_DIR) -cm_name $(TEST)_seed$(SEED) -l $(LOG)

# The Makefile remains the short command interface. Python owns the matrix
# loop, per-run metadata, log classification, and Markdown/JSON report.
regression: comp
	python3 scripts/regress.py --no-compile \
	  --tests "$(REGRESS_TESTS)" --seeds "$(REGRESS_SEEDS)" \
	  --run-args "$(RUN_ARGS)" --results-dir "$(RESULTS_DIR)"

# Merge all generated VDBs, then create a text report that is easy to archive.
merge:
	@test -n "$(COV_INPUTS)" || (echo "No VDB found under $(RESULTS_DIR)"; exit 1)
	rm -rf $(COV_MERGE_DIR)
	$(URG_CMD) -full64 \
	  -noreport \
	  -dir $(COMPILE_COV_DIR) $(COV_INPUTS) -dbname $(COV_MERGE_DIR)

cov: merge
	$(VERDI_CMD) -cov -covdir $(COV_MERGE_DIR) $(COV_ELFILE_OPT) &

cov_txt: merge
	rm -rf $(COV_REPORT_DIR)
	$(URG_CMD) -full64 \
	  -dir $(COV_MERGE_DIR) $(COV_ELFILE_OPT) -format text -report $(COV_REPORT_DIR)


# Run after `make clean` for an unambiguous campaign.  The first phase keeps
# the directed boundary results in summary.log; the random phase appends its
# results and then URG merges all generated VDBs.
coverage_full:
	$(MAKE) regression REGRESS_TESTS="$(COVERAGE_DIRECTED_TESTS)" REGRESS_SEEDS="1" REGRESS_SUMMARY_RESET=1
	$(MAKE) regression REGRESS_TESTS="$(COVERAGE_RANDOM_TESTS)" REGRESS_SUMMARY_RESET=0
	$(MAKE) cov_txt

verdi:
	$(VERDI_CMD) -ssf sramc_uvm.fsdb &

# Python scripts keep stateful workflow logic out of Make recipes.
# `py_run` is useful while debugging exactly one test/seed; `py_regression`
# compiles once then runs a matrix; `py_coverage` reports the default results/.
PY_ARGS ?=
py_run:
	python3 scripts/run.py $(PY_ARGS)

py_regression:
	python3 scripts/regress.py $(PY_ARGS)

py_coverage:
	python3 scripts/coverage.py $(PY_ARGS)

# Formal is deliberately separate from UVM simulation: it uses verif/formal
# assumptions and proof/cover properties, not simv transactions or VDBs.
FORMAL_ARGS ?=
formal:
	@echo "[formal] entering from verif/sim: $(CURDIR)"
	$(MAKE) -C ../formal prove $(if $(strip $(FORMAL_ARGS)),FORMAL_ARGS="$(FORMAL_ARGS)")

formal_clean:
	$(MAKE) -C ../formal clean

clean:
	rm -rf csrc simv* *.log *.vpd *.fsdb novas* ucli.key DVEfiles \
	  $(COMPILE_COV_DIR) $(RESULTS_DIR) $(COV_MERGE_DIR) $(COV_REPORT_DIR) \
	  verdiLog vdCovLog urgReport_bypass verdi_config_file vc_hdrs.h
