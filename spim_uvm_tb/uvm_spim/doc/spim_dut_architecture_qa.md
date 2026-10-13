# SPIM DUT 架构问答

本文说明 `spim_uvm_tb` 中 SPI Master 的 RTL 架构，以及验证环境中一次 SPI 传输是如何被激励、观察和判定的。重点目录为 `rtl/` 与 `verif/`。

## 1. DUT 是什么

这是一个由 APB 配置的 SPI Master。CPU/APB master 写入发送数据和控制寄存器；DUT 输出 CSn、SCLK、MOSI，采样外部从机返回的 MISO；传输完成时可产生 IRQ。

```text
APB master/CPU
       |
       v
+------------------------- spi_top --------------------------+
| APB 从接口、寄存器组、CSn 控制、IRQ                          |
|       |                                      |              |
|       v                                      v              |
| spi_clgen                              spi_shift            |
| PCLK 分频产生 SCLK                     TX/RX 串行移位引擎     |
+-------------------------------------------------------------+
       |                |              |              |
      CSn              SCLK           MOSI           MISO
       \_________________ SPI slave _________________/
```

| RTL 模块 | 职责 |
| --- | --- |
| `spi_top.v` | APB 接口、寄存器组、CSn、IRQ，以及子模块连接。 |
| `spi_clgen.v` | 计数 PCLK 周期以产生 SCLK 和边沿使能脉冲。 |
| `spi_shift.v` | 保存一帧数据、发送 MOSI、采样 MISO，并报告 busy。 |
| `spi_defines.v` | 编译期位宽、寄存器地址偏移和 CTRL 字段位置。 |

主要入口：`rtl/spi_top.v`、`rtl/spi_clgen.v`、`rtl/spi_shift.v`。

## 2. 时钟与 CDC

该设计内部只有 **PCLK 一个时钟域**。所有时序逻辑都由 PCLK 驱动；`sclk_pad_o` 是由 PCLK 推导出的输出波形，并不是供内部寄存器触发的时钟。`spi_clgen` 在 PCLK 域内产生 `pos_edge` / `neg_edge` 两个单周期使能，`spi_shift` 依据这些使能完成串行收发。

```text
PCLK -> APB 寄存器 / 分频计数器 / SCLK 输出 / 移位寄存器
```

因此 APB 与 SPI 引擎之间没有内部 CDC。芯片引脚处的 MISO 来自外部从机；本 RTL 假设从机遵循本 master 产生的 SPI 时序，**没有**为任意异步 MISO 设置通用的两级同步器。

TB 中 PCLK 周期为 20 ns，因此频率为 50 MHz。分频器重装 `divider`、每个 PCLK 递减，到零时翻转一次 SCLK：

```text
f_SCLK = f_PCLK / (2 × (DIVIDER + 1))
```

| DIVIDER | PCLK=50 MHz 时的 SCLK |
| ---: | ---: |
| 0 | 25 MHz |
| 1 | 12.5 MHz |
| 4 | 5 MHz |
| 24 | 1 MHz |

## 3. 编译期配置与编辑器灰色 `ifdef`

`spi_defines.v` 选择了 16 位分频器、最大 128 bit 帧、8 路从机选择：

```verilog
`define SPI_DIVIDER_LEN_16
`define SPI_MAX_CHAR_128
`define SPI_SS_NB_8
```

所以当前编译配置中有 `divider[15:0]`、`data[127:0]`、四个 32-bit TX/RX 窗口，以及 `ss[7:0]`。若编辑器把本应生效的分支也显示为灰色，通常只是它没解析到 `` `include "spi_defines.v" ``；仿真/综合预处理仍会保留正确分支。

## 4. APB 寄存器映射与 `PADDR[4:2]`

APB 数据总线宽度为 32 bit，正常寄存器访问应采用四字节对齐的字节地址。RTL 只译码 `PADDR[4:2]`，因此有八个 32-bit 槽位：

