interface dff_if;
    logic clk;
    logic rst;
    logic din;
    logic dout;
endinterface

class transaction;
    rand bit din;
    bit dout;
    
    function void display(input string tag);
        $display("[%0s] : din : %0b dout : %0b",tag, din, dout);
    endfunction
    
    function transaction copy();
        copy=new();
        copy.din=this.din;
        copy.dout=this.dout;
    endfunction
    
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    mailbox #(transaction) mbxref;
    
    int count;
    
    event sconext;
    event done;
    
    function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
        this.mbx=mbx;
        this.mbxref=mbxref;
        tr=new();
    endfunction
    
    task run();
        repeat(count)
        begin
            for(int i=0; i<10;i++)
            assert(tr.randomize) else $error("RANDOMIZATION FAILED");
            mbx.put(tr.copy);
            mbxref.put(tr.copy);
            tr.display("GEN");
            @(sconext);
        end
        ->done;
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual dff_if vif;
    
    
    function new(mailbox #(transaction) mbx);
        this.mbx=mbx;
    endfunction
    
    task reset();
        vif.rst <= 1'b1;
        repeat(5)
            @(posedge vif.clk)
            vif.rst <= 1'b0;
            
        repeat(2)
            @(posedge vif.clk)
            $display("[DRV] : DUT reset Done");     
    endtask
    
    task run();
        forever begin
            mbx.get(tr);
            @(posedge vif.clk)
            vif.din <= tr.din;
            tr.display("DRV");
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual dff_if vif;
    
    function new(mailbox #(transaction) mbx);
        this.mbx=mbx;
    endfunction
    
    task run();
        tr=new();
        forever begin
            @(posedge vif.clk)
            tr.din=vif.din;
            tr.dout=vif.dout;
            mbx.put(tr);
            tr.display("MON");
        end
    endtask
endclass

class scoreboard;
    transaction tr;
    transaction trref;
    mailbox #(transaction) mbx;
     mailbox #(transaction) mbxref;
    event sconext;
    
    function new(mailbox #(transaction) mbx,  mailbox #(transaction) mbxref);
        this.mbx=mbx;
        this.mbxref=mbxref;
    endfunction
    
    task run();
        forever begin
            mbx.get(tr);
            mbxref.get(trref);
            tr.display("SCO");
            trref.display("REF");
            if(tr.dout==trref.din)begin
                $display("[SCO]: DATA MATCH");
                end
            else begin
                $display("[SCO]: DATA MISMATCH");
                end
        ->sconext;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    event next;
    
    mailbox #(transaction) gdmbx;
    mailbox #(transaction) msmbx;
    mailbox #(transaction) mbxref;
    
    virtual dff_if vif;
    
    function new(virtual dff_if vif);
        gdmbx = new();
        mbxref=new();
        
        gen = new(gdmbx,mbxref);
        drv = new(gdmbx);
        
        msmbx = new();
//        mon = new(mbxms);
        mon = new(msmbx);
        sco = new(msmbx, mbxref);
        
        this.vif=vif;
        mon.vif=this.vif;
        drv.vif=this.vif;
        
        gen.sconext = next;
        sco.sconext = next;
    endfunction
    
    task pre_test();
        drv.reset();
    endtask
    
    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
    endtask
    
    
    task post_test();
        wait(gen.done.triggered);
        $finish();
    endtask
    
    task run();
        pre_test();
        test();
        post_test();
    endtask
endclass

module tb;
    dff_if vif();
    
    d_ff dut(vif.clk, vif.rst, vif.din, vif.dout);
    
    initial
    begin
        vif.clk <= 0;
    end
    
    always #10 vif.clk <= ~vif.clk;
    
    environment env;
    
    initial
    begin
        env = new(vif);
        env.gen.count=30;
        env.run();
    end
    
    initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
    
endmodule