
`define BUILD_REG_BLOCK(name,addr,type,bkdr) \
    name = name``_reg::type_id::create(`"name`",,get_full_name()); \
    name.configure(this,null,bkdr); \
    name.build(); \
    default_map.add_reg(name,addr,type);

class reg_block extends uvm_reg_block;
    rand rxtx0_reg      rxtx0;
    rand ctrl_reg      ctrl;
    rand divider_reg      divider;
    rand ss_reg      ss;
    rand rxtx1_reg      rxtx1;
    rand rxtx2_reg      rxtx2;
    rand rxtx3_reg      rxtx3;

    `uvm_object_utils(reg_block)

    function new(input string name="reg_block");
        super.new(name,UVM_NO_COVERAGE);
    endfunction

    function void build();
      string s;
        default_map = create_map("default_map",0,4,UVM_LITTLE_ENDIAN);
        `BUILD_REG_BLOCK(rxtx0,'h0,"RW","");
        `BUILD_REG_BLOCK(ctrl,'h10,"RW","ctrl");
        `BUILD_REG_BLOCK(divider,'h14,"RW","divider");
        `BUILD_REG_BLOCK(ss,'h18,"RW","ss");
        `BUILD_REG_BLOCK(rxtx1,'h4,"RW","");
        `BUILD_REG_BLOCK(rxtx2,'h8,"RW","");
        `BUILD_REG_BLOCK(rxtx3,'hc,"RW","");
         for(int i = 0; i < 32; i++) begin
           $sformat(s, "rx[%0d]", i);
           rxtx0.add_hdl_path_slice(s, i, 1);
         end
         for(int i = 32; i < 64; i++) begin
           $sformat(s, "rx[%0d]", i);
           rxtx1.add_hdl_path_slice(s, i-32, 1);
         end
         for(int i = 64; i < 96; i++) begin
           $sformat(s, "rx[%0d]", i);
           rxtx2.add_hdl_path_slice(s, i-64, 1);
         end
         for(int i = 96; i < 128; i++) begin
           $sformat(s, "rx[%0d]", i);
           rxtx3.add_hdl_path_slice(s, i-96, 1);
         end
    endfunction

endclass
