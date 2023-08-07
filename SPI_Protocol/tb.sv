//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/01/2023 10:05:09 PM
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
interface spi_if;
    logic clk;
    logic newd;
    logic rst;
    logic [11:0]din;
//    logic newd;
    logic sclk;
    logic cs;
    logic mosi;
endinterface


class transaction;
    rand bit newd;
    rand bit [11:0] din;
    bit cs;
    bit mosi;
    
    function void display(input string tag);
        $display("[%0s] : DATA_NEW : %0b din : 0%b cs : %0b mosi : 0%b",tag,newd,din,cs,mosi);
        
    endfunction
    
    function transaction copy();
        copy = new();
        copy.newd = this.newd;
        copy.din = this.din;
        copy.cs = this.cs;
        copy.mosi = this.mosi;
    endfunction    
endclass

class generator;
    transaction tr;
    mailbox #(transaction) mbxgd;
    event done;
    event drvnext;
    event sconext;
    
    int count = 0;
    
    function new(mailbox #(transaction) mbxgd);
        this.mbxgd=mbxgd;
        tr=new();
    endfunction
    
    task run();
        repeat(count)
        begin
            assert(tr.randomize) else $error("RANDOMIZATION FAILED");
            
            mbxgd.put(tr.copy);
            tr.display("GEN");
            @(drvnext);
            @(sconext);
        end
        ->done;
    endtask
endclass

class driver;
    virtual spi_if vif;
    transaction tr;
    event drvnext;
    mailbox #(transaction) mbxgd;
    mailbox #(bit[11:0]) mbxds;
    
    function new(mailbox #(transaction) mbxgd, mailbox #(bit [11:0]) mbxds);
        this.mbxgd=mbxgd;
        this.mbxds=mbxds;
    endfunction
    
    task reset();
        vif.rst <= 1'b1;
        vif.cs <= 1'b1;
        vif.mosi <= 1'b0;
        vif.newd <= 1'b0;
        vif.din <= 1'b0;
        repeat(10) @(posedge vif.clk)
            vif.rst <= 1'b0;
        repeat(5) @(posedge vif.clk)
            $display("DUT : RESET DONE");    
    endtask
    
    task run();
        forever
        begin
            mbxgd.get(tr);
            @(posedge vif.sclk);
            vif.newd <= 1'b1;
            vif.din <= tr.din;
            mbxds.put(tr.din);
            @(posedge vif.sclk);
            vif.newd <= 1'b0;
            wait(vif.cs==1'b1);
            $display("[DRV] : DATA SENT : 0%d ",tr.din);
            ->drvnext;
        end
    endtask
endclass

class monitor;
    transaction tr;
    virtual spi_if vif;
    mailbox #(bit [11:0]) mbxms;
    bit[11:0] srx;
//    event sconext;
    function new(mailbox #(bit [11:0]) mbxms);
        this.mbxms= mbxms;
    endfunction
    
    task run();
        forever begin
            @(posedge vif.sclk);
            wait(vif.cs==1'b0);
            @(posedge vif.sclk);
            for(int i =0; i<=11; i++)begin
              @(posedge vif.clk);
                srx[i]=vif.mosi;
              
            end
            wait(vif.cs==1'b1);
            $display("[MON] : DATA : %0d", srx);
            mbxms.put(srx);
//            ->sconext;
        end
    endtask
endclass


class scoreboard;
    mailbox  #(bit [11:0] )mbxms,mbxds;
    event sconext;
    bit[11:0]ds,ms;
    
    function new(mailbox #(bit [11:0]) mbxms, mailbox #(bit [11:0])mbxds);
        this.mbxms= mbxms;
        this.mbxds= mbxds;
    endfunction
    
    task run();
        forever begin
            mbxds.get(ds);
            mbxms.get(ms);
            $display("[SCO] : DRV DATA : %0d MON DATA : %0d",ds,ms);
            if(ds==ms)
                $display("[SCO] : DATA MATCH");
            else
                $display("[SCO] : DATA MISMATCH");  
            ->sconext;      
        end
    endtask
endclass


class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    event nextgd;
    event nextgs;
    
    mailbox #(transaction) mbxgd;
    mailbox #(bit [11:0]) mbxds;
    mailbox #(bit [11:0]) mbxms;
    
    virtual spi_if vif;
    
    function new(virtual spi_if vif);
        mbxgd=new();
        mbxds=new();
        mbxms=new();
        
        gen=new(mbxgd);
        drv=new(mbxgd,mbxds);
        
        mon=new(mbxms);
        sco=new(mbxds,mbxms);
        
        this.vif=vif;
        drv.vif=this.vif;
        mon.vif=this.vif;
        
        gen.sconext=nextgs;
        sco.sconext=nextgs;
        
        gen.drvnext=nextgd;
        drv.drvnext=nextgd;
        
        
        
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
   
    spi_if vif();
    spi dut(vif.clk, vif.newd, vif.rst, vif.din, vif.sclk, vif.cs,vif.mosi);
    
    initial begin
        vif.clk<=1'b0;
    end
    
    always #10  vif.clk <=  ~vif.clk;
    
    environment env;
    
    initial begin
        env=new(vif);
        env.gen.count=20;
        env.run();
    end
      
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule