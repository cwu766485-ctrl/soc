// Consolidated directed coverage test for SPI clock generation and transfer
// functional crosses.  spi_shift_mode_test remains focused serial debug.
class spi_transfer_cov_test extends spi_cov_test_base;

  `uvm_component_utils(spi_transfer_cov_test)

  function new(string name = "spi_transfer_cov_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    logic [15:0] dividers [0:8];
    logic [6:0] lengths [0:12];
    logic [127:0] patterns [0:3];
    int item;

    dividers = '{16'h0, 16'h1, 16'h2, 16'h4, 16'h8,
                 16'h10, 16'h20, 16'h40, 16'h80};
    lengths = '{7'd0, 7'd1, 7'd31, 7'd32, 7'd33, 7'd63, 7'd64,
                7'd65, 7'd95, 7'd96, 7'd97, 7'd126, 7'd127};
    patterns = '{128'h0, {16{8'hff}}, {16{8'ha5}}, {16{8'h3c}}};
    item = 0;

    phase.raise_objection(this,
      "Exercise divider boundaries and length/divider functional crosses");

    foreach (dividers[i]) begin
      run_directed_transfer(dividers[i], 7'd31, i[0], i[1], i[2],
                            i[0], i[1], patterns[i % 4]);
    end

    foreach (lengths[i]) begin
      foreach (dividers[j]) begin
        run_directed_transfer(dividers[j], lengths[i], item[0], item[1],
                              item[2], item[3], item[4], patterns[item % 4]);
        item++;
      end
    end
    access_every_register();
    repeat (2) @(posedge m_apb_cfg.APB.PCLK);

    phase.drop_objection(this, "Transfer coverage complete");
  endtask

endclass
