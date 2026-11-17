// status_leds.v - Drives the board status LEDs (all active high).
// led_busy      : a request is being processed or answered.
// led_error     : set by an invalid command, cleared by the next valid request.
// led_done      : lit after a successful result, cleared by the next request.
// led_heartbeat : toggles every 2^(HEARTBEAT_BITS-1) clocks, ~0.67 s at 50 MHz,
//                 so you can see the design is running.
module status_leds #(
    parameter integer HEARTBEAT_BITS = 26
)(
    input  wire clk,
    input  wire reset,
    input  wire busy,
    input  wire request_start,   // valid request accepted
    input  wire request_error,   // invalid command received
    input  wire result_ready,    // AES result captured
    output wire led_busy,
    output reg  led_error,
    output reg  led_done,
    output wire led_heartbeat
);
    reg [HEARTBEAT_BITS-1:0] heartbeat;

    assign led_busy      = busy;
    assign led_heartbeat = heartbeat[HEARTBEAT_BITS-1];

    always @(posedge clk) begin
        if (reset) begin
            heartbeat <= {HEARTBEAT_BITS{1'b0}};
            led_error <= 1'b0;
            led_done  <= 1'b0;
        end else begin
            heartbeat <= heartbeat + 1'b1;
            if (request_start) begin
                led_error <= 1'b0;
                led_done  <= 1'b0;
            end else if (request_error) begin
                led_error <= 1'b1;
                led_done  <= 1'b0;
            end else if (result_ready) begin
                led_done  <= 1'b1;
            end
        end
    end
endmodule
