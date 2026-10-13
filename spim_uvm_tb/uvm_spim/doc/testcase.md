# SPI Master UVM 测试计划

运行目录：`uvm_spim/verif/sim`。

```bash
make all TEST=spi_reg_test SEED=1
make cov_regr SEED=1
make merge_cov
make func_urg
```

`spi_test_base` 与 `spi_cov_test_base` 是测试基础类，不作为独立 testcase 回归。

## 当前 testcase

| Testcase | 验证目标 | 通过标准 |
|---|---|---|
| `spi_reg_test` | 统一执行 reset、前门随机写后读回、后门 `poke/peek` 和普通 RAL access。 | 无 RAL/APB/UVM error。`CTRL`、`DIVIDER` 因状态语义由专用 sequence 检查；RXT 寄存器地址写 TX、读 RX，不参加假定写后读回相等的通用 RAL access，由端到端 scoreboard 检查；SS 由项目 sequence 专门检查，不走通用 backdoor restore。CTRL backdoor 比较忽略保留位 7。 |
| `spi_poll_test` | 配置寄存器、写 GO、并行运行从机 responder，轮询完成后读取 RX。 | GO/TIP 正常结束，RX 读回正确，scoreboard 的 MOSI/MISO/RX/CS 检查零 mismatch。 |
| `spi_interrupt_test` | 使能 `IE` 后启动传输，等待完成 IRQ，并检查后续 APB 访问清除 IRQ。 | IRQ 完成时拉高、APB 访问后拉低，端到端 scoreboard 无 mismatch。 |
| `spi_interrupt_mask_test` | `IE=0` 时运行端到端 SPI 传输，并逐周期监视 IRQ。 | 传输数据由 scoreboard 检查；传输期间及结束后 IRQ 始终为低。 |
| `spi_mid_reset_test` | 在 `TIP=1` 的长传输中施加复位。 | DUT 回到 idle，且无 assertion、timeout 或 UVM error。 |
| `spi_transfer_cov_test` | 覆盖时钟发生器边界及 `CHAR_LEN × CLK_DIV` 交叉。分频取 `0,1,2,4,8,16,32,64,128`，长度取 13 个代表值。 | 每笔定向传输完成、无 timeout/UVM error；长度×分频交叉达到 117 个 bin。 |
| `spi_shift_mode_test` | 端到端检查 `ASS/LSB/TX_NEG/RX_NEG` 的 16 种组合。 | MOSI、MISO、RX、CS 的 scoreboard 检查全部通过，16 个模式 bin 全命中。 |
| `spi_busy_write_cov_test` | 在 `TIP=1` 时尝试写 TX、DIVIDER、SS，并启用 SPI responder/scoreboard。 | MOSI scoreboard 检查忙写没有替换当前 TX 流；完成后读回 CTRL/DIVIDER/SS，检查除自然清零的 GO 外状态保持不变。 |

## 协议关键点

- `GO=1` 是软件启动请求；`TIP=1` 表示移位引擎实际传输中。普通寄存器测试保持 `GO=0`，避免意外启动 SPI。
- IRQ 为高有效的传输完成中断，不是启动指示。`IE=0` 时传输仍应完成，但不应产生 IRQ。
- `divider=0` 走 `spi_clgen` 的特殊最快路径；`divider=1` 走普通 `1 -> 0 -> 1` 计数路径。二者均不代表 SCLK 与 PCLK 同频，必须分别覆盖。
- `CHAR_LEN=0` 表示 128 bit；非零值表示实际 bit 数。

## 当前验证范围与收口状态

- SPIM：定向模式、轮询、中断、`IE=0`、忙时写保护和中途复位纳入计划；收口应以当前代码版本的 `make regr`、`make cov_regr`、覆盖率报告及可用的 formal 结果为准。`spi_transfer_cov_test` 单独用于覆盖率收集，不承担端到端串行数据判定；端到端证据由带 SPI responder/scoreboard 的用例提供。
- SRAMC：本项目规格确认 `BYTE` 使用 `HADDR[15]` 选 bank、`HADDR[14:13]` 选 lane；`HALFWORD` 使用 `[14]` 选 bank、`[13]` 选半字；`WORD` 使用 `[13]` 选 bank，`[12:0]` 为行地址。此映射为项目要求，参考模型和用例按该规格验证。
- SRAMC 当前只对合法、正常模式 AHB 路径收口。`HREADY=0`、非法或未对齐访问、窗口外访问、ERROR/RETRY/SPLIT、BIST/DFT 及实际 SRAM macro 的 PVT/时序 signoff 不在本回归范围；实际 macro 仍需独立的库模型/时序检查。
- SRAMC 当前 RTL 已将写数据分发和 HRDATA 组合路径改为完整赋值；Verilator lint 未再报告 latch。真实 SRAM macro 时序及目标工艺 signoff 仍需在集成阶段单独完成。

### 2026-10-08 当前版本本地检查

