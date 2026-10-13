//------------------------------------------------------------
//
// Class Description: 传输完成后 IRQ 是否置位、APB 访问后是否清除
//
//
class spi_interrupt_test extends spi_test_base;

// UVM Factory Registration Macro
//
`uvm_component_utils(spi_interrupt_test)

//------------------------------------------
// Methods
//------------------------------------------

// Standard UVM Methods:
extern function new(string name = "spi_interrupt_test", uvm_component parent = null);
extern function void build_phase(uvm_phase phase);
extern task run_phase(uvm_phase phase);

endclass: spi_interrupt_test

function spi_interrupt_test::new(string name = "spi_interrupt_test", uvm_component parent = null);
  super.new(name, parent);
endfunction

// Build the env, create the env configuration
// including any sub configurations and assigning virtural interfaces
function void spi_interrupt_test::build_phase(uvm_phase phase);
  uvm_reg::include_coverage("*", UVM_CVR_ADDR_MAP, this);
  super.build_phase(phase);
endfunction: build_phase

task spi_interrupt_test::run_phase(uvm_phase phase);

  config_interrupt_test t_seq = config_interrupt_test::type_id::create("t_seq");

  phase.raise_objection(this, "Test Started");
  t_seq.start(null);
  #100ns;
  phase.drop_objection(this, "Test Finished");

endtask: run_phase
