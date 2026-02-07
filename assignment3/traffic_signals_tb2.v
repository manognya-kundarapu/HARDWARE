`timescale 1s/1ms
module traffic_signals_tb;

    // Inputs
    reg clk;
    reg reset;
    reg emergency_left;
    reg emergency_right;

    // Outputs
    wire [1:0] T1state, T2state;
    wire T1_WALK, T2_WALK, buzzer_walk;

    // Instantiate DUT
    traffic_signals uut (
        .clk(clk),
        .reset(reset),
        .emergency_left(emergency_left),
        .emergency_right(emergency_right),
        .T1state(T1state),
        .T2state(T2state),
        .T1_WALK(T1_WALK),
        .T2_WALK(T2_WALK),
        .buzzer_walk(buzzer_walk)
    );

    // Clock generation (1Hz with 0.5s high, 0.5s low)
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk; // Exactly as you specified
    end

    // Waveform dumping
    initial begin
        $dumpfile("traffic_waves.vcd");
        $dumpvars(0, traffic_signals_tb);
    end

    // Test sequence with guaranteed timing
    initial begin
        // Initialize
        reset = 1;
        emergency_left = 0;
        emergency_right = 0;
        
        // Release reset after 10s
        #10 reset = 0;
        
        // Wait for EXACTLY one full cycle (95s)
        // GREEN(30s) + YELLOW(5s) + RED(60s)
        #95;
        
        // Trigger left emergency at 105s (10+95)
        emergency_left = 1;
        #1 emergency_left = 0;
        #10; // Emergency lasts 10s
        
        // Trigger right emergency at 116s (105+10+1)
        emergency_right = 1;
        #1 emergency_right = 0;
        #10;
        
        // Observe recovery
        #50;
        $finish;
    end

endmodule
