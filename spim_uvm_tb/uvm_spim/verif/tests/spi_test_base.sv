//------------------------------------------------------------
//
// Class Description:
//
//
class spi_test_base extends uvm_test;

// UVM Factory Registration Macro
//
`uvm_component_utils(spi_test_base)

//------------------------------------------
// Data Members
//------------------------------------------

//------------------------------------------
// Component Members
//------------------------------------------
// The environment class
spi_env m_env;
// Configuration objects
spi_env_config m_env_cfg;
apb_agent_config m_apb_cfg;
spi_agent_config m_spi_cfg;
// Register map
reg_block spi_rm;

//------------------------------------------
// Methods
//------------------------------------------
extern function void configure_apb_agent(apb_agent_config cfg);
extern virtual function void configure_env(spi_env_config cfg);
// Standard UVM Methods:
extern function new(string name = "spi_test_base", uvm_component parent = null);
extern function void build_phase(uvm_phase phase);
extern function void connect_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);
endclass: spi_test_base

function spi_test_base::new(string name = "spi_test_base", uvm_component parent = null);
  super.new(name, parent);
endfunction

// Build the env, create the env configuration
// including any sub configurations and assigning virtural interfaces
function void spi_test_base::build_phase(uvm_phase phase);
  // env configuration
  m_env_cfg = spi_env_config::type_id::create("m_env_cfg");
  configure_env(m_env_cfg);
  // Register model
  // Enable all types of coverage available in the register model
  uvm_reg::include_coverage("*", UVM_CVR_ALL);
  // Create the register model:
  spi_rm = reg_block::type_id::create("spi_rm");
  // Build and configure the register model
  spi_rm.build();
  spi_rm.set_hdl_path_root("top_tb.DUT");
  spi_rm.lock_model();
  spi_rm.reset();
  // Assign a handle to the register model in the env config
  m_env_cfg.spi_rm = spi_rm;
  // APB configuration
  m_apb_cfg = apb_agent_config::type_id::create("m_apb_cfg");
  configure_apb_agent(m_apb_cfg);
  if(!uvm_config_db #(virtual apb_if)::get(this, "", "APB_vif", m_apb_cfg.APB)) begin
    `uvm_error("RESOURCE_ERROR", "APB virtual interface not found")
  end
  m_env_cfg.m_apb_agent_cfg = m_apb_cfg;
  // The SPI is not configured as such
  m_spi_cfg = spi_agent_config::type_id::create("m_spi_cfg");
  if(!uvm_config_db #(virtual spi_if)::get(this, "", "SPI_vif", m_spi_cfg.SPI)) begin
    `uvm_error("RESOURCE_ERROR", "SPI virtual interface not found")
  end
  m_spi_cfg.has_functional_coverage = 0;
  m_env_cfg.m_spi_agent_cfg = m_spi_cfg;
  // Insert the interrupt virtual interface into the env_config:
  if(!uvm_config_db #(virtual intr_if)::get(this, "", "INTR_vif", m_env_cfg.INTR)) begin
    `uvm_error("RESOURCE_ERROR", "INTR virtual interface not found")
  end
  // Set the spi env config object
  uvm_config_db #(spi_env_config)::set(this, "*", "spi_env_config", m_env_cfg);
  m_env = spi_env::type_id::create("m_env", this);
endfunction: build_phase

function void spi_test_base::connect_phase(uvm_phase phase);
  $display("debug: this.get_full_name = %s", this.get_full_name());
// $display("debug: this.get_full_name2 = %s", uvm_root::get().get_full_name());
  if (m_env.m_apb_agent != null)
    uvm_config_db #(apb_sequencer)::set(this, "*", "apb_sequencer", m_env.m_apb_agent.m_sequencer);
  if (m_env.m_spi_agent != null)
    uvm_config_db #(spi_sequencer)::set(this, "*", "spi_sequencer", m_env.m_spi_agent.m_sequencer);
endfunction: connect_phase

//
// Convenience function to configure the apb agent
//
// This can be overloaded by extensions to this test base class
function void spi_test_base::configure_apb_agent(apb_agent_config cfg);
  cfg.active = UVM_ACTIVE;
  cfg.has_functional_coverage = 0;
  cfg.has_scoreboard = 0;
  // SPI is on select line 0 for address range 0-18h
  cfg.no_select_lines = 1;
  cfg.start_address[0] = 32'h0;
  cfg.range[0] = 32'h18;
endfunction: configure_apb_agent

// Extension hook for tests that need to disable or specialize environment
// components before spi_env is built.
function void spi_test_base::configure_env(spi_env_config cfg);
endfunction: configure_env

function void spi_test_base::end_of_elaboration_phase(uvm_phase phase);
  uvm_top.print_topology();
  `uvm_info(get_type_name(), $sformatf("Verbosity level is set to: %d", get_report_verbosity_level()), UVM_MEDIUM)
  `uvm_info(get_type_name(), "Print all Factory overrides", UVM_MEDIUM)
  factory.print();
endfunction : end_of_elaboration_phase
