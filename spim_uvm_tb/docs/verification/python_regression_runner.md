# Python 回归脚本使用说明

## 它做什么，不做什么

[`run_regression.py`](../../uvm_spim/verif/sim/scripts/run_regression.py) 不替代
UVM，也不产生 SPI transaction。UVM sequence、driver、monitor、scoreboard 仍然
负责验证 DUT；这个 Python 脚本负责：

```text
挑选 testcase
-> 逐个调用原有 Makefile/VCS
-> 保存每个 case 的控制台日志
-> 解析 UVM_ERROR / UVM_FATAL
-> 生成一次回归的 Markdown + JSON 汇总
```

脚本刻意采用**串行**执行。当前 Makefile 的 `simv`、`comp.log` 和部分输出目录
是共享的；直接并发执行会互相覆盖。工业环境若要并行，会为每个 job 创建独立的
build/run 目录，或使用编译缓存和集群调度器。

## 快速开始

从项目根目录执行：

```bash
# 默认：跑 3 个已启用端到端 checker 的 smoke testcase
python3 uvm_spim/verif/sim/scripts/run_regression.py

# 先确认它会执行什么，不启动仿真
python3 uvm_spim/verif/sim/scripts/run_regression.py --suite coverage --dry-run

# 只跑指定 testcase，并固定随机种子
python3 uvm_spim/verif/sim/scripts/run_regression.py \
  --tests spi_shift_mode_test,spi_interrupt_test --seed 20260801

# 回归中某个 case 失败后仍继续，以便一次收集所有失败
python3 uvm_spim/verif/sim/scripts/run_regression.py --suite coverage --seed 7 --keep-going
```

预定义 suite：

| Suite | testcase | 适合何时使用 |
|---|---|---|
| `smoke`（默认） | `spi_poll_test`、`spi_interrupt_test`、`spi_shift_mode_test` | 修改 TB/RTL 后的快速端到端冒烟检查。 |
| `coverage` | 当前 Makefile 的 `COV_TESTS`：传输交叉、模式、busy 写、IRQ、poll、mid-reset。 | 收集并合并 coverage 前。 |
| `all` | 当前 Makefile 的 `TESTS` 全集，包含合并后的 `spi_reg_test`。 | 做完整基线。 |

## 如何看结果

每次真实执行都会创建一个目录：

```text
uvm_spim/verif/sim/logs/regression/20260801_143808/
  spi_poll_test.console.log
  spi_interrupt_test.console.log
  spi_shift_mode_test.console.log
  summary.md
  summary.json
```

- `PASS`：`make all` 返回 0，且 UVM report summary 中 `UVM_ERROR=0`、
  `UVM_FATAL=0`。
- `FAIL`：编译/仿真命令失败，或 UVM report 中有 error/fatal。
- `INCONCLUSIVE`：命令返回 0，但没有找到 UVM report summary。它不能当作通过，
  需要检查对应 console log。
- `INFRA_LICENSE`：VCS 无法取得 licence。这是 EDA 环境问题，不代表 RTL 或
  testcase 功能失败；脚本会停止并保留 console log 作为证据。

波形和 VCS 原始 UVM 日志仍沿用既有路径：
`logs/<testcase>/<testcase>.vpd` 和 `logs/<testcase>/<testcase>.log`。失败后可执行：

```bash
cd uvm_spim/verif/sim
make verdi TEST=spi_shift_mode_test
```

## 这就是验证项目里 Python 的价值

单个 UVM testcase 的功能正确性由 scoreboard/assertion 决定；当 testcase 和
seed 增加到几百上千时，人工逐次执行、记录、筛失败、找日志会成为瓶颈。这个脚本
先把最基本的“编排 + 结果汇总 + 可追溯日志”自动化。后续可以继续加：多 seed、
失败 seed 自动重跑、coverage merge、HTML 报告、独立 run directory 和并行调度。

## Makefile 和 Python 到底怎么分工？

它们的功能有一点重叠，但层次不同，不是二选一：

| 需求 | 更适合谁 | 本项目例子 | 原因 |
|---|---|---|---|
| 执行一个固定 EDA 命令 | Makefile | `make all TEST=spi_poll_test SEED=1` | Make 天生适合声明“这个 target 依赖哪些命令”。 |
| 打开一个波形、合并 coverage | Makefile | `make verdi`、`make merge_cov` | 参数和命令固定，直接透明。 |
| 对一串 testcase 重复执行 | Python | `run_regression.py --suite smoke` | Python 可以维护 list、循环、退出策略和时间戳目录。 |
| 解析数百份 log 并给出结论 | Python | `summarize_logs.py --fail-only` | 正则表达式、JSON、表格输出在 Python 中更自然。 |
| 删除前展示、按类别选择清理 | Python | `clean_sim.py --scope verdi` | Python 可逐个检查路径，默认 dry-run；比长串 `rm -rf` 更安全易读。 |

调用关系是：

```text
run_regression.py
  -> make all TEST=<test> SEED=<seed>
      -> vcs 编译
      -> simv 运行 UVM testcase
  -> 解析 UVM log
  -> summary.md / summary.json
```

所以，**Python 不判断 SPI 协议对不对**。SPI 正确性仍由 UVM scoreboard、SVA、
RAL readback 判断；Python 判断的是“这一批仿真中，哪些 case 通过、日志在哪、
是否属于 licence 等环境故障”。

## 另外两个学习脚本

```bash
# 不运行仿真，只汇总当前已经存在的 UVM log
python3 uvm_spim/verif/sim/scripts/summarize_logs.py

# 只显示失败或不完整的 log
python3 uvm_spim/verif/sim/scripts/summarize_logs.py --fail-only

# 输出 JSON，方便后续接 CI 或网页报告
python3 uvm_spim/verif/sim/scripts/summarize_logs.py --json

# 清理前先展示将删除什么；默认绝不会删除
python3 uvm_spim/verif/sim/scripts/clean_sim.py

# 只清 Verdi 生成物，例如 verdiLog/vdCovLog/vfastLog
python3 uvm_spim/verif/sim/scripts/clean_sim.py --scope verdi --apply

# 等价于全部清理；Makefile 也调用这一条
cd uvm_spim/verif/sim
make clean
```

`clean_sim.py` 只会处理 `sim/` 下明确列出的生成物，绝不删除 RTL、UVM 源码、
coverage 排除规则、Python/Perl 源脚本或文档。执行 `--apply` 前先看 dry-run，是
工程里安全清理的基本习惯。
