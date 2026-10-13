# VC Formal command-line options vary slightly by release. Keep the tool name
# and extra options overridable so the same harness runs on course/WSL servers.
VCF ?= vcf
# Formal proof state is generated data. `vcf -reset` only resets and exits,
# so it must be launched separately before the actual proof invocation.
VCF_SESSION_RESET ?= -reset
# Source SVA is registered with native `fvassume`/`fvassert`/`fvcover`
# commands in formal.f. Keep FORMAL_ARGS available for site-specific options.
FORMAL_ARGS ?=

.PHONY: prove cover license_check clean help

license_check:
	@echo "VCF=$$(command -v $(VCF) 2>/dev/null || echo NOT_FOUND)"
	@echo "SNPSLMD_LICENSE_FILE=$${SNPSLMD_LICENSE_FILE-<unset>}"
	@echo "LM_LICENSE_FILE=$${LM_LICENSE_FILE-<unset>}"
	@echo "VC_FORMAL_HOME=$${VC_FORMAL_HOME-<unset>}"
	@command -v lmutil >/dev/null 2>&1 && lmutil lmstat -a -c "$${SNPSLMD_LICENSE_FILE:-$${LM_LICENSE_FILE}}" || \
	  echo "lmutil unavailable; ask the site setup/license administrator for VC-STATIC-COMPILE access"

prove:
	@command -v $(VCF) >/dev/null || { echo "VC Formal command '$(VCF)' not found; source the Synopsys formal setup first."; exit 127; }
	# formal.f is a VC Formal Tcl script, not a VCS file list. It performs
	# analyze, elaborate and check_fv itself.
	$(VCF) $(VCF_SESSION_RESET)
	$(VCF) -f formal.f $(FORMAL_ARGS)

# The harness contains both assert and cover properties. Tool-specific cover
# options, if required by the installed release, belong in FORMAL_ARGS.
cover: prove

clean:
	rm -rf vcformal* vcf* vcst_rtdb work* *.log *.rpt *.vdb

help:
	@echo "make prove VCF=vcf FORMAL_ARGS='<site-specific-options>'"
	@echo "make license_check  # inspect license variables and optional lmutil status"
	@echo "Run from verif/formal after sourcing the server's VC Formal setup."
