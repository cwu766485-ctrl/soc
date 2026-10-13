## 2026-07-23：reset recovery testcase 与代码覆盖率 waiver 细化

- 新增 `sramc_reset_if`：reset 是 testbench 对 DUT 的驱动信号，而 `ahb_if` 中的 reset 是 agent 的观察输入；单独的虚接口让 UVM testcase 可以在受控时机拉低/释放 reset，避免 class 直接反向驱动 `ahb_if` 输入。
- 新增 `sramc_reset_recovery_test` 和 `make reset_recovery`：先完成一轮 AHB 写读，再等待 monitor 收尾，于空闲期将 `hresetn` 拉低两个完整 AHB cycle；释放后重新执行写读，由 reference model/scoreboard 检查恢复链路。该测试不假定 SRAM 数据在 reset 后保留或清零，因为恢复阶段会先写后读。
- 将 reset testcase 纳入默认 regression 与 `coverage_full` 的定向阶段，使 `hresetn` 的 1→0 及 0→1 都成为有实际验证意义的覆盖行为。
- coverage waiver 补充 `ahb_slave_if_u.hsize_r[2]` 与 `haddr_r[31:16]`：前者是当前规格外的 HSIZE 编码位，后者是 64 KiB 地址窗口外的锁存地址位；保留合法位 `[1:0]` 和 `[15:0]` 的覆盖目标。
- 进一步使用 URG `-dump full_exclusions` 生成的精确 object ID，waive `hsize_sel==2'b00` 的非法 false bin，以及五个 `haddr_sel`/`haddr_sel[0]` 的 X/Z `MISSING_DEFAULT` branch；不会排除合法 BYTE/HALFWORD/WORD 或合法 byte-lane 分支。
- 当前 normal-AHB 签核范围明确不包含上游 `HREADY=0` wait-state protocol，也不包含 BIST；因此 waiver `hready` 的未翻转和 `hsel && hready` 中 `hsel=1/hready=0` 的 condition bin，并完整 waiver `sram_core` 的 BIST 聚合信号。RTL 的 HREADY 门控与 BIST 逻辑均未删除，后续若纳入专项验证计划，应移除相应 waiver 并补 testcase。

## 2026-07-08 19:37:48 +08:00

### 本次任务

- 根据 `docs/产生UVM_TB框架01.pdf` 和 `docs/产生UVM_TB框架02.pdf` 的课程流程，在 VNC/Linux 服务器上生成 AHB_SRAMC 的 UVM TB 初始框架。
- 目标是先让 UVM 框架可以编译、仿真并正常退出，后续课程再逐步补充 AHB transaction、sequence、driver、monitor、scoreboard 等功能行为。

### 远端环境

- 当前远端工程路径：`/home/stu_wck/uvm_prj/sramc_uvm_tb`
- 初始调试路径：`/home/stu_wck/verification/projects/sramc_uvm_tb_codex/sramc`
- 课程生成脚本：`/home/stu_wck/verification/projects/uvm_tb_gen.pl`
- 生成命令：

```sh
cd /home/stu_wck/verification/projects
rm -rf sramc_uvm_tb_codex
mkdir -p sramc_uvm_tb_codex
cd sramc_uvm_tb_codex
cp ../uvm_tb_gen.pl .
perl uvm_tb_gen.pl -p sramc -i ahb
```

### 生成与修改内容

- 生成 UVM 目录 `verif/`，包括：
  - `verif/agent/ahb/`：AHB agent、config、driver、monitor、sequencer、sequence item、package、interface。
  - `verif/env/`：`sramc_env`、`sramc_env_config`、`sramc_refm`、`sramc_scb`、`sramc_env_pkg`。
  - `verif/tests/`：`sramc_test_base`、`sramc_test_pkg`。
  - `verif/tb/`：`sramc_tb`。
  - `verif/sim/Makefile`。
- 将本地 `rtl/` 同步到远端工程，并添加远端 `rtl/rtl.f`：

```text
../../rtl/ahb_slave_if.v
../../rtl/RA1SH.v
../../rtl/sram_bist_8kx8.v
../../rtl/sram_bist.v
../../rtl/sram_core.v
../../rtl/sramc_top.v
```

- 修改 `verif/tb/sramc_tb.sv`：
  - 增加 `hclk`、`sram_clk`、`hresetn`。
  - 实例化 `ahb_if m_ahb_if(hclk, hresetn)`。
  - 实例化并连接 `sramc_top u_sramc_top`。
  - 通过 `uvm_config_db#(virtual ahb_if)::set(null, "*", "vif", m_ahb_if)` 将 virtual interface 传入 UVM 组件。
  - 增加可选 `FSDB` dump。
- 修改 `verif/agent/ahb/ahb_if.sv`：
  - 增加 AHB 基本信号：`hsel/haddr/htrans/hsize/hburst/hwrite/hwdata/hready/hready_resp/hresp/hrdata`。
  - 增加 `drv_cb` 和 `mon_cb` clocking block。
- 修改 `verif/agent/ahb/ahb_driver.sv`：
  - 在 `main_phase` 开始时驱动 AHB 空闲默认值，避免 DUT 输入悬空。
- 修改 `verif/tests/sramc_test_base.sv`：
  - 修正 AHB agent config 的 `uvm_config_db` 路径和字段名，使其匹配 `ahb_agent` 中读取的 `"m_cfg"`。
  - 在 `main_phase` 中加入最小 smoke objection，仿真运行 `1000ns` 后正常退出。
- 修改 `verif/sim/Makefile`：
  - 编译时加入 `-f ${RTL_PATH}/rtl.f`。
  - 扩展 `clean` 目标，清理日志、波形和 VCS 临时文件。

### 验证结果

