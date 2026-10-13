//////////////////////////////////////////////////////////////////////
////                                                              ////
////  spi_top.v                                                   ////
////                                                              ////
////  APB wrapper for the OpenCores SPI clock generator and       ////
////  serial shift engine.                                        ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "spi_defines.v"
`include "timescale.v"

module spi_top
(
  // APB interface
  PCLK, PRESETN, PADDR, PWDATA, PRDATA, PSEL,
  PWRITE, PENABLE, PREADY, PSLVERR,
  // Interrupt
  IRQ,
  // SPI pins
  ss_pad_o, sclk_pad_o, mosi_pad_o, miso_pad_i
);

  parameter Tp = 1;

  // ------------------------------------------------------------------
  // APB and SPI ports
  // ------------------------------------------------------------------
  input                            PCLK;
  input                            PRESETN;
  input [4:0]                      PADDR;
  input [31:0]                     PWDATA;
  output [31:0]                    PRDATA;
  input                            PWRITE;
  input                            PSEL;
  input                            PENABLE;
  output                           PREADY;
  output                           PSLVERR;
  output                           IRQ;

  output [`SPI_SS_NB-1:0]          ss_pad_o;
  output                           sclk_pad_o;
  output                           mosi_pad_o;
  input                            miso_pad_i;

  reg [31:0]                       PRDATA;
  reg                              PREADY;
  reg                              IRQ;

  // ------------------------------------------------------------------
  // Software-visible configuration and APB read-data mux
  // ------------------------------------------------------------------
  reg [`SPI_DIVIDER_LEN-1:0]       divider;
  reg [`SPI_CTRL_BIT_NB-1:0]       ctrl;
  reg [`SPI_SS_NB-1:0]             ss;
  reg [31:0]                       wb_dat;

  // ------------------------------------------------------------------
  // Decoded APB accesses
  // ------------------------------------------------------------------
  wire                             spi_divider_sel;
  wire                             spi_ctrl_sel;
  wire [3:0]                       spi_tx_sel;
  wire                             spi_ss_sel;

  // ------------------------------------------------------------------
  // SPI control and datapath connections
  // ------------------------------------------------------------------
  wire [`SPI_MAX_CHAR-1:0]         rx;
  wire                             rx_negedge;
  wire                             tx_negedge;
  wire [`SPI_CHAR_LEN_BITS-1:0]    char_len;
  wire                             go;
  wire                             lsb;
  wire                             ie;
  wire                             ass;
  wire                             tip;
  wire                             pos_edge;
  wire                             neg_edge;
  wire                             last_bit;

  // ==================================================================
  // APB address decoding
  // ==================================================================
  assign spi_divider_sel = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_DEVIDE);
  assign spi_ctrl_sel    = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_CTRL);
  assign spi_tx_sel[0]   = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_TX_0);
  assign spi_tx_sel[1]   = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_TX_1);
  assign spi_tx_sel[2]   = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_TX_2);
  assign spi_tx_sel[3]   = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_TX_3);
  assign spi_ss_sel      = PSEL & PENABLE & (PADDR[`SPI_OFS_BITS] == `SPI_SS);

  // ==================================================================
  // APB read path
  // TX and RX share addresses: writes load spi_shift data, while reads
  // return its received-data view through rx.
  // ==================================================================
  always @(PADDR or rx or ctrl or divider or ss)
  begin
    case (PADDR[`SPI_OFS_BITS])
`ifdef SPI_MAX_CHAR_128
      `SPI_RX_0:   wb_dat = rx[31:0];
      `SPI_RX_1:   wb_dat = rx[63:32];
      `SPI_RX_2:   wb_dat = rx[95:64];
      `SPI_RX_3:   wb_dat = {{128-`SPI_MAX_CHAR{1'b0}}, rx[`SPI_MAX_CHAR-1:96]};
`else
`ifdef SPI_MAX_CHAR_64
      `SPI_RX_0:   wb_dat = rx[31:0];
      `SPI_RX_1:   wb_dat = {{64-`SPI_MAX_CHAR{1'b0}}, rx[`SPI_MAX_CHAR-1:32]};
      `SPI_RX_2:   wb_dat = 32'b0;
      `SPI_RX_3:   wb_dat = 32'b0;
`else
      `SPI_RX_0:   wb_dat = {{32-`SPI_MAX_CHAR{1'b0}}, rx[`SPI_MAX_CHAR-1:0]};
      `SPI_RX_1:   wb_dat = 32'b0;
      `SPI_RX_2:   wb_dat = 32'b0;
      `SPI_RX_3:   wb_dat = 32'b0;
`endif
`endif
      `SPI_CTRL:   wb_dat = {{32-`SPI_CTRL_BIT_NB{1'b0}},
                              ass, ie, lsb, tx_negedge, rx_negedge,
                              go, 1'b0, char_len};
      `SPI_DEVIDE: wb_dat = {{32-`SPI_DIVIDER_LEN{1'b0}}, divider};
      `SPI_SS:     wb_dat = {{32-`SPI_SS_NB{1'b0}}, ss};
      default:      wb_dat = 32'bx;
    endcase
  end

  always @(posedge PCLK or negedge PRESETN)
  begin
    if (!PRESETN)
      PRDATA <= #Tp 32'b0;
    else
      PRDATA <= #Tp wb_dat;
  end

  // APB response timing is retained from the original implementation.
  always @(posedge PCLK or negedge PRESETN)
  begin
    if (!PRESETN)
      PREADY <= #Tp 1'b0;
    else
      PREADY <= #Tp PSEL & PENABLE & ~PREADY;
  end

  assign PSLVERR = 1'b0;

  // ==================================================================
  // APB-programmable configuration registers
  // Writes are blocked while tip is high to protect an active transfer.
  // ==================================================================
  always @(posedge PCLK or negedge PRESETN)
  begin
    if (!PRESETN)
      divider <= #Tp {`SPI_DIVIDER_LEN{1'b1}};
    else if (spi_divider_sel && PWRITE && !tip)
      begin
`ifdef SPI_DIVIDER_LEN_8
        divider <= #Tp PWDATA[`SPI_DIVIDER_LEN-1:0];
`endif
`ifdef SPI_DIVIDER_LEN_16
        divider[`SPI_DIVIDER_LEN-1:0] <= #Tp PWDATA[`SPI_DIVIDER_LEN-1:0];
`endif
`ifdef SPI_DIVIDER_LEN_24
        divider[`SPI_DIVIDER_LEN-1:0] <= #Tp PWDATA[`SPI_DIVIDER_LEN-1:0];
`endif
`ifdef SPI_DIVIDER_LEN_32
        divider[`SPI_DIVIDER_LEN-1:0] <= #Tp PWDATA[`SPI_DIVIDER_LEN-1:0];
`endif
      end
  end

  always @(posedge PCLK or negedge PRESETN)
  begin
    if (!PRESETN)
      begin
        // Keep the original field assignments: CTRL bit 7 remains reserved.
        ctrl[`SPI_CTRL_RX_NEGEDGE] = 1'b0;
        ctrl[`SPI_CTRL_TX_NEGEDGE] = 1'b0;
        ctrl[`SPI_CTRL_GO]         = 1'b0;
        ctrl[`SPI_CTRL_CHAR_LEN]   = {`SPI_CHAR_LEN_BITS{1'b0}};
        ctrl[`SPI_CTRL_LSB]        = 1'b0;
        ctrl[`SPI_CTRL_IE]         = 1'b0;
        ctrl[`SPI_CTRL_ASS]        = 1'b0;
      end
    else if (spi_ctrl_sel && PWRITE && !tip)
      begin
        ctrl[`SPI_CTRL_RX_NEGEDGE] = PWDATA[`SPI_CTRL_RX_NEGEDGE];
        ctrl[`SPI_CTRL_TX_NEGEDGE] = PWDATA[`SPI_CTRL_TX_NEGEDGE];
        ctrl[`SPI_CTRL_GO]         = PWDATA[`SPI_CTRL_GO];
        ctrl[`SPI_CTRL_CHAR_LEN]   = PWDATA[`SPI_CTRL_CHAR_LEN];
        ctrl[`SPI_CTRL_LSB]        = PWDATA[`SPI_CTRL_LSB];
        ctrl[`SPI_CTRL_IE]         = PWDATA[`SPI_CTRL_IE];
        ctrl[`SPI_CTRL_ASS]        = PWDATA[`SPI_CTRL_ASS];
      end
    else if (tip && last_bit && pos_edge)
      ctrl[`SPI_CTRL_GO] <= #Tp 1'b0;
  end

  always @(posedge PCLK or negedge PRESETN)
  begin
    if (!PRESETN)
      ss <= #Tp {`SPI_SS_NB{1'b0}};
    else if (spi_ss_sel && PWRITE && !tip)
      begin
`ifdef SPI_SS_NB_8
        ss <= #Tp PWDATA[`SPI_SS_NB-1:0];
`endif
`ifdef SPI_SS_NB_16
        ss[`SPI_SS_NB-1:0] <= #Tp PWDATA[`SPI_SS_NB-1:0];
`endif
`ifdef SPI_SS_NB_24
        ss[`SPI_SS_NB-1:0] <= #Tp PWDATA[`SPI_SS_NB-1:0];
`endif
`ifdef SPI_SS_NB_32
        ss[`SPI_SS_NB-1:0] <= #Tp PWDATA[`SPI_SS_NB-1:0];
`endif
      end
  end

  // CTRL field breakout for the SPI engine and output-control logic.
  assign rx_negedge = ctrl[`SPI_CTRL_RX_NEGEDGE];
  assign tx_negedge = ctrl[`SPI_CTRL_TX_NEGEDGE];
  assign go         = ctrl[`SPI_CTRL_GO];
  assign char_len   = ctrl[`SPI_CTRL_CHAR_LEN];
  assign lsb        = ctrl[`SPI_CTRL_LSB];
  assign ie         = ctrl[`SPI_CTRL_IE];
  assign ass        = ctrl[`SPI_CTRL_ASS];

  // ==================================================================
  // Completion interrupt and active-low slave-select outputs
  // ==================================================================
  always @(posedge PCLK or negedge PRESETN)
  begin
    if (!PRESETN)
      IRQ <= #Tp 1'b0;
    else if (ie && tip && last_bit && pos_edge)
      IRQ <= #Tp 1'b1;
    else if (PREADY)
      IRQ <= #Tp 1'b0;
  end

  // ASS gates CS with TIP. Manual SS leaves the selected CS asserted.
  assign ss_pad_o = ~((ss & {`SPI_SS_NB{tip & ass}}) |
                      (ss & {`SPI_SS_NB{!ass}}));

  // ==================================================================
  // SPI engine: clock generation and parallel/serial data shifting
  // ==================================================================
  spi_clgen clgen (
    .clk_in   (PCLK),
    .rst      (!PRESETN),
    .go       (go),
    .enable   (tip),
    .last_clk (last_bit),
    .divider  (divider),
    .clk_out  (sclk_pad_o),
    .pos_edge (pos_edge),
    .neg_edge (neg_edge)
  );

  spi_shift shift (
    .clk        (PCLK),
    .rst        (!PRESETN),
    .latch      (spi_tx_sel & {4{PWRITE}}),
    .byte_sel   (4'hF),
    .len        (char_len),
    .lsb        (lsb),
    .go         (go),
    .pos_edge   (pos_edge),
    .neg_edge   (neg_edge),
    .rx_negedge (rx_negedge),
    .tx_negedge (tx_negedge),
    .tip        (tip),
    .last       (last_bit),
    .p_in       (PWDATA),
    .p_out      (rx),
    .s_clk      (sclk_pad_o),
    .s_in       (miso_pad_i),
    .s_out      (mosi_pad_o)
  );

endmodule
