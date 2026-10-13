`include "apb_macro.svh"
interface apb_if(input PCLK,
                 input PRESETn);

  logic[`APB_ADDR_WIDTH-1:0] PADDR;
  logic[`APB_DATA_WIDTH-1:0] PRDATA;
  logic[`APB_DATA_WIDTH-1:0] PWDATA;
  logic[15:0] PSEL; // Only connect the ones that are needed
  logic PENABLE;
  logic PWRITE;
  logic PREADY;

  property psel_valid;
    @(posedge PCLK)
    !$isunknown(PSEL);
  endproperty: psel_valid

  property pready_check;
    @(posedge PCLK) disable iff(PRESETn==0)
    PREADY |-> (PENABLE==1) && (PSEL==1);
  endproperty: pready_check
  
  CHK_PREADY: assert property(pready_check);

  CHK_PSEL: assert property(psel_valid);

  COVER_PSEL: cover property(psel_valid);

endinterface: apb_if
