module clock(
    input clk,
    input rst,                   // Global reset
    input [2:0] current_mode,    // Mode selector
    input [16:0] in,             // Input for timer/alarm initialization (hh:mm:ss format)
    input mode_rst,              // Reset for individual modes
    output reg [16:0] out        // Output in hh:mm:ss or dd:mm:yy format
);   // for hours max 23 so 5 bits minutes and seconds max 59 so 6 bits

    // Mode Definitions
    // 000 = 24-hour clock, 001 = 12-hour clock, 010 = Date Display
    // 011 = Timer, 100 = Stopwatch, 101 = Alarm
    reg [2:0] mode;

    // for default clock
    reg [5:0] seconds;
    reg [5:0] minutes;
    reg [4:0] hours;

    // for timer alarm and stopwatch
    reg [5:0] s;
    reg [5:0] m;
    reg [4:0] h;
    reg timer_running;
    reg timer_started;
    reg buzz;
    reg [4:0] buzz_time;

    // for date display
  reg [4:0] date; // upto 31 dates so 5 bits needed
  reg [3:0] month;// 12 months - 4 bits needed
  reg [4:0] year;// only last two digits of the year is considering so 5 bits as asked in question 2020 to 2025 for 20 to 25 we need 5 bits

    wire is_leap_year;

    // Leap year logic
    assign is_leap_year = (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));

    // Mode Update
    always @(posedge clk or posedge rst) begin
        if (rst) 
            mode <= 3'b000; // Default to 24-hour clock
        else 
            mode <= current_mode;
    end

    // Main Clock Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all values
            seconds <= 6'b0;
            minutes <= 6'b0;
            hours <= 5'b0;
            date <= 5'd1;
            month <= 4'd1;
            year <= 5'd20;
            s <= 6'b0;
            m <= 6'b0;
            h <= 5'b0;
            timer_running <= 0;
            timer_started <= 0;
            buzz <= 0;
            buzz_time <= 0;
        end else begin
            // Increment in clock
            seconds <= seconds + 1;
            if (seconds == 6'd60) begin
                seconds <= 6'b0;
                minutes <= minutes + 1;
                if (minutes == 6'd60) begin
                    minutes <= 6'b0;
                    hours <= hours + 1;
                    if (hours == 5'd24) begin
                        hours <= 5'b0;

                        // Increment in date
                        date <= date + 1;
                        if ((month == 5'd2 && date == (is_leap_year ? 5'd30 : 5'd29)) ||
                            ((month == 5'd4 || month == 5'd6 || month == 5'd9 || month == 5'd11) && date == 5'd31) ||
                            date == 5'd32) begin
                            date <= 5'd1;
                            month <= month + 1;
                            if (month == 5'd12) begin
                                month <= 5'd1;
                                year <= (year < 6'd25) ? year + 1 : 6'd20;
                            end
                        end
                    end
                end
            end

            // Mode logic
            case (mode)
                3'b000: begin // 24 hour format clock
                    if (mode_rst) begin
                        s <= 6'b0;
                        m <= 6'b0;
                        h <= 5'b0;
                    end
                    s <= seconds;
                    m <= minutes;
                    h <= hours;
                end // 24 hour format clock

                3'b001: begin // 12 hour format clock
                    if (mode_rst) begin
                        s <= 6'b0;
                        m <= 6'b0;
                        h <= 5'b0;
                    end
                    h[4] <= (hours >= 12) ? 1 : 0; // AM/PM indicator (PM=1, AM=0)
                  h[3:0] <= (hours % 12);
                  m <= minutes;
                   s <= seconds;
                end // 12 hour format

                3'b010: begin // Date display
                    if (mode_rst) begin
                        date <= 5'd1;
                        month <= 4'd1;
                        year <= 5'd20;
                    end
                    h <= date;
                    m <= month;
                    s <= year;
                end // date

                3'b011: begin // Timer
                  if (mode_rst) begin // if l:129
                        s <= 6'b0;
                        m <= 6'b0;
                        h <= 5'b0;
                        timer_running <= 0;
                        timer_started <= 0;
                        buzz <= 0;
                        buzz_time <= 0;
                    end else begin // if l:129 else l:137
                      if (!timer_started) begin // if l:138
                            h <= in[16:12];
                            m <= in[11:6];
                            s <= in[5:0];
                            timer_running <= 1;
                            timer_started <= 1;
                            buzz <= 0;
                      end else if (timer_running) begin // if l:138 else l:145
                            if (s > 0) s <= s - 1;
                            else if (m > 0) begin
                                m <= m - 1;
                                s <= 6'd59;
                            end else if (h > 0) begin
                                h <= h - 1;
                                m <= 6'd59;
                                s <= 6'd59;
                            end else begin
                                timer_running <= 0;
                                buzz <= 1;
                                buzz_time <= 30; // Example buzz duration
                            end
                        end else if // else l:145
                          (buzz_time > 0 && buzz) buzz_time <= buzz_time - 1;
                        else buzz <= 0;
                    end // if l:137
                end // timer
              3'b100: begin // Stopwatch
                    if (mode_rst) begin
                        s <= 6'b0;
                        m <= 6'b0;
                        h <= 5'b0;
                    end else begin
                        s <= s + 1;
                        if (s == 6'd60) begin
                            s <= 6'b0;
                            m <= m + 1;
                            if (m == 6'd60) begin
                                m <= 6'b0;
                                h <= h + 1;
                                if (h == 5'd24) h <= 5'b0;
                            end
                        end
                    end
                end // stopwatch

                3'b101: begin // Alarm
                    if (mode_rst) begin
                        buzz_time <= 0;
                        buzz <= 0;
                    end
                    h <= in[16:12];
                    m <= in[11:6];
                    s <= in[5:0];
                    if (h == hours && m == minutes && s == seconds) begin
                        buzz <= 1;
                        buzz_time <= 30;
                    end else if (buzz_time > 0) buzz_time <= buzz_time - 1;
                    else buzz <= 0;
                end //alarm
            endcase

            // output
            out[16:12] <= h;
            out[11:6] <= m;
            out[5:0] <= s;
        end
    end
endmodule
