module traffic_signals(
    input clk,reset,emergency_left,emergency_right,
    output reg[1:0] T1state,T2state,
    output reg T1_WALK,T2_WALK,buzzer_walk
);
//assigning the states for fsm;
parameter RED=2'b00;
parameter GREEN=2'b01;
parameter YELLOW=2'b10;
//setting the timers
parameter R_TIME=60;
parameter G_TIME=30;
parameter Y_TIME=5;
parameter EMERG_TIME=10;
parameter BUZZ_TIME=5;
reg [3:0]emerg_counter;
reg [5:0] T1counter,T2counter;
reg emerg_active, emerg_type;
reg [1:0] last_T1state, last_T2state;
always @(posedge reset or posedge clk) begin
  if(reset) begin
    T1state<=GREEN;
    T2state<=GREEN;//as they are independent starting both of them from green so to say
    T1counter<=0;
    T2counter<=0;
    T1_WALK<=0;
    T2_WALK<=0;
    buzzer_walk<=0;
    emerg_active<=0;
    emerg_counter<=0;
  end
end
//for ambulance emergency
always @(posedge clk) begin
  if((emergency_left||emergency_right) && !emerg_active) begin
    emerg_active<=1;
    emerg_type<=emergency_right;
    emerg_counter<=0;
    last_T1state<=T1state;
    last_T2state<=T2state;
    if(emergency_left) T1state<=RED;
    else if (emergency_right) begin
      T1state<=RED;
      T2state<=RED;
    end
  end
  else if(emerg_active) begin
    if(emerg_counter<EMERG_TIME-1)begin
      emerg_counter<=emerg_counter+1;
    end
    else begin
      emerg_active<=0;
      T1state<=last_T1state;
      if(emerg_type)T2state<=last_T2state;
    end
  end
end
//now for traffic1 route
always@(posedge clk)begin
  if(emerg_active &&(emerg_type||emergency_left)) begin
    T1state<=RED;
    T1counter<=0;
  end
  else begin
    case (T1state)
    GREEN: begin
      if(T1counter>=G_TIME-1) begin
        T1state<=YELLOW;
        T1counter<=0;
      end
      else T1counter<=T1counter+1;
    end
    YELLOW: begin
       if (T1counter>=Y_TIME - 1) begin
            T1state<=RED;
            T1counter<=0;
       end
       else T1counter<=T1counter+1;
    end
    RED:begin
      if(T1counter>=R_TIME-1) begin
        T1state<=GREEN;
        T1counter<=0;
      end
      else T1counter<=T1counter+1;
    end
    endcase
end
end 
// traffic route2 case
always@(posedge clk)begin
    if(emerg_active && emerg_type)begin
        T2state<=RED;
        T2counter<=0;
    end
    else begin
        case(T2state)
            GREEN:begin
                if(T2counter>=G_TIME-1)begin
                    T2state<=YELLOW;
                    T2counter <= 0;
                end
                else T2counter<=T2counter+1;
            end
            YELLOW:begin
                if(T2counter>=Y_TIME - 1)begin
                    T2state <= RED;
                    T2counter<=0;
                end
                else T2counter<=T2counter + 1;
            end
            RED: begin
                if (T2counter >= R_TIME - 1) begin
                    T2state <= GREEN;
                    T2counter <= 0;
                end
                else T2counter<=T2counter + 1;
            end
        endcase
    end
end
//for walking, it shoukd be high only last 5 sec of red signal
always @(*) begin
    T1_WALK = (T1state==RED) && (T1counter>=R_TIME-5) && !emerg_active;
    T2_WALK = (T2state==RED) && (T2counter>=R_TIME-5) && !emerg_active;
end
// Buzzer (for last 5s of RED)
always @(*) begin
    if (T1state == RED && T1counter >= R_TIME - BUZZ_TIME)
        buzzer_walk = 1;
    else if (T2state == RED && T2counter >= R_TIME - BUZZ_TIME)
        buzzer_walk = 1;
    else
        buzzer_walk = 0;
end
endmodule
