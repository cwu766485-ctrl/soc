# SPI UVM 面试题与参考答案

### 1. 你的验证平台架构是什么？
标准回答：
平台以 UVM 为基础，包含 APB agent、SPI slave agent、RAL model、SPI environment、scoreboard、coverage subscriber 和 SVA。APB agent 配置 DUT 寄存器，SPI slave BFM 在 MISO 上提供从机数据，SPI monitor 从真实 MOSI/MISO/SCLK/CS 引脚重建 transaction。scoreboard 同时检查 TX 到 MOSI、BFM 请求到实际 MISO、实际 MISO 到 DUT RX，并通过 RAL readback 进一步验证 APB 可见结果。

### 2. seqlib 是做什么的？
标准回答：
seqlib 是 sequence library，放可复用的 APB sequence、SPI sequence 和 virtual sequence。testcase 不直接堆大量 bus 操作，而是组合和配置这些 sequence。这样激励复用、层次清楚，也便于把“寄存器配置”“SPI 从机回传”“中途 reset”等并发行为组织为 virtual sequence。

### 3. 为什么需要 SPI monitor，driver 不是已经知道发了什么吗？
标准回答：
driver 只表示验证环境计划驱动什么，不能代表 DUT 真正看到了什么。monitor 从真实接口采样，能够发现 driver 时序错误、DUT 时序错误、采样边沿错误和连线错误。scoreboard 应以 monitor 的实际观测为依据，而不是只信 sequence 或 driver 的预期值。

### 4. RX_NEG 与 TX_NEG 分别影响什么？
标准回答：
TX_NEG 决定 DUT 在 SCLK 哪个边沿更新 MOSI；RX_NEG 决定 DUT 在哪个边沿采样 MISO。两者组合形成不同 SPI 时序模式，因此 monitor 必须按物理 posedge/negedge 保存采样数据，scoreboard 再按 CTRL 的 TX_NEG/RX_NEG 选择正确边沿进行比较。

### 5. 你遇到过什么验证平台 bug？
标准回答：
遇到过两个关键问题。第一，SPI slave BFM 在 RX_NEG=1 模式下第一次采样前过早把 MISO 从 bit0 更新到 bit1，导致首 bit 对齐错误；修复为保持 bit0 直到第一个有效采样边沿完成。第二，monitor 原先把真实正、负边沿采样数据存反了；后续统一为 pedge=0->1、nedge=1->0，并同步修改 scoreboard 的选择逻辑。

### 6. CHAR_LEN=0 为什么代表 128 bit？
标准回答：
CHAR_LEN 字段只有 7 bit，无法直接编码 128，因此采用特殊编码：0 表示最大长度 128，非零数值表示实际 bit 数。BFM、scoreboard、test sequence 和覆盖率模型必须使用同一语义，否则会出现一边发 32 bit、另一边按 33 bit 检查的假错误。

### 7. 代码覆盖率和功能覆盖率有什么差别？
标准回答：
代码覆盖率反映 RTL 是否被执行，例如 line、condition、toggle、FSM、assertion；功能覆盖率反映规格定义的场景是否发生，例如 16 种 SPI mode、寄存器读写交叉、长度×分频组合。代码 100% 不代表规格覆盖完整，功能覆盖率 100% 也不代表所有 RTL 分支都执行，因此需要两者交叉收敛。

### 8. 为什么 DUT 覆盖率要排除 APB interface 或 UVM package？
标准回答：
sign-off 的 DUT code coverage 应仅衡量设计 RTL。APB interface、agent、UVM package 属于验证基础设施，纳入统计会稀释或污染 DUT 覆盖率。因此编译阶段用 cm_hier.cfg 限定到 top_tb.DUT；合理的不可达 RTL 项则通过有理由的 exclusion file 管理。

### 9. 为什么还要 Formal？
标准回答：
仿真只能证明已激励到的 testcase 和 seed；Formal 在 APB 协议假设下穷举状态空间，适合证明 reset 不变量、边沿互斥、busy 写保护、CS 输出关系等控制性质。复杂的 128-bit 端到端数据路径状态空间太大，仍由 UVM BFM、monitor 和 scoreboard 处理。因此两者是互补关系。

### 10. 你如何定义 scoreboard 的参考模型？为什么不能只比较 TX 和 RX 寄存器？

标准回答：
参考模型应从真实 monitor 事务构建，而不是只读取 sequence 的期望值。对每一笔事务，保存 APB 写入的 TX 帧、CTRL 的位序和边沿配置、SS/ASS 状态；再按 DUT 实际产生的 SCLK 边沿，预测 MOSI 序列、应该采样 MISO 的边沿以及最终 RX 帧。这样可以分别定位配置错误、串行波形错误、从机响应错误和 RX 装载错误。

举例：软件写入 `TX=8'hA5`，从机返回 `RX=8'h3C`。如果 DUT 在第 4 个 bit 把 MOSI 提前改变了一拍，但后面仍然采到了正确的 MISO，最终 RX 可能仍是 `3C`。只比较 RX 会误以为通过；逐位比较 monitor 采集的 MOSI，才能发现中间那一拍错误。最终数据是结果检查，中间波形是过程检查，两者都需要。

当前 scoreboard 已检查 MOSI、MISO、RX 和 CS；SCLK 是否多出边沿、边沿间隔是否正确、CS 是否提前释放，最好由独立 SVA 或协议 checker 检查，不要把所有协议规则都堆进 scoreboard。

“monitor 与 scoreboard 共享同一个错误的边沿/位序假设”是一个风险示例：如果二者都把上升沿当成下降沿，或者都把 MSB-first 当成 LSB-first，那么它们会一致地错，测试可能假通过。解决办法是 monitor 只记录真实引脚和真实物理边沿，scoreboard 根据规格独立计算期望，再用 assertion 检查边沿互斥、边沿数量和 CS 时序。

追问：如果 monitor 没有看到完整 CS 事务怎么办？

标准答案：
不能简单把它当作数据 mismatch。应在 monitor 增加事务超时、CS 开始/结束状态和 bit 数检查，并让 scoreboard 报告“事务未闭合”；同时保留 APB 配置日志，区分 DUT 没拉 CS、monitor 采样条件错误和测试在传输中结束三类原因。

## 11. 为什么 `spi_shift_mode_test` 不能只看 16 个 coverage bin 命中？

标准回答：
覆盖 bin 只证明四个控制位组合曾在 GO 写入时被采样，不证明该模式的串行行为正确。可以把 coverage 理解成“这道题做过”，把 checker 理解成“答案是否正确”。每种模式还必须有有效从机响应、正确的 MOSI 位序、TX/RX 边沿关系、CS 生命周期和 RX readback。当前测试保留 SPI agent 和 scoreboard，正是为了把“场景发生过”和“功能正确”分开。

追问：16 个组合是否都一定是系统支持的合法 SPI mode？

标准答案：
不一定。ASS 是片选控制，LSB 是位序，TX_NEG/RX_NEG 是 DUT 的两个独立边沿选择；16 个组合是 RTL 控制空间的覆盖，不等于外部从机协议都推荐。规格若限制某些组合，应将其标为非法配置并增加 negative test，而不是盲目要求所有 bin 都成为 signoff 目标。

## 12. 这个项目为什么把 `CTRL` 和 `DIVIDER` 排除在通用 `uvm_reg_access_seq` 之外？

标准回答：
通用 RAL access 假设寄存器像普通存储单元一样：写入什么，随后就能读回什么。但 CTRL.GO 是“写 1 触发动作”的命令位，传输完成后 DUT 又会自动清零；DIVIDER 在 TIP=1 时不能写，写入可能被硬件忽略。若直接使用通用 sequence，合法的状态变化可能被误报成 readback mismatch。当前 `spi_reg_test` 将普通 RW 寄存器交给通用 sequence，将 CTRL/DIVIDER 交给专用 sequence，在明确的 idle/busy 状态下分别检查 reset、前门、后门和行为。

追问：排除是否等于不验证？

标准答案：
不是。排除只代表不使用“不理解副作用”的通用序列；CTRL/DIVIDER 仍由 `check_regs_seq`、端到端传输、divider coverage 和 busy-write test 验证。测试计划必须记录每个排除寄存器由哪一个专用 testcase 闭环。

## 13. raw APB 访问后为什么要手动 `predict` RAL mirror？

标准回答：
RAL model 是验证环境里的寄存器地图和镜像，不是 DUT 内部寄存器本身。raw sequence 直接在 APB 引脚上写数据，不经过 RAL adapter/predictor，因此 RAL model 不一定知道 DUT 已被写入什么。如果 coverage subscriber 在 GO 写入时读取 `spi_rm.ctrl`、`spi_rm.divider`，未预测的 mirror 就会保留旧值，导致 coverage 采到旧配置。解决方式是 raw write 后显式 `predict`，或让 APB monitor 接入 RAL predictor。predict 只是让模型跟上 DUT，不是证明 DUT 写对了；正确性仍靠 readback/checker。

追问：`predict` 能证明 DUT 写对了吗？

标准答案：
不能。`predict` 只是同步模型状态，不是 checker。真正的正确性仍要靠 APB readback、RAL mirror(UVM_CHECK)、scoreboard 或 assertion；否则可能出现 model 和 DUT 一起被错误期望“污染”的假通过。

## 14. APB driver 为什么必须区分 setup、access 和 PREADY？

标准回答：
APB 一笔传输至少包含 setup 和 access 两阶段：setup 中 PSEL=1、PENABLE=0，access 中 PENABLE=1，地址/方向/数据保持稳定直到 PREADY=1。driver 若提前改变地址或在 PREADY 前结束，会违反协议；monitor 和 assertion 应检查这些稳定性要求。当前 DUT 的 PREADY 是完成信号，所以 sequence 不能只等待固定延时。

追问：如何验证“PREADY 前地址稳定”？

标准答案：
在 APB interface 或 protocol checker 中写 `PSEL && PENABLE && !PREADY |=> $stable({PADDR,PWRITE,PWDATA})`，并对 wait-state 场景定向拉低 PREADY 或让 DUT 保持多周期，从而证明 checker 真被激励。

### 15. 如何验证忙时写保护确实“写入被忽略”，而不是仅仅覆盖了 if 分支？

标准回答：
“覆盖 if 分支”只说明执行过 busy guard，不能说明寄存器真的保持原值。正确做法是：保存启动前快照，例如 DIVIDER=8、SS=1、TX=A5；TIP=1 时写入不同的 DEAD_BEEF、divider=1、SS=2；传输完成后逐项 APB readback，并检查整个传输仍使用原 TX、divider 和 SS。这样才证明写入被忽略，而不是只证明代码走过该分支。

### 16. 你会怎样处理中途 reset 导致的 scoreboard mismatch？

标准回答：
中途 reset 会合法地截断一笔 SPI 事务，因此不能把“少了几个 bit”直接按普通数据 mismatch 报错。test 应在 reset 前通知 responder/scoreboard 取消当前事务，或让 scoreboard 识别 reset flush；reset 释放后重新检查 tip、SCLK、IRQ、CS 和寄存器 reset 值。若 reset 后仍观察到边沿、残留 CS 或 IRQ 未清，才是 DUT 错误。

追问：为什么不能简单关闭 scoreboard？

标准答案：
可以在专门的 mid-reset test 中暂时关闭“未完成帧数据比较”，但不能关闭 reset 后状态检查和 assertion；否则会把 reset 泄漏、IRQ 残留或错误恢复隐藏掉。

### 17. 断言 `a_go_starts_transfer` 使用 `$rose(go) |-> tip` 有什么时序风险？

标准回答：
`|->` 是重叠蕴含，后件在同一个采样点检查。若 GO 和 tip 都在同一 PCLK 的非阻塞赋值中更新，断言采样到的 tip 可能仍是旧值，导致合法设计被误报；若规格定义 tip 下一拍才有效，应使用 `|=> tip`，或明确断言 `$rose(go) |-> ##[0:1] tip`。应结合 RTL 更新时序和仿真波形确认采样语义，不能只看自然语言注释。

### 18. Formal 报告 `PROVEN`，为什么还要检查 vacuity？

