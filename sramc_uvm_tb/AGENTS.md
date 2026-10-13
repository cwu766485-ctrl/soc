# AGENTS.md - sramc_uvm_tb project guide

## Project Purpose

This repository is a learning project for migrating an existing SRAM Controller
SystemVerilog verification platform into a UVM-style verification platform.
Follow the course materials under `docs/` and preserve the learning trail:
implement code, explain what changed, and keep the project easy to compare with
the previous SV platform.

Current course focus:

- `docs/*.pdf` - UVM course slides

The PDFs appear to be slide/image based. If text extraction fails, inspect pages
visually or convert selected pages to images before reconstructing code.

## Repository Map

- `rtl/`: local RTL copy for the new `sramc_uvm_tb` work.
- `verify/`: target verification area for the UVM iteration.
- `docs/`: current UVM course PDFs.
- `sram_controller/`: previous SV verification platform and useful reference
  implementation.

The previous SV platform read/debug order is:

1. `sram_controller/verify/tb/tb_top.sv`
2. `sram_controller/verify/tests/test.sv`
3. `sram_controller/verify/env/ahb_sramc_env.sv`
4. `sram_controller/verify/agent/ahb_trans.sv`
5. `sram_controller/verify/agent/ahb_trans_generator.sv`
6. `sram_controller/verify/agent/ahb_master_driver.sv`
7. `sram_controller/verify/agent/ahb_monitor.sv`
8. `sram_controller/verify/env/ahb_sramc_scoreboard.sv`
9. `sram_controller/verify/tb/ahb_sramc_assertions.sv`

Use this SV platform as the behavioral reference while building the UVM version.

## Working Style

- This is primarily a learning repository. After meaningful code changes, explain
  the purpose and role of the new/changed SV or UVM code in Chinese.
- Prefer small, course-aligned iterations over large speculative rewrites.
- Keep names close to the course and existing SV platform unless there is a
  clear reason to diverge.
- Do not silently delete or rewrite the previous SV reference implementation.
- Update a Chinese `update_log.md` after project changes. If a root-level
  `update_log.md` does not exist yet, create one when the first substantial
  implementation change is made.
- Keep generated simulator artifacts out of source control.

## UVM Migration Direction

Map the old SV components to UVM concepts conservatively:

- `ahb_trans.sv` -> `uvm_sequence_item`
- `ahb_trans_generator.sv` -> sequences / sequence library
- `ahb_master_driver.sv` -> `uvm_driver`
- `ahb_monitor.sv` -> `uvm_monitor` with analysis port
- old env glue -> `uvm_agent`, `uvm_env`, config objects
- old scoreboard -> `uvm_scoreboard`
- top-level `test.sv` flow -> `uvm_test` plus `run_test()`
- `ahb_interface.sv` remains the virtual interface boundary
- assertions and system coverage may stay module/interface based at first, then
  be connected from `tb_top` as needed

Use standard UVM phases:

- `build_phase`: create components, get config, assign virtual interfaces
- `connect_phase`: connect driver/sequencer and analysis ports
- `run_phase`: objections and sequence start
- `report_phase` or scoreboard checks: summarize pass/fail

## Build And Simulation

The previous SV reference flow lives in `sram_controller/`:

- `make run`
- `make random_smoke`
- `make random_regression RANDOM_SEEDS=20 REGRESS_TRANS_NUM=200`
- `make coverage_regression`
- `make verdi`
- `make clean`

For the new UVM platform, keep the same spirit:

- maintain a clear `filelist.f`
- compile with VCS and UVM enabled
- dump FSDB only when requested or under an `FSDB` define
- keep compile/sim logs readable and summarize the important failures

Expected Synopsys-style tools on the Linux/VNC server:

- `vcs`
- `verdi`
- `urg`

## Remote/VNC Workflow

The likely workflow is:

1. Use VNC for GUI work, framework generation, waveform, and Verdi debug.
2. Use `scp` or `rsync` to copy the generated framework back to this local
   workspace.
3. Edit code locally with Codex.
4. Copy changes back to the VNC/Linux server.
5. Compile and simulate on the server.
6. Bring back logs, reports, and selected generated files for analysis.

Known connection context from the user:

- VNC endpoint shown in screenshot: `101.254.99.137:5999`
- login username: `stu_wck`

Do not store passwords, tokens, or private server account files in this
repository. Ask the user before using or persisting any credential.

Suggested transfer commands once the remote project path is known:

```sh
scp -r verify rtl filelist.f Makefile stu_wck@101.254.99.137:/path/to/sramc_uvm_tb/
scp stu_wck@101.254.99.137:/path/to/sramc_uvm_tb/sim.log .
rsync -av --exclude 'simv*' --exclude '*.vdb' --exclude 'csrc' ./ stu_wck@101.254.99.137:/path/to/sramc_uvm_tb/
```

Confirm the SSH port and remote project path before running transfer commands.
The VNC port is not necessarily the SSH port.

## Coding Conventions

- Use SystemVerilog/UVM idioms rather than ad hoc string-based control.
- Keep include guards in `.sv` files where the existing style uses them.
- Prefer packages for class definitions and keep `tb_top` responsible for module
  instances, interface instances, DUT connection, and `run_test()`.
- Avoid mixing unrelated refactors into course-step implementations.
- Use Chinese comments sparingly for learning-critical concepts; do not clutter
  obvious assignments.
- Preserve AHB protocol intent from the SV reference platform.

## Verification Expectations

Before calling a step done:

- compile the changed file set if server tools are available
- run at least a smoke test when possible
- inspect `com.log` / `sim.log` for real errors, not just command exit status
- explain any test that could not be run locally

Important behavior from the SV reference to preserve:

- AHB write/read stimulus over `sramc_top`
- monitor collection of accepted AHB transfers
- scoreboard comparison against expected SRAM contents
- reset, BIST, DFT, and coverage-oriented scenarios as the course reaches them
- assertions and functional/system coverage hooks

## Notes For Codex

- Read this file first, then inspect only the files needed for the requested
  course step.
- If a task references a PDF page, inspect that page before implementing.
- When terminal output is mojibake, retry with UTF-8 (`Get-Content -Encoding
  UTF8`) before assuming the source is corrupted.
- Do not paste secrets into logs, docs, or commits.
- The user prefers Chinese explanations and wants to understand the platform, not
  only receive finished code.
