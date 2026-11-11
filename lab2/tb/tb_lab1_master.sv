`timescale 1ns/1ps
module master_case #(parameter SUBTRACT = 0) (
    input logic pclk, presetn,
    output logic done
);
    logic [31:0] paddr, pwdata, prdata;
    logic psel, penable, pwrite, pready, pslverr;
    integer transfers = 0;

    // same master as in lab 1 with lab 2 data
    apb_master #(.DATA0(32'd100), .DATA1(32'd42),
                 .DATA2(SUBTRACT), .DATA3(32'd99)) master (.*);
    apb_alu_slave slave (.*);

    always @(posedge pclk) begin
        if (presetn && psel && penable && pready) begin
            if (pwrite !== 1'b1 ||
                paddr !== (32'h70000000 + 4 * transfers))
                $fatal(1, "unexpected master transaction %0d", transfers);
            // the fourth write targets the read-only result
            if (pslverr !== (transfers == 3))
                $fatal(1, "unexpected error flag on transfer %0d", transfers);
            transfers <= transfers + 1;
        end
    end

    always @(posedge done) begin
        if (transfers != 4 || slave.operand1 !== 32'd100 ||
            slave.operand2 !== 32'd42 || slave.control !== SUBTRACT ||
            slave.result !== (SUBTRACT ? 32'd58 : 32'd142))
            $fatal(1, "incorrect result with lab 1 master");
    end
endmodule

module tb_lab1_master;
    logic pclk = 0, presetn = 0;
    logic add_done, sub_done;
    master_case add_case(pclk, presetn, add_done);
    master_case #(.SUBTRACT(1)) sub_case(pclk, presetn, sub_done);
    always #5 pclk = ~pclk;

    initial begin
        repeat (3) @(negedge pclk);
        presetn = 1;
        wait (add_done && sub_done);
        @(negedge pclk);
        $display("PASS: lab 1 APB master verified addition, subtraction and result write protection");
        $finish;
    end
    initial begin #1000; $fatal(1, "timeout"); end
endmodule