| 地址 | `PADDR[4:2]` | 写操作 | 读操作 |
| ---: | :---: | --- | --- |
| `0x00` | `000` | TX_0 | RX_0 |
| `0x04` | `001` | TX_1 | RX_1 |
| `0x08` | `010` | TX_2 | RX_2 |
| `0x0C` | `011` | TX_3 | RX_3 |
| `0x10` | `100` | CTRL | CTRL |
| `0x14` | `101` | DIVIDER | DIVIDER |
| `0x18` | `110` | SS | SS |
| `0x1C` | `111` | 未定义 | 未定义 |

`PADDR[1:0]` 表示一个 32-bit word 内的字节位置。合法 word 地址低两位为 `00`，例如 `0x14` 的 `[4:2]=101`、`[1:0]=00`。

本 RTL 不译码低两位，所以 `0x14`、`0x15`、`0x16`、`0x17` 都会选中 DIVIDER。正常 UVM 事务限制 `addr[1:0] == 0`，只使用对齐地址。

## 5. APB 事务如何变成引脚波形

UVM 中一次 APB 访问是一个 `apb_seq_item`：

```systemverilog
addr   // 字节地址
data   // 写数据或读回数据
we     // 1：写；0：读
delay  // 访问前等待的 PCLK 个数
```

例如写 `DIVIDER=4`，事务为 `addr=0x14`、`data=0x0000_0004`、`we=1`。`apb_write_seq` 生成它，`apb_driver` 则把它翻译为 APB 两阶段：

```text
Setup：  PSEL=1, PENABLE=0, PADDR=0x14, PWRITE=1, PWDATA=4
Access： PSEL=1, PENABLE=1，地址/控制/数据保持稳定，等待 PREADY=1
```

DUT 不认识 SystemVerilog class，它只看到引脚。例如内部的 DIVIDER 选择信号为：

```verilog
assign spi_divider_sel = PSEL & PENABLE &
                          (PADDR[4:2] == `SPI_DEVIDE);
```

当 `spi_divider_sel && PWRITE && !tip` 成立时，`divider` 才装入 `PWDATA[15:0]`。`PREADY` 为寄存器信号，因此 driver 会等待完成；`PSLVERR` 固定为零。

## 6. SS、ASS、IE、IRQ、GO 与 tip

### SS 与 ASS

`SS` 是 8-bit 从机选择位图，位为 1 表示选择对应从机。但物理 `ss_pad_o` 是低有效，所以被选中从机的 CSn 引脚会输出 0。

`ASS`（CTRL[13]，Automatic Slave Select）决定 CSn 的时序：

| ASS | CSn 行为 |
| :---: | --- |
| 1 | 自动模式：仅在 `tip=1` 的传输期间拉低被选 CSn。 |
| 0 | 手动模式：`SS` 直接决定 CSn，空闲时也可能保持拉低。 |

若 `SS=8'b0000_0001`：

```text
ASS=1, tip=0 -> CSn = 1111_1111
ASS=1, tip=1 -> CSn = 1111_1110
ASS=0        -> CSn = 1111_1110（与 tip 无关）
```

### IE 与 IRQ

`IE` 是软件写入的中断使能位（CTRL[12]）；`IRQ` 是 DUT 向 CPU 发出的中断请求。

```text
IE=0：传输完成，但不产生 IRQ。
IE=1：最后一位传输完成时，IRQ 拉高。
```

在本 RTL 中，**之后一次完成的 APB 访问**（`PREADY=1`）会清除 IRQ。因此软件可采用两种完成等待方式：轮询 CTRL.GO 直到为零，或使能 IE 后等待 IRQ。

### GO 与 tip

`GO` 是 CTRL[8] 中软件可见的启动请求；`tip`（Transfer In Progress）是 `spi_shift` 输出的内部实际忙状态。

