`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: RA1SH

// 模块功能：
//   8K x 8-bit 单端口 SRAM 行为模型。
//
//   该文件模拟一片 SRAM macro 的基本行为：
//     - CEN 低有效片选。
//     - WEN 低有效写使能。
//     - OEN 低有效输出使能。
//     - CLK 上升沿锁存输入并执行读/写。
//
//   它还包含 specify 时序检查和 notifier 处理逻辑，用于在仿真中模拟
//   setup/hold、clock period、clock width 等时序违规导致的 X 传播。
//
// 注意：
//   这是仿真用 SRAM model，不是可综合 RTL 存储器实现。
//////////////////////////////////////////////////////////////////////////////////


`celldefine
module RA1SH ( // 8K x 8-bit SRAM macro model
   Q,          // 读数据输出 [7:0]。
   CLK,        // SRAM 时钟，上升沿执行读/写。
   CEN,        // 片选，低有效。0：选中；1：不访问。
   WEN,        // 写使能，低有效。0：写；1：读。
   A,          // 地址输入 [12:0]。
   D,          // 写数据输入 [7:0]。
   OEN         // 输出使能，低有效。
);
   parameter		   BITS = 8; // 数据位宽 8-bit。
   parameter		   word_depth = 8192; // 存储深度 8K = 8192 = 2^13。
   parameter		   addr_width = 13; // 地址宽度 13-bit。
   parameter		   wordx = {BITS{1'bx}}; // 数据 X 值。
   parameter		   addrx = {addr_width{1'bx}};
	
   output [BITS-1:0] Q;
   input CLK;
   input CEN;
   input WEN;
   input [addr_width-1:0] A;
   input [BITS-1:0] D;
   input OEN;

   // SRAM 存储体。行为模型中用二维 reg 数组模拟真实 SRAM 阵列。
   reg [BITS-1:0]	   mem [word_depth-1:0];

   // specify 时序检查的 notifier 信号。
   // 当 setup/hold/period/width 违规时，仿真器会改变这些 notifier。
   // 下面的 process_violations 会根据 notifier 变化传播 X。
   reg			           NOT_CEN;
   reg			           NOT_WEN;

   reg			           NOT_A0;
   reg			           NOT_A1;
   reg			           NOT_A2;
   reg			           NOT_A3;
   reg			           NOT_A4;
   reg			           NOT_A5;
   reg			           NOT_A6;
   reg			           NOT_A7;
   reg			           NOT_A8;
   reg			           NOT_A9;
   reg			           NOT_A10;
   reg			           NOT_A11;
   reg			           NOT_A12;
   reg [addr_width-1:0]	   NOT_A;
   reg			           NOT_D0;
   reg			           NOT_D1;
   reg			           NOT_D2;
   reg			           NOT_D3;
   reg			           NOT_D4;
   reg			           NOT_D5;
   reg			           NOT_D6;
   reg			           NOT_D7;
   reg [BITS-1:0]	       NOT_D ;
   reg			           NOT_CLK_PER;
   reg			           NOT_CLK_MINH;
   reg			           NOT_CLK_MINL;

   reg			           LAST_NOT_CEN;
   reg			           LAST_NOT_WEN;
   reg [addr_width-1:0]    LAST_NOT_A;
   reg [BITS-1:0]	       LAST_NOT_D;
   reg			           LAST_NOT_CLK_PER;
   reg			           LAST_NOT_CLK_MINH;
   reg			           LAST_NOT_CLK_MINL;


   wire [BITS-1:0]         _Q;
   wire			           _OENi;
   wire [addr_width-1:0]   _A;
   wire			           _CLK;
   wire			           _CEN;
   wire			           _OEN;
   wire                    _WEN;

   wire [BITS-1:0]   _D;
   wire                    re_flag;
   wire                    re_data_flag;


   reg			           LATCHED_CEN;
   reg	                   LATCHED_WEN;
   reg [addr_width-1:0]	   LATCHED_A;
   reg [BITS-1:0]	       LATCHED_D;

   reg			           CENi;
   reg           	       WENi;
   reg [addr_width-1:0]	   Ai;
   reg [BITS-1:0]	       Di;
   reg [BITS-1:0]	       Qi;
   reg [BITS-1:0]	       LAST_Qi;

   reg			           LAST_CLK;

//-------------------------------------------------------------------------
// task: update_notifier_buses
//
// 将单 bit notifier 汇总成总线形式的 NOT_A 和 NOT_D，方便后续统一
// 判断地址/数据哪些位发生了时序违规。
//-------------------------------------------------------------------------
task update_notifier_buses;
begin
    NOT_A = {
             NOT_A12,
             NOT_A11,
             NOT_A10,
             NOT_A9,
             NOT_A8,
             NOT_A7,
             NOT_A6,
             NOT_A5,
             NOT_A4,
             NOT_A3,
             NOT_A2,
             NOT_A1,
             NOT_A0};
    NOT_D = {
             NOT_D7,
             NOT_D6,
             NOT_D5,
             NOT_D4,
             NOT_D3,
             NOT_D2,
             NOT_D1,
             NOT_D0};
end
endtask

//-------------------------------------------------------------------------
// task: mem_cycle
//
// 根据锁存后的 CENi/WENi 执行一次 SRAM 访问。
//   {WENi,CENi}=2'b10：读操作。
//   {WENi,CENi}=2'b00：写操作。
//   CENi=1           ：SRAM 未选中，不操作。
//   控制信号含 X     ：按未知状态处理，可能输出 X 或污染存储体。
//-------------------------------------------------------------------------
task mem_cycle;
begin
    casez({WENi,CENi}) // WENi 0:写、1:读；CENi 低有效片选。
        2'b10: begin // 读状态。
            read_mem(1,0); // 从 mem[Ai] 读出数据。
        end
        2'b00: begin // 写状态。
            write_mem(Ai,Di); // 写入 mem[Ai]。
            read_mem(0,0); // 写周期输出写入数据 Di。
        end
        2'b?1: ;
        2'b1x: begin
            read_mem(0,1); // 控制不确定，输出 X。
        end
        2'bx0: begin
            write_mem_x(Ai); // 写入 X。
            read_mem(0,1); // 输出 X。
        end
        2'b0x,
        2'bxx: begin
            write_mem_x(Ai); // 写入 X。
            read_mem(0,1); // 输出 X。
        end
    endcase
end
endtask
      

//-------------------------------------------------------------------------
// task: update_last_notifiers
//
// 保存当前 notifier 值，供下一次 notifier 变化检测使用。
//-------------------------------------------------------------------------
task update_last_notifiers;
begin
    LAST_NOT_A = NOT_A;
    LAST_NOT_D = NOT_D;
    LAST_NOT_WEN = NOT_WEN;
    LAST_NOT_CEN = NOT_CEN;
    LAST_NOT_CLK_PER = NOT_CLK_PER;
    LAST_NOT_CLK_MINH = NOT_CLK_MINH;
    LAST_NOT_CLK_MINL = NOT_CLK_MINL;
end
endtask

//-------------------------------------------------------------------------
// task: latch_inputs
//
// 在 CLK 上升沿锁存 SRAM 输入信号。真实 SRAM macro 通常也是在
// 时钟边沿采样地址、数据和控制信号。
//-------------------------------------------------------------------------
task latch_inputs;
begin
    LATCHED_A = _A ;
    LATCHED_D = _D ;
    LATCHED_WEN = _WEN ;
    LATCHED_CEN = _CEN ;
    LAST_Qi = Qi;
end
endtask


//-------------------------------------------------------------------------
// task: update_logic
//
// 将锁存后的输入转移到内部工作信号 CENi/WENi/Ai/Di。
//-------------------------------------------------------------------------
task update_logic;
begin
    CENi = LATCHED_CEN;
    WENi = LATCHED_WEN;
    Ai = LATCHED_A;
    Di = LATCHED_D;
end
endtask



//-------------------------------------------------------------------------
// task: x_inputs
//
// 当 notifier 变化表示某些输入发生 setup/hold 违规时，把对应锁存
// 输入打成 X。后续 mem_cycle 会把 X 按 SRAM 读写行为传播。
//-------------------------------------------------------------------------
task x_inputs;
    integer n;
begin
    for (n=0; n<addr_width; n=n+1)begin
        LATCHED_A[n] = (NOT_A[n]!==LAST_NOT_A[n]) ? 1'bx : LATCHED_A[n] ;
    end
    for (n=0; n<BITS; n=n+1)begin
        LATCHED_D[n] = (NOT_D[n]!==LAST_NOT_D[n]) ? 1'bx : LATCHED_D[n] ;
    end
    LATCHED_WEN = (NOT_WEN!==LAST_NOT_WEN) ? 1'bx : LATCHED_WEN ;
    LATCHED_CEN = (NOT_CEN!==LAST_NOT_CEN) ? 1'bx : LATCHED_CEN ;
end
endtask

//-------------------------------------------------------------------------
// task: read_mem
//
// r_wb=1：真正从 mem[Ai] 读出数据。
// r_wb=0：用于写周期后的输出行为；xflag=0 时输出 Di，xflag=1 时输出 X。
//-------------------------------------------------------------------------
task read_mem;
    input r_wb;
    input xflag;
begin
    if (r_wb)begin
        if (valid_address(Ai))begin
            Qi=mem[Ai];
        end
        else begin
            Qi=wordx;
        end
    end
    else begin
        if (xflag)begin
            Qi=wordx;
        end
        else begin
            Qi=Di;
        end
    end
end
endtask

//-------------------------------------------------------------------------
// task: write_mem
//
// 向指定地址写入数据。如果地址包含 X，则整个存储体污染为 X。
//-------------------------------------------------------------------------
task write_mem;
    input [addr_width-1:0] a;
    input [BITS-1:0] d;
begin
    casez({valid_address(a)})
        1'b0:x_mem;
        1'b1: mem[a]=d;
    endcase
end
endtask

//-------------------------------------------------------------------------
// task: write_mem_x
//
// 向指定地址写入 X。如果地址本身未知，则整个存储体污染为 X。
//-------------------------------------------------------------------------
task write_mem_x;
    input [addr_width-1:0] a;
begin
    casez({valid_address(a)}) // 检查地址是否有效。
        1'b0:x_mem;        
        1'b1: mem[a]=wordx;
    endcase
end
endtask

//-------------------------------------------------------------------------
// task: x_mem
//
// 将整个 SRAM 存储体写成 X，用于模拟严重时序违规或未知地址写入。
//-------------------------------------------------------------------------
task x_mem;
    integer n;
begin
    for (n=0; n<word_depth; n=n+1)
        mem[n]=wordx;
end
endtask

//-------------------------------------------------------------------------
// task: process_violations
//
// specify notifier 变化后的主处理流程。
// 如果是时钟周期/脉宽违规，并且 SRAM 当前被选中，则整个存储体污染为 X。
// 否则，将发生 setup/hold 违规的输入位打成 X，再执行一次 mem_cycle。
//-------------------------------------------------------------------------
task process_violations;
begin
    if ((NOT_CLK_PER!==LAST_NOT_CLK_PER) ||
    (NOT_CLK_MINH!==LAST_NOT_CLK_MINH) ||
    (NOT_CLK_MINL!==LAST_NOT_CLK_MINL))begin
        if (CENi !== 1'b1)begin
            x_mem;
            read_mem(0,1);
        end
    end
    else begin
        update_notifier_buses;
        x_inputs;
        update_logic;
        mem_cycle;
    end
    update_last_notifiers;
end
endtask

//-------------------------------------------------------------------------
// function: valid_address
//
// 判断地址是否完全确定。归约异或结果为 X 时，说明地址中存在 X/Z。
//-------------------------------------------------------------------------
function valid_address;
  input [addr_width-1:0] a;
begin
  valid_address = (^(a) !== 1'bx);
end
endfunction


//-------------------------------------------------------------------------
// 输出三态门和输入 buffer
//
// bufif0：控制端为 0 时导通。这里表示 OEN 低有效时，内部 Qi 通过 _Q
// 驱动到输出 Q；OEN 为高时 Q 进入高阻态。
//
// 后面的 buf 用于把端口输入接到内部 _A/_D/_CLK/_CEN/_WEN/_OEN 信号。
//-------------------------------------------------------------------------
bufif0 (Q[0], _Q[0], _OENi);// 三态门，_OENi=0 时输出有效。
bufif0 (Q[1], _Q[1], _OENi);
bufif0 (Q[2], _Q[2], _OENi);
bufif0 (Q[3], _Q[3], _OENi);
bufif0 (Q[4], _Q[4], _OENi);
bufif0 (Q[5], _Q[5], _OENi);
bufif0 (Q[6], _Q[6], _OENi);
bufif0 (Q[7], _Q[7], _OENi);
buf (_D[0], D[0]);// 输入 buffer。
buf (_D[1], D[1]);
buf (_D[2], D[2]);
buf (_D[3], D[3]);
buf (_D[4], D[4]);
buf (_D[5], D[5]);
buf (_D[6], D[6]);
buf (_D[7], D[7]);
buf (_A[0], A[0]);
buf (_A[1], A[1]);
buf (_A[2], A[2]);
buf (_A[3], A[3]);
buf (_A[4], A[4]);
buf (_A[5], A[5]);
buf (_A[6], A[6]);
buf (_A[7], A[7]);
buf (_A[8], A[8]);
buf (_A[9], A[9]);
buf (_A[10], A[10]);
buf (_A[11], A[11]);
buf (_A[12], A[12]);
buf (_CLK, CLK);
buf (_WEN, WEN);
buf (_OEN, OEN);
buf (_CEN, CEN);


assign _OENi = _OEN;
assign _Q = Qi;
assign re_flag = !(_CEN);
assign re_data_flag = !(_CEN || _WEN);


//-------------------------------------------------------------------------
// always 块 1：notifier 变化处理
//
// 这个 always 监听 specify 块产生的 notifier。
// 当 setup/hold/period/width 检查发生违规时，对应 notifier 会变化，
// 从而触发 process_violations，把违规影响传播为 X。
//-------------------------------------------------------------------------
always @( // Verilog-95 风格敏感列表。
	    NOT_A0 or // 地址、数据 notifier 按 bit 展开，便于独立传播 X。
	    NOT_A1 or
	    NOT_A2 or
	    NOT_A3 or
	    NOT_A4 or
	    NOT_A5 or
	    NOT_A6 or
	    NOT_A7 or
	    NOT_A8 or
	    NOT_A9 or
	    NOT_A10 or
	    NOT_A11 or
	    NOT_A12 or
	    NOT_D0 or
	    NOT_D1 or
	    NOT_D2 or
	    NOT_D3 or
	    NOT_D4 or
	    NOT_D5 or
	    NOT_D6 or
	    NOT_D7 or
	    NOT_WEN or
	    NOT_CEN or
	    NOT_CLK_PER or
	    NOT_CLK_MINH or
	    NOT_CLK_MINL
	    )begin
         process_violations; // 时序违规处理。
end

//-------------------------------------------------------------------------
// always 块 2：SRAM 主功能时钟检测
//
// 在 _CLK 发生 0->1 上升沿时：
//   1. latch_inputs：锁存地址、数据、控制信号。
//   2. update_logic：更新内部工作信号。
//   3. mem_cycle   ：执行读或写。
//
// 如果时钟变成 X，则认为 SRAM 行为不确定，污染存储体并输出 X。
//-------------------------------------------------------------------------
always@( _CLK )begin // 时钟边沿检测。
    casez({LAST_CLK,_CLK})
	   2'b01: begin
	      latch_inputs;
	      update_logic;
	      mem_cycle;
	   end
	   2'b10,
	   2'bx?,
	   2'b00,
	   2'b11: ;
	   2'b?x: begin
	      x_mem;
          read_mem(0,1);
	   end
	 endcase
	 LAST_CLK = _CLK;
end

//-------------------------------------------------------------------------
// specify 块：SRAM macro 时序检查和路径延迟
//
// $setuphold：检查输入信号相对 CLK 上升沿的建立/保持时间。
// $period   ：检查 CLK 周期。
// $width    ：检查 CLK 高/低电平宽度。
//
// 最后两组路径延迟描述 CLK->Q 和 OEN->Q 的时序路径。
// 这些内容主要服务于门级/时序仿真；纯功能仿真通常不重点关注。
//-------------------------------------------------------------------------
specify // 路径延迟和时序检查块。
      $setuphold(posedge CLK, CEN, 1.000, 0.500, NOT_CEN); // setup/hold 检查。
      $setuphold(posedge CLK &&& re_flag, WEN, 1.000, 0.500, NOT_WEN);
      $setuphold(posedge CLK &&& re_flag, A[0], 1.000, 0.500, NOT_A0);
      $setuphold(posedge CLK &&& re_flag, A[1], 1.000, 0.500, NOT_A1);
      $setuphold(posedge CLK &&& re_flag, A[2], 1.000, 0.500, NOT_A2);
      $setuphold(posedge CLK &&& re_flag, A[3], 1.000, 0.500, NOT_A3);
      $setuphold(posedge CLK &&& re_flag, A[4], 1.000, 0.500, NOT_A4);
      $setuphold(posedge CLK &&& re_flag, A[5], 1.000, 0.500, NOT_A5);
      $setuphold(posedge CLK &&& re_flag, A[6], 1.000, 0.500, NOT_A6);
      $setuphold(posedge CLK &&& re_flag, A[7], 1.000, 0.500, NOT_A7);
      $setuphold(posedge CLK &&& re_flag, A[8], 1.000, 0.500, NOT_A8);
      $setuphold(posedge CLK &&& re_flag, A[9], 1.000, 0.500, NOT_A9);
      $setuphold(posedge CLK &&& re_flag, A[10], 1.000, 0.500, NOT_A10);
      $setuphold(posedge CLK &&& re_flag, A[11], 1.000, 0.500, NOT_A11);
      $setuphold(posedge CLK &&& re_data_flag, D[0], 1.000, 0.500, NOT_D0);
      $setuphold(posedge CLK &&& re_data_flag, D[1], 1.000, 0.500, NOT_D1);
      $setuphold(posedge CLK &&& re_data_flag, D[2], 1.000, 0.500, NOT_D2);
      $setuphold(posedge CLK &&& re_data_flag, D[3], 1.000, 0.500, NOT_D3);
      $setuphold(posedge CLK &&& re_data_flag, D[4], 1.000, 0.500, NOT_D4);
      $setuphold(posedge CLK &&& re_data_flag, D[5], 1.000, 0.500, NOT_D5);
      $setuphold(posedge CLK &&& re_data_flag, D[6], 1.000, 0.500, NOT_D6);
      $setuphold(posedge CLK &&& re_data_flag, D[7], 1.000, 0.500, NOT_D7);
    
      $period(posedge CLK, 3.000, NOT_CLK_PER);
      $width(posedge CLK, 1.000, 0, NOT_CLK_MINH);
      $width(negedge CLK, 1.000, 0, NOT_CLK_MINL);
    
      (CLK => Q[0])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[1])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[2])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[3])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[4])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[5])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[6])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (CLK => Q[7])=(1.000, 1.000, 0.500, 1.000, 0.500, 1.000);
      (OEN => Q[0])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[1])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[2])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[3])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[4])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[5])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[6])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
      (OEN => Q[7])=(1.000, 1.000, 1.000, 1.000, 1.000, 1.000);
endspecify 

endmodule
`endcelldefine
