1. 3 分钟项目介绍
我的项目是对 AHB SRAM Controller 的 UVM 验证平台开发。  
DUT 的功能是把 AHB slave 接口的访问转换为 SRAM 访问。顶层结构是 sramc_top，内部由 ahb_slave_if 完成 AHB 到 SRAM 控制的转换，sram_core 管理两个 bank；每个 bank 由四片 8-bit SRAM macro 组成，因此一个 physical row 可以组成 32-bit 数据。  
验证平台采用标准 UVM 分层架构。test 启动 sequence，sequence 创建 ahb_seq_item；sequencer 采用标准 UVM item 调度；driver 将 transaction 按 AHB 地址阶段、数据阶段的时序驱动到 virtual interface。对于 burst，driver 支持前一 beat 的数据和后一 beat 的地址控制重叠。  
monitor 从真实 AHB pin 采样，在地址阶段缓存 HADDR/HWRITE/HSIZE/HTRANS/HBURST，在下一拍补上 HWDATA 或 DUT 返回的 HRDATA，重组成 observed transaction。该 transaction 通过 analysis port 广播给 reference model、scoreboard 和 coverage collector。  
reference model 是项目的重点。我没有简单按 AHB 地址保存数据，而是复刻 RTL 的 bank-row-lane 映射：根据 HSIZE 和地址位选择 physical bank、SRAM row 和 byte lane。这样可以正确建模 BYTE/HALFWORD/WORD 的 partial write，以及不同 AHB 地址访问同一 physical SRAM word 的场景。  
对读操作，monitor 采到 DUT 的 HRDATA 作为 actual；refm 基于已维护的 physical memory 预测 expected；scoreboard 逐 beat 比较两者。  
测试上，我实现了基础读写、三种 HSIZE、地址边界、SINGLE/INCR/WRAP/INCR4/8/16、burst BUSY、reset recovery，以及 stateful constrained-random。随机测试会保留历史 write 的物理 SRAM 状态，再随机用不同 HSIZE 发起 read，从而验证 cross-size partial write/read。  
检查层面，scoreboard 检查数据功能正确性，SVA 检查 HSIZE、对齐、地址窗口、zero-wait response 和 bank 选择等协议不变量，functional coverage 收集 burst、HSIZE、BUSY、物理 bank/lane 和 write-size × read-size cross。  
当前明确未覆盖的范围包括上游 HREADY=0 wait-state、error response，以及 BIST/DFT 专项验证；这些会在 VPlan 中标记为 out-of-scope，而不是用 coverage 数字掩盖。

2. 为什么 refm 维护 bank/row/lane？stateful random 如何验证 partial write？
因为 refm 的职责是复刻 DUT 的可见存储行为。这个 DUT 不是普通的 memory[HADDR] 结构，而是两组 bank，每个 bank 有四条 8-bit SRAM lane。不同的 AHB 地址可能映射到同一个 physical row 的不同 lane。  
如果 refm 只写 memory[HADDR]=HWDATA，它会把这些地址当成独立位置，无法预测 partial write 之后的跨 HSIZE read。  
因此我的 refm 使用 physical_memory[bank][row] 保存 32-bit word；BYTE write 只改一条 lane，HALFWORD write 改相邻两条 lane，WORD write 改全部四条 lane。读时也按 DUT 的 HSIZE 和 lane 拼接规则返回 expected data。  
stateful random 的“state”是历史 write 留下的物理 SRAM 内容和已初始化 lane。随机 write 后，后续 read 不只读刚写的同地址同宽度，而是可从历史物理位置以 BYTE/HALFWORD/WORD 读取。scoreboard 比较 refm expected 和 DUT actual。这样可以抓到 partial-write merge、lane select、bank decode 或 cross-size read path 的问题。

3. 为什么用 UVM？
平台分层、可复用，sequence/driver/monitor/checker 解耦；analysis port 支持多个订阅者，利于 refm、scoreboard、coverage 独立演进。