```text
软件写 GO=1
  -> spi_shift 看到 go && !tip
  -> tip=1：SCLK 运行，自动 CSn 拉低，受保护写入被屏蔽
  -> 最后一位完成
  -> tip=0，spi_top 将 GO 清为 0
```

所以 GO 是“命令/请求”，tip 是“引擎正在工作”。CTRL 将 GO 作为软件轮询状态暴露，因此代码中也称它为 GO/BSY。

## 7. CTRL 字段

| 字段 | 含义 |
| --- | --- |
| `ASS` | 自动 CSn 时序控制。 |
| `IE` | 中断使能。 |
| `LSB` | `1`：LSB first；`0`：MSB first。 |
| `TX_NEGEDGE` | `1`：在 SCLK 下降沿更新 MOSI。 |
| `RX_NEGEDGE` | `1`：在 SCLK 下降沿采样 MISO。 |
| `GO` | 启动请求。 |
| `CHAR_LEN[6:0]` | 位数编码；零表示 128 bit。 |

SCLK 空闲为低。常见的 mode-0 类配置是 `TX_NEGEDGE=1`、`RX_NEGEDGE=0`：下降沿更新 MOSI，上升沿采样 MISO。

## 8. 共用的 128-bit TX/RX 帧存储

设计没有独立的 128-bit TX buffer 和 RX buffer。`spi_shift` 中只有一个共用的 `data[127:0]`：

```text
传输前：data 保存经 TX_0～TX_3 写入的待发数据。
传输中：data 提供后续 MOSI 位，并被采到的 MISO 位逐步覆盖。
传输后：data 保存 RX_0～RX_3 可读出的接收数据。
```

当前 128-bit 配置的映射：

```text
TX_0/RX_0 = data[31:0]
TX_1/RX_1 = data[63:32]
TX_2/RX_2 = data[95:64]
TX_3/RX_3 = data[127:96]
```

## 9. 共用存储为何仍可全双工

虽然帧存储共用，但当前正输出到 MOSI 的一位保存在独立寄存器 `s_out` 中。`data` 提供下一待发位；`s_out` 保持已经驱动到 MOSI 的当前位。之后 MISO 的采样即使覆盖了 `data` 中某位，也不会改变当前 MOSI 引脚。

```verilog
s_out <= (tx_clk || !tip) ? data[tx_bit_pos] : s_out;
data[rx_bit_pos] <= rx_clk ? s_in : data[rx_bit_pos];
```

典型 MSB-first、mode-0 类传输的时序是：

```text
开始：       第一位 TX 在第一个 SCLK 上升沿前已放到 MOSI。
上升沿：     采样 MISO，写入 RX 位位置。
下降沿：     把下一位 TX 送到 s_out/MOSI。
重复：       每个 bit interval 同时完成一个 MOSI 位和一个 MISO 位。
```

这就是 SPI 全双工的含义：两个方向的 bit 在同一个位周期反向流动，不要求同一存储位在同一刻读写。

## 10. 一个完整的 8-bit 传输

假设：

```text
TX=8'hA5，从机返回 8'h3C
DIVIDER=4，SS=1，ASS=1，CHAR_LEN=7
LSB=0，TX_NEGEDGE=1，RX_NEGEDGE=0，IE=1
```

流程：

```text
1. APB 写 TX_0=0xA5 -> data[7:0]=A5。
2. APB 写 DIVIDER=4、SS=1。
3. APB 写 CTRL 配置字段，最后写 GO=1。
4. spi_shift 置 tip=1。
5. ASS=1 且 tip=1，选中 CSn 拉低。
6. spi_clgen 每五个 PCLK 使 SCLK 翻转一次。
7. spi_shift 以 MSB-first 发送 A5，并在 RX 边沿将 3C 写入 data。
8. 最后一位完成：tip=0、GO=0、CSn 释放；IE=1 时 IRQ 拉高。
9. APB 读 RX_0，得到 data[7:0]=3C。
```

## 11. `spi_poll_test` 与 `spi_interrupt_test` 到底在测什么

