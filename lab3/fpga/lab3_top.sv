module lab3_top (
    input  wire       clk_50,
    input  wire       reset_n,
    input  wire [7:0] switches,
    output wire [7:0] leds
);
    reg [7:0] switches_meta;
    reg [7:0] switches_sync;

    // Two stages synchronise the external switches to the system clock.
    always @(posedge clk_50 or negedge reset_n) begin
        if (!reset_n) begin
            switches_meta <= 8'b0;
            switches_sync <= 8'b0;
        end else begin
            switches_meta <= switches;
            switches_sync <= switches_meta;
        end
    end

    nios_system u_system (
        .clk_clk         (clk_50),
        .reset_reset_n   (reset_n),
        .switches_export (switches_sync),
        .leds_export     (leds)
    );
endmodule
