`timescale 1ns/1ps

module tb_traffic_light;
    reg clk_50 = 0;
    reg reset_n = 0;
    wire [7:0] leds;

    lab3_top dut (
        .clk_50(clk_50),
        .reset_n(reset_n),
        .switches(8'b0),
        .leds(leds)
    );

    always #10 clk_50 = ~clk_50;

    task automatic expect_phase(
        input [7:0] expected,
        input time duration_ns,
        input time tolerance_ns
    );
        time started_at, elapsed_ns;
        started_at = $time;
        @(leds);
        elapsed_ns = $time - started_at;
        if (leds !== expected)
            $fatal(1, "Expected LED mask %02h, got %02h", expected, leds);
        if (elapsed_ns + tolerance_ns < duration_ns ||
            elapsed_ns > duration_ns + tolerance_ns)
            $fatal(1, "Expected %0d ns, got %0d ns", duration_ns, elapsed_ns);
        $display("LED mask %02h after %0d ns", leds, elapsed_ns);
    endtask

    initial begin
        #1000;
        if (leds !== 8'h09)
            $fatal(1, "Expected red on both roads during reset");
        reset_n = 1;

        @(leds);
        if (leds !== 8'h0c)
            $fatal(1, "Expected road A to get green after startup");
        $display("LED mask %02h after startup", leds);

        expect_phase(8'h0a, 40_000,   3_000);
        expect_phase(8'h09, 12_000,   3_000);
        expect_phase(8'h21,  4_000,   3_000);
        expect_phase(8'h11, 40_000,   3_000);
        expect_phase(8'h09, 12_000,   3_000);
        expect_phase(8'h0c,  4_000,   3_000);

        reset_n = 0;
        #1000;
        if (leds !== 8'h09)
            $fatal(1, "Reset did not restore both red signals");

        $display("PASS: Nios II firmware, six phases, timing and reset");
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "Timeout waiting for the traffic light cycle");
    end
endmodule