4. sequence、sequencer、driver 分别做什么？
标答：
sequence 描述激励场景并创建 transaction；sequencer 调度 transaction；driver 把 transaction 转为 AHB pin 时序。

5. 为什么不能直接用 driver 发出的 transaction 做 scoreboard 输入？
标答：
driver transaction 是 sequence 的设计意图，不是 DUT 实际接收到的事实。若 driver 地址、数据相位或 BUSY 时序有 bug，直接使用它检查会掩盖问题。因此项目由 monitor 从 interface 观察真实总线，重组成 transaction 后再送给 refm、scoreboard 和 coverage。

6. BUSY 是否是有效的数据传输？
标答：
不是。当前项目中 hsel && hready && htrans[1] 才是有效传输，因此只有 NONSEQ 与 SEQ 会访问 SRAM。BUSY 保持 burst 上下文但不产生新数据 beat。monitor 会记录 BUSY 的位置，不能把它误当成读写 beat。

7. INCR 和 WRAP 的区别？
标答：
INCR 地址持续按 beat size 递增，testbench 对未定长 INCR 随机限定为 2～16 beat，并在末尾驱动 IDLE 结束。WRAP 同样递增，但达到固定 burst 的 wrap window 边界后回绕。项目通过 WRAP4/8/16 且从窗口末拍附近起始的场景，确认回绕逻辑真实发生。

8. functional coverage 100% 是否代表没有 bug？
标答：
不代表。它只表示已定义的 coverpoint、cross 和 bin 被命中。还需要确认 VPlan 中每个 feature 都有 stimulus、checker 和 coverage 的对应关系；并审查 waiver 是否合理。比如当前 BIST/DFT、HREADY wait-state 不在 normal-AHB scope，不能因为 coverage 显示高就宣称这些功能已验证。

9. 发现 scoreboard mismatch 时如何 debug？
标答：
从第一条 mismatch 获取地址、beat index、HSIZE、expected、actual、test 和 seed；再向前看 monitor 观察到的对应 transaction，区分 sequence 意图和总线实际行为；然后检查 refm 的 memory 更新与预测，最后在 Verdi 看 AHB address/data phase、BUSY、bank CSN、SRAM data。这样能分辨 sequence、driver、monitor、refm/scoreboard 还是 RTL 的问题。

10. 为什么既要 sramc_burst_test，又要 sramc_legal_random_test？
标答：
sramc_burst_test 是 directed test，确保每个支持的 HBURST 与 HSIZE 组合都能被确定性执行，并且对非 SINGLE write 强制插入 BUSY，保证关键协议路径不依赖随机命中。
sramc_legal_random_test 则在合法约束下随机 burst 类型、大小、地址、INCR 长度和 BUSY，并引入跨 HSIZE 读写，目的是探索定向测试难以枚举的组合空间。两者结合能兼顾可重复性、corner 覆盖和随机探索能力。

追问：只跑 1 万个随机 seed 能替代 directed test 吗？
不能。随机次数只能提高概率，不能保证关键边界或特定 cross 一定命中。比如 WRAP 从窗口末拍开始、reset recovery、指定 bank 边界，都应该由 directed test 明确保证。

11. 你如何保证随机 transaction 不违反 AHB 协议？
标答：
随机化只针对合法参数空间。HSIZE 限制为 BYTE/HALFWORD/WORD；HALFWORD 和 WORD 地址满足对齐；地址限制在 64 KiB 窗口内；HBURST 限制为项目支持的 burst 类型。burst 的首拍固定为 NONSEQ，后续拍由 driver 生成 SEQ；BUSY 只插在有效 beat 之间，不会出现在首拍前或末拍后。未定长 INCR 的长度在 testbench 中限制为有限范围，并以 IDLE 结束。

