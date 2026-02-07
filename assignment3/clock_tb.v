`timescale 1s/1ms

module Testbench_Clock;
    reg clk;
    reg rst;
    reg [2:0] current_mode;
    reg [16:0] in;
    reg mode_rst;
    wire [16:0] out;

    // Instantiate the clock module
    clock uut (
        .clk(clk),
        .rst(rst),
        .current_mode(current_mode),
        .in(in),
        .mode_rst(mode_rst),
        .out(out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end
    initial begin
        // Initialize all inputs
        rst = 1;
        current_mode = 3'b000; // Start in 24-hour clock mode
        in = 0;
        mode_rst = 0;

        // Generate VCD file for GTKWave
        $dumpfile("testbench_clock.vcd"); // Name of the generated VCD file
        $dumpvars(0, Testbench_Clock);    // Dump all variables in the current scope

        // Release reset after 2 seconds
        #2 rst = 0;

        // Let the simulation run for some time
        #10000; // Simulate 100,000 seconds (approx. 1 day and 3 hours)

        // End simulation
        $finish;
    end

    // Test sequence
    initial begin
        // Test 1: Global reset
        $display("Test 1: Global Reset");
        rst = 1; mode_rst = 0; current_mode = 3'b000; in = 0;
        #20 rst = 0; // Release reset

        // Test 2: 24-hour clock mode
        $display("Test 2: 24-hour Clock Mode");
        current_mode = 3'b000; mode_rst = 1;
        #10 mode_rst = 0;
        #100; // Let the clock run for some time

        // Test 3: 12-hour clock mode
        $display("Test 3: 12-hour Clock Mode");
        current_mode = 3'b001; mode_rst = 1;
        #10 mode_rst = 0;
        #100; // Let the clock run for some time

        // Test 4: Date display mode
        $display("Test 4: Date Display Mode");
        current_mode = 3'b010; mode_rst = 1;
        #10 mode_rst = 0;
        #100; // Let the date increment

        // Test 5: Timer mode
        $display("Test 5: Timer Mode");
        current_mode = 3'b011; mode_rst = 1; in = 17'b00000_000000_001010; // Timer set to 1 hour, 1 minute, 2 seconds
        #10 mode_rst = 0;
        #500; // Let the timer decrement

        // Test 6: Stopwatch mode
        $display("Test 6: Stopwatch Mode");
        current_mode = 3'b100; mode_rst = 1;
        #10 mode_rst = 0;
        #500; // Let stopwatch increment

        // Test 7: Alarm mode
        $display("Test 7: Alarm Mode");
        current_mode = 3'b101; mode_rst = 1; in = 17'b00000_000001_000010; // Alarm at 00:01:02
        #10 mode_rst = 0;
        #1000; // Simulate time until alarm triggers

        // End simulation
        $finish;
    end

    // Monitor output in decimal format
    initial begin
        $monitor("Time: %0t | Mode: %b | Out: %02d:%02d:%02d (hh:mm:ss or dd:mm:yy)",
                 $time, current_mode, out[16:12], out[11:6], out[5:0]);
    end
endmodule
