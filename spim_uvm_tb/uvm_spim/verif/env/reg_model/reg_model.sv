class rxtx0_reg extends uvm_reg;
    rand uvm_reg_field rxtx0;
    `uvm_object_utils(rxtx0_reg)

    function new(input string name="rxtx0");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rxtx0 = uvm_reg_field::type_id::create("rxtx0");
        rxtx0.configure(this,32,0,"RW",0,'b00000000000000000000000000000000,1,1,0);
    endfunction 
endclass

class rxtx1_reg extends uvm_reg;
    rand uvm_reg_field rxtx1;
    `uvm_object_utils(rxtx1_reg)

    function new(input string name="rxtx1");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rxtx1 = uvm_reg_field::type_id::create("rxtx1");
        rxtx1.configure(this,32,0,"RW",0,'b00000000000000000000000000000000,1,1,0);
    endfunction 
endclass

class rxtx2_reg extends uvm_reg;
    rand uvm_reg_field rxtx2;
    `uvm_object_utils(rxtx2_reg)

    function new(input string name="rxtx2");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rxtx2 = uvm_reg_field::type_id::create("rxtx2");
        rxtx2.configure(this,32,0,"RW",0,'b00000000000000000000000000000000,1,1,0);
    endfunction 
endclass

class rxtx3_reg extends uvm_reg;
    rand uvm_reg_field rxtx3;
    `uvm_object_utils(rxtx3_reg)

    function new(input string name="rxtx3");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        rxtx3 = uvm_reg_field::type_id::create("rxtx3");
        rxtx3.configure(this,32,0,"RW",0,'b00000000000000000000000000000000,1,1,0);
    endfunction 
endclass

class ctrl_reg extends uvm_reg;
    rand uvm_reg_field ie;
    rand uvm_reg_field char_len;
    rand uvm_reg_field rx_neg;
    rand uvm_reg_field lsb;
    rand uvm_reg_field ass;
    rand uvm_reg_field go_bsy;
    rand uvm_reg_field tx_neg;
    `uvm_object_utils(ctrl_reg)

    function new(input string name="ctrl");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        ie = uvm_reg_field::type_id::create("ie");
        ie.configure(this,1,12,"RW",0,'b0,1,1,0);
        char_len = uvm_reg_field::type_id::create("char_len");
        char_len.configure(this,7,0,"RW",0,'b0000000,1,1,0);
        rx_neg = uvm_reg_field::type_id::create("rx_neg");
        rx_neg.configure(this,1,9,"RW",0,'b0,1,1,0);
        lsb = uvm_reg_field::type_id::create("lsb");
        lsb.configure(this,1,11,"RW",0,'b0,1,1,0);
        ass = uvm_reg_field::type_id::create("ass");
        ass.configure(this,1,13,"RW",0,'b0,1,1,0);
        go_bsy = uvm_reg_field::type_id::create("go_bsy");
        go_bsy.configure(this,1,8,"RW",0,'b0,1,1,0);
        tx_neg = uvm_reg_field::type_id::create("tx_neg");
        tx_neg.configure(this,1,10,"RW",0,'b0,1,1,0);
    endfunction 
endclass

class divider_reg extends uvm_reg;
    rand uvm_reg_field divider;
    `uvm_object_utils(divider_reg)

    function new(input string name="divider");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        divider = uvm_reg_field::type_id::create("divider");
        divider.configure(this,16,0,"RW",0,'b1111111111111111,1,1,0);
    endfunction 
endclass

class ss_reg extends uvm_reg;
    rand uvm_reg_field ss;
    `uvm_object_utils(ss_reg)

    function new(input string name="ss");
        super.new(name,32,UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        ss = uvm_reg_field::type_id::create("ss");
        ss.configure(this,8,0,"RW",0,'b00000000,1,1,0);
    endfunction 
endclass

