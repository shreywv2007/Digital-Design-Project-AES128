// de10_lite_top.v - Board wrapper for Terasic DE10-Lite (MAX 10, 50 MHz clock).
// The DE10-Lite has no USB-UART chip, so use a 3.3 V USB-to-serial adapter:
//   adapter TX -> GPIO[0] (FPGA receives)    adapter RX -> GPIO[1] (FPGA sends)
//   adapter GND -> any GPIO header GND pin.  NEVER use a 5 V adapter.
// KEY[0] (push button, active low) = reset. Press it after a partial request.
// LEDR[0] = busy, LEDR[1] = last request had an invalid command.
// LEDR[9] blinks about once a second to show the design is running.
// Pin numbers are in constraints/de10_lite_pins.tcl.
module de10_lite_top (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    output wire [9:0] LEDR,
    input  wire       UART_RXD,   // GPIO[0]
    output wire       UART_TXD    // GPIO[1]
);
    // Synchronise the reset button; registers power up as 0, so the design
    // is held in reset until the (released, high) button value arrives.
    reg [1:0] key0_sync = 2'b00;
    always @(posedge MAX10_CLK1_50)
        key0_sync <= {key0_sync[0], KEY[0]};
    wire reset = ~key0_sync[1];

    reg [25:0] heartbeat = 26'd0;
    always @(posedge MAX10_CLK1_50)
        heartbeat <= heartbeat + 26'd1;

    wire busy_led, error_led;

    aes_top #(
        .CLK_FREQ_HZ(50000000),
        .BAUD_RATE(115200)
    ) u_aes_top (
        .clk(MAX10_CLK1_50),
        .reset(reset),
        .uart_rx_pin(UART_RXD),
        .uart_tx_pin(UART_TXD),
        .busy_led(busy_led),
        .error_led(error_led)
    );

    assign LEDR[0]   = busy_led;
    assign LEDR[1]   = error_led;
    assign LEDR[8:2] = 7'b0;
    assign LEDR[9]   = heartbeat[25];
endmodule
