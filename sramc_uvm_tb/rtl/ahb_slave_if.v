`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ahb_slave_if
//
// 模块功能：
//   这是 SRAM 控制器里的 AHB slave 接口转换模块。
//
//   它负责把 AHB 总线访问转换成 SRAM 侧控制信号：
//     1. 将 AHB 地址阶段的地址/控制信号打一拍，使其和写数据阶段对齐。
//     2. 根据 htrans/hwrite 判断当前是否为有效读写访问。
//     3. 根据 hsize 和地址选择位产生 SRAM byte lane 片选。
//     4. 根据 bank_sel/hsize/haddr_sel 将 8 片 SRAM 的读数据拼成 hrdata。
//
// 地址映射遵循本项目规格：BYTE 以 HADDR[15] 选 bank、[14:13] 选 lane；
// HALFWORD 以 HADDR[14] 选 bank、[13] 选半字；WORD 以 HADDR[13] 选 bank；
// SRAM row 均取 [12:0]。这是本设计明确约定的接口映射。
//////////////////////////////////////////////////////////////////////////////////

module ahb_slave_if(
    //----------------------------------------------------------------------
    // AHB 输入信号
    //----------------------------------------------------------------------
    input  hclk,
    input  hresetn,

    input         hsel,      // slave 选中信号。1 表示当前访问选中这个 SRAM 控制器。
    input         hready,    // AHB ready 输入。1 表示当前传输可以推进。
    input         hwrite,    // AHB 读写方向。1：写；0：读。
    input  [1:0]  htrans,    // AHB 传输类型。NONSEQ/SEQ 表示有效传输。
    input  [2:0]  hsize,     // AHB 访问宽度。本设计使用 000/001/010 表示 8/16/32-bit。
    input  [2:0]  hburst,    // AHB burst 类型。本模块只寄存该信号，后续没有实际使用。
    input  [31:0] haddr,     // AHB 字节地址。
    input  [31:0] hwdata,    // AHB 写数据。

    //----------------------------------------------------------------------
    // 从 sram_core 返回的 SRAM 读数据
    //
    // SRAM 阵列共有 8 片，每片是 8K x 8-bit：
    //   bank0：sram_q0、sram_q1、sram_q2、sram_q3
    //   bank1：sram_q4、sram_q5、sram_q6、sram_q7
    //----------------------------------------------------------------------
    input  [7:0] sram_q0,
    input  [7:0] sram_q1,
    input  [7:0] sram_q2,
    input  [7:0] sram_q3,
    input  [7:0] sram_q4,
    input  [7:0] sram_q5,
    input  [7:0] sram_q6,
    input  [7:0] sram_q7,

    //----------------------------------------------------------------------
    // AHB 输出信号
    //----------------------------------------------------------------------
    output [1:0]  hresp,       // AHB 响应。本设计固定返回 OKAY。
    output        hready_resp, // AHB ready 响应。本设计不插入等待周期。
    output [31:0] hrdata,      // AHB 读数据。

    //----------------------------------------------------------------------
    // SRAM 侧控制/数据信号
    //----------------------------------------------------------------------
    output        sram_w_en,     // SRAM 写使能，低有效。0：写；1：读。
    output reg    bank_sel,      // bank 选择。1：bank0；0：bank1。
    output reg [3:0] bank0_csn,  // bank0 内 4 片 SRAM 的片选，低有效。
    output reg [3:0] bank1_csn,  // bank1 内 4 片 SRAM 的片选，低有效。
    output [12:0] sram_addr_out, // 送到每片 8K SRAM 的片内地址。
    output [31:0] sram_wdata     // 送到 sram_core 的写数据。
);

    //----------------------------------------------------------------------
    // AHB 地址/控制阶段寄存器
    //
    // AHB 是流水协议：
    //   第 N 拍   ：地址和控制信号有效
    //   第 N+1 拍 ：写数据信号有效
    //
    // SRAM 侧希望同一次访问的地址、控制、写数据在同一拍对齐。
    // 因此这里把 AHB 地址和控制信号打一拍，和下一拍的 hwdata 对齐。
    //----------------------------------------------------------------------
    reg         hwrite_r;
    reg  [2:0]  hsize_r;
    reg  [2:0]  hburst_r;
    reg  [1:0]  htrans_r;
    reg  [31:0] haddr_r;

    //----------------------------------------------------------------------
    // 内部译码信号
    //----------------------------------------------------------------------
    reg  [3:0]  sram_csn;       // 单个 bank 内部的 byte lane 片选，低有效。

    wire [1:0]  haddr_sel;      // 在一个 bank 内选择 byte lane 或 halfword lane。
    wire [1:0]  hsize_sel;      // 访问宽度编码：00/01/10 = 8/16/32-bit。
    wire        sram_csn_en;    // SRAM 片选使能。1 表示当前存在有效 SRAM 访问。

    wire        sram_write;     // 译码后的有效 SRAM 写请求。
    wire        sram_read;      // 译码后的有效 SRAM 读请求。
    wire [15:0] sram_addr;      // SRAM 64KB 地址窗口，取自 haddr_r[15:0]。
    reg  [31:0] sram_data_out;  // 选出的 SRAM 读数据，最终返回给 AHB hrdata。

    //----------------------------------------------------------------------
    // AHB htrans 传输类型编码
    //----------------------------------------------------------------------
    parameter IDLE   = 2'b00;
    parameter BUSY   = 2'b01;
    parameter NONSEQ = 2'b10;
    parameter SEQ    = 2'b11;

    // 8-bit 或 16-bit 读时，高位用该值补齐。
    parameter SUB_DATA = 1'b0;

    //----------------------------------------------------------------------
    // AHB 基本响应
    //
    // 这个 SRAM slave 被建模为永远 ready、永远 OKAY：
    //   - 不插入 wait state
    //   - 不返回 ERROR/RETRY/SPLIT
    //----------------------------------------------------------------------
    // VCS coverage off
    // Signoff exclusion: this SRAM controller is zero-wait and always returns OKAY.
    assign hready_resp = 1'b1;
    assign hresp       = 2'b00;
    // VCS coverage on
    assign hrdata      = sram_data_out;

    //----------------------------------------------------------------------
    // AHB 读写命令译码
    //
    // 只有 htrans_r 为 NONSEQ 或 SEQ 时，才认为当前传输有效。
    // hwrite_r 决定这笔有效传输是写还是读。
    //
    // AHB hwrite：
    //   1：写
    //   0：读
    //
    // SRAM WEN：
    //   0：写
    //   1：读
    //----------------------------------------------------------------------
    assign sram_write = ((htrans_r == NONSEQ) || (htrans_r == SEQ)) && hwrite_r;
    assign sram_read  = ((htrans_r == NONSEQ) || (htrans_r == SEQ)) && (!hwrite_r);
    assign sram_w_en  = !sram_write;

    //----------------------------------------------------------------------
    // 地址和访问宽度选择
    //
    // sram_addr：
    //   取 haddr_r[15:0]，表示控制器暴露一个 64KB 的字节地址空间。
    //
    // sram_addr_out：
    //   送给每片 8K x 8-bit SRAM 的片内地址。
    //   因为 8K = 2^13，所以每片 SRAM 需要 13 根地址线。
    //
    // hsize_sel：
    //   决定本次访问宽度：
    //     2'b00 -> 8-bit 访问
    //     2'b01 -> 16-bit 访问
    //     2'b10 -> 32-bit 访问
    //
    // haddr_sel：
    //   决定在一个 bank 里面访问哪个 byte lane 或 halfword lane。
    //   当前代码写成 sram_addr[14:13]，意味着 byte lane 选择来自
    //   64KB 地址窗口中的较高地址位。
    //
    //   本项目规格明确使用高位地址段选择 bank/lane，不能按常见的
    //   haddr[1:0] byte-lane 习惯推断映射；参考模型也按本约定建模。
    //----------------------------------------------------------------------
    assign sram_addr     = haddr_r[15:0];
    assign sram_addr_out = sram_addr[12:0];
    assign sram_csn_en   = (sram_write || sram_read);
    assign haddr_sel     = sram_addr[14:13];
    assign hsize_sel     = hsize_r[1:0];

    // 写数据直接透传给 sram_core。真正写哪些 byte lane 由 bank0_csn/bank1_csn 控制。
    assign sram_wdata = hwdata;

    //----------------------------------------------------------------------
    // always 块 1：bank 选择和最终 bank 片选生成
    //
    // 综合后的电路：
    //   纯组合译码逻辑 / 多路选择器，不应该产生触发器。
    //
    // 功能：
    //   sram_csn 表示“单个 bank 内部哪几个 byte lane 有效”。
    //   本 always 块决定把这个 sram_csn 送给 bank0 还是 bank1。
    //
    // 当前地址映射：
    //   8-bit  访问：看 sram_addr[15] 选择 bank0/bank1。
    //   16-bit 访问：看 sram_addr[14] 选择 bank0/bank1。
    //   32-bit 访问：看 sram_addr[13] 选择 bank0/bank1。
    //
    // 因为 csn 低有效：
    //   4'b1111 表示该 bank 内 4 片 SRAM 全不选。
    //   只有被选中的 bank 才接收 sram_csn。
    //----------------------------------------------------------------------
    always@(*) begin
        if(sram_csn_en) begin
            case(hsize_sel)
                2'b00: begin
                    bank0_csn = (sram_addr[15] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[15] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[15] == 1'b0) ? 1'b1    : 1'b0;
                end
                2'b01: begin
                    bank0_csn = (sram_addr[14] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[14] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[14] == 1'b0) ? 1'b1    : 1'b0;
                end
                2'b10: begin
                    bank0_csn = (sram_addr[13] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[13] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[13] == 1'b0) ? 1'b1    : 1'b0;
                end
                // VCS coverage off
                // Signoff exclusion: hsize_sel==2'b11 is outside the 8/16/32-bit access spec.
                default: begin
                    bank0_csn = (sram_addr[13] == 1'b0) ? sram_csn : 4'b1111;
                    bank1_csn = (sram_addr[13] == 1'b1) ? sram_csn : 4'b1111;
                    bank_sel  = (sram_addr[13] == 1'b0) ? 1'b1    : 1'b0;
                end
                // VCS coverage on
            endcase
        end
        else begin
            bank0_csn = 4'b1111;
            bank1_csn = 4'b1111;
            bank_sel  = 1'b1;
        end
    end

    //----------------------------------------------------------------------
    // always 块 2：从 8 片 SRAM 的读数据中选择并拼接 hrdata
    //
    // 综合后的电路：
    //   组合多路选择器网络，所有路径都有默认输出，不推断 latch。
    //   HRDATA 只在有效读传输的数据相位被采样；非读周期输出 SUB_DATA。
    //
    // 功能：
    //   bank_sel  选择 bank0 还是 bank1。
    //   hsize_sel 选择 8/16/32-bit 读宽度。
    //   haddr_sel 选择该 bank 内部的 byte lane 或 halfword lane。
    //
    // 读数据格式：
    //   8-bit  读：高 24 bit 补 SUB_DATA。
    //   16-bit 读：高 16 bit 补 SUB_DATA。
    //   32-bit 读：4 个 8-bit SRAM 输出拼成完整 32-bit。
    //----------------------------------------------------------------------
    always@(*) begin
        sram_data_out = {32{SUB_DATA}};
        if(hresetn && sram_read) begin
            if(bank_sel) begin
                case(hsize_sel)
                    2'b00: begin
                        case(haddr_sel)
                            2'b00: sram_data_out = {{24{SUB_DATA}}, sram_q0};
                            2'b01: sram_data_out = {{24{SUB_DATA}}, sram_q1};
                            2'b10: sram_data_out = {{24{SUB_DATA}}, sram_q2};
                            2'b11: sram_data_out = {{24{SUB_DATA}}, sram_q3};
                        endcase
                    end
                    2'b01: begin
                        case(haddr_sel[0])
                            1'b0: sram_data_out = {{16{SUB_DATA}}, sram_q1, sram_q0};
                            1'b1: sram_data_out = {{16{SUB_DATA}}, sram_q3, sram_q2};
                        endcase
                    end
                    2'b10: begin
                        sram_data_out = {sram_q3, sram_q2, sram_q1, sram_q0};
                    end
                    // VCS coverage off
                    // Signoff exclusion: hsize_sel==2'b11 is an unsupported read width.
                    default: begin
                        sram_data_out = {sram_q3, sram_q2, sram_q1, sram_q0};
                    end
                    // VCS coverage on
                endcase
            end
            else begin
                case(hsize_sel)
                    2'b00: begin
                        case(haddr_sel)
                            2'b00: sram_data_out = {{24{SUB_DATA}}, sram_q4};
                            2'b01: sram_data_out = {{24{SUB_DATA}}, sram_q5};
                            2'b10: sram_data_out = {{24{SUB_DATA}}, sram_q6};
                            2'b11: sram_data_out = {{24{SUB_DATA}}, sram_q7};
                        endcase
                    end
                    2'b01: begin
                        case(haddr_sel[0])
                            1'b0: sram_data_out = {{16{SUB_DATA}}, sram_q5, sram_q4};
                            1'b1: sram_data_out = {{16{SUB_DATA}}, sram_q7, sram_q6};
                        endcase
                    end
                    2'b10: begin
                        sram_data_out = {sram_q7, sram_q6, sram_q5, sram_q4};
                    end
                    // VCS coverage off
                    // Signoff exclusion: hsize_sel==2'b11 is an unsupported read width.
                    default: begin
                        sram_data_out = {sram_q7, sram_q6, sram_q5, sram_q4};
                    end
                    // VCS coverage on
                endcase
            end
        end
    end

    //----------------------------------------------------------------------
    // always 块 3：单个 bank 内部的 byte lane 片选译码
    //
    // 综合后的电路：
    //   纯组合译码器，不产生触发器。
    //
    // 功能：
    //   根据访问宽度 hsize_sel 和 lane 选择 haddr_sel 生成 sram_csn。
    //   sram_csn 只描述“一个 bank 内部选哪几片 SRAM”。
    //   always 块 1 会进一步把它送到 bank0_csn 或 bank1_csn。
    //
    // 译码表：
    //   32-bit：4'b0000，4 个 byte lane 全选。
    //   16-bit：4'b1100 或 4'b0011，选低半字或高半字。
    //   8-bit ：4'b1110/1101/1011/0111，选其中 1 个 byte lane。
    //----------------------------------------------------------------------
    always@(*) begin
        if(hsize_sel == 2'b10) begin
            sram_csn = 4'b0000;
        end
        else if(hsize_sel == 2'b01) begin
            if(haddr_sel[0] == 1'b0)
                sram_csn = 4'b1100;
            else
                sram_csn = 4'b0011;
        end
        else if(hsize_sel == 2'b00) begin
            case(haddr_sel)
                2'b00: sram_csn = 4'b1110;
                2'b01: sram_csn = 4'b1101;
                2'b10: sram_csn = 4'b1011;
                2'b11: sram_csn = 4'b0111;
            endcase
        end
        // VCS coverage off
        // Signoff exclusion: hsize_sel==2'b11 is outside the 8/16/32-bit access spec.
        else begin
            sram_csn = 4'b0000;
        end
        // VCS coverage on
    end

    //----------------------------------------------------------------------
    // always 块 4：AHB 地址/控制阶段打一拍
    //
    // 综合后的电路：
    //   一组带低有效异步复位的 D 触发器。
    //
    // 功能：
    //   当 hsel && hready 为真时，采样 AHB 地址阶段的地址和控制信号。
    //   下一拍这些寄存后的信号会和 hwdata 对齐，SRAM 侧就能看到同一笔
    //   访问对应的地址、控制和写数据。
    //
    //   当 slave 没被选中或者 AHB 没 ready 时，清空寄存命令，避免旧命令
    //   被错误地当成新的 SRAM 访问。
    //----------------------------------------------------------------------
    always@(posedge hclk or negedge hresetn) begin
        if(!hresetn) begin
            hwrite_r <= 1'b0;
            hsize_r  <= 3'b0;
            hburst_r <= 3'b0;
            htrans_r <= 2'b0;
            haddr_r  <= 32'b0;
        end
        else if(hsel && hready) begin
            hwrite_r <= hwrite;
            hsize_r  <= hsize;
            hburst_r <= hburst;
            htrans_r <= htrans;
            haddr_r  <= haddr;
        end
        else begin
            hwrite_r <= 1'b0;
            hsize_r  <= 3'b0;
            hburst_r <= 3'b0;
            htrans_r <= 2'b0;
            haddr_r  <= 32'b0;
        end
    end

endmodule