- 在 Rocky-8.10 WSL、VCS V-2023.12-SP1 下，SPIM 全套回归 seed=1 为 **8/8 PASS**，包含新增的 `spi_busy_write_cov_test` 和 `spi_interrupt_mask_test`；UVM_ERROR/FATAL 均为 0。结果见 `verif/sim/logs/regression/20261008_220148/summary.md`。
- 合并 7 个带覆盖率的 testcase 后，两个 functional coverage group 均为 100%。未应用 exclusion 的 DUT hierarchy code coverage：line 100%、condition 92.41%、toggle 98.86%、assert 100%；应用 `verif/sim/coverage_unreachable.el` 的 URG 报告显示 line 100%、condition 97.99%、toggle 100%、assert 100%。不过 URG 同时报告 `top_tb.DUT` exclusion checksum mismatch，提示部分 exclusions 未应用；需按本次 VDB 重新生成并审核 exclusion 后，才能把 waived code coverage 作为最终签核数据。当前未应用 exclusion 的报告在 `verif/sim/logs/COV/merged_report/`，带 exclusion 的复核报告在 `verif/sim/logs/COV/closeout_report_20261008/`。
- UVM assertion 汇总含 2 个未尝试的 UVM RAL 库 assertion；SPI scoreboard/APB 检查及 DUT bind 的 assertion 均有尝试且无失败，DUT bind 的 3 条 assertion 均有命中。
- VC Formal V-2023.12-SP2：忙时 CTRL（忽略保留 bit7 后）、DIVIDER、SS 写保护，CS truth table 和 PSLVERR 属性共 7 项 proven；3 个 cover 均 covered。`a_no_two_sclk_edge_pulses` 在 120 s effort limit 下 inconclusive，不能计作已证明。报告见 `formal/reports/formal_summary.rpt`，完整运行日志见 `formal/reports/closeout2_20261008.log`。
- SRAMC 当前版本另在相同 Rocky WSL 下运行；详细 regression、coverage、formal 结果与合法 AHB 范围及排除项见 sibling project 的 `../docs/testcase.md`。Icarus/Verilator 结果与 latch 实现风险仍按该文档记录。

### 2026-10-09 当前源码版本复核（覆盖上面的历史快照）

- SPIM 全套 8 个 testcase 分别使用 seed 1、2、3 运行，三组均为 8/8 PASS、UVM_ERROR/FATAL=0。seed 3 曾发现 RX bit 127 被错误改写和首位 MISO 仿真竞争；计数器饱和修复及 responder 预驱动后，24/24 testcase 运行通过。报告分别见 `verif/sim/logs/regression/20261008_235250/summary.md`、`20261008_235511/summary.md` 和 `20261008_235718/summary.md`。
- SPIM 7 个 coverage testcase 的 functional groups 均为 100%。按当前 URG full-exclusion 输出复核并更新 waiver checksum 后，`make urg` 无 checksum warning；DUT hierarchy line/condition/toggle/assert 均为 100%。报告在 `verif/sim/logs/COV/report/`，functional report 在 `verif/sim/logs/COV/func_report/`。2 个 UVM RAL 内部 assertion 被排除；9 个其余 assertions 成功、0 失败，4 个 cover property 全部命中。
- 当前源码版本 VC Formal：8/8 assertions proven、3/3 covers covered，`a_no_two_sclk_edge_pulses` 已 proven。报告见 `formal/reports/formal_summary.rpt`、`formal_assertions.rpt`、`formal_covers.rpt`。形式验证范围限于 harness 中的 APB、忙时写保护、片选和时钟边沿安全属性，不代表 datapath 全等价或完整协议证明。
- SRAMC 最新收口证据：VCS 回归 6 个 testcase × 5 seeds = 30/30 PASS；decoder Formal 5/5 proven、mapping covers 3/3 covered；Verilator lint 未报告 latch。DUT hierarchy line/condition/toggle/branch/assert 分别为 100%/95.77%/100%/93.22%/100%。具体适用 AHB 访问范围和排除项记录在 sibling project 的 `docs/testcase.md`。

## 覆盖率与签核

功能覆盖率在 Verdi **Groups** 或 `logs/COV/func_report` 查看；代码覆盖率只看 `top_tb.DUT`，在 **Hierarchy** 或 `logs/COV/merged_report` 查看。

签核使用 `logs/COV/merged.vdb`，不使用单个 testcase 的 VDB。签核需同时满足：计划测试全部通过、scoreboard 零 mismatch、assertion 无失败、功能覆盖率闭合、DUT 代码覆盖率达到目标，以及不可达项有经过评审的 exclusion 说明。

## 面试要点

1. `spi_reg_test` 将 reset、前门/后门读写和普通 RAL access 合并；`CTRL` 与 `DIVIDER` 因副作用采用专用检查。
2. `spi_transfer_cov_test` 合并 divider 与长度×分频覆盖；`spi_shift_mode_test` 保持独立，便于定位位序和采样边沿问题。
3. Code coverage 反映 RTL 结构是否执行；functional coverage 反映规格场景是否发生。二者都不能单独作为 signoff 证据。
4. raw APB 访问适合定向覆盖和忙时写保护；因其绕过 RAL 前门，使用前需同步 RAL mirror。
