# Python Regression Workflow

## 目的

SystemVerilog/UVM 负责 clock-cycle 级的激励、监测、reference model、
scoreboard、assertion 与 functional coverage。Python 不替代这些组件；它负责
把多组 `test x seed` 仿真组织成可重复、可汇总的 regression。

脚本只使用 Python 标准库，兼容课程服务器常见的 Python 3.6，不需要安装第三方
package。

## 它做了什么

| 脚本 | 职责 | 何时使用 |
|---|---|---|
| `scripts/run.py` | 跑一个 `test + seed`，生成 log/VDB 与 `result.json` | 定位单个失败、复现一个 seed |
| `scripts/regress.py` | 编译一次，生成 test x seed 矩阵并调用 `run.py` | smoke、nightly、指定随机回归 |
| `scripts/collect_results.py` | 将所有 `result.json` 汇总成 `summary.md/json` | 单独重建或检查回归报告 |
| `scripts/coverage.py` | 检查标准 `results/` 下 VDB，再调用 `make cov_txt` | 回归完成后生成 URG 文本报告 |

单项结果默认放在 `verif/sim/results/<test>/seed<seed>/`；每个目录有 log、VDB
和 `result.json`。矩阵结果放在 `results/summary.md`、`results/summary.json`。

脚本与现有 Makefile 的关系：Makefile 仍定义 VCS/URG/Verdi 工具链和单项命令；
Python 只承担复杂循环、结果分类和报告格式化。这是实际 DV 项目常见的分工。

## 常用命令

在 `verif/sim/` 下执行：

```sh
# 单独复现一个 test/seed；不触发编译。
python3 scripts/run.py --test sramc_legal_random_test --seed 17 \
  --run-args '+LEGAL_RANDOM_PAIRS=200 +CROSS_SIZE_READS=3 +PROBE_READS=2'

# 先打印回归矩阵与 plusargs，不运行仿真。
python3 scripts/regress.py --dry-run --tests sramc_test,sramc_legal_random_test --seeds 1-3

# 默认回归：六个 test，各 1~3 seed，编译一次。
python3 scripts/regress.py

# stateful random 加强版：只跑 random test 的 1~20 seed。
python3 scripts/regress.py \
  --tests sramc_legal_random_test \
  --seeds 1-20 \
  --run-args '+LEGAL_RANDOM_PAIRS=200 +CROSS_SIZE_READS=3 +PROBE_READS=2 +BUSY_PCT=20'

# 已编译 simv 时跳过编译。
python3 scripts/regress.py --no-compile --tests sramc_burst_test --seeds 7,11

# 对现有 results/ 中的 VDB 生成 URG 文本报告。
python3 scripts/coverage.py
```

也可用 Makefile 入口：

```sh
make py_regression PY_ARGS='--tests sramc_test,sramc_burst_test --seeds 1-5'

# 对单一失败复现。
make py_run PY_ARGS='--test sramc_legal_random_test --seed 17 --run-args "+BUSY_PCT=20"'

# 在已有 VDB 的前提下产生 URG 文本 coverage report。
make py_coverage
```

## 如何读结果

`summary.md` 是给人看的结果表；`summary.json` 适合后续接 dashboard、趋势图或
失败重跑脚本。一次 run 通过，至少要求：

- `simv` 返回码为零；
- log 没有非零 `UVM_ERROR/UVM_FATAL`；
- log 没有 scoreboard `data mismatch` 或 `[SVA]` 失败。

当前 Python 相对 Makefile 的优势不是“替代一个命令”，而是保留每项仿真的结构化
元数据 `result.json`，再按矩阵生成机器可读的 `summary.json`。这使失败重跑、并发/
集群提交、Git revision 与工具版本记录、趋势 dashboard 都可在不改 SV/UVM 或复杂
Make recipe 的情况下继续扩展。当前仍顺序执行，便于学习并保证日志顺序清楚。
