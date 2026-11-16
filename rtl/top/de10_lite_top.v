// de10_lite_top.v - Board wrapper for Terasic DE10-Lite (MAX 10, 50 MHz clock).
// The DE10-Lite has no USB-UART chip, so use a 3.3 V USB-to-serial adapter:
//   adapter TX -> GPIO[0] (FPGA receives)    adapter RX -> GPIO[1] (FPGA sends)
//   adapter GND -> any GPIO header GND pin.  NEVER use a 5 V adapter.
// KEY[0] (push button, active low) = reset. Press it after a partial request.
// LEDR[0] = busy, LEDR[1] = invalid command, LEDR[2] = result ready,
// LEDR[9] = heartbeat blink.
// HEX5..HEX0 = first 3 bytes of the last result (blank until one is ready).
// Pin numbers are in quartus/aes128.qsf; see docs/pin_connections.md.
module de10_lite_top (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    output wire [9:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire [7:0] HEX3,
    output wire [7:0] HEX4,
    output wire [7:0] HEX5,
    input  wire       UART_RXD,   // GPIO[0]
    output wire       UART_TXD    // GPIO[1]
);
    // Synchronise the reset button; registers power up as 0, so the design
    // is held in reset until the (released, high) button value arrives.
    reg [1:0] key0_sync = 2'b00;
    always @(posedge MAX10_CLK1_50)
        key0_sync <= {key0_sync[0], KEY[0]};
    wire reset = ~key0_sync[1];

    wire        busy_led, error_led, done_led, heartbeat_led;
    wire [23:0] display_value;
    wire        display_blank;

    aes_top #(
        .CLK_FREQ_HZ(50000000),
        .BAUD_RATE(115200)
    ) u_aes_top (
        .clk(MAX10_CLK1_50),
        .reset(reset),
        .uart_rx_pin(UART_RXD),
        .uart_tx_pin(UART_TXD),
        .busy_led(busy_led),
        .error_led(error_led),
        .done_led(done_led),
        .heartbeat_led(heartbeat_led),
        .display_value(display_value),
        .display_blank(display_blank)
    );

    seven_segment_display u_display (
        .value(display_value), .blank(display_blank),
        .hex0(HEX0), .hex1(HEX1), .hex2(HEX2),
        .hex3(HEX3), .hex4(HEX4), .hex5(HEX5)
    );

    assign LEDR[0]   = busy_led;
    assign LEDR[1]   = error_led;
    assign LEDR[2]   = done_led;
    assign LEDR[8:3] = 6'b0;
    assign LEDR[9]   = heartbeat_led;
endmodule
