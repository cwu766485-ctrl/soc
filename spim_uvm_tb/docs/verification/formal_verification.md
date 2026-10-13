# SPI 项目的 Formal Verification 入门

## 先把最容易混淆的概念分开

你觉得 assertion 和 formal 很像，这个感觉是对的：它们常常共用同一条 SVA。
**差别不在断言文本，而在谁执行它、输入从哪里来、结果代表什么。**

| 项目 | UVM 仿真中的 assertion | VC Formal 中的 assertion |
|---|---|---|
| 同一条性质 | 例如 `!(pos_edge && neg_edge)` | 可以是完全相同的 SVA |
| 输入 | test/sequence/driver 产生的一条具体激励 | 所有满足 `assume` 的 APB/MISO 输入序列 |
| 检查范围 | 只检查本次仿真走到的时钟周期 | 尝试证明任意周期、任意合法路径都不会违反 |
| 成功结论 | 这个 seed/这个 testcase 没碰到错误 | `PROVEN` 才表示在模型与假设内不存在反例 |
| 失败产物 | 当前 testcase 的 VPD/VCD 波形 | formal 自动构造的最短 counterexample trace |
| 风险 | 没激励到 bug，就不会报错 | assumption 写错或过强，可能把 bug 排除在世界之外 |

一句面试回答：

> Assertion 是可执行的设计规则；simulation assertion 在有限 testcase 上监测这条
> 规则，formal assertion 则在环境假设内穷举状态空间，证明它永远成立或给出反例。

## 本项目新增的 formal 结构

```text
spi_formal_harness.sv
  - 实例化真实 spi_top
  - APB/MISO 输入不由 driver 赋值，交给 VC Formal 自由枚举
  - assume：限定合法 APB 形状与初始复位
  - assert：需要证明的设计不变量
  - cover：要求 formal 找到一条“能到达”的 witness trace

spi_formal.tcl
  - 读 RTL + harness
  - 定义 PCLK、PRESETN
  - 启动 FPV，输出 report
```

文件位置：

- [formal harness](../../uvm_spim/formal/spi_formal_harness.sv)
- [VC Formal Tcl](../../uvm_spim/formal/spi_formal.tcl)

## 这次真正证明什么？

| 性质 | 规则的人话解释 | 为什么适合 formal |
|---|---|---|
| `a_no_two_sclk_edge_pulses` | 同一个 PCLK 周期，不能同时说 SCLK 出现上升沿和下降沿。 | 是任意时序下的硬不变量。 |
| `a_reset_forces_idle_outputs` | `PRESETN=0` 时，不可 busy、不可有 SCLK/edge/IRQ。 | 异步复位边界很适合 exhaustive proof。 |
| `a_pslverr_is_tied_low` | 本 SPI 从设备永不返回 APB error。 | 组合/时序都很短，proof 很快。 |
| busy-write 三条性质 | `TIP=1` 时，写 CTRL/DIVIDER/SS 不得改写它们；CTRL 的 GO bit 可在自然完成边沿清零，故只检查其余字段。 | UVM 的 busy-write 只试了几种数据；formal 覆盖任意 `PWDATA` 和发生时刻。 |
| 自动/手动 CS 三条性质 | 自动模式 idle 时全部 CS 高；自动 active/手动时 `ss_pad_o=~ss`。 | 很容易因为模式交叉遗漏，formal 可全部枚举。 |

`cover property` 不是“覆盖率 bin”。它是在问 formal：**是否存在一条合法路径到达
这个场景？** 若存在，工具给 witness；若不可达，结果为 `UNCOVERABLE`。本项目 cover
了“CTRL 写后 busy”“busy 时尝试写寄存器”“自动 CS 激活”。

## 如何运行 Synopsys VC Formal

本机检测到 VC Formal 的启动器位于：

```text
/opt/Synopsys/vcs/V-2023.12-SP1/vcfca/bin/vcf
```

从项目根目录：

```bash
# 批处理证明。输出在 uvm_spim/formal/reports/ 和 formal_session/。
make -C uvm_spim/verif/sim formal

# 故意打开一条错误性质；正确结果应是该性质 FALSIFIED，并产生反例。
make -C uvm_spim/verif/sim formal_demo_fail

# 仅删除 VC Formal 生成的 session/report，不删除 RTL、harness、Tcl 或文档。
make -C uvm_spim/verif/sim formal_clean
```

本项目使用的命令含义：