追问：为什么不随机 HTRANS？
因为直接随机 HTRANS 容易产生孤立 SEQ、BUSY 位于非法位置等无效协议序列。项目随机的是 burst 语义和 BUSY 插入位置，HTRANS 由协议规则派生，这样随机性和合法性可以同时保证。

12. 为什么 reference model 的输入来自 monitor？
标答：
reference model 的输入必须是 DUT 实际看到的总线事务。monitor 从接口采样并重组 transaction，可以发现 driver 地址相位、数据相位、BUSY 或 burst 结束处理错误。若直接把 sequence 或 driver transaction 送入 refm，就会把 driver 的意图误认为真实总线行为，可能掩盖 testbench 自身 bug。

追问：monitor 为什么还要 clone transaction？
analysis port 传递的是 class handle。若下游组件共享同一个对象，而 monitor 后续继续修改该对象的 queue，refm、scoreboard 和 coverage 看到的数据可能被污染。因此 monitor 在发布前 clone，coverage/refm 内部也会 clone，确保每个消费者拿到稳定快照。

13. scoreboard 如何支持 BYTE、HALFWORD、WORD 比较？
标答：
scoreboard 会按 actual transaction 的 HSIZE 生成比较 mask：BYTE 用 0x000000ff，HALFWORD 用 0x0000ffff，WORD 用 0xffffffff。reference model 根据相同 HSIZE 和物理 lane 映射预测 read data；scoreboard 再逐 beat mask 比较 expected 与 actual。对于未初始化 lane，reference model 将该 beat 标记为 non-comparable，scoreboard 跳过比较并给出 warning，而不是把 SRAM 初始 X 误报为 DUT bug。

追问：跳过比较会不会掩盖 bug？
只对没有被任何先前合法写初始化的 lane 跳过。对测试自己写入过的 lane，必须比较。后续可通过 memory initialization、backdoor initialization 或专门的 reset-value spec，将更多 read 变成可比较场景。

14. 你目前的 SVA 覆盖了什么？没有覆盖什么？
标答：
当前 SVA 覆盖 zero-wait/OKAY 响应、HSIZE 合法性、地址窗口、半字与字对齐、有效请求后的单 bank 选择、bank 互斥及 CSN 合法编码；同时用 cover property 记录 read、write、三类 HSIZE 与 BUSY 是否发生。
目前未验证上游 HREADY=0 wait-state 协议、ERROR/RETRY/SPLIT response，以及 BIST/DFT 功能模式。这些在当前 normal-AHB coverage 范围中被记录为 waiver，而不是伪造非法激励去刷覆盖率。

1. 为什么 valid_transfer 用 htrans[1] 判断？
标答：
AHB 中 NONSEQ=2'b10、SEQ=2'b11 的最高位都是 1，代表有效传输；IDLE=00、BUSY=01 最高位为 0，不是有效数据 beat。因此项目用 hsel && hready && htrans[1] 表示 DUT 真正接受的访问。

追问：BUSY 为什么不算有效 beat？
BUSY 用于保持 burst 上下文或插入空拍，本拍没有新的数据访问，不能更新 reference model，也不能送入 scoreboard 比较。

2. 你的 driver 如何处理 burst？
标答：
sequence item 用 queue 保存完整 burst 的每拍地址和数据。driver 读取 queue 后，首拍驱动 NONSEQ，后续拍驱动 SEQ；若 busy_before_beat_q 记录了某个 beat 前有 BUSY，就先驱动对应数量的 BUSY cycle，再继续该 SEQ beat。完成后总线回到 IDLE。

3. 未定长 INCR 如何结束？为什么不能无限跑？
标答：
AHB 的 INCR 是未定长 burst，协议层面由 master 决定何时终止。项目为仿真可控性，在 sequence 中随机限制为 2～16 个 beat，最后驱动 IDLE 作为结束标志。monitor 看到 IDLE 后发布已重组完成的 INCR transaction。

