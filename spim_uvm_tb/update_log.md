# 更新日志

## 2026-08-01 18:57:59 +08 - 迁移项目到 E 盘工作区

- 已将完整项目从 `/home/ray/ic/spim_uvm_tb` 迁移到
  `/mnt/e/workspace/chip/spim_uvm_tb`（Windows 路径：
  `E:\workspace\chip\spim_uvm_tb`），包括 `.git` 历史和当前所有未提交修改。
- 迁移前后已核验 Git HEAD 均为 `4af6ad7`、Git 对象库完整、工作区逐文件内容一致、
  Codex 对话导出文档存在；旧路径已在验证成功后删除。
- 目标仓库设置本地 `core.filemode=false`，避免 Windows DrvFS 将普通文件显示为
  可执行文件而产生无意义的 Git mode change。

## 2026-08-01 18:53:38 +08 - 导出 Codex 项目学习对话

- 新增 `export_codex_history.py`：从本机 `~/.codex/archived_sessions` 中筛选
  `cwd=/home/ray/ic/spim_uvm_tb` 的已归档会话，只导出用户/Codex 文本到项目 docs，
  排除系统提示、环境信息、工具调用和隐藏推理。
- 导出文件位于 `docs/codex_history/spim_uvm_tb_codex_dialogue.md`；当前 live
  对话将在会话结束并归档后，通过再次运行脚本补充导出。

## 2026-08-01 17:27:01 +08 - 新增 Synopsys VC Formal SPI 性质验证

- 新增 `uvm_spim/formal/spi_formal_harness.sv`：以真实 `spi_top` 为 DUT，采用
  symbolic APB/MISO 输入、合法 APB assumption，以及 reset、SCLK edge、PSLVERR、
  busy 写保护、自动/手动 CS 的 assert/cover property。
- 新增 `spi_formal.tcl` 与 Makefile 的 `formal`、`formal_demo_fail`、`formal_clean`
  target；使用本机检测到的 Synopsys VC Formal (`vcf`) FPV 模式。demo target 含一条
  故意错误的自动 CS assertion，用于学习 counterexample。
- 新增中文 `docs/verification/formal_verification.md`，说明 assertion 与 formal
  的区别、assume/assert/cover 的边界、VC Formal 命令与 `PROVEN/FALSIFIED/UNKNOWN`
  结果解读；不替代既有 UVM 端到端数据通路验证。
- 根据 SPI RX/TX 共用 `shift.data` 的真实语义，formal busy-write 性质只检查
  CTRL//SS：接收中的 `shift.data` 可以合法变化，CTRL.GO 可在完成边沿合法
  清零，不能被错误地写成“整个寄存器永远稳定”的 assertion。
- `formal_clean` 同时清理 VC Formal 实际生成的 `*_rtdb` session 目录和 report，
  保留 formal 输入文件；`.gitignore` 覆盖这些 formal 运行产物。

## 2026-08-01 15:24:59 +08 - 整理仿真清理流程与 Python 工具职责

- 修正 Makefile 的 `clean`：改为调用安全的 `clean_sim.py --apply`，现在会清理
  VCS build、根目录或 `logs/` 下的 log/wave/VDB、Verdi 会话（含 `vfastLog`）和 Python cache；新增
  `make clean_logs` 仅清理日志、波形与 coverage 结果。
- 新增 `summarize_logs.py`：不重新编译或仿真，只解析已有 UVM log 的
  `UVM_ERROR/UVM_FATAL`，用于快速定位失败 testcase。
- 删除失效的 `Makefile_questsim`（指向已不存在的旧目录）以及无引用的 Verdi
  临时文件、自动导出的旧 `fullexclude.*` 文件；保留仍被 Makefile 使用的
  `coverage_unreachable.el` 与 `cm_hier.cfg`。
- 扩充 `.gitignore`，避免这些 EDA/Verdi 生成物再次进入版本控制。

## 2026-08-01 14:40:36 +08 - 新增 Python 串行回归脚本

- 新增 `uvm_spim/verif/sim/scripts/run_regression.py`：可选择 smoke、coverage、
  all suite 或指定 testcase，复用原有 `make all`/VCS/UVM 执行流程。