先记住：test 的通过不是因为“看到了波形”，而是因为 monitor 和 scoreboard 收到的数据与预期一致，且 UVM log 中没有 `UVM_ERROR/UVM_FATAL`。波形是定位失败和理解协议的工具。

### `spi_poll_test`：验证轮询完成路径

`config_polling_test` 中依次做下面这些事：

```text
1. SPI_config_rand_order_seq：随机写 TX 数据、DIVIDER、SS、CTRL（含位宽、边沿、位序）。
2. ctrl_go_seq：通过 RAL 前门把 CTRL.GO 写成 1，启动传输。
3. 并行执行：
   - spi_tfer_seq：交给 SPI agent 的从机 driver，要求它在正确边沿回驱随机 MISO 数据；
   - tfer_over_by_poll_seq：反复 APB 读 CTRL，直到 GO/BSY 从 1 变为 0。
4. 轮询结束后：取消 SS，并用 RAL mirror 读取 RX_0～RX_3。
```

它验证的不是“能不能读 CTRL”，而是一条完整闭环：APB 配置是否生效、GO 能否启动、CS/SCLK 时序是否出现、MOSI 是否等于写入的 TX、DUT 是否在设定边沿采到 MISO、GO 是否在结束后清零、RX 寄存器读回是否正确。

### `spi_interrupt_test`：验证中断完成路径

前半段配置、GO 和 SPI 从机响应与 `spi_poll_test` 相同，但它强制 `IE=1`，并将等待方式换成：

```text
1. 等待 intr_if.IRQ 的上升沿。
2. 传输结束后执行一次 APB 访问（轮询/读寄存器）。
3. 调用 is_interrupt_cleared() 确认 IRQ 已被该完成的 APB 访问清零。
4. 重复十次随机配置的传输。
```

它验证的目标是：`IE=1` 时完成事件是否确实产生 IRQ，以及软件响应中断后 APB 访问是否能把 IRQ 清掉。它并没有覆盖“IE=0 时 IRQ 必须保持低”；那是一个很适合你后续补的新 directed test。

### 看波形时只盯这几组关系

| 要确认的事 | 波形/日志上的证据 |
| --- | --- |
| APB 配置被接受 | `PSEL & PENABLE & PREADY` 完成，随后对应寄存器值改变。 |
| 传输真正开始 | 写 GO 后 `tip=1`，ASS=1 时 CSn 拉低，SCLK 开始翻转。 |
| TX 正确 | scoreboard 比较写入 RAL mirror 的 TX 与 monitor 采集的 MOSI。 |
| RX 正确 | SPI driver 发布期望 MISO；scoreboard 比较采样 MISO、DUT RX 寄存器与 RAL readback。 |
| polling 逻辑正确 | CTRL.GO 由 1 回到 0。 |
| interrupt 逻辑正确 | `IRQ` 在完成时拉高，并在随后成功的 APB 访问后拉低。 |

## 12. `intr_if` 为什么存在，能否删除

`intr_if` 只是把 DUT 的单根 `IRQ` 信号包装为一个 virtual interface：

```systemverilog
interface intr_if;
  logic IRQ;
endinterface
```

`top_tb` 将它连到 `.IRQ(INTR.IRQ)`，再通过 `uvm_config_db` 传给 `spi_env_config`；`config_interrupt_test` 最终使用 `@(posedge INTR.IRQ)` 等待中断。

所以对当前环境 **不能删除**：删掉它，`spi_interrupt_test` 就没有合法的 UVM 级 IRQ 观察通道。它不参与 DUT 功能，也不需要 agent；这种只有一两根异步/事件信号的轻量 virtual interface 是合理做法。只有在你同时删除中断测试和所有 `INTR` 引用时，它才可以删。

## 13. `spi_assertions` 的三条 assertion 检查什么

它们通过 `bind spi_top ...` 绑定进 DUT 层次，采样时钟是 `@(posedge PCLK)`。它们不驱动信号，只在规则被违背时打印 assertion failure，并参与 assertion coverage。