4. monitor 如何判断一个 fixed burst 已经结束？
标答：
monitor 根据 HBURST 计算预期 beat 数：INCR4/WRAP4 是 4，INCR8/WRAP8 是 8，INCR16/WRAP16 是 16。它从 NONSEQ 建立 active burst，后续 SEQ 逐拍加入 queue；当 queue 长度达到固定 beat 数时发布 transaction。

5. 为什么 BYTE/HALFWORD/WORD 的物理 bank 映射不同？
标答：
这是该 RTL 的地址译码实现决定的，而不是通用 AHB 规则。reference model 必须严格复现 ahb_slave_if 的映射：BYTE 使用特定位选 bank 和 lane，HALFWORD 使用另一组地址位，WORD 又使用不同地址位。这样 partial write/read 才能与 RTL 对齐。

6. 什么是 partial write bug？你的平台怎样抓它？
标答：
partial write bug 指 BYTE 或 HALFWORD 写入时错误覆盖了同一个 32-bit SRAM word 中未命中的其他 lane。项目的 reference model 用 physical_memory + valid_lane_mask 按 lane 更新；stateful random 会做跨 HSIZE 读写，例如 WORD 写、BYTE 改写、WORD 读。若未写 lane 被破坏，scoreboard 的 WORD read 就会 mismatch。

7. 为什么 coverage collector 放在 monitor 侧？
标答：
coverage 应采样实际发生在 interface 上的 transaction，而不是 sequence 的计划。monitor 输出的是已被 DUT 接收、且已经完成 burst 重组的 observed transaction。因此功能覆盖放在 monitor 侧可以同时覆盖 DUT 实际协议行为和 testbench 驱动正确性。

8. 什么情况下你会把 agent 配成 passive？
标答：
当 DUT 所在 SoC 已经有真实 CPU、DMA 或其他 AHB master 驱动接口时，AHB agent 应配置为 passive，只保留 monitor、coverage、scoreboard/refm，不再创建 driver 和 sequencer。当前项目是 block-level standalone 验证，所以使用 active agent 自己产生激励。

9. 为什么 coverage waiver 不能随便加？
标答：
waiver 会改变最终 coverage 分母，错误 waiver 会掩盖真实验证缺口。每条 waiver 必须有规格或架构依据。例如本项目的 HREADY wait-state、BIST/DFT、非法 HSIZE、地址窗口外位明确不属于 normal-AHB scope，因此可以 waiver；如果 RTL 宣称支持的合法分支没有覆盖，必须补 testcase，不能 waiver。

10. UVM 仿真与 Formal 在这个项目中如何分工？
标答：
UVM 负责真实 transaction、burst、BUSY、数据完整性、reference model 比较和功能覆盖；Formal 负责在约束后的所有合法输入空间中证明有限控制性质，例如 zero-wait/OKAY、bank 互斥、下一拍恰选一个 bank。当前 Formal harness 已完成，但尚未在具备 VC Formal 的环境得到正式 Proven 结果，因此不能把它当成已完成的 proof。

追问：为什么不对整个 SRAM 数据阵列做 Formal？
SRAM 存储状态空间很大，直接穷举数据保持会导致状态爆炸。当前 Formal 聚焦控制译码；数据完整性由 UVM 的 reference model、directed test 和 constrained-random 回归验证。

11. 为什么 valid_transfer 用 htrans[1] 判断？
标答：
AHB 中 NONSEQ=2'b10、SEQ=2'b11 的最高位都是 1，代表有效传输；IDLE=00、BUSY=01 最高位为 0，不是有效数据 beat。因此项目用 hsel && hready && htrans[1] 表示 DUT 真正接受的访问。

追问：BUSY 为什么不算有效 beat？
BUSY 用于保持 burst 上下文或插入空拍，本拍没有新的数据访问，不能更新 reference model，也不能送入 scoreboard 比较。

