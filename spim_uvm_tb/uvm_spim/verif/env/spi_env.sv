//------------------------------------------------------------
//
// Class Description:
//
//
class spi_env extends uvm_env;

// UVM Factory Registration Macro
//
`uvm_component_utils(spi_env)
//------------------------------------------
// Data Members
//------------------------------------------
apb_agent m_apb_agent;
spi_agent m_spi_agent;
spi_env_config m_cfg;
spi_reg_functional_coverage m_func_cov_monitor;
spi_scoreboard m_scoreboard;
// Register layering adapter:
reg2apb_adapter reg2apb;
//------------------------------------------
// Constraints
//------------------------------------------

//------------------------------------------
// Methods
//------------------------------------------

// Standard UVM Methods:
extern function new(string name = "spi_env", uvm_component parent = null);
extern function void build_phase(uvm_phase phase);
extern function void connect_phase(uvm_phase phase);

endclass:spi_env

function spi_env::new(string name = "spi_env", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void spi_env::build_phase(uvm_phase phase);
  if(!uvm_config_db #(spi_env_config)::get(this, "", "spi_env_config", m_cfg)) begin
    `uvm_error("build_phase", "Failed to find spi_env_config")
  end
  if(m_cfg.has_apb_agent) begin
    uvm_config_db #(apb_agent_config)::set(this, "m_apb_agent*", "apb_agent_config", m_cfg.m_apb_agent_cfg);
    m_apb_agent = apb_agent::type_id::create("m_apb_agent", this);
  end
  if(m_cfg.has_spi_agent) begin
    uvm_config_db #(spi_agent_config)::set(this, "m_spi_agent*", "spi_agent_config", m_cfg.m_spi_agent_cfg);
    m_spi_agent = spi_agent::type_id::create("m_spi_agent", this);
  end
  if(m_cfg.has_spi_functional_coverage) begin
    m_func_cov_monitor = spi_reg_functional_coverage::type_id::create("m_func_cov_monitor", this);
  end
  if(m_cfg.has_spi_scoreboard) begin
    m_scoreboard = spi_scoreboard::type_id::create("m_scoreboard", this);
  end
endfunction:build_phase

function void spi_env::connect_phase(uvm_phase phase);
  if(m_cfg.m_apb_agent_cfg.active == UVM_ACTIVE) begin
    reg2apb = reg2apb_adapter::type_id::create("reg2apb");
    //
    // Register sequencer layering part:
    //
    // Only set up register sequencer layering if the top level env
    if(m_cfg.spi_rm.get_parent() == null) begin
      m_cfg.spi_rm.default_map.set_sequencer(m_apb_agent.m_sequencer, reg2apb);
    end
    // Register prediction part, Set the predictor adapter:
    // set the register models auto-prediction
    m_cfg.spi_rm.default_map.set_auto_predict(1);
  end
  if(m_cfg.has_spi_functional_coverage) begin
    m_apb_agent.ap.connect(m_func_cov_monitor.analysis_export);
    m_func_cov_monitor.spi_rm = m_cfg.spi_rm;
  end
  if(m_cfg.has_spi_scoreboard) begin
    m_spi_agent.ap.connect(m_scoreboard.spi.analysis_export);
    m_spi_agent.m_driver.expected_ap.connect(m_scoreboard.expected_spi.analysis_export);
    m_scoreboard.spi_rm = m_cfg.spi_rm;
    m_spi_agent.m_monitor.spi_rm = m_cfg.spi_rm;
  end
  //// Set up the agent sequencers as resources:
  //uvm_config_db #(apb_sequencer)::set(null, "*", "apb_sequencer", m_apb_agent.m_sequencer);
  //uvm_config_db #(spi_sequencer)::set(null, "*", "spi_sequencer", m_spi_agent.m_sequencer);
endfunction: connect_phase