- 脚本按 testcase 保存控制台日志，解析 UVM summary 的 error/fatal，并在
  `logs/regression/<时间戳>/` 下生成 `summary.md` 和 `summary.json`。
- 实跑 `spi_shift_mode_test` 时 VCS 在编译阶段无法连接 licence server；脚本已
  将该类环境故障单列为 `INFRA_LICENSE`，不会误报为 DUT/testcase 功能失败。
- 新增 `docs/verification/python_regression_runner.md`，说明使用命令、结果判定和
  当前为何必须串行执行；不改变 DUT、UVM 激励或 checker 的功能。

## 2026-07-31 20:54:22 +08 - 新增中文 testcase 验证矩阵

- 新增 `docs/verification/testcase_matrix.md`，按 testcase 说明验证点、
  激励、通过判据和覆盖率来源。
- 明确区分 RAL 寄存器测试、带 SPI BFM/monitor/scoreboard 的端到端测试、
  覆盖率定向测试和传输中复位测试，避免将 coverage 命中误认为数据通路已检查。
- 如实记录 `spi_busy_write_cov_test` 的当前缺口：它已覆盖 busy 时的写保护
  分支，但尚缺传输后读回原值的显式功能比较。

## 2026-07-30 16:28:01 +08 - 统一 SPI monitor 边沿字段语义

- 修正 SPI monitor 的边沿采样字段：`pedge_*` 现在保存 SCLK 上升沿
  (`0->1`) 样本，`nedge_*` 保存 SCLK 下降沿 (`1->0`) 样本。
- 同步修正 scoreboard 对 MOSI/MISO 采样字段的选择，保持
  `RX_NEG`/`TX_NEG` 所描述的物理边沿检查不变。
- 清理 monitor 的历史调试打印，并在 transaction 字段定义处记录边沿
  命名约定。该修改是可维护性重构，不改变 DUT 功能或测试意图。

## 2026-07-28 14:59:41 +08 - 修正 SPI 字符长度检查

- 修正验证平台对 `CHAR_LEN` 的解释，使其与 SPI 规格一致：非零值就是
  实际串行传输 bit 数，零才是 128 bit 的特殊编码。
- 删除 SPI slave BFM 和 scoreboard 对非零 `CHAR_LEN` 错误执行的 `N + 1`
  扩展。例如，`CHAR_LEN=32` 现在驱动和检查恰好 32 bit，不再是 33 bit。
- 更新定向传输 helper 注释和 RTL 端口注释，使文档、规格与实现使用同一
  个字符长度定义。
- `spi_shift_mode_test`、`spi_poll_test` 与 `spi_interrupt_test` 均以零
  UVM error 通过，验证上述修复。

## 2026-07-27 - 检查 SPI slave BFM 的 MISO 预期值

- 为 `spi_driver` 到 `spi_scoreboard` 增加 expected-response analysis
  通路。
- driver 在驱动 MISO 前复制并发布每个 `spi_seq_item`；scoreboard 根据
  配置的接收边沿，将 sequence 请求的 `spi_data` 与 `spi_monitor` 实际
  采到的 MISO bit 比较。
- 同时修正 SPI slave driver 的长度处理：当时的实现将
  `spi_seq_item.no_bits` 视为 DUT `CHAR_LEN` 编码，非零值 N 被当作
  `N+1` 个串行 bit。原循环遗漏最后一个 MISO bit，因此 driver 与
  expected-MISO checker 当时使用相同的解码长度。
- 修正两种 MISO 采样模式的首 bit 对齐。在 `RX_NEG=1` 模式中，旧 driver
  在第一个上升沿就推进到 bit 1，导致主机在紧接的下降沿采样 bit 0 时得到
  错误数据；现在会维持 bit 0 直到首次采样完成后才推进。
- 该修改关闭了一个验证盲区：此前 RX checker 只比较 monitor 观察到的 MISO
  与 DUT RX 存储值；如果 driver 稳定地驱动了错误 MISO 数据，检查可能误通过。
- 既有 DUT 检查保持不变：RAL 中的 TX/配置仍与 MOSI/CSn 比对，monitor
  观察到的 MISO 仍与 DUT RX 数据比对。