| Property | 形式化含义 | 能抓到的典型 bug |
| --- | --- | --- |
| `a_edges_mutually_exclusive` | 任意一个 PCLK 周期内，`pos_edge` 与 `neg_edge` 不能同时为 1。 | 分频器边沿判定错误，导致同周期既当上升沿又当下降沿，移位引擎可能一次执行两种操作。 |
| `a_reset_clears_transfer_state` | `PRESETN=0` 时，`tip=0`、SCLK=0、两个边沿使能均为 0。 | 复位漏清 busy/时钟/边沿脉冲；复位期间仍产生 SPI 时序。 |
| `a_go_starts_transfer` | 非复位时，检测到 GO 从 0 上升到 1 的该采样点必须同时看到 `tip=1`（`|->` 是重叠蕴含）。 | 软件已经发 GO，但 shift engine 没启动，例如 go/tip 握手或条件判断写错。 |

注意：最后两个 `c_reset_*` 是 **cover property**，不是 assertion；它们只记录“复位拉低、复位释放、busy 时复位”是否曾发生，不会使仿真失败。

这三条是很基础的安全网，远不等于 SPI 协议验证完成。后续可增加：`tip=1` 时 DIVIDER/SS/TX 写入不应改变寄存器、ASS=1 时 CSn 只能在 tip 期间有效、IE=0 时完成不得拉高 IRQ、每个传输的 SCLK 边沿数与 CHAR_LEN 一致等。

## 14. 这个设计适合 FIFO 吗

当前共用寄存器方案适合低复杂度、软件逐帧驱动的场景：

```text
装载一帧 TX -> 传输 -> 读取一帧 RX -> 装载下一帧
```

它在 `tip=1` 时禁止 TX、CTRL、DIVIDER、SS 写入，避免软件破坏正在进行的帧。局限是不能连续流式传输，当前帧忙时不能准备下一帧。

若需求包含连续传输、DMA、高吞吐外设/Flash，或 APB 与 SPI 的速率差异很大，应使用独立 TX/RX FIFO：

```text
APB/DMA -> TX FIFO -> shift engine -> MOSI
MISO    -> shift engine -> RX FIFO -> APB/DMA
```

此时还需要 empty/full、读写指针、溢出/下溢、水位线等设计和验证；应有两个 FIFO，而不是一个共用 FIFO。

## 15. 改成 FIFO 后验证要改什么

| 验证区域 | 需要的改动 |
| --- | --- |
| RAL | 增加 FIFO 数据口、状态、level、empty/full、overflow、underflow 寄存器。 |
| Scoreboard | 采用 reference queue，检查 TX 出队顺序、RX 入队顺序和软件读出顺序。 |
| Sequence/test | 增加 burst、连续收发、同时填充/读取、速率不匹配。 |
| Assertion | 检查指针回绕、空读、满写、flag 时序、溢出/下溢处理。 |
| Coverage | 覆盖 empty/full 跳变、水位、回绕、深度、错误和速率比。 |
| 当前 busy-write test | 必须更新：有 TX FIFO 后，忙时继续写 TX 很可能应合法。 |

## 16. 面试中的简洁描述

> 本项目验证一个 APB 可编程 SPI Master。APB 用于配置帧数据、时钟分频、控制字段和从机选择；GO 写入后，PCLK 同步的时钟发生器生成 SCLK 和边沿使能，移位引擎依配置的位序和采样边沿完成全双工 MOSI/MISO 传输。RTL 使用一块 128-bit 共用帧寄存器，`tip` 为高时保护数据和配置不被写坏；传输完成后 GO 清零、自动 CSn 释放，IE 使能时产生 IRQ。验证环境包含 APB/SPI agent、RAL、scoreboard、SVA 与功能覆盖，并用 polling 和 interrupt 两条完成路径进行端到端检查。