```text
VC_STATIC_HOME=...   告诉 vcf 自己的安装根目录
vcf -batch            不打开 GUI，适合脚本/回归
-fmode FPV            Formal Property Verification 模式
-f spi_formal.tcl     执行 Tcl：读设计、定义 clock/reset、proof、出报告
```

若想看 GUI，不使用 `-batch`，在 `uvm_spim/formal/` 下执行：

```bash
export VC_STATIC_HOME=/opt/Synopsys/vcs/V-2023.12-SP1/vcfca
$VC_STATIC_HOME/bin/vcf -fmode FPV -f spi_formal.tcl
```

GUI 中重点看三种状态：

| 状态 | 含义 | 下一步 |
|---|---|---|
| `PROVEN` | 给定所有 assumption，这条 assertion 没有反例。 | 检查它是否 vacuous；确认 assumption 没有约束过强。 |
| `FALSIFIED` | 找到违反性质的具体输入轨迹。 | 看 counterexample，判断是 DUT bug、性质写错，还是环境 assumption 缺失。 |
| `UNKNOWN` / `TIMEOUT` | 工具在资源/时间内没证明也没找到反例。 | 简化性质、增加 helper invariant、做 abstraction 或提高 runtime。 |

如果启动阶段提示 `Cannot connect to license server`，这还没有开始 property proof，
不能把它记录为 DUT failure 或 `FALSIFIED`；先修 licence 环境再运行。

## 读一条最重要的性质

三条 busy-write 性质的核心意思是：

```systemverilog
(DUT.tip && APB 正在写 DIVIDER 或 SS)
|=> 下一拍相应寄存器保持不变
```

CTRL 也是同样的写保护，但 RTL 可在传输完成时合法地把 `GO` 清零。因此 formal
检查 CTRL 的其他字段稳定，不把 GO 的自然清零误报为 violation。它不是假设 APB 会
“乖乖不写”：formal 会主动枚举 busy 的第一拍/最后一拍、任意 `PWDATA` 和所有合法
APB 时机；RTL 的 `&& !tip` 门控必须挡住全部 busy write，assertion 才能 `PROVEN`。

这里**不能**要求 `shift.data` 在 `TIP=1` 时稳定：它同时是 RX 接收数据存储，MISO
每采到一位，RTL 都应合法更新它。这个 TX/RX 共享存储的端到端数据语义，仍由 UVM
的 SPI BFM、monitor、scoreboard 来检查。

注意：`PREADY` 是 DUT 输出，因此不能在 assumption 中规定它的值；environment 只约束
APB master 输入的合法行为。写 assumption 的原则是：只描述协议或真实系统保证的事情，
绝不把你想证明的 DUT 行为假设进去。

## 一个刻意失败的教学实验

`make formal_demo_fail` 会定义下面这句错误规则：

```systemverilog
(ASS=1 && TIP=1 && SS!=0) |-> (ss_pad_o == 8'hff)
```

它说“自动 CS 正在传输且选择了从机时，所有 CS 都高”，显然不对。实际正确逻辑是
`ss_pad_o == ~ss`，选中的位应该为低。VC Formal 会自己寻找：写 SS、设 ASS、写 GO，
并给出这条反例。你不需要像 UVM 一样先写 sequence 才能碰到它。

这就是你应该体会到的区别：

```text
仿真：我写一个 testcase 去尝试让 bug 出现。
Formal：我写“bug 绝不出现”的规则；工具替我找所有可能反例。
```

## 它不替代 UVM

Formal 很强，但不会替代这个项目的 SPI agent、scoreboard 或随机回归：

- formal 更适合控制状态机、不变量、仲裁、边界条件、寄存器写保护、死锁/溢出；
- UVM 更适合端到端串行数据语义、真实协议 transaction、长序列、性能和系统交互；
- 对 128-bit SPI data path 做“任意数据、任意长度、任意位序、任意时钟模式”的完整
  end-to-end formal 会迅速状态爆炸，应该分解成小性质，不能靠一条大 assertion 硬证。

面试收口可以说：

> 我在 UVM 中用 scoreboard 做 APB-to-SPI-to-RX 的端到端数据验证，同时对 reset、
> edge pulse 互斥、busy 写保护和 CS 输出关系补充 SVA。随后将这些安全性质放入
> VC Formal，在合法 APB assumption 下做 exhaustive proof；对复杂 128-bit serial
> data path 保留仿真随机/定向验证，避免把 formal 用在不适合的状态空间上。
