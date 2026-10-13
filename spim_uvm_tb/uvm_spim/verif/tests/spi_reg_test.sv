//------------------------------------------------------------
// Main register test: reset, frontdoor/backdoor, and generic RAL access.
//------------------------------------------------------------
class spi_reg_test extends spi_test_base;

  `uvm_component_utils(spi_reg_test)

  extern function new(string name = "spi_reg_test", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

endclass: spi_reg_test

function spi_reg_test::new(string name = "spi_reg_test", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void spi_reg_test::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction: build_phase

task spi_reg_test::run_phase(uvm_phase phase);
  uvm_reg_hw_reset_seq reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
  register_test_vseq reg_test_seq = register_test_vseq::type_id::create("reg_test_seq");
  uvm_reg_access_seq access_seq = uvm_reg_access_seq::type_id::create("access_seq");

  reset_seq.model = spi_rm;
  access_seq.model = spi_rm;

  // GO/TIP and busy-write protection make these registers stateful.  The
  // dedicated frontdoor/backdoor sequence checks them with GO held low.
  uvm_resource_db#(bit)::set({"REG::", spi_rm.ctrl.get_full_name()},
                              "NO_REG_TESTS", 1, this);
  uvm_resource_db#(bit)::set({"REG::", spi_rm.divider.get_full_name()},
                              "NO_REG_TESTS", 1, this);
  // These addresses write TX data but read the corresponding RX shift data;
  // generic RAL access sequences incorrectly assume a read returns the value
  // most recently written. End-to-end SPI tests check TX/RX through scoreboard.
  uvm_resource_db#(bit)::set({"REG::", spi_rm.rxtx0.get_full_name()},
                              "NO_REG_TESTS", 1, this);
  uvm_resource_db#(bit)::set({"REG::", spi_rm.rxtx1.get_full_name()},
                              "NO_REG_TESTS", 1, this);
  uvm_resource_db#(bit)::set({"REG::", spi_rm.rxtx2.get_full_name()},
                              "NO_REG_TESTS", 1, this);
  uvm_resource_db#(bit)::set({"REG::", spi_rm.rxtx3.get_full_name()},
                              "NO_REG_TESTS", 1, this);
  // SS is checked by the project sequence's frontdoor/backdoor readback and
  // busy-write test; keep it out of the generic sequence's backdoor restore.
  uvm_resource_db#(bit)::set({"REG::", spi_rm.ss.get_full_name()},
                              "NO_REG_TESTS", 1, this);

  phase.raise_objection(this, "Run consolidated register checks");
  reset_seq.start(null);
  reg_test_seq.start(null);
  access_seq.start(null);
  #100ns;
  phase.drop_objection(this, "Consolidated register checks complete");
endtask: run_phase
