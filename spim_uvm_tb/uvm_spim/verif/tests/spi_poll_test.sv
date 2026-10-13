//------------------------------------------------------------
//
// Class Description: 传输结束后轮询 GO/BSY 的流程
//
//
class spi_poll_test extends spi_test_base;

// UVM Factory Registration Macro
//
`uvm_component_utils(spi_poll_test)

//------------------------------------------
// Methods
//------------------------------------------

// Standard UVM Methods:
extern function new(string name = "spi_poll_test", uvm_component parent = null);
extern function void build_phase(uvm_phase phase);
extern task run_phase(uvm_phase phase);

endclass: spi_poll_test

function spi_poll_test::new(string name = "spi_poll_test", uvm_component parent = null);
  super.new(name, parent);
endfunction

// Build the env, create the env configuration
// including any sub configurations and assigning virtural interfaces
function void spi_poll_test::build_phase(uvm_phase phase);
  super.build_phase(phase);
endfunction: build_phase

task spi_poll_test::run_phase(uvm_phase phase);

  config_polling_test t_seq = config_polling_test::type_id::create("t_seq");

  phase.raise_objection(this, "Test Started");
  t_seq.start(null);
  #100ns;
  phase.drop_objection(this, "Test Finished");

endtask: run_phase

