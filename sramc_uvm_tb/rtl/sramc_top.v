`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sramc_top
//
// 模块功能：
//   AHB SRAM 控制器顶层封装。
//
//   对外是一个 AHB slave SRAM 控制器接口，对内包含：
//     1. ahb_slave_if：将 AHB 访问转换成 SRAM 地址、读写、bank 和片选控制。
//     2. sram_core   ：封装 8 片 8K x 8-bit SRAM，并接入 BIST/DFT 测试逻辑。
//////////////////////////////////////////////////////////////////////////////////

module sramc_top(
    //----------------------------------------------------------------------
    // 时钟和复位
    //----------------------------------------------------------------------
    input wire          hclk,       // AHB 总线时钟。
    input wire          sram_clk,   // SRAM 工作时钟。testbench 中通常接 hclk 的反相。
    input wire          hresetn,    // 低有效复位。

    //----------------------------------------------------------------------
    // AHB 输入信号
    //----------------------------------------------------------------------
    input wire          hsel,       // AHB slave 选中信号，1 表示访问本 SRAM 控制器。
    input wire          hwrite,     // AHB 读写方向，1：写；0：读。
    input wire          hready,     // AHB ready 输入，表示总线当前传输可以推进。
    input wire [2:0]    hsize,      // AHB 访问宽度，000/001/010 对应 8/16/32-bit。
    input wire [2:0]    hburst,     // AHB burst 类型，本设计未实际使用。
    input wire [1:0]    htrans,     // AHB 传输类型，NONSEQ/SEQ 表示有效传输。
    input wire [31:0]   hwdata,     // AHB 写数据。
    input wire [31:0]   haddr,      // AHB 地址。

    //----------------------------------------------------------------------
    // BIST / DFT 测试模式控制
    //----------------------------------------------------------------------
    input wire          dft_en,     // DFT 测试模式使能，正常功能仿真时接 0。
    input wire          bist_en,    // BIST 内建自测试使能，正常功能仿真时接 0。

    //----------------------------------------------------------------------
    // AHB 输出信号
    //----------------------------------------------------------------------
    output wire         hready_resp, // AHB ready 响应。本设计不插等待周期，恒为 1。
    output wire [1:0]   hresp,       // AHB 响应。本设计固定返回 OKAY，即 2'b00。
    output wire [31:0]  hrdata,      // AHB 读数据。

    //----------------------------------------------------------------------
    // BIST 测试结果
    //----------------------------------------------------------------------
    output wire         bist_done,   // 8 片 SRAM 的 BIST 全部完成后拉高。
    output wire [7:0]   bist_fail    // 每一位对应一片 SRAM，1 表示对应 SRAM BIST 失败。
);

    //----------------------------------------------------------------------
    // ahb_slave_if 和 sram_core 之间的内部连接信号
    //----------------------------------------------------------------------
    wire        bank_sel;      // bank 选择。1：bank0；0：bank1。
    wire [3:0]  bank0_csn;     // bank0 内 4 片 SRAM 的片选，低有效。
    wire [3:0]  bank1_csn;     // bank1 内 4 片 SRAM 的片选，低有效。

    wire        sram_w_en;     // SRAM 写使能，低有效。0：写；1：读。
    wire [12:0] sram_addr;     // 每片 8K SRAM 的片内地址，8K = 2^13。
    wire [31:0] sram_wdata;    // 写入 SRAM core 的 32-bit 数据。

    //----------------------------------------------------------------------
    // 8 片 SRAM 的读数据输出，每片 SRAM 输出 8-bit
    //
    // bank0：sram_q0、sram_q1、sram_q2、sram_q3
    // bank1：sram_q4、sram_q5、sram_q6、sram_q7
    //----------------------------------------------------------------------
    wire [7:0] sram_q0;
    wire [7:0] sram_q1;
    wire [7:0] sram_q2;
    wire [7:0] sram_q3;
    wire [7:0] sram_q4;
    wire [7:0] sram_q5;
    wire [7:0] sram_q6;
    wire [7:0] sram_q7;

    //----------------------------------------------------------------------
    // AHB slave 接口模块
    //
    // 输入 AHB 访问和 SRAM 返回数据，输出 AHB 响应数据以及 SRAM 控制信号。
    //----------------------------------------------------------------------
    ahb_slave_if ahb_slave_if_u(
        .hclk          (hclk),
        .hresetn       (hresetn),
        .hsel          (hsel),
        .hwrite        (hwrite),
        .hready        (hready),
        .hsize         (hsize),
        .htrans        (htrans),
        .hburst        (hburst),
        .hwdata        (hwdata),
        .haddr         (haddr),

        .sram_q0       (sram_q0),
        .sram_q1       (sram_q1),
        .sram_q2       (sram_q2),
        .sram_q3       (sram_q3),
        .sram_q4       (sram_q4),
        .sram_q5       (sram_q5),
        .sram_q6       (sram_q6),
        .sram_q7       (sram_q7),

        .hready_resp   (hready_resp),
        .hresp         (hresp),
        .hrdata        (hrdata),

        .sram_w_en     (sram_w_en),
        .sram_addr_out (sram_addr),
        .sram_wdata    (sram_wdata),
        .bank_sel      (bank_sel),
        .bank0_csn     (bank0_csn),
        .bank1_csn     (bank1_csn)
    );

    //----------------------------------------------------------------------
    // SRAM core 模块
    //
    // 接收 ahb_slave_if 生成的 SRAM 控制信号，驱动 8 片 SRAM，并返回读数据。
    //----------------------------------------------------------------------
    sram_core sram_core_u(
        .hclk         (hclk),
        .sram_clk     (sram_clk),
        .hresetn      (hresetn),

        .sram_addr    (sram_addr),
        .sram_wdata_in(sram_wdata),
        .sram_wen     (sram_w_en),
        .bank_sel     (bank_sel),
        .bank0_csn    (bank0_csn),
        .bank1_csn    (bank1_csn),

        .bist_en      (bist_en),
        .dft_en       (dft_en),

        .sram_q0      (sram_q0),
        .sram_q1      (sram_q1),
        .sram_q2      (sram_q2),
        .sram_q3      (sram_q3),
        .sram_q4      (sram_q4),
        .sram_q5      (sram_q5),
        .sram_q6      (sram_q6),
        .sram_q7      (sram_q7),

        .bist_done    (bist_done),
        .bist_fail    (bist_fail)
    );

endmodule