- 远端执行：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make all
```

- VCS 编译通过，生成 `simv`。
- `sramc_test_base` 仿真正常结束。
- 日志关键结果：

```text
UVM_INFO ../tests/sramc_test_base.sv(73) @ 0: uvm_test_top [sramc_test_base] sramc UVM smoke framework is running
UVM_ERROR :    0
UVM_FATAL :    0
```

### 本地同步

- 已将调通后的远端 `verif/` 同步回本地工程：
  - `verif/agent/ahb/*`
  - `verif/env/*`
  - `verif/tests/*`
  - `verif/tb/sramc_tb.sv`
  - `verif/sim/Makefile`

### 后续计划

- 继续按课程推进，在当前可跑通框架上补充：
  - AHB `sequence_item` 字段和约束。
  - AHB write/read sequence。
  - driver 的真实 AHB 时序驱动。
  - monitor 的 AHB transfer 采样。
  - reference model 和 scoreboard 数据通路。

## 2026-07-08 21:18:35 +08:00

### 本次任务

- 彻底结束 `产生UVM_TB框架01.pdf` 和 `产生UVM_TB框架02.pdf` 两份 PPT 对应的 UVM TB 框架阶段。
- 在上一版 smoke-only 框架基础上，补齐真正可执行的 AHB write/read sequence、driver、monitor 和 scoreboard 数据通路。

### 完成内容

- 修改 `verif/agent/ahb/ahb_seq_item.sv`：
  - 增加 `haddr/hwdata/hrdata/hwrite/hsize/htrans` 字段。
  - 增加默认传输约束：`htrans == 2'b10`，`hsize` 限定为 byte/halfword/word。
  - 增加 UVM field automation，便于 `print/sprint/copy/clone`。
- 修改 `verif/agent/ahb/ahb_if.sv`：
  - 保留 AHB 基本信号。
  - 增加课程风格 `drvCLK` 和 `monCLK` clocking block。
  - 增加 `driver/monitor` modport。
- 修改 `verif/agent/ahb/ahb_driver.sv`：
  - 增加 `reset_phase`，复位期间驱动 AHB idle 默认值。
  - 在 `main_phase` 等待 reset 释放后从 sequencer 获取 transaction。
  - 在 `do_drive()` 中按 AHB 地址/控制相位和写数据相位驱动 DUT。
- 修改 `verif/agent/ahb/ahb_monitor.sv`：
  - 采样有效 AHB transfer。
  - 对 write 采样写数据，对 read 采样读数据。
  - 通过 `analysis_port` 发送 transaction。
  - 增加课程中的 AHB transfer covergroup。
- 修改 `verif/env/sramc_env.sv`：
  - 连接 `m_ahb_agent.analysis_port` 到 `m_scb.analysis_imp`。
- 重写 `verif/env/sramc_scb.sv`：
  - 增加 `uvm_analysis_imp`。
  - write transaction 进入期望队列。
  - read transaction 与前序同地址 write 数据比较。
  - 将 `compare` 实现为 function，避免 VCS `Task enabled inside a function` 警告。
- 新增 `verif/tests/seqlib/ahb_seq_rw.sv`：
  - 写地址 `0x0` 到 `0x4c` 共 20 笔 word transaction。
  - 读回同一地址范围共 20 笔 transaction。
  - 额外写读地址 `0x190`，数据为 `32'hffff_ffff`。
- 新增 `verif/tests/sramc_test.sv`：
  - 从 `sramc_test_base` 派生。
  - 在 `main_phase` 中启动 `ahb_seq_rw`。
- 修改 `verif/tests/sramc_test_pkg.sv`：
  - include `ahb_seq_rw.sv` 和 `sramc_test.sv`。
- 修改 `verif/sim/Makefile`：
  - 默认 testcase 从 `sramc_test_base` 切换为 `sramc_test`。
- 新增 `rtl/rtl.f`：
  - 保存本地/远端一致的 RTL 编译 filelist。

### 远端验证

- 远端路径：

```sh
/home/stu_wck/uvm_prj/sramc_uvm_tb
```

- 执行命令：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make all
```

- 验证结果：

```text
Running test sramc_test
data compare match addr=00000000 ...
...
data compare match addr=00000190, exp data=ffffffff, rtl data=ffffffff
UVM_WARNING :    0
UVM_ERROR   :    0
UVM_FATAL   :    0
```

### 当前 PPT 进度结论

- `产生UVM_TB框架01.pdf`：已完成。
- `产生UVM_TB框架02.pdf`：已完成。
- 当前平台已经不是只有 UVM 空框架，而是具备：
  - `sramc_tb + sramc_top` 连接。
  - AHB active agent。
  - sequence -> sequencer -> driver -> interface -> DUT。
  - monitor -> analysis_port -> scoreboard。
  - 基础功能覆盖率采样。
  - write/read 数据比对并通过远端 VCS 仿真。

### 下一步

- 可以进入 `完善UVM TB 02.pdf`。
- 下一阶段重点预计是继续完善 sequence 类型、覆盖率、scoreboard/ref model 结构和更多 testcase。

## 2026-07-08 22:38:22 +08:00

### 本次任务

- 根据 `docs/完善UVM TB 02.pdf` 中 demo testcase 的代码思路，实现 UVM 平台发出一笔 transaction 的最小闭环。
- 该步骤对应课程中 `ahb_sramc_uvmtb_demo_test` / `uvm_ahb_sramc_demo_test` 的作用：创建一个 sequence，并启动到 AHB agent 的 sequencer。

### 完成内容

- 新增 `verif/tests/sramc_demo_test.sv`：
  - 从 `sramc_test_base` 继承。
  - 在 `main_phase` 中创建 `ahb_seq m_seq`。
  - 通过 `m_seq.start(m_env.m_ahb_agent.m_sequencer)` 发起一笔 transaction。
  - 使用 objection 包住 sequence 执行，保证仿真不会提前结束。
- 修改 `verif/tests/sramc_test_pkg.sv`：
  - include `sramc_demo_test.sv`。
- 修改 `verif/agent/ahb/ahb_seq.sv`：
  - 将默认 `ahb_seq` 约束为一笔可观察的 word write transaction：

```systemverilog
haddr  == 32'h0000_0000;
hwrite == 1'b1;
hsize  == 3'b010;
hwdata == 32'h1234_5678;
```

### 远端验证

- 执行：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make comp
./simv +UVM_TESTNAME=sramc_demo_test +UVM_VERBOSITY=UVM_MEDIUM +ntb_random_seed=1 -l sramc_demo_test.log
```

- 关键日志：

```text
Running test sramc_demo_test
Demo testcase main phase starting ...
store write addr=00000000 data=12345678
UVM_WARNING :    0
UVM_ERROR   :    0
UVM_FATAL   :    0
```

### 知识点结论

- 本步骤说明 UVM 发一笔 transaction 的最小路径：

```text
sramc_demo_test
  -> ahb_seq
  -> m_env.m_ahb_agent.m_sequencer
  -> ahb_driver.seq_item_port.get_next_item(req)
  -> ahb_driver.do_drive(req)
  -> ahb_if
  -> sramc_top
```

- 这就是课程里“让 UVM 平台发一笔 trans”的核心。

## 2026-07-08 22:50:34 +08:00

### 本次任务

- 继续对齐 `docs/完善UVM TB 02.pdf`，确认第 49-53 页 demo testcase 的核心代码已经落地。
- 本步骤本质是：在 UVM test 中创建一个 `ahb_seq`，并将它启动到 AHB agent 的 sequencer，从而让平台发出一笔 transaction。

### 实现内容

- 检查并确认 `verif/tests/sramc_demo_test.sv` 已实现课程 demo test 的主路径：
  - 声明 `ahb_seq m_seq`。
  - 使用 `ahb_seq::type_id::create("m_seq")` 创建 sequence。
  - 调用 `m_seq.start(m_env.m_ahb_agent.m_sequencer)` 启动 sequence。
  - 使用 `phase.raise_objection/drop_objection` 包住 sequence，防止仿真提前结束。
- 补充 `objection.set_drain_time(this, 1us)`，给 monitor/scoreboard 留出收尾时间。
- 保持 `verif/agent/ahb/ahb_seq.sv` 的默认 transaction 为一笔固定 word write，便于观察和调试：

```systemverilog
haddr  == 32'h0000_0000;
hwrite == 1'b1;
hsize  == 3'b010;
hwdata == 32'h1234_5678;
```

### 远端验证

- 已同步本地 `verif/` 和 `rtl/` 到远端：

```sh
/home/stu_wck/uvm_prj/sramc_uvm_tb
```

- 执行：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make comp
./simv +UVM_TESTNAME=sramc_demo_test +UVM_VERBOSITY=UVM_MEDIUM +ntb_random_seed=1 -l sramc_demo_test.log
```

- 关键结果：

```text
Running test sramc_demo_test
Demo testcase main phase starting ...
store write addr=00000000 data=12345678
UVM_WARNING :    0
UVM_ERROR   :    0
UVM_FATAL   :    0
```

### 结论

- `完善UVM TB 02.pdf` 里“实现 UVM 平台发一笔 trans”的 demo test 已经实现并远端跑通。
- 当前最小闭环是：

```text
sramc_demo_test
  -> ahb_seq
  -> ahb_sequencer
  -> ahb_driver
  -> ahb_if
  -> sramc_top
  -> ahb_monitor
  -> sramc_scb
```

## 2026-07-09 12:31:57 +08:00

### 本次任务

- 继续实现 `docs/完善UVM TB 02.pdf` 后半部分代码，补齐“UVM 平台发一笔 trans”相关的 transaction 抽象、demo 运行入口和 Verdi 入口。
- 对齐 PDF 第 54-62 页中 demo test 运行、`ahb_seq_item` 字段扩展、Makefile 调试入口等内容。

### 实现内容

- 修改 `verif/agent/ahb/ahb_seq_item.sv`：
  - 增加课程中更高层的 AHB transaction 枚举类型：
    - `ahb_trans_type_e`：`IDLE/BUSY/NONSEQ/SEQ`
    - `ahb_op_type_e`：`READ/WRITE`
    - `ahb_beat_size_e`：`BYTE/HALFWORD/WORD`
    - `ahb_burst_type_e`：`SINGLE/INCR/WRAP4/INCR4/...`
    - `ahb_rsp_type_e`：`OKAY/ERROR/RETRY/SPLIT`
  - 在保留现有 `haddr/hwrite/hsize/htrans/hwdata/hrdata` 低层 AHB 字段的基础上，增加：
    - `trans/op/size/burst/resp`
    - `beats_addr/hxdata/beat_hxdata/busy_cycle`
  - 增加对应 UVM field automation，方便 `print/sprint/clone`。
- 修改 `verif/agent/ahb/ahb_seq.sv`：
  - 默认 sequence 仍然发一笔固定 word write：

```systemverilog
haddr  == 32'h0000_0000;
hwrite == 1'b1;
hsize  == 3'b010;
htrans == 2'b10;
hburst == 3'b000;
hwdata == 32'h1234_5678;
op     == WRITE;
size   == WORD;
trans  == NONSEQ;
burst  == SINGLE;
```

  - 同步填充课程抽象字段：
    - `beats_addr.push_back(req.haddr)`
    - `hxdata.push_back(req.hwdata)`
    - `beat_hxdata = req.hwdata`
    - `resp.push_back(OKAY)`
- 修改 `verif/sim/Makefile`：
  - 增加 `demo` 目标：

```sh
make demo
```

  - 等价于编译后运行：

```sh
./simv +UVM_TESTNAME=sramc_demo_test +UVM_VERBOSITY=${VERB} +ntb_random_seed=${SEED} -l sramc_demo_test.log
```

  - 增加 `verdi` 目标：

```sh
make verdi
```

  - 默认编译没有强制打开 `+define+FSDB`，原因是当前 VCS 命令没有自动加载 Novas/Verdi FSDB PLI；强制打开会导致 `$fsdbDumpfile/$fsdbDumpvars` 未定义。后续若要默认生成 FSDB，需要补完整 Verdi PLI 编译选项。

### 远端验证

- 已同步到远端：

```sh
/home/stu_wck/uvm_prj/sramc_uvm_tb
```

- 执行：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make demo
```

- 验证结果：

```text
Running test sramc_demo_test
Demo testcase main phase starting ...
store write addr=00000000 data=12345678
UVM_WARNING :    0
UVM_ERROR   :    0
UVM_FATAL   :    0
```

### 结论

- `完善UVM TB 02.pdf` 中“UVM 平台发一笔 trans”的主线已继续补齐：
  - demo test 启动 sequence。
  - sequence 产生一笔 AHB word write transaction。
  - driver 将 transaction 驱动到 AHB interface。
  - monitor/scoreboard 能观察到该笔写操作。
- 当前实现采用“课程字段 + 现有可运行单笔 driver”的兼容路线，没有贸然切换到完整 burst split/merge driver，避免破坏当前已跑通的 SRAMC 单笔访问闭环。

## 2026-07-11 19:15:43 +08:00

### 本次任务

- 根据新版 `docs/完善UVM TB 02.pdf` 完善 AHB UVM monitor。
- 课件重点是将 AHB 地址/控制相位与下一拍数据相位正确配对，完成 transaction 后通过 analysis port 发给后端组件。

### 实现内容

- 修改 `verif/agent/ahb/ahb_monitor.sv`：
  - 将原先“同一段代码内直接等待一拍”的简化采样方式，改为地址相位队列 `addr_phase_q`。
  - 在 `hready_resp == 1` 时，先完成队列中上一笔地址相位对应的数据相位，再采集新的地址/控制相位。
  - 写 transaction 从 `hwdata` 补齐数据；读 transaction 从 `hrdata` 补齐数据；同时记录 `hresp`。
  - 采样到完成的 transaction 后 clone 一份，并通过 `analysis_port.write()` 发送，防止 monitor 内部对象后续修改影响 scoreboard。
  - 增加 `merge_trans` 和 `burst_length()`：`SINGLE` 可立即发送，固定长度 `INCR4/8/16`、`WRAP4/8/16` 保留按 `SEQ` beat 合并的接口。
  - 更新 coverage 的数据采样，使写操作采样 `hwdata`，读操作采样 `hrdata`。

### 与当前 driver 的配合

- 当前 `ahb_driver` 是单笔、非流水式驱动：控制相位会保持到数据相位结束。
- 因此 monitor 在存在待完成地址相位时只完成数据而不重复采样控制，避免把同一笔 single transfer 收集两次。
- 后续若将 driver 改成真正连续流水 AHB 驱动，可在同一个 ready 周期同时完成上一笔数据相位并采集下一笔地址相位。

### 远端验证状态

- 新 monitor 已同步到远端路径：

```sh
/home/stu_wck/uvm_prj/sramc_uvm_tb/verif/agent/ahb/ahb_monitor.sv
```

- 已发起：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make all
```

- VCS 已完成源文件解析并进入 inline pass/链接阶段，但 SSH 连接被远端意外关闭，尚未取得 `sramc_test` 最终 UVM summary。
- 待远端网络恢复后，需要重新执行 `make all`，确认 `UVM_ERROR : 0`、`UVM_FATAL : 0`，并检查全部读回 compare match 日志。

## 2026-07-11 20:21:09 +08:00

### 本次任务

- 根据 `docs/完善UVM TB 03.pdf` 完善 UVM scoreboard。
- 课件要求：将旧 SV 平台的 scoreboard 迁移到 UVM，学习 `analysis_port`、`uvm_tlm_analysis_fifo`、`uvm_blocking_get_port` 和 `get()` 的用法。

### 实现内容

- 修改 `verif/env/sramc_scb.sv`：
  - 移除直接接收 transaction 的 `uvm_analysis_imp` / `write()` 模式。
  - 增加 `uvm_tlm_analysis_fifo #(ahb_seq_item) mon2scb_fifo`，作为 monitor 与 scoreboard 间的 transaction 缓冲。
  - 增加 `uvm_blocking_get_port #(ahb_seq_item) scb_get_port`。
  - 在 `run_phase()` 中循环调用 `get_and_check()`；该 task 通过 `scb_get_port.get(tr)` 阻塞等待下一笔已观测到的 transaction。
  - 使用关联数组 `exp_mem[addr]` 保存每个地址最近一次写入的期望数据；读 transaction 到来时直接按地址检查 `hrdata`。
  - 增加 write/read/match/mismatch 计数器，并在 `report_phase()` 输出 scoreboard 汇总。
- 修改 `verif/env/sramc_env.sv`：

```systemverilog
m_ahb_agent.analysis_port.connect(m_scb.mon2scb_fifo.analysis_export);
m_scb.scb_get_port.connect(m_scb.mon2scb_fifo.blocking_get_export);
```

- 最终数据路径：

```text
ahb_monitor.analysis_port
  -> ahb_agent.analysis_port
  -> sramc_scb.mon2scb_fifo.analysis_export
  -> sramc_scb.scb_get_port.get()
  -> update_expected() / compare()
```

### 远端验证状态

- 已尝试同步 scoreboard/env 并执行：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make all
```

- SSH 会话没有返回 VCS 输出即结束，暂未获取最终仿真 summary。
- 远端网络恢复后需重新运行上述命令，预期 scoreboard 汇总应显示 `writes=21 reads=21 matches=21 mismatches=0`，且 UVM error/fatal 为 0。

## 2026-07-14 11:04:09 +08:00

### 本次任务

- 根据 `docs/编写testcase.pdf` 编写 UVM testcase。
- 课程目标包括 AHB 时序类型、BUSY、burst、HSIZE、低功耗相关场景和定向数据 `0101/1010/1111/0000`；本次先完成当前 RTL/driver 可以真实执行的 testcase 覆盖。

### 实现内容

- 新增 `verif/tests/seqlib/ahb_seq_testcase.sv`：
  - 使用标准 `start_item()` / `randomize() with {...}` / `finish_item()` 发送 transaction。
  - 对每组定向数据 `32'h0101_0101`、`32'h1010_1010`、`32'h1111_1111`、`32'h0000_0000`，执行先写后读。
  - 覆盖 `HSIZE=BYTE/HALFWORD/WORD`。
  - 覆盖 64KB AHB 地址窗口的低端、高端和两侧 bank/lane 边界地址，例如 `0x0000`、`0x7ffc`、`0x8000`、`0xfffc`。
  - 在 word write 后发送 `HTRANS=BUSY` 空拍，验证 BUSY 不被当作 SRAM 有效访问。
- 新增 `verif/tests/sramc_testcase_test.sv`：
  - 继承 `sramc_test_base`。
  - 在 `main_phase` 启动 `ahb_seq_testcase`，使用 objection 和 5us drain time 保证 monitor/FIFO/scoreboard 收尾。
- 修改 `verif/tests/sramc_test_pkg.sv`：include 新 sequence 和 testcase。
- 修改 `verif/sim/Makefile`：新增 `make testcase`，运行 `sramc_testcase_test`。
- 修改 `verif/agent/ahb/ahb_driver.sv`：将 `req.hburst` 透传到 interface，而不是固定写为 `3'b000`。
- 修改 `verif/env/sramc_scb.sv`：读回比较根据 `HSIZE` 使用 byte/halfword/word mask，避免 DUT 对 8/16-bit 读的零扩展被错误作为 32-bit mismatch。

### 当前实现边界

- DUT 当前接收但不使用 `HBURST`；driver 也尚未实现完整连续 `NONSEQ/SEQ` 多拍 burst 拆分。
- 因此 testcase 可以真实覆盖 `HBURST` 信号透传和 BUSY 空拍，但不能把它称为完整的 INCR/WRAP burst 功能验证。
- Low-power/DFT/BIST 场景需要后续课程补充 testbench 控制路径后再单独实现。

### 远端验证状态

- 已同步 `verif/` 并发起：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make testcase
```

- 当前 SSH 通道未返回 VCS 输出即结束，尚未取得最终 UVM summary。
- 网络恢复后执行 `make testcase`，预期有 12 笔有效写、12 笔有效读、12 个 compare match，且 `UVM_ERROR : 0`、`UVM_FATAL : 0`。

## 2026-07-14 12:47:57 +08:00

### 本次任务

- 根据 `docs/Debug方法.pdf` 补齐平台的可调试性，并按 `docs/回归测试0102.pdf` 建立可重复执行的 UVM 回归入口。

### Debug 配套修改

- `verif/sim/Makefile` 编译选项更新为 `-debug_access+all -kdb`，便于 Verdi 追踪设计和 testbench 层级；新增 `make debug`，它以 `UVM_HIGH` 输出 sequence、driver、monitor 和 scoreboard 的 transaction 日志。
- `sramc_tb.sv` 原有的 `FSDB` 条件 dump 保持不变。由于远端 Novas PLI 路径尚未确认，本次没有在默认编译中强制 `+define+FSDB`，以免普通回归因找不到 `$fsdbDumpfile` 失败。

### 回归测试实现

- 新增 `ahb_seq_random` 和 `sramc_random_test`：每个随机 seed 产生 32 组 word 对齐的单拍 write/read pair，scoreboard 对每组读回数据检查。
- 随机 testcase 当前只使用 `SINGLE/NONSEQ/WORD`，这是当前单拍 driver 和 RTL 已可可靠支持的范围；完整 burst、多 lane 随机回归留待相应 driver/RTL 能力完成后扩展。
- Makefile 新增 `make random` 和 `make regression`：后者只编译一次，依次运行 `sramc_test`、`sramc_testcase_test`、`sramc_random_test` 的多个 seed，日志写入 `regress/<test>_seed<seed>.log`，并在 `regress/summary.log` 记录 PASS/FAIL。

### 建议的远端验证命令

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make regression REGRESS_SEEDS="1 2"
```

- 本地没有 VCS/UVM 仿真器，且远端 SSH 通道此前不稳定；本次代码尚未取得新的远端 VCS/UVM summary，需以上述命令确认最终结果。

## 2026-07-14 14:15:08 +08:00

### 本次任务

- 根据 `docs/覆盖率分析01.pdf` 和 `docs/覆盖率分析02.pdf`，将 UVM 平台改造成可执行 code coverage、functional coverage 和多 testcase/seed coverage 合并的流程。

### Makefile 覆盖率流程

- `verif/sim/Makefile` 的 VCS 编译加入 `-cm line+cond+fsm+tgl+branch+assert`，采集 line、condition、FSM、toggle、branch 和 assertion coverage。
- 每次 run 以 `results/<test>/seed<seed>/` 为独立目录，保存该次仿真的 `.log` 与 `.vdb`；因此不同 testcase 和 seed 不会互相覆盖。
- `make regression` 保持一次编译、多 testcase/seed 仿真；`make merge` 使用 `urg -full64` 合并全部 VDB 到 `merge_coverage.vdb`；`make cov` 打开 Verdi coverage GUI，`make cov_txt` 生成 `urgReport/` 文本报告。
- `make coverage_regression REGRESS_SEEDS="1 2"` 是课程对应的一键入口：回归、合并并输出报告。

### 验证平台修改

- `ahb_monitor` 读取 agent config，仅在 `coverage_enable==1` 时采样 transaction covergroup；这让 functional coverage 成为受 UVM configuration 控制的 monitor 职责。
- `ahb_agent` 显式将同一份 config 下发给 `m_monitor`，保证 monitor 能稳定读取 `coverage_enable`，不依赖 config_db 的隐式层级匹配。
- `sramc_test_base` 默认打开 `m_ahb_agent_config.coverage_enable`，所以课程 testcase 已能收集 monitor 中的地址、方向、数据、HSIZE 及地址方向 cross coverage。

### 远端验证状态

- 本机在本次修改开始及结束时检测 `101.254.99.137:22` 均不可达，无法登录 VNC/Linux 服务器、同步文件或取得 VCS/URG 真实结果。
- SSH 恢复后建议执行：

```sh
cd /home/stu_wck/uvm_prj/sramc_uvm_tb/verif/sim
make clean
make coverage_regression REGRESS_SEEDS="1 2"
```

## 2026-07-15 23:36:21 +08:00

### 远端同步与 2023 工具配置

- 定位到此前自动连接失败并非服务器或 VNC 被占用，而是 PuTTY 登录后的 `Press Return to begin session` 反欺骗确认；交互 SSH/SFTP 按回车后可以正常登录和传输。
- 远端原工程已备份为 `/home/stu_wck/uvm_prj/sramc_uvm_tb_backup_20260715_231025`，本地工程已完整同步到 `/home/stu_wck/uvm_prj/sramc_uvm_tb`。
- 服务器登录环境默认是 VCS 2020 和 Verdi 2021；实际安装的 2023 工具为：
  - VCS：`/eda/synopsys_2021/vcs/V-2023.12-SP2`
  - Verdi：`/eda/synopsys_2021/verdi/V-2023.12-SP2`
- Makefile 使用绝对路径固定到 2023 工具。VCS 同时覆盖 `VCS_HOME`，避免 2023 启动脚本被旧环境变量引回 2020 compiler；Verdi 启动时清除旧 `NOVAS_HOME`，避免与 `VERDI_HOME` 冲突。
- 新增 `make tool_versions`，可检查当前工程实际调用的工具版本。
- 远端使用 VCS 2023 编译通过，KDB 生成结果为 `0 error(s), 0 warning(s)`；默认 `sramc_test` 仿真结果为 `writes=21 reads=21 matches=21 mismatches=0`，且 `UVM_ERROR=0`、`UVM_FATAL=0`。
- 回归发现定向 testcase 的不同访问宽度会因 RTL 特殊 bank/lane 地址映射发生物理别名；将 sequence 调整为每个 word/byte/halfword 场景写后立即读，避免后续场景覆盖前一场景的数据。
- BUSY helper 在 randomize 前关闭 sequence item 的默认 `NONSEQ` 约束，消除四笔 BUSY transaction 的约束冲突。

## 2026-07-17 15:42:23 +08:00

### 工具链切换与 RTL code coverage 范围修正

- `verif/sim/Makefile` 新增 `TOOLCHAIN=2023|legacy`：默认使用固定的 2023 VCS/URG/Verdi；`legacy` 使用服务器登录环境中的旧工具版本。
- 新增 `verif/sim/select_toolchain.sh`，可通过 `source ./select_toolchain.sh 2023` 或 `source ./select_toolchain.sh legacy` 切换当前 VNC/Linux terminal 的工具环境。
- 新增 `verif/sim/coverage_hierarchy.cfg`，以 `+tree sramc_tb.u_sramc_top` 限制 line/condition/FSM/toggle/branch/assert code coverage 的采集范围，并以 `-module RA1SH` 排除 SRAM 宏模型。
- 修正前，`-cm` 会覆盖整个编译集合，Verdi 因此会显示 `sramc_tb`、`m_ahb_if` 与 UVM 库的 code coverage；修正后应以 `u_sramc_top` 为 DUT code coverage 的主要查看对象。当前确认 `-cm_hier` 同时过滤了 monitor 中的 functional covergroup，需在后续编译配置中为功能覆盖率单独保留 UVM monitor scope。

### 分离 SRAM reference model 与 scoreboard

- `sramc_refm` 不再是空组件：它通过 analysis imp 接收 monitor 观察到的 AHB transaction，维护期望 SRAM 内容，并对每个 read 生成 expected transaction。
- `sramc_scb` 不再维护期望内存；它接收 actual transaction FIFO 与 refm 生成的 expected-read FIFO，按 read 顺序比较 expected `hrdata` 和 DUT 实际 `hrdata`。
- `sramc_env` 的 analysis 连接调整为 `monitor → refm`、`monitor → scoreboard(actual)`、`refm → scoreboard(expected)`，使预测与比较职责分离。
- `ahb_seq_item` 增加非随机的 `compare_enable` 元数据，标记 read 是否有前序 write 可以比较；未写即读继续以 warning 跳过比较，避免 scoreboard 无限等待。

### UVM AHB/SRAMC assertion 层

- 新增 `verif/tb/sramc_assertions.sv`，由 `sramc_tb` 实例化。该模块检查零等待/OKAY response、有效访问宽度、64-KiB 地址窗口、halfword/word 对齐、BIST/DFT 模式互斥、BIST 结果确定性以及功能模式下 SRAM bank 片选的合法性和互斥性。
- assertion 仅基于本 RTL 已明确的接口和设计契约；尤其不再把 `bist_done && bist_fail!=0` 当作错误，因为故障注入时 BIST 失败是合法结果。
- Makefile 将 assertion 源加入 VCS 编译，并在 regression 日志中将 `[SVA]` 标记视为失败；coverage hierarchy 同时保留 `u_sramc_assertions` 的 assertion coverage。

### 修复随机 seed 导致 AHB agent 变为 passive

- 回归中 seed=2 的多个 testcase 在 0ns 报 `neither the item's sequencer nor dedicated sequencer has been supplied to start item`。根因是 `ahb_agent_config.is_active` 被声明为 `rand`，而 base test 对整个 config 调用 `randomize()`；某些 seed 将 agent 设为 `UVM_PASSIVE`，使 driver/sequencer 没有创建。
- `is_active`、`coverage_enable`、`checks_enable` 改为非随机 testbench 配置；`sramc_test_base` 显式固定 active agent 和 coverage/check 开关。
- 在 `end_of_elaboration_phase` 增加 active-agent/driver/sequencer 完整性检查，使配置错误在 test 开始前以明确的 `AGENT_MODE` fatal 报出。

### AHB transaction 单一真相与独立 coverage collector

- `ahb_seq_item` 删除与 enum 重复的 `hwrite/hsize/htrans/hburst` 字段；保留 `op/size/trans/burst` 作为唯一 transaction 描述。它们的 packed encoding 与 AHB pin 相同，driver 直接驱动到 interface，monitor 从 interface 转换回 enum，避免两套字段在 sequence 中失配。
- 新增 `ahb_coverage`（`verif/agent/ahb/ahb_coverage.sv`），继承 `uvm_subscriber`，通过 `m_monitor.analysis_port` 接收 monitor 实际观察到的 transaction 并采样 AHB protocol covergroup。
- monitor 现在只负责总线采样与 transaction 重建；coverage collector 只负责 functional coverage；refm/scoreboard 保持预测与比较职责。这使 analysis-port 广播路径成为 monitor 到 refm、scoreboard 和 coverage 的三个独立订阅者。
- `coverage_hierarchy.cfg` 仍只约束 DUT 的代码覆盖率范围；SystemVerilog `covergroup` 由 `ahb_coverage` 在仿真中采样，不属于 VCS `-cm` 的 code-coverage metric 列表。
- Makefile 的 2023/legacy toolchain 命令分离为 `VCS_CMD`、`URG_CMD`、`VERDI_CMD`。旧版本分支不再错误清除 `VCS_HOME`；但 2023 VCS 产生的 VDB 必须仍由 2023 URG/Verdi 处理。
- `coverage_hierarchy.cfg` 排除 `sram_bist` 与 `sram_bist_8kx8`，使当前 AHB 主功能 DV 的 RTL code coverage 不被尚未纳入本计划的 BIST/DFT 逻辑拉低；保留 `sram_core`、`ahb_slave_if` 与顶层控制路径。
- 将 `ahb_coverage.sv` 作为 `+file` 显式保留在 coverage 编译范围，且 URG 合并/报告不再用 code-metric `-metric` 过滤 VDB；`ahb_coverage.report_phase` 会在每次仿真日志输出 functional coverage 百分比，用于确认 covergroup 实际被 sample。
- `sramc_assertions` 移除 BIST/DFT 专属端口、assertion 与 cover property；该 assertion checker 只覆盖当前 AHB-to-SRAMC 正常功能验证范围。
- 当前正常功能范围没有 RTL FSM，且 BIST FSM 已排除；`COV_TYPES` 移除 `fsm`，避免 Verdi 对缺失 FSM coverage shape 发出无意义警告。

## 2026-07-18 22:27:31 +08:00

### 命名收敛与 burst 验证准备

- 将环境中的 `sramc_refm`、`sramc_scb` 分别更名为
  `sramc_reference_model`、`sramc_scoreboard`；analysis 端口和 FIFO 改为
  `observed_transfer`、`expected_read` 等职责化名称，减少缩写歧义。
- 将 transaction 中的 `trans/op/size/burst`、`hxdata` 更名为
  `transfer_type/direction/access_size/burst_type`、`beat_addr_q/beat_data_q`；
  多拍地址、数据、response 和 BUSY 插入点统一由 queue 表达。
- driver、monitor、reference model、scoreboard 升级为按 beat 处理固定长度 burst：
  首拍 `NONSEQ`、后续 `SEQ`，monitor 重组 transaction，reference model 与 scoreboard
  对每一拍维护并比较预期数据。
- 新增 `ahb_seq_burst` 与 `sramc_burst_test`，定向验证 `INCR4`、`WRAP4` 和一个
  burst 内的合法 `BUSY` 空拍；Makefile 新增 `make burst` 并纳入默认 regression。
  未定长 `INCR` 明确报错，待定义结束条件后再纳入随机回归。
- 新增 `ahb_seq_legal_random` 与 `sramc_legal_random_test`：每个 seed 产生 64 组
  write/read 对，随机选择 `SINGLE/INCR4/WRAP4`、word 对齐起始地址、数据和 burst
  中的 BUSY 插入；`NONSEQ/SEQ` 则由协议规则生成，而不是随机产生非法时序。
  Makefile 新增 `make legal_random`，并纳入默认 regression。
- Makefile 增加 `TOOLCHAIN=local`：不再绑定课程服务器的 `/eda/...` 路径，直接调用
  当前 Linux shell 中由用户自己的 EDA 环境脚本提供的 `vcs`、`urg` 和 `verdi`。
- WSL 中 `vcs` 的交互 alias 隐含了 `-full64`，但 Makefile 的非交互 shell 不会展开
  alias，导致 VCS 错选不存在的 `linux/bin/vcs1`。`TOOLCHAIN=local` 现显式使用
  `vcs -full64`，从而选择安装实际存在的 `linux64/bin/vcs1`。
- Makefile 现检测 `/opt/Synopsys/vcs/*/bin/vcs`：在个人 WSL 安装环境下默认选
  `TOOLCHAIN=local`，在课程服务器仍默认选 `TOOLCHAIN=2023`；因此 WSL 可直接执行
  `make cov`，无需每个命令重复指定工具链。
# 2026-07-22 — AHB 全类型 burst、HSIZE 与 constrained-random 扩展

- 新增 `ahb_seq_burst_base`，统一构造符合 AHB 规则的 burst transaction：首 beat 为 `NONSEQ`、后续为 `SEQ`，并根据 `HSIZE` 计算 byte/halfword/word 的地址步进与 WRAP 边界。
- `sramc_legal_random_test` 现在随机覆盖 `BYTE/HALFWORD/WORD`、`SINGLE/INCR/WRAP4/INCR4/WRAP8/INCR8/WRAP16/INCR16`。未定长 `INCR` 在 testbench 中选择 2~16 个 beat，并以最终 `IDLE` 作为本次 burst 的明确结束条件。
- BUSY 采用每个合法 beat 间隔 20% 的默认插入概率（可用 `+BUSY_PCT` 修改），每次插入随机持续 1~3 cycle（可用 `+MAX_BUSY_CYCLES` 修改）；不会出现在初始 `NONSEQ` 前或最终 beat 后。
- driver 支持同一位置的多周期 BUSY；monitor 在观察到 `IDLE` 时收尾并发布未定长 INCR transaction。
- functional coverage 扩展所有 burst/HSIZE bin、BUSY cycle 数、边界地址区间，以及 `burst × size × direction` 和 `burst × busy` cross。
- 新增 `sramc_boundary_test` / `ahb_seq_boundary`：对每个 HSIZE、HBURST，在 64-KiB 窗口低端和高端运行 0 / all-ones 写读回环。
- Makefile 新增 `make boundary`，并将 `sramc_boundary_test` 纳入默认 regression。
- 清理 `coverage_hierarchy.cfg` 中 VCS 不支持的注释与 `+file` 条目，避免把功能覆盖 collector 误当成 code-coverage hierarchy 规则；functional coverage 仍由 UVM collector 在运行期采样。
- 修复 `regression` recipe 中 `if grep ...` 行缺失 Tab 的问题；该 Tab 缺失会让 `/bin/sh` 只收到未闭合的 `for` 循环并报 `Syntax error: unexpected end of file`。
- `REGRESS_SEEDS` 应为单行空格分隔列表；在 shell 中生成 1~20 时使用 `$(seq -s ' ' 1 20)`，不能使用默认以换行分隔的 `$(seq 1 20)`，否则 Make 展开 recipe 时会破坏 `for` 循环语法。
# 2026-07-23：覆盖率闭环规则修正

- `ahb_coverage` 中将 `SINGLE × HAS_BUSY` 设为 `ignore_bins`：本项目的
  BUSY 建模只允许插在 burst 的相邻 data beat 之间，SINGLE 只有一个 beat，
  因而没有合法插入位置。该 bin 不能通过增加 seed 覆盖，忽略它比生成非法
  stimulus 更符合 AHB 验证计划。
- BIST/DFT、固定 `HREADY/HRESP`、非法 HSIZE 的代码覆盖率将按“可达性”做
  documented waiver；不通过驱动 RTL 不支持的模式来刷代码覆盖率。

- 新增 `verif/sim/coverage_waivers.el`，由 `make cov` 与 `make cov_txt`
  自动加载。它仅在 URG/Verdi 计算报告时排除正常 AHB 功能范围外的 toggle：
  BIST/DFT、固定 zero-wait/OKAY 响应、非法 HSIZE[2] 与 64 KiB 地址窗口外的
  地址位；仿真和 assertion 检查并未关闭。该文件为手工、版本控制的 waiver，
  因此报告时使用 `-excl_bypass_checks` 适配 WSL/VNC 复制后不同的 VDB checksum；
  每条 waiver 均需代码审查，不允许作为掩盖真实未覆盖项的手段。
- `coverage_hierarchy.cfg` 仅保留 DUT 树 `sramc_tb.u_sramc_top` 用于
  line/condition/toggle/branch；`sramc_assertions` 不再稀释 DUT 代码覆盖率，
  但 `-cm assert` 继续独立采集并报告 assertion coverage。
- 新增 `make coverage_full`：先执行 `sramc_test`、`sramc_testcase_test`、
  `sramc_burst_test`、`sramc_boundary_test`（各 1 seed），再执行两个随机测试的
  指定 seed 集合，最后合并 VDB。避免只跑随机 test 而遗漏定向边界 bin。
## 2026-07-24：补全仿真产物清理规则

- 扩展 `verif/sim/Makefile` 的 `make clean`：除 VCS 编译物、波形、VDB、回归结果和普通 URG 报告外，也清除 Verdi/URG 自动生成的 `verdiLog/`、`vdCovLog/`、`urgReport_bypass/`、`verdi_config_file` 与 `vc_hdrs.h`，使下一次仿真从干净工作目录开始。
- `.gitignore` 同步忽略 `vdCovLog/`、`urgReport_bypass/` 和任意 `*.vdb/` 覆盖率数据库，防止工具副产物被误提交。
- 保留 `coverage_hierarchy.cfg`、`coverage_waivers.el` 及 `full_exclusions/`：它们是人工维护的覆盖率范围与 waiver 依据，不属于可随意删除的仿真垃圾。

## 2026-07-24：精简 Makefile 低频入口

- 删除不可用的 `demo`、与 `all`/变量覆盖重复的 `debug`、未生成 VPD 的 `dve`，以及仅打印帮助或版本的 `toolchain_help`、`tool_versions` 目标，避免日常入口分散。
- 保留单项 testcase、编译/运行、回归、覆盖率合并与报告、Verdi 波形和 `clean`；这些目标覆盖当前 UVM 学习和验证流程。
- `select_toolchain.sh` 改为直接提示使用 `vcs -ID`、`urg -version`、`verdi -version` 检查工具版本，不再引用已删除的 Makefile 目标。

## 2026-07-24：补全 burst testcase 与 sequence library 分层

- `ahb_seq_burst` 从仅覆盖 `INCR4`/`WRAP4` 的 word smoke test，扩展为定向覆盖 `SINGLE`、`INCR`、`WRAP4/8/16`、`INCR4/8/16` 与 `BYTE/HALFWORD/WORD`。每种组合都执行 write/read 回环；除 SINGLE 外，write leg 强制在每个合法 beat 间插入 BUSY，WRAP 则从最后一个对齐 beat 起始以实际跨越回绕边界。
- seqlib 采用三层职责：`ahb_base_seq` 是基础层；新增 `ahb_seq_single_access` 和既有 `ahb_seq_burst_base` 为原子层，分别构建单拍和合法多拍 transaction；`ahb_seq_rw`、`ahb_seq_burst`、`ahb_seq_boundary`、`ahb_seq_legal_random` 等为场景层，组合原子 sequence 完成 testcase。
- `ahb_seq_rw` 改为复用 `ahb_seq_single_access`，避免基础写读场景重复直接创建 transaction；其测试语义保持原来的 20 个 word 地址和全 1 数据读回。

## 2026-07-26：reference model 对齐 SRAM 物理地址映射

- `sramc_reference_model` 不再以完整 AHB 地址作为独立 memory key；现按 RTL `ahb_slave_if` 的映射维护两 bank、每 bank 8K row、每 row 四个 byte lane 的逻辑模型。BYTE 用 `HADDR[15]` 选 bank、`[14:13]` 选 lane；HALFWORD 用 `[14]` 选 bank、`[13]` 选低/高 halfword；WORD 用 `[13]` 选 bank 并访问四个 lane。row 始终为 `[12:0]`。
- refm 对 BYTE/HALFWORD write 只更新命中的 lane，并用 lane-valid mask 区分“已写入的可比较数据”和 SRAM 初值未知的 lane；read 会按 RTL 的 zero-extension/拼接方式生成预测数据。这样可正确检查不同 HSIZE、不同 AHB 地址映射到同一个物理 SRAM row 的部分写组合。
- 不新增单独的 lane testcase 或 Makefile 入口；后续将把跨 HSIZE、跨 lane 的读写组合纳入现有的 constrained-random 场景，并用 functional coverage 证明关键映射组合已被采样。

## 2026-07-27：stateful constrained-random SRAM 验证

- `ahb_seq_legal_random` 从“每次 write 后立刻以相同 HSIZE/read burst 回读”升级为 stateful random：随机合法 write burst 累积已初始化的物理 SRAM lane；之后随机读取历史 burst，并从已知 bank/row/lane 中随机选择 BYTE/HALFWORD/WORD 的 SINGLE read。read HSIZE 可不同于产生该 lane 最后一次 write 的 HSIZE。
- 为避免 64 KiB 空间中的物理 row/lane 碰撞概率过低而长期漏掉 cross-size 场景，35% 概率将随机 write 改为对已知物理 word 的 SINGLE BYTE/HALFWORD overlay；它仍随机选择 word、lane、数据和访问宽度，但可稳定产生“WORD 写后 BYTE/HALFWORD 改写，再 WORD 读”的真实部分写组合。
- 随机 write 仍覆盖所有支持的 SINGLE/INCR/WRAP/INCR 4/8/16 burst，随机 burst 长度、合法对齐、数据和 burst 内 BUSY；历史 burst read 保证完整 burst 的所有 beat 已由同样几何的 write 初始化，避免把 SRAM 初值未知误当失败。
- `ahb_coverage` 新增物理 SRAM mapping covergroup：追踪每个实际写入 lane 的最后 write HSIZE，并在 read 时采样 `write HSIZE × read HSIZE × bank`，另覆盖 physical lane 与 low/high/interior row。它用于证明“大随机”真正产生跨 HSIZE 的 write/read 组合，而不以随机次数替代覆盖证据。
- 每轮还会发送随机合法的 probe read：地址、HSIZE、burst、BUSY 均不受 write history 限制；refm 只比较其中已初始化的 lane，未初始化 lane 记录为 non-comparable。这样既覆盖自由读协议路径，也保留已知数据读的有效比较。
- 保留 `+LEGAL_RANDOM_PAIRS` 作为兼容参数（现在表示随机 write 数）；新增 `+CROSS_SIZE_READS=<N>`、`+PROBE_READS=<N>` 控制每次 write 后的物理 cross-size SINGLE read 与自由 probe read 数，默认分别为 2、1。

## 2026-08-01：Python regression infrastructure 学习示例

- Python workflow 拆为四个标准库脚本：`run.py` 运行单个 test/seed 并写入结构化 `result.json`；`regress.py` 编排一次编译后的 test x seed 矩阵；`collect_results.py` 汇总 Markdown/JSON 报告；`coverage.py` 复用现有 Makefile/URG 生成 coverage 文本报告。UVM/SV 仍负责周期精确激励、checking 和 coverage，Python 只负责 regression orchestration。
- Makefile 保持日常短命令入口，`make regression` 仍编译一次但将矩阵循环和失败分类委托给 Python；新增 `make py_run`、`make py_regression`、`make py_coverage` 供单项复现、独立矩阵和 coverage 报告使用。结果统一写入已忽略的 `results/`，使 Make 与 Python 生成的 VDB 可共同由 URG 合并。
- `docs/python_scripts_workflow.md` 记录 Makefile/Python/UVM 的职责边界、脚本清单、dry-run、常用随机回归和结果读取方法。
- 删除 `sramc_demo_test`、 `sramc_random_test`

## 2026-08-01：AHB-to-SRAM control decoder Formal 验证骨架

- 新增 `verif/formal/`：以 `ahb_slave_if` 为 formal DUT，建立独立 harness、`formal.f` 与 VC Formal 可配置 Makefile；它不复用 UVM testbench，也不试图用 formal 穷举 SRAM 数据保持，而是聚焦有限的控制/译码性质。
- harness 使用合法 AHB 环境 assumption（zero-wait 上游、支持的 HSIZE、64 KiB 地址窗口和对齐），proof assertion 检查固定 `HREADY_RESP/OKAY`、有效请求下一拍恰选一个 bank、bank 互斥和 CSN 编码；formal cover 搜索 BYTE lane3、high-halfword、bank1 WORD 的可达 witness。
- `make formal` 从 `verif/sim/` 转入 formal flow；当前本机未发现 `vcf`/`vcformal`，因此只交付可在课程服务器环境运行的 VC Formal 模板，尚无实际 proof 结果。`docs/formal_verification_workflow.md` 说明 assume/assert/cover 与 simulation SVA 的区别、工具使用和结果判读。

## 2026-08-01：Codex 对话归档与 WSL 迁移说明

- 新增 `scripts/export_codex_history.py`：从用户目录 `~/.codex` 的 session JSONL 中，按 session `cwd` 筛选本项目会话，导出用户/Codex 的可读 Markdown；工具调用、框架提示和图片不导出，并对常见凭据赋值做基础脱敏。
- 新增 `docs/codex_conversation_workflow.md`：记录导出命令、`E:\\workspace\\chip` 与 WSL 路径对应关系，以及将活跃 EDA 工程放在 Linux 文件系统、E 盘作为备份的性能/权限取舍。
- 生成的 `docs/codex_conversation_export.md` 加入 `.gitignore`，作为本机个人记录保留，避免默认提交冗长或潜在私密的聊天内容。

## 2026-08-03：VC Formal flow 适配 V-2023.12-SP2

- 确认 `vcf -f formal.f` 将 `formal.f` 作为 Tcl script 读取，而不是 VCS filelist。
- 确认该版本支持 `analyze` 和 positional `elaborate sramc_ahb_formal_harness`，不支持 VCS 风格的 `-top`、`-sverilog` 参数。
- 移除 Tcl `clock hclk` / `reset hresetn` 命令：Formal harness 已通过 `(* gclk *)`、`default clocking @(posedge hclk)` 和 assume property 表达时钟/复位约束。
- 忽略 VC Formal 生成的 `vcst_rtdb/`、`.dw_map_file` 等产物；下一步验证目标是让 `prove -all` 进入实际 property proof，并记录 Proven/Falsified/Cover reached 结果。
- 根据 `NO_PROPERTIES_FOUND_FV` 诊断，在 `analyze` 命令中加入 `-sva`；该版本默认只完成 RTL/harness elaboration，不会自动导入 source `assume/assert/cover property`。

## 2026-08-03：统一从 `verif/sim` 调用 Formal

- `verif/sim/Makefile` 的 `formal` 目标增加入口提示，并继续负责递归进入 `verif/formal`；用户侧固定执行 `cd verif/sim && make formal`。
- 曾尝试将 `-sva` 作为 VCF 启动选项；V-2023.12-SP2 实测不支持该选项，最终改为 native `fvassume`/`fvassert`/`fvcover` script property flow。
- 已在服务器实际确认 license、RTL 分析和 harness elaboration 成功；此前 `vcf -f formal.f` 能到 `check_fv`，但因未启用 source SVA 报 `NO_PROPERTIES_FOUND_FV`。
- F 盘 bridge 曾因 Windows CRLF 将命令变成 `cd ...\r`，已使用 LF-only 命令验证传输修复；当前 bridge 监听进程未消费后续命令，因此最终 property proof 尚待重启 bridge 后由 `verif/sim/make formal` 复跑确认。
- 确认 `vcst_rtdb/session.lock` 中记录的 PID `13646` 已不存在，清理该 stale lock；该锁会使后续 `make formal` 直接报 Error 34。VCF 的 source-property 开关改为 `check_fv -sva`，而不是会触发 CMD-010 的 `analyze -sva`。
- VC Formal 在脚本执行完 `check_fv` 后默认停留在交互式 `vcf>`；为避免 bridge 卡在未退出的 VCF 会话，`formal.f` 末尾显式加入 `exit`。
- `check_fv` 默认非阻塞，若紧接 `exit` 会在 proof 完成前结束。改为 `check_fv -block`，保证 `make formal` 返回前已输出全部 Proven/Falsified/Covered 结果。
- native `fvassert` 对跨拍输入采样的定义与源 SVA 不同，`p_one_bank_after_request` 改为直接约束 DUT 已锁存的 `dut.htrans_r`：只要译码阶段有效，必须恰好选中一个 SRAM bank。这直接对应 RTL 的实际译码状态。
- 最终从 `verif/sim` 执行 `make formal` 成功：VC Formal V-2023.12-SP2 返回 `exit_status=0`；`p_zero_wait`、`p_okay_response`、`p_one_bank_after_request`、`p_bank_mutual_exclusion`、`p_legal_chip_select` 全部 `proven`，`c_byte_lane3`、`c_halfword_high`、`c_word_bank1` 全部 `covered`。Makefile 先单独执行 `vcf -reset` 清理旧 session，再执行实际 proof。

## 2026-08-03：bridge 重命名

- 将无关工艺名的 `tsmc40_bridge` 重命名为 `sramc_uvm_bridge`，明确它只负责 Windows F 盘与本 SRAMC UVM 项目的 WSL 命令桥接，不代表 TSMC 40nm PDK 或工具链。
- 环境变量相应改为 `SRAMC_UVM_PROJECT_DIR`，文档中的启动、状态检查和停止命令均使用新路径。

## 2026-10-08：SRAMC/SPIM 验证收口复核

- 按项目规格确认 SRAM BYTE/HALFWORD/WORD 的 bank/lane/row 高位地址映射符合要求，并同步修订 RTL 注释与 testcase 文档，明确它是接口约定而非待核实偏差。
- 为 SPIM 忙时写保护用例加入忙态确认及传输后 CTRL、DIVIDER、SS 读回；启用 SPI responder/scoreboard 通过 MOSI 检查 TX 写保护。新增 `spi_interrupt_mask_test` 验证 IE=0 时传输仍完成且 IRQ 始终为低，并加入默认回归、coverage 和 Python suite 列表。
- 补充正常模式合法 AHB 的收口范围、排除项及 latch 评审结论。Verilator lint 观察到 `sram_core.v` 的 8 个 `sram_cs*_data_in` 隐式 latch；源码注释表明其用于保持未选中 lane 的写数据；`sram_data_out` 的非读保持也由 RTL 显式表达。是否允许目标实现含这些 latch 仍需综合/工艺 signoff。
- 当前 WSL：Icarus 对 SPIM 与 SRAMC 顶层 RTL 编译通过；Verilator lint 退出码 0，但报告 8 个 latch 及其他 warning。SPIM/SRAMC 的 VCS UVM 编译分别因 VCS 安装路径不存在而未执行，SRAMC formal 因 `vcf` 不在 PATH 而未执行。历史回归/formal 记录不作为当前版本重跑结果。

## 2026-10-08：Rocky WSL 当前版本复跑结果

- 上一段“工具缺失、尚未复跑”的记录只反映默认 WSL 发行版。切换到 Rocky-8.10 后，使用 VCS V-2023.12-SP1 重新编译并运行完整六用例矩阵，seed=1，6/6 PASS，UVM_ERROR/FATAL=0。
- 为覆盖所有物理 mapping cross，在 `sramc_legal_random_test` 前置同一 row 的确定性 BYTE/HALFWORD 别名读写；合并报告中 AHB transfer 与 SRAM mapping 两个 functional coverage group 均为 100%，18/18 `WRITE_SIZE × READ_SIZE × PHYSICAL_BANK` bins 命中。DUT hierarchy line/condition/toggle/branch/assert 均为 100%；9 条 DUT assertion 无失败，6 个 cover property 全命中。
- VC Formal V-2023.12-SP2 当前工作区 proof 通过：5 项 AHB response/bank decoder assertion proven，BYTE lane3、HALFWORD high、WORD bank1 三个 cover 均 covered。
- 这是一轮 seed=1 的完整 testcase 矩阵，不是多 seed 统计回归。正常模式、合法对齐地址及排除场景仍按 `docs/testcase.md` 限定；8 个数据输入 latch 和 `sram_data_out` 的保持行为仍需综合/目标工艺签核。

## 2026-10-08：清除 SRAM 数据路径组合 latch 并完成五 seed 复核

- `sram_core` 的 8 个 SRAM 写数据输入现在每拍先默认赋 0，再按有效 bank/lane 覆盖；未选中 SRAM 的写数据输入不需要跨周期保持。`ahb_slave_if` 的 `sram_data_out` 在有效读外默认输出 `SUB_DATA`，避免用组合自保持实现非读周期 HRDATA。
- Ubuntu WSL Verilator 对 `sram_core` 和 `ahb_slave_if` lint 退出码为 0，未报告 latch；行为 SRAM 模型 `RA1SH.v` 仍有 CASEWITHX 提示。Rocky WSL VC Formal elaboration gate count 显示 `Latch Bitwise 0`，5/5 AHB assertion proven、3/3 cover covered。
- Rocky WSL VCS `make regression REGRESS_SEEDS=1-5`：30/30 testcase-seed PASS，UVM_ERROR/FATAL=0、scoreboard mismatch=0。合并 30 份 VDB 后两个功能覆盖组均为 100%；DUT hierarchy line/condition/toggle/branch/assert 为 100%/95.77%/100%/93.22%/100%，9/9 DUT assertion 和 6/6 cover property 均通过/命中。
- 仍不包含真实 SRAM macro 的 PVT/时序、BIST/DFT、HREADY wait-state 和非法访问验证；这些仍属于单独计划与 signoff 项。