12. 你的 driver 如何处理 burst？
标答：
sequence item 用 queue 保存完整 burst 的每拍地址和数据。driver 读取 queue 后，首拍驱动 NONSEQ，后续拍驱动 SEQ；若 busy_before_beat_q 记录了某个 beat 前有 BUSY，就先驱动对应数量的 BUSY cycle，再继续该 SEQ beat。完成后总线回到 IDLE。

3. 未定长 INCR 如何结束？为什么不能无限跑？
标答：
AHB 的 INCR 是未定长 burst，协议层面由 master 决定何时终止。项目为仿真可控性，在 sequence 中随机限制为 2～16 个 beat，最后驱动 IDLE 作为结束标志。monitor 看到 IDLE 后发布已重组完成的 INCR transaction。

4. monitor 如何判断一个 fixed burst 已经结束？
标答：
monitor 根据 HBURST 计算预期 beat 数：INCR4/WRAP4 是 4，INCR8/WRAP8 是 8，INCR16/WRAP16 是 16。它从 NONSEQ 建立 active burst，后续 SEQ 逐拍加入 queue；当 queue 长度达到固定 beat 数时发布 transaction。

5. 为什么 BYTE/HALFWORD/WORD 的物理 bank 映射不同？
标答：
这是该 RTL 的地址译码实现决定的，而不是通用 AHB 规则。reference model 必须严格复现 ahb_slave_if 的映射：BYTE 使用特定位选 bank 和 lane，HALFWORD 使用另一组地址位，WORD 又使用不同地址位。这样 partial write/read 才能与 RTL 对齐。

6. 什么是 partial write bug？你的平台怎样抓它？
标答：
partial write bug 指 BYTE 或 HALFWORD 写入时错误覆盖了同一个 32-bit SRAM word 中未命中的其他 lane。项目的 reference model 用 physical_memory + valid_lane_mask 按 lane 更新；stateful random 会做跨 HSIZE 读写，例如 WORD 写、BYTE 改写、WORD 读。若未写 lane 被破坏，scoreboard 的 WORD read 就会 mismatch。

7. 为什么 coverage collector 放在 monitor 侧？
标答：
coverage 应采样实际发生在 interface 上的 transaction，而不是 sequence 的计划。monitor 输出的是已被 DUT 接收、且已经完成 burst 重组的 observed transaction。因此功能覆盖放在 monitor 侧可以同时覆盖 DUT 实际协议行为和 testbench 驱动正确性。

8. 什么情况下你会把 agent 配成 passive？
标答：
当 DUT 所在 SoC 已经有真实 CPU、DMA 或其他 AHB master 驱动接口时，AHB agent 应配置为 passive，只保留 monitor、coverage、scoreboard/refm，不再创建 driver 和 sequencer。当前项目是 block-level standalone 验证，所以使用 active agent 自己产生激励。

9. 为什么 coverage waiver 不能随便加？
标答：
waiver 会改变最终 coverage 分母，错误 waiver 会掩盖真实验证缺口。每条 waiver 必须有规格或架构依据。例如本项目的 HREADY wait-state、BIST/DFT、非法 HSIZE、地址窗口外位明确不属于 normal-AHB scope，因此可以 waiver；如果 RTL 宣称支持的合法分支没有覆盖，必须补 testcase，不能 waiver。

10. UVM 仿真与 Formal 在这个项目中如何分工？
标答：
UVM 负责真实 transaction、burst、BUSY、数据完整性、reference model 比较和功能覆盖；Formal 负责在约束后的所有合法输入空间中证明有限控制性质，例如 zero-wait/OKAY、bank 互斥、下一拍恰选一个 bank。当前 Formal harness 已完成，但尚未在具备 VC Formal 的环境得到正式 Proven 结果，因此不能把它当成已完成的 proof。

追问：为什么不对整个 SRAM 数据阵列做 Formal？
SRAM 存储状态空间很大，直接穷举数据保持会导致状态爆炸。当前 Formal 聚焦控制译码；数据完整性由 UVM 的 reference model、directed test 和 constrained-random 回归验证。