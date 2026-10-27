module apb_alu_slave (
    input logic pclk, presetn,
    input logic [31:0] paddr, pwdata,
    input logic psel, penable, pwrite,
    output logic [31:0] prdata,
    output logic pready, pslverr
);
    localparam [31:0] BASE = 32'h7000_0000;
    logic [31:0] operand1, operand2, control, result;
    logic valid_addr;

    // apb register logic
    always_comb begin
        valid_addr = (paddr == BASE) || (paddr == BASE + 4) ||
                     (paddr == BASE + 8) || (paddr == BASE + 12);
        pready = presetn && psel && penable;
        pslverr = pready && (!valid_addr ||
                  (pwrite && paddr == BASE + 12) ||
                  (pwrite && paddr == BASE + 8 && pwdata[31:1] != 0));
        prdata = 0;
        if (presetn && psel && !pwrite && !pslverr) begin
            case (paddr)
                BASE:      prdata = operand1;
                BASE + 4:  prdata = operand2;
                BASE + 8:  prdata = control;
                BASE + 12: prdata = result;
                default:   prdata = 0;
            endcase
        end
    end

    // apb register logic
    always_ff @(posedge pclk) begin
        if (!presetn) begin
            operand1 <= 0;
            operand2 <= 0;
            control <= 0;
            result <= 0;
        end else if (pready && pwrite && !pslverr) begin
            case (paddr)
                BASE: operand1 <= pwdata;
                BASE + 4: operand2 <= pwdata;
                BASE + 8: begin
                    control <= pwdata;
                    // apb register logic
                    if (pwdata[0]) result <= operand1 - operand2;
                    else result <= operand1 + operand2;
                end
                default: begin end
            endcase
        end
    end
endmodule