标准回答：
性质 `A |-> B` 在所有轨迹中都可能因为 A 从未发生而平凡成立。Formal 的 `PROVEN` 只说明在当前 assumption 下找不到反例，不保证触发条件可达。必须为关键前件增加 `cover property`，例如 cover GO 启动、TIP 忙时写、复位期间状态；并审查 APB/复位 assumption 是否过强。

追问：如果 cover 是 `UNREACHABLE`，你怎么判断是设计问题还是环境问题？

标准答案：
先逐条放宽 assumption 做可达性实验，再检查 harness 的端口连接、复位极性、时钟定义和触发条件。若放宽后可达，说明 assumption 过强；若仍不可达，再回到 RTL 状态机确认规格是否真的允许该场景，并把结论记录为 reviewed exclusion 或规格约束。

# 资深题

## 19. 如果让你为这个项目制定 signoff closure plan，你会按什么顺序做？

标准回答：
先建立需求—寄存器—sequence—checker—coverage 的追踪矩阵；再跑 compile/elaboration smoke，确认环境和 RAL 连接；然后跑 `spi_reg_test`、poll/interrupt/shift 三类功能测试，确保 scoreboard 和 assertion 干净；再跑 transfer、busy-write、mid-reset 覆盖回归并合并 VDB；最后分别审查 DUT code coverage、functional groups、assertion coverage 和 Formal proof/vacuity。所有 exclusions 必须有 RTL/规格依据、责任人和复审记录。

## 20. 回归出现“UVM_ERROR=0 但结果 INCONCLUSIVE”，你是否判 PASS？

标准回答：
不能。若日志没有可靠的 UVM report summary、进程返回码非零、发生 license/编译错误，或者 scoreboard 根本未创建，必须判为 FAIL 或 INCONCLUSIVE，不能用“没有看到 error”代替通过。当前 Python runner 将 license 问题单独标成 `INFRA_LICENSE`，并保留 console log 作为证据。

## 21. 如果功能覆盖率只有 92%，你如何决定是补 testcase、改 bin 还是加 exclusion？

标准回答：
先定位未命中的具体 bin 和采样条件，确认是 stimulus 未到达、monitor/coverage 采样 bug、bin 定义错误，还是规格不可达。可达场景补 sequence；采样错误修 coverage/monitor；规格不允许的场景才写 reviewed exclusion。不能为追求百分比直接删除 bin 或放宽采样条件。

## 22. 这个单帧 128-bit SPI Master 的架构瓶颈是什么？验证如何体现？

标准回答：
当前 RTL 只有一组 128-bit 帧寄存器。传输开始后 TIP=1；为了保护正在移位的数据，DUT 禁止软件再写 TX、DIVIDER、SS。因此“不支持忙时装载下一帧”就是：第一帧还没发完时，CPU 不能把第二帧提前写进 TX 缓冲区，只能等 TIP 清零后再写。

“吞吐受 APB 软件干预限制”可以按时间线理解：`CPU/APB 写第一帧 -> SPI 发送 -> 轮询或中断确认完成 -> CPU/APB 写第二帧 -> SPI 再发送`。每帧之间都有 APB 配置和软件等待空隙，SPI 引脚可能空闲，下一帧却还没装载，所以连续数据流的有效带宽低于单帧 SPI 时钟速率。DMA 可以减少 CPU 参与，但单帧寄存器本身仍要求等待 TIP 清零。

如果需求变成 DMA/连续流，就需要 TX FIFO 和 RX FIFO。TX FIFO 可在当前帧发送时排队后续帧，RX FIFO 可暂存已收到但软件尚未读取的数据。验证还要增加入队/出队顺序、empty/full 边界、满时写入、空时读取、溢出/下溢、连续 burst，以及 DMA 与 SPI 同时运行场景；FIFO 引入的是队列状态和并发读写协议，不只是多几个寄存器。

## 23. 你发现 scoreboard 与 monitor 都通过，但芯片仍可能有问题吗？

标准答案：
可能。若 monitor 与 scoreboard 共享同一个错误的边沿/位序假设，二者会一致地“错”；若只检查最终 RX，也可能漏掉中间 MOSI、CS 脉宽或额外 SCLK 边沿。因此参考模型应独立于 driver，monitor 要做物理接口协议检查，并结合 SVA、波形、RAL readback 和 Formal 控制性质形成交叉证据。
