`timescale 1ns/1ps
module tb_alu;
    logic pclk = 0, presetn = 0;
    logic [31:0] paddr = 0, pwdata = 0, prdata;
    logic psel = 0, penable = 0, pwrite = 0, pready, pslverr;
    integer checks = 0;
    logic [31:0] a, b, seed = 32'h12345678;
    localparam [31:0] BASE = 32'h70000000;
    apb_alu_slave dut(.*);
    always #5 pclk = ~pclk;

    // master drives at falling edges
    task automatic transfer(input bit wr, input logic [31:0] addr,
                            input logic [31:0] data, input bit err,
                            input logic [31:0] expected);
        @(negedge pclk);
        psel = 1; penable = 0; pwrite = wr; paddr = addr; pwdata = data;
        @(posedge pclk); #1;
        if (pready || pslverr) $fatal(1, "response in setup");
        @(negedge pclk); penable = 1;
        #1;
        if (pready !== 1 || pslverr !== err)
            $fatal(1, "handshake addr=%h ready=%b err=%b", addr,pready,pslverr);
        if (!wr && prdata !== expected)
            $fatal(1, "read addr=%h expected=%h actual=%h",addr,expected,prdata);
        @(posedge pclk); #1; checks++;
        // next transfer can start with psel held high
    endtask

    task automatic calculate(input logic [31:0] x,y, input bit sub);
        transfer(1,BASE,x,0,0);
        transfer(1,BASE+4,y,0,0);
        transfer(0,BASE,x,0,x);
        transfer(0,BASE+4,y,0,y);
        transfer(1,BASE+8,{31'b0,sub},0,0);
        transfer(0,BASE+8,0,0,{31'b0,sub});
        transfer(0,BASE+12,0,0,sub ? x-y : x+y);
    endtask

    initial begin
        repeat(3) @(negedge pclk);
        presetn = 1;
        for (int i=0;i<4;i++) transfer(0,BASE+4*i,0,0,0);
        calculate(32'd100,32'd42,0);
        calculate(32'd100,32'd42,1);
        calculate(0,1,1);
        calculate(32'hffffffff,1,0);
        calculate(32'h7fffffff,1,0);
        calculate(32'h80000000,1,1);
        calculate(32'hffffffff,32'hffffffff,1);
        for(int i=0;i<100;i++) begin
            seed = seed ^ (seed << 13); seed = seed ^ (seed >> 17); seed = seed ^ (seed << 5); a=seed;
            seed = seed ^ (seed << 13); seed = seed ^ (seed >> 17); seed = seed ^ (seed << 5); b=seed;
            calculate(a,b,0);
            calculate(a,b,1);
        end
        calculate(8,3,0);
        transfer(1,BASE+12,99,1,0);
        transfer(1,BASE+8,2,1,0);
        transfer(1,BASE+16,99,1,0);
        transfer(1,BASE+1,99,1,0);
        transfer(1,32'h71000000,99,1,0);
        transfer(0,BASE+1,0,1,0);
        transfer(0,32'h71000000,0,1,0);
        transfer(0,BASE+12,0,0,11);
        transfer(0,BASE+8,0,0,0);
        transfer(0,BASE,0,0,8);
        transfer(1,BASE,20,0,0);
        transfer(0,BASE+12,0,0,11);

        // aborted setup must not write
        @(negedge pclk);
        psel=1; penable=0; pwrite=1; paddr=BASE; pwdata=999;
        @(negedge pclk); psel=0;
        @(negedge pclk);
        transfer(0,BASE,0,0,20);

        // reset during access
        @(negedge pclk);
        psel=1; penable=1; pwrite=1; paddr=BASE; pwdata=999; presetn=0;
        @(posedge pclk); #1;
        if(pready !== 0 || pslverr !== 0) $fatal(1,"reset response");
        @(negedge pclk); psel=0; penable=0; presetn=1;
        for(int i=0;i<4;i++) transfer(0,BASE+4*i,0,0,0);
        @(negedge pclk); psel=0; penable=0;
        #1;
        if(pready || pslverr) $fatal(1,"idle response");
        $display("PASS: %0d APB transfers; 208 arithmetic cases; reset and error checks",checks);
        $finish;
    end
    initial begin #200000; $fatal(1,"timeout"); end
endmodule
