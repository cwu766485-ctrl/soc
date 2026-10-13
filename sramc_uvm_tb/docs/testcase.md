## 规格、范围与 2026-10-08 本地复核

项目规格已确认当前 SRAM 地址映射：BYTE 用 `HADDR[15]` 选 bank、`[14:13]` 选 byte lane；HALFWORD 用 `[14]` 选 bank、`[13]` 选低/高半字；WORD 用 `[13]` 选 bank；行地址均为 `[12:0]`。参考模型和 testcase 按此映射检查，这是本项目要求的映射。

本验证只覆盖合法、对齐、64 KiB 窗口内的正常模式 AHB 访问，并假定 zero-wait/OKAY。`HREADY=0`、非法/未对齐/窗口外访问、ERROR/RETRY/SPLIT、BIST/DFT 和实际 SRAM macro 的 PVT/时序验证不在当前 UVM/formal 收口范围内。

SRAM 写数据输入现在在每拍默认驱动 0，只覆盖被选中的有效 lane；非读周期的 `HRDATA` 默认输出 `SUB_DATA`。有效读数据仍由 `sram_read` 选择，非读周期不参与 AHB 读数据比较。该实现避免了原先 8 个 `sram_cs*_data_in` 和 `sram_data_out` 的组合保持 latch。Verilator 对 `sram_core` 和 `ahb_slave_if` 的 lint 未报告 latch；VC Formal elaboration 的 gate count 也显示 `Latch Bitwise 0`。剩余 Verilator `CASEWITHX` 提示来自行为 SRAM 模型的 X/Z `casez` 分支。实际 SRAM macro 的 PVT/时序仍不在本项目签核范围内。

### 2026-10-08 Rocky WSL 当前版本回归与证明

- 在 Rocky-8.10 WSL、VCS V-2023.12-SP1 下运行 `make regression REGRESS_SEEDS=1-5`：6 个 testcase × 5 个 seed 共 30/30 PASS，UVM_ERROR/FATAL=0，scoreboard mismatch=0。结果见 `verif/sim/results/summary.md`，逐用例日志在 `verif/sim/results/<test>/seed<seed>/`。
- `sramc_legal_random_test` 在同一物理 row 上定向访问 BYTE/HALFWORD/WORD 别名；reference model 和 scoreboard 检查数据。合并 30 份 VDB 后，两个 functional coverage group 均为 100%，`WRITE_SIZE × READ_SIZE × PHYSICAL_BANK` cross 为 18/18 bins。报告见 `verif/sim/urgReport/dashboard.txt`、`verif/sim/urgReport/groups.txt`。
- DUT hierarchy line/condition/toggle/branch/assert coverage 为 100%/95.77%/100%/93.22%/100%。9/9 DUT SVA assertion 均有尝试且无失败，6/6 cover property 命中；另有 2 个未尝试 assertion 属于 UVM RAL 库，不属于 DUT。
- VC Formal V-2023.12-SP2 当前工作区 proof：5/5 AHB response/bank decoder assertion proven，3/3 mapping cover covered；elaboration gate count 为 0 latch。范围见 `verif/formal/formal.f`；proof 不覆盖 `HREADY=0`、非法/未对齐访问、BIST/DFT 或 SRAM macro 行为。
- 五 seed campaign 提高了随机回归样本量，但不替代未覆盖协议/DFT 场景；实际 SRAM macro 的 PVT/时序仍需独立验证。

| 验证点 | 激励怎么做 | 怎么判定通过 | 覆盖怎么收 |
|---|---|---|---|
| 基础单拍 WORD 读写 | `sramc_test`：20 个 word 地址写后读，再测全 1 数据 | refm 预测 + scoreboard 比较；`mismatched_beats=0` | read/write、WORD、数据 0/non-zero/all-ones |
| HSIZE | `sramc_testcase_test`：BYTE/HALFWORD/WORD 写后读 | scoreboard 按 8/16/32-bit mask 比较；SVA 检查合法 HSIZE 与对齐 | BYTE/HALFWORD/WORD bins；SVA cover property |
| 地址窗口与 bank 边界 | testcase 访问 `0x0`、`0x7ffc`、`0x8000`、`0xfffc` 等 | refm/scb 数据一致；SVA 检查地址位于 64 KiB、下拍恰好选一个 bank | low/high edge、bank 边界、read/write cross |
| SRAM bank/row/lane | stateful random 随机 write，按物理位置读取 | physical refm 按 DUT 同款 bank-row-lane 映射预测数据 | physical bank、lane0~3、low/high/interior row |
| 跨 HSIZE partial write/read | 大随机随机 BYTE/HALFWORD/WORD write，再以不同 HSIZE read | refm 合并 lane 后预测；scoreboard 比较 actual `HRDATA` | `write HSIZE × read HSIZE × bank` cross |
| SINGLE / INCR / WRAP burst | `sramc_burst_test` 覆盖全部 HBURST 和三种 HSIZE；random 继续扩展 | monitor 重组完整 beat 队列；refm/scb 逐 beat 比较 | HBURST、beat count、burst×size×read/write |
| INCR 不定长 | legal random 对 INCR 随机 2~16 beat，driver 用 IDLE 结束 | monitor 在 IDLE 后发布重组的 INCR；scb 逐 beat 比较 | 2~3、5~7、9~15 等 beat-count bins |
| WRAP 地址回绕 | directed burst 从 wrap 窗口末拍起始 | monitor/refm 依据真实地址队列比对数据 | WRAP4/8/16 bins；burst×HSIZE |
| BUSY | burst 中随机插入；定向 burst 对非 SINGLE write 强制 BUSY | monitor 保留 burst 上下文、正确记录 BUSY；数据不丢拍 | has-busy、busy-cycle count、burst×BUSY cross |
| reset recovery | 正常写读 -> reset 两周期 -> 再写读 | reset 后 monitor 状态清空；恢复后 scb 无 mismatch | reset transition；回归中包含该 test |
| AHB response | DUT 固定 zero-wait / OKAY | SVA 检查 `HREADY_RESP==1`、`HRESP==OKAY` | SVA assertion coverage |
| SVA 协议/译码 | 所有 testcase 自动运行 | 无 `[SVA]` 错误：HSIZE、地址范围、对齐、bank 冲突、CSN 编码等 | assertion coverage + code `-cm assert` |

## Testcase 完整说明

### `sramc_test`

基础 smoke testcase。通过 `ahb_seq_rw` 发送 20 个 WORD 写、20 个 WORD
读，以及 `0xffff_ffff` 数据的写读。它主要确认 UVM agent、driver、monitor、
reference model、scoreboard 和 DUT 的基本连接正确。

### `sramc_testcase_test`

定向 HSIZE、bank 和地址边界 testcase。它分别对 BYTE、HALFWORD、WORD
访问指定地址，并在写入后立即读取，避免项目规定的 bank/lane 映射造成后续
场景之间的物理别名干扰。它还插入 BUSY 空拍，确认 BUSY 不会被 monitor
误认为有效数据传输。

### `sramc_burst_test`

定向 burst testcase，遍历：

- `SINGLE`、`INCR`、`WRAP4/8/16`、`INCR4/8/16`
- `BYTE`、`HALFWORD`、`WORD`
- read/write 方向

对非 `SINGLE` 的 write burst 强制在每个相邻有效 beat 之间插入 BUSY，保证
BUSY 路径确定性命中。这里的 HTRANS 不是随意随机：首 beat 固定为
`NONSEQ`，后续有效 beat 固定为 `SEQ`，BUSY 只作为中间空拍插入。

### `sramc_boundary_test`

定向地址边界 testcase，访问 64 KiB 窗口低端、高端、bank 边界和 WRAP
窗口边界，覆盖各种 HSIZE 和 HBURST。它验证地址没有越界、截断或错误
回绕，并检查边界处的物理 bank/lane 译码。

### `sramc_legal_random_test`

这是项目中的大随机 testcase。它不是把每个 AHB pin 独立随机，而是随机化
合法的 transaction 语义，再由 sequence/driver 按 AHB 规则生成 HTRANS：

| 随机对象 | 当前行为 |
|---|---|
| 读写方向 | 随机 `READ/WRITE` |
| HSIZE | 随机 `BYTE/HALFWORD/WORD` |
| HBURST | 随机 `SINGLE/INCR/WRAP4/8/16/INCR4/8/16` |
| 起始地址 | 在 64 KiB 窗口内随机，并满足 HSIZE 对齐和 burst 边界 |
| 写数据 | 随机 data seed |
| INCR 长度 | 默认 2~16 beat，可由 `+INCR_MAX_BEATS` 修改 |
| BUSY | 默认 20% 概率在有效 beat 之间插入 |
| BUSY 持续周期 | 默认 1~3 cycle，可由 `+MAX_BUSY_CYCLES` 修改 |
| cross-size read | 默认每次 write 后 2 次，从已初始化物理 lane 随机选择读 HSIZE |
| probe read | 默认每次 write 后 1 次，不要求地址之前被写过 |

HTRANS 的生成规则是：

```text
NONSEQ -> [BUSY ...] -> SEQ -> [BUSY ...] -> SEQ -> IDLE
```

因此可以说 HTRANS 的“位置和时序”被覆盖了，但不能说 HTRANS 被独立
无约束随机化。独立随机 `HTRANS` 会产生孤立 `SEQ`、首拍 `BUSY`、非法
burst 结束等协议错误；当前做法是随机 burst 语义和 BUSY 插入点，再派生
合法 HTRANS。

大随机的核心是 stateful：sequence 保存已经写入的 physical bank/row/lane，
后续 read 可以使用不同 HSIZE 读取同一物理 SRAM word。因此它能覆盖：

```text
WORD write -> BYTE/HALFWORD overlay write -> WORD read
BYTE write -> HALFWORD/WORD read
不同 AHB 地址 -> 同一 physical row/lane
```

参考模型按 RTL 的 bank-row-lane 映射合并 partial write，scoreboard 按
实际 monitor 观察到的读数据逐 beat 比较。

常用运行方式：

```sh
make legal_random RUN_ARGS='+LEGAL_RANDOM_PAIRS=200 +BUSY_PCT=20 +MAX_BUSY_CYCLES=3'
make regression REGRESS_SEEDS="$(seq -s ' ' 1 20)"
```

### `sramc_reset_recovery_test`

先执行正常写读，再将 reset 拉低两个 AHB 周期，释放后重新执行写读。
它验证 reset 后总线和 UVM monitor 状态能够恢复；数据正确性由
reference model 和 scoreboard 检查，SVA 在 reset 释放后继续检查协议性质。

## 各检查器的职责

```text
sequence/driver 产生合法激励
        |
        v
monitor 采集 DUT 实际接受的总线行为
        |
        +--> reference model: 预测 physical SRAM 数据
        +--> scoreboard: 比较 expected/actual read data
        +--> coverage: 采样实际 transaction 和 mapping cross
        +--> SVA: 每个时钟检查协议/译码不变量
```

Formal harness 位于 `verif/formal/`，它不运行上述 UVM testcase；它直接
把自由 AHB 输入接到 `ahb_slave_if`，用 assume 限制合法环境，再证明
assert property。也就是说，UVM testcase 和 Formal harness 是两条不同
执行路径，不能把 `make prove` 理解成运行 `sramc_legal_random_test`。

## 从 Spec 到 VPlan

VPlan 不是“把所有信号都随机一遍”，而是把每条 spec requirement 变成
一条可追踪的验证闭环：

```text
Requirement
    -> Stimulus
    -> Checker
    -> Coverage
    -> Test / Regression
```

每个验证点至少回答五个问题：

1. DUT 应该实现什么行为？
2. 什么激励能触发这个行为？
3. 用什么 checker 判断对错？
4. 用什么 coverage 证明场景确实发生过？
5. 哪个 testcase/seed 负责执行它？

### 建议的 VPlan 骨架

| ID | Spec requirement | Stimulus | Checker | Coverage | 当前 testcase | 状态 |
|---|---|---|---|---|---|---|
| AHB-01 | 有效传输由 `NONSEQ/SEQ` 接受，`IDLE/BUSY` 不产生数据访问 | single、burst、BUSY | monitor + SVA + scoreboard beat count | HTRANS 类型、BUSY 位置 | testcase、burst、legal random | 已实现 |
| AHB-02 | 首 beat 是 `NONSEQ`，后续有效 beat 是 `SEQ` | INCR/WRAP burst | monitor 重组、SVA/协议检查 | 首/中/尾 beat、burst 长度 | burst、legal random | 已实现 |
| AHB-03 | BUSY 只出现在相邻有效 beat 之间 | burst 中插入 1~3 cycle BUSY | monitor 不增加 data beat，scoreboard 不丢数据 | burst × has_busy、BUSY 周期数 | burst、legal random | 已实现 |
| AHB-04 | 支持 BYTE/HALFWORD/WORD | 三种 HSIZE 的读写 | refm + scoreboard + 对齐 SVA | HSIZE bins/cross | testcase、burst、boundary、random | 已实现 |
| AHB-05 | 支持的 HBURST 地址序列正确 | SINGLE/INCR/WRAP4/8/16/INCR4/8/16 | monitor 地址队列 + refm/scb | HBURST × HSIZE × direction | burst、legal random | 已实现 |
| MEM-01 | BYTE/HALFWORD/WORD 映射到正确 bank/row/lane | 物理边界地址、不同 HSIZE | bank CSN SVA + physical refm | bank/lane/row | boundary、legal random | 已实现 |
| MEM-02 | partial write 只修改命中的 lane | WORD -> BYTE/HALFWORD overlay -> WORD read | physical refm + scoreboard | write HSIZE × read HSIZE × bank | legal random | 已实现 |
| MEM-03 | 未初始化 SRAM 数据不被误判 | 未写过地址 probe read | refm valid lane mask | comparable/non-comparable | legal random | 已实现 |
| RESP-01 | 正常模式 zero-wait、OKAY | 任意合法传输 | SVA | assertion coverage | 全部 testcase | 已实现 |
| RESET-01 | reset 后总线功能恢复 | reset 前后写读 | scoreboard + reset monitor cleanup | reset transition | reset recovery | 已实现 |
| NEG-01 | 非法 HSIZE/未对齐/越界的行为符合 spec | negative stimulus | 预期 error/no-access checker | illegal input bins | 当前无明确 RTL 规格 | 待 spec |
| BUS-01 | 上游 HREADY=0 时保持/暂停传输 | wait-state master | protocol checker + data checker | HREADY wait length | 当前 waiver | 待 RTL/driver |
| RESP-02 | ERROR/RETRY/SPLIT 响应处理 | response agent | response checker | response bins | 当前 waiver | 待 spec |
| DFT-01 | BIST/DFT 模式正确 | BIST/DFT sequence | 专项 checker | mode/result coverage | 当前 normal-AHB 范围外 | 待专项计划 |

### “每个地址都读写没毛病”为什么不是完整 VPlan

64 KiB 窗口有大量地址，逐地址穷举既昂贵，也不一定比等价类测试更有价值。
应先根据 RTL/spec 找出决定行为的地址位：

```text
BYTE:     bank = HADDR[15], lane = HADDR[14:13], row = HADDR[12:0]
HALFWORD: bank = HADDR[14], half = HADDR[13],    row = HADDR[12:0]
WORD:     bank = HADDR[13], lanes = all four,    row = HADDR[12:0]
```

因此地址测试要覆盖的是决定译码的等价类，而不是盲目遍历所有地址：

- bank 选择位为 0/1；
- lane 选择为 0/1/2/3；
- row 为低端、内部、最高值；
- HSIZE 对齐边界；
- WRAP window 的起始、最后一个 beat 和回绕后的地址；
- 不同 HSIZE 访问同一 physical word 的 alias 组合。

### 数据 pattern 怎么规划

`1111_0000`、`1010_0101`、全 0、全 1、walking 1/0 等 pattern 有价值，
但它们属于 data-value coverage，不能替代地址、协议和时序 coverage。建议
至少覆盖：

- all zero；
- all one；
- alternating `1010`/`0101`；
- 每个 byte lane 使用不同值，例如 `32'h11_22_44_88`；
- walking 1/0；
- BYTE/HALFWORD 写后检查未命中 lane 保持原值。

最关键的不是 pattern 数量，而是 checker 能区分每条 lane 是否被错误覆盖。

### 当前项目的签核边界

当前 normal-AHB VPlan 可以声称：合法 HSIZE、合法 HBURST、BUSY、地址译码、
物理 partial write、读写数据一致性、reset recovery 和正常响应已经有
对应的 stimulus/checker/coverage。不能直接声称“所有地址和所有协议场景都验证
了”。

以下项目必须等 spec 明确后再定义 pass/fail：

- 非法 HSIZE、未对齐、窗口外地址应该返回什么；
- HREADY=0 时 DUT/driver 应该如何保持；
- ERROR/RETRY/SPLIT 是否支持；
- BIST/DFT 模式的进入、完成和失败语义。

如果 spec 说这些场景“不支持”或“由上游保证不会出现”，VPlan 应写成
assumption/negative robustness check；如果 spec 说支持，就不能用 waiver，
必须新增 testcase、checker 和 coverage。