## 2026-10-08 - 补齐 SPIM 忙写与屏蔽中断检查

- `spi_busy_write_cov_test` 现在启用 SPI responder/scoreboard，在写保护寄存器前确认传输处于忙态；传输完成后读回 CTRL、DIVIDER、SS，检查 busy-time writes 未改变配置。由于 TX/RX 共用移位寄存器，TX 写保护由 MOSI scoreboard 对原始发送流作端到端检查。
- 新增 `spi_interrupt_mask_test`：IE=0 时发送一笔 SPI 传输，scoreboard 检查串行数据，监视器逐周期检查 IRQ 保持低；加入 Makefile 和 Python smoke/coverage/all suites。
- 当前环境中 Icarus 编译 `spi_top` 通过；SPIM `make comp` 因缺少 `/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs` 失败，新增 UVM 用例尚未执行。当前版本 regression/coverage/formal 结果仍待具备 VCS/VC Formal 的环境复跑。

## 2026-10-08 - Rocky WSL 当前版本复跑结果

- 上一段“工具缺失、尚未复跑”的记录只反映默认 WSL 发行版。切换到 Rocky-8.10 后，使用 VCS V-2023.12-SP1 完成 SPIM 回归：seed=1，8/8 testcase PASS，UVM_ERROR/FATAL=0；新增忙时写保护读回和 `IE=0` 无 IRQ 检查均通过。
- 7 个 coverage testcase 的两个 functional coverage group 均为 100%。DUT hierarchy 未应用 exclusion 的 line/condition/toggle/assert 为 100%/92.41%/98.86%/100%。带 exclusion 的 URG 报告提示 `top_tb.DUT` checksum mismatch，需更新和审核 `coverage_unreachable.el` 后再作为正式 waived code-coverage 签核依据。
- VC Formal V-2023.12-SP2 复跑中，修正了 busy-CTRL assertion 对保留位 bit7 的误检查后，7 条 assertion proven、3 个 cover covered；`a_no_two_sclk_edge_pulses` 在 120 s effort limit 下 inconclusive，不能计为 proven。报告在 `uvm_spim/formal/reports/formal_summary.rpt`。

## 2026-10-09 - 修复边界采样并完成当前版本收口复跑

- 定位 seed 3 的两项最高位错误：`spi_shift` 在计数器到零时仍递减，导致 8 位计数下溢并可能写到 RX bit 127；SPI slave BFM 则可能在零分频首个采样沿后才收到 transaction 并驱动 MISO 首位。RTL 计数器现在停在零，virtual sequence 先启动 responder，driver 在 CS 有效前预驱动首位。
- Rocky-8.10 / VCS V-2023.12-SP1 下全套 8 个 testcase 使用 seed 1、2、3 各跑一次，三份报告均为 **8/8 PASS**，共 24/24 testcase 运行，UVM_ERROR/FATAL=0。seed 3 报告：`uvm_spim/verif/sim/logs/regression/20261008_235718/summary.md`；seed 1/2 报告分别在 `20261008_235250`、`20261008_235511`。
- 重新生成 7 个 coverage testcase 的 VDB、合并数据库和 URG 报告；两个 functional coverage group 均为 100%。按当前 `fullexclude.cond` 审核并刷新 `coverage_unreachable.el` 中的当前 checksum/condition ID 后，URG 不再报 checksum mismatch；DUT hierarchy line/condition/toggle/assert 均为 100%。11 个 assertion 中 9 个成功、2 个为 UVM RAL 内部已排除项，失败数为 0；4 个 cover property 均命中。
- 当前源码版本重新运行 VC Formal：8/8 assertion proven（含此前 inconclusive 的 `a_no_two_sclk_edge_pulses`），3/3 cover covered。结果见 `uvm_spim/formal/reports/formal_summary.rpt`、`formal_assertions.rpt` 和 `formal_covers.rpt`。
- SRAMC 同期收口结果记录在 sibling project：VCS 回归 6 testcase × 5 seeds = 30/30 PASS，decoder Formal 5/5 proven、mapping cover 3/3 covered，Verilator lint 不再报告 latch；适用范围和排除项见其 `docs/testcase.md`。
