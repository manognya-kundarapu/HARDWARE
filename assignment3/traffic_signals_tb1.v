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
    
    // Intermediate signals for monitoring
    wire [7:0] T1_str, T2_str;

    // Instantiate Unit Under Test (UUT)
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

    // Assign state names to wires for monitoring
    assign T1_str = (T1state == 2'b00) ? "RED" : 
                   (T1state == 2'b01) ? "GREEN" : "YELLOW";
    assign T2_str = (T2state == 2'b00) ? "RED" : 
                   (T2state == 2'b01) ? "GREEN" : "YELLOW";

    // Clock generation (1Hz = 1 second per tick)
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk; // 1Hz clock (0.5s high, 0.5s low)
    end

    // Initialize waveform dumping
    initial begin
        $dumpfile("traffic_waves.vcd");
        $dumpvars(0, traffic_signals_tb);
    end

    // Test procedure
    initial begin
        // Initialize inputs
        reset = 1;
        emergency_left = 0;
        emergency_right = 0;
        
        // Monitor signals (prints to console)
        $monitor("Time=%0t: T1=%s T2=%s | Walk: T1=%b T2=%b | Buzzer=%b",
                 $time,
                 T1_str, T2_str,
                 T1_WALK, T2_WALK, buzzer_walk);
        
        // Reset the system
        #10 reset = 0;
        
        $display("\n=== Testing Normal Operation ===");
        $display("Observing 2 full cycles (about 190 seconds)...\n");
        
        // Let it run for 2 full cycles (GREEN→YELLOW→RED→GREEN)
        #190;
        
        $display("\n=== Test Complete ===");
        $finish;
    end

endmodule
