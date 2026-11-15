// Integer clock divider shared by the UART receiver and transmitter.
// 50000000 is the specification's placeholder, NOT a board-clock selection.
// Member 4 must override CLK_FREQ_HZ with the frequency of the connected clk.
// enable=0 clears the phase. tick is a one-clk clock enable, never a clock.
// BAUD_RATE must be positive and CLK_FREQ_HZ must be >= BAUD_RATE.
module baud_generator #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire reset,
    input  wire enable,
    output wire tick
);
    function integer counter_width;
        input integer count;
        integer value;
        begin
            value = count - 1;
            counter_width = 0;
            while (value > 0) begin
                counter_width = counter_width + 1;
                value = value >> 1;
            end
            if (counter_width == 0)
                counter_width = 1;
        end
    endfunction

    localparam integer ROUNDED_DIVISOR =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
    localparam integer CLKS_PER_TICK =
        (ROUNDED_DIVISOR < 1) ? 1 : ROUNDED_DIVISOR;
    localparam integer COUNTER_WIDTH = counter_width(CLKS_PER_TICK);
    localparam [COUNTER_WIDTH-1:0] LAST_COUNT = CLKS_PER_TICK - 1;
    reg [COUNTER_WIDTH-1:0] clock_counter;

    assign tick = enable && !reset && (clock_counter == LAST_COUNT);

    always @(posedge clk) begin
        if (reset) begin
            clock_counter <= {COUNTER_WIDTH{1'b0}};
        end else if (!enable || tick) begin
            clock_counter <= {COUNTER_WIDTH{1'b0}};
        end else begin
            clock_counter <= clock_counter + 1'b1;
        end
    end
endmodule
