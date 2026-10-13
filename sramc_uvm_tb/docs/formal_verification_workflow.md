# SRAMC Formal Verification Workflow

## Goal And Scope

`verif/formal/` is a separate proof flow for the AHB-to-SRAM control decoder.
It targets `ahb_slave_if`, not the UVM testbench and not the full SRAM macro
array. UVM remains the primary flow for transaction data integrity, burst
sequences, reference-model checking and functional coverage.

The formal harness proves or searches reachability for:

- zero-wait response: `HREADY_RESP` is always high;
- OKAY response: `HRESP` is always `2'b00`;
- every valid registered AHB decode stage selects exactly one bank;
- bank chip-select encoding is legal and banks cannot be selected together;
- BYTE lane3, high-halfword and bank1 WORD access are reachable.

## Formal Harness

The harness is `verif/formal/sramc_ahb_formal_harness.sv`.

`formal.f` is a VC Formal Tcl script, not a VCS-style file list. It explicitly
does `analyze`, `elaborate sramc_ahb_formal_harness`, registers properties with
`fvassume`/`fvassert`/`fvcover`, and runs `check_fv -block`. The
harness declares `(* gclk *) hclk` and a default clocking block, so no Tcl
`clock hclk` command is needed. Reset behavior is constrained inside the
harness. This VCF release does not accept `-sva` on `analyze`, `check_fv`, or
the VCF startup command; native `fv*` commands are used instead. This release
takes the elaboration top as a positional argument;
it rejects VCS-style `-top` and `-sverilog` options.

```text
free formal inputs
  + legal-AHB assumptions
  -> ahb_slave_if DUT
  -> assert property: prove for all legal traces
  -> cover property: find one legal witness trace
```

### `assume`, `assert`, And `cover`

| Construct | Meaning in this project |
|---|---|
| `fvassume` | Limits the external AHB environment to the normal supported scope: reset is released, `HREADY=1`, valid transfers use supported/aligned accesses within 64 KiB. |
| `fvassert` | A design obligation. VC Formal proves it for every trace satisfying the assumptions or returns a counterexample waveform. |
| `fvcover` | A reachability request. VC Formal searches for one legal trace that reaches the scenario and returns a witness waveform. It is not a simulation assertion-coverage hit count. |

This is the key difference from the UVM SVA module: simulation SVA checks only
the finite transactions driven by sequences; formal assertion proof explores
all legal input traces within the stated assumptions.

## Running Synopsys VC Formal

The VC Formal environment must be sourced on the server/site before running.
Confirm it before running:

```sh
command -v vcf
vcf -help
```

Then run from `verif/sim/`:

```sh
make formal
```

Or work directly in the formal directory:

```sh
cd verif/formal
make prove
```

If the command reaches a message such as `License checkout failed for
VC-STATIC-COMPILE`, the SV harness has not started yet. Check the shell setup
first:

```sh
cd verif/formal
make license_check
env | grep -E 'SNPSLMD_LICENSE_FILE|LM_LICENSE_FILE|VC_FORMAL_HOME'
```

`VC-STATIC-COMPILE` is a VC Formal/VC Static feature. A working VCS license
does not necessarily grant this feature. If the license variables are empty,
source the site's Synopsys license/setup script. If they are set but checkout
still fails, the license server must grant this feature to the current user or
host; changing the harness cannot fix that error.

If the local release requires additional VC Formal flags, pass only those
VCF-specific flags without editing the harness:

```sh
make formal FORMAL_ARGS='<site-specific-options>'
```

`formal.f` uses native `fvassume`/`fvassert`/`fvcover` commands because this
VCF release rejects `-sva` in all of those other positions. `check_fv -block`
is used so the script does not exit before proof completion. Record the exact
command, tool version, proof status and any counterexample/witness in the
project log when a server proof is run.

## Reading Results

| Result | Meaning | Next action |
|---|---|---|
| Proven | The assertion holds for all traces under the assumptions. | Review assumptions; a proof is only as strong as its environment constraints. |
| Falsified | Tool found a counterexample. | Inspect waveform, determine RTL bug, assertion bug or missing assumption. |
| Undetermined / timeout | Tool ran out of resources. | Reduce cone of influence, add justified assumptions, or bound/partition proof. |
| Cover reached | Tool found a legal witness trace. | Review it as a protocol/address-decode example. |

Do not use formal assumptions to hide real legal cases solely to obtain a proof.
