// Simple reaction game for FPGA or simulator
// Implements a reaction timer with 3 indicator LEDs and 4 time LEDs.
// One of three LEDs lights up randomly. The player must press the button
// as fast as possible when the LED lights. Reaction time is shown in
// binary on four LEDs. Early button press causes an error flash.

module reaction_game #(
    parameter CLK_FREQ = 50_000_000   // input clock frequency in Hz
) (
    input  wire clk,     // system clock
    input  wire reset,   // active high synchronous reset
    input  wire button,  // player button
    output reg  [2:0] led_select, // one of three LEDs
    output reg  [3:0] time_leds   // reaction time display
);

    // generate 10 ms tick for timers
    localparam integer TICK_CYCLES = CLK_FREQ / 100; // 10ms
    reg [31:0] tick_cnt = 0;
    reg tick = 0;
    always @(posedge clk) begin
        if (reset) begin
            tick_cnt <= 0;
            tick <= 0;
        end else if (tick_cnt == TICK_CYCLES-1) begin
            tick_cnt <= 0;
            tick <= 1;
        end else begin
            tick_cnt <= tick_cnt + 1;
            tick <= 0;
        end
    end

    // simple 8-bit LFSR for pseudo random numbers
    reg [7:0] lfsr = 8'h1;
    wire lfsr_fb = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];
    always @(posedge clk) begin
        if (reset)
            lfsr <= 8'h1;
        else if (tick)
            lfsr <= {lfsr[6:0], lfsr_fb};
    end

    // button edge detection (debounced using tick)
    reg [1:0] btn_sync = 0;
    always @(posedge clk) btn_sync <= {btn_sync[0], button};
    reg btn_prev = 0;
    wire btn_edge;
    always @(posedge clk) begin
        if (reset)
            btn_prev <= 0;
        else if (tick)
            btn_prev <= btn_sync[1];
    end
    assign btn_edge = btn_sync[1] & ~btn_prev;

    // FSM states
    localparam S_IDLE  = 3'd0,
               S_DELAY = 3'd1,
               S_WAIT  = 3'd2,
               S_SHOW  = 3'd3,
               S_ERR   = 3'd4;

    reg [2:0] state = S_IDLE;
    reg [7:0] delay_cnt = 0;    // random delay before LED lights
    reg [3:0] react_cnt = 0;    // reaction time counter
    reg [7:0] show_cnt  = 0;    // show/error duration
    reg flash = 0;              // flashing flag for error

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            led_select <= 3'b000;
            time_leds <= 4'b0000;
            delay_cnt <= 0;
            react_cnt <= 0;
            show_cnt <= 0;
            flash <= 0;
        end else if (tick) begin
            case (state)
                S_IDLE: begin
                    led_select <= 3'b000;
                    time_leds <= 4'b0000;
                    delay_cnt <= lfsr;          // 0..255 * 10ms
                    if (btn_edge) begin
                        state <= S_ERR;         // early press
                        show_cnt <= 50;         // ~0.5s
                    end else begin
                        state <= S_DELAY;
                    end
                end
                S_DELAY: begin
                    if (btn_edge) begin
                        state <= S_ERR;         // early press
                        show_cnt <= 50;
                    end else if (delay_cnt == 0) begin
                        case (lfsr[1:0])
                            2'b00: led_select <= 3'b001;
                            2'b01: led_select <= 3'b010;
                            default: led_select <= 3'b100;
                        endcase
                        react_cnt <= 0;
                        state <= S_WAIT;
                    end else begin
                        delay_cnt <= delay_cnt - 1;
                    end
                end
                S_WAIT: begin
                    if (btn_edge) begin
                        time_leds <= react_cnt;
                        show_cnt <= 100;        // show for 1s
                        state <= S_SHOW;
                    end else begin
                        if (react_cnt != 4'hF)
                            react_cnt <= react_cnt + 1;
                    end
                end
                S_SHOW: begin
                    led_select <= 3'b000;
                    if (show_cnt == 0)
                        state <= S_IDLE;
                    else
                        show_cnt <= show_cnt - 1;
                end
                S_ERR: begin
                    flash <= ~flash;
                    led_select <= flash ? 3'b111 : 3'b000;
                    time_leds <= flash ? 4'b1111 : 4'b0000;
                    if (show_cnt == 0)
                        state <= S_IDLE;
                    else
                        show_cnt <= show_cnt - 1;
                end
            endcase
        end
    end

endmodule

