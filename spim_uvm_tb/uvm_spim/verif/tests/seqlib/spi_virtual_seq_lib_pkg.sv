
package spi_virtual_seq_lib_pkg;

import uvm_pkg::*;
`include "uvm_macros.svh"

import apb_agent_pkg::*;
import spi_agent_pkg::*;
import spi_env_pkg::*;
import apb_seq_lib_pkg::*;
import spi_seq_lib_pkg::*;

// Base class to get sub-sequencer handles
//
// Note that this virtual sequence uses resources to get
// the handles to the target sequencers
//
// This means that we do not need a virtual sequencer
//
class spi_vseq_base extends uvm_sequence #(uvm_sequence_item);

`uvm_object_utils(spi_vseq_base)

function new(string name = "spi_vseq_base");
  super.new(name);
endfunction

// Virtual sequencer handles
apb_sequencer apb;
spi_sequencer spi;

// Handle for env config to get to interrupt line
spi_env_config m_cfg;

// This set up is required for child sequences to run
task body;
  if(!uvm_config_db #(apb_sequencer)::get(null, {"uvm_test_top.",get_full_name()}, "apb_sequencer", apb)) begin
    `uvm_error("CONFIG_DB_ERROR", "apb sequencer not found")
  end
  if(!uvm_config_db #(spi_sequencer)::get(null, {"uvm_test_top.",get_full_name()}, "spi_sequencer", spi)) begin
    `uvm_error("CONFIG_DB_ERROR", "spi sequencer not found")
  end
  $display("Virtual sequence get_full_name = %s", get_full_name());
  if(!uvm_config_db #(spi_env_config)::get(null, {"uvm_test_top.", get_full_name()}, "spi_env_config", m_cfg)) begin
    `uvm_error("body", "Cannot find spi_env_config")
  end
endtask: body

endclass: spi_vseq_base

//
// This virtual sequence does SPI transfers with randomized config
// and tests the interrupt handling
//
class config_interrupt_test extends spi_vseq_base;

`uvm_object_utils(config_interrupt_test)

logic[31:0] control;

function new(string name = "config_interrupt_test");
  super.new(name);
endfunction

task body;
  // Sequences to be used
  ctrl_go_seq go = ctrl_go_seq::type_id::create("go");
  SPI_config_rand_order_seq spi_config = SPI_config_rand_order_seq::type_id::create("spi_config");
  tfer_over_by_poll_seq wait_unload = tfer_over_by_poll_seq::type_id::create("wait_unload");
  spi_tfer_seq spi_transfer = spi_tfer_seq::type_id::create("spi_transfer");

  super.body;

  control = 0;

  repeat(10) begin
    spi_config.interrupt_enable = 1;
    spi_config.start(apb);
    control = spi_config.data;
    spi_transfer.BITS = control[6:0];
    spi_transfer.rx_edge = control[9];
    fork
      begin
        // Arm the slave responder before GO can launch the first SCLK edge.
        #1ns;
        go.start(apb);
        m_cfg.wait_for_interrupt;
        wait_unload.start(apb);
        if(!m_cfg.is_interrupt_cleared()) begin
          `uvm_error("INT_ERROR", "Interrupt not cleared by register read/write");
        end
      end
      begin
        spi_transfer.start(spi);
      end
    join
  end
endtask

endclass: config_interrupt_test

//
// This virtual sequence does SPI transfers with randomized config
// and polls the go_bsy bit in the control register to determine
// when the transfer has completed
//
class config_polling_test extends spi_vseq_base;

`uvm_object_utils(config_polling_test)

logic[31:0] control;

function new(string name = "config_polling_test");
  super.new(name);
endfunction

task body;
  // Sequences to be used
  ctrl_go_seq go = ctrl_go_seq::type_id::create("go");
  SPI_config_rand_order_seq spi_config = SPI_config_rand_order_seq::type_id::create("spi_config");
  tfer_over_by_poll_seq wait_unload = tfer_over_by_poll_seq::type_id::create("wait_unload");
  spi_tfer_seq spi_transfer = spi_tfer_seq::type_id::create("spi_transfer");

  super.body;

  control = 0;

  repeat(1) begin
    spi_config.interrupt_enable = 1;
    spi_config.start(apb);
    control = spi_config.data;
    spi_transfer.BITS = control[6:0];
    spi_transfer.rx_edge = control[9];
    fork
      begin
        // Arm the slave responder before GO can launch the first SCLK edge.
        #1ns;
        go.start(apb);
        wait_unload.start(apb);
      end
      begin
        spi_transfer.start(spi);
      end
    join
  end
endtask

endclass: config_polling_test

//
// Register test:
//
// Checks the reset values
// Does a randomized read/write bit test using the front door
// Repeats the read/write bit test using the back door (not necessary, but as an illustration)
//
class register_test_vseq extends spi_vseq_base;

`uvm_object_utils(register_test_vseq)

function new(string name = "register_test_vseq");
  super.new(name);
endfunction

task body;
  check_regs_seq reg_seq = check_regs_seq::type_id::create("reg_seq");

  super.body;
  reg_seq.start(apb);
endtask: body


endclass: register_test_vseq

endpackage:spi_virtual_seq_lib_pkg
