// aes_top.v - Member 4 system integration: UART <-> controller <-> AES cores.
//
// Request  (35 bytes): A5 5A CMD KEY[16] DATA[16]   CMD 01=encrypt, 02=decrypt
// Response (19 bytes): 5A A5 STATUS RESULT[16]
//   STATUS 00 = success, 01 = invalid command (result is all zero).
//
// Block diagram:
//   uart_interface (Member 3) --packet--> input_registers --> aes_key_expansion
//          ^                                   |                  |
//          |                                   v                  v
//   output_registers <-- mode_selector <-- aes_encrypt (Member 1) / aes_decrypt (Member 2)
//                aes_controller sequences every step; status_leds shows state.
//
// reset is synchronous and active high. Byte 0 of every block is [127:120].
module aes_top #(
    parameter integer CLK_FREQ_HZ    = 50000000,
    parameter integer BAUD_RATE      = 115200,
    parameter integer HEARTBEAT_BITS = 26
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        uart_rx_pin,
    output wire        uart_tx_pin,
    output wire        busy_led,       // request in progress
    output wire        error_led,      // last request had an invalid command
    output wire        done_led,       // last request finished successfully
    output wire        heartbeat_led,  // blinks while the design runs
    output wire [23:0] display_value,  // first 3 bytes of the last result
    output wire        display_blank   // no successful result to show yet
);
    // ---------------- UART (Member 3) ----------------
    wire [7:0]   rx_command;
    wire [127:0] rx_key, rx_data;
    wire         packet_valid, packet_error;
    wire [7:0]   status;
    wire [127:0] result;
    wire         response_start, response_busy, response_done;

    uart_interface #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)
    ) u_uart (
        .clk(clk), .reset(reset),
        .uart_rx_pin(uart_rx_pin), .uart_tx_pin(uart_tx_pin),
        .command(rx_command), .key(rx_key), .data(rx_data),
        .packet_valid(packet_valid), .packet_error(packet_error),
        .status(status), .result(result),
        .response_start(response_start),
        .response_busy(response_busy), .response_done(response_done)
    );

    // ---------------- Controller ----------------
    wire load_inputs, expand_keys, core_start;
    wire capture_result, capture_error, busy;
    wire core_done;

    aes_controller u_controller (
        .clk(clk), .reset(reset),
        .packet_valid(packet_valid), .packet_error(packet_error),
        .core_done(core_done),
        .response_busy(response_busy), .response_done(response_done),
        .load_inputs(load_inputs), .expand_keys(expand_keys),
        .core_start(core_start),
        .capture_result(capture_result), .capture_error(capture_error),
        .response_start(response_start), .busy(busy)
    );

    // ---------------- Input side ----------------
    wire [7:0]    command;
    wire [127:0]  key, data;
    wire [1407:0] round_keys_comb, round_keys;

    input_registers u_input_registers (
        .clk(clk), .reset(reset),
        .load(load_inputs),
        .command_in(rx_command), .key_in(rx_key), .data_in(rx_data),
        .expand(expand_keys), .round_keys_in(round_keys_comb),
        .command(command), .key(key), .data(data), .round_keys(round_keys)
    );

    aes_key_expansion u_key_expansion (          // Member 1 (shared)
        .key(key), .round_keys(round_keys_comb)
    );

    // ---------------- AES cores ----------------
    wire         enc_start, dec_start, is_encrypt;
    wire [127:0] enc_out, dec_out, core_result;
    wire         enc_busy, enc_done, dec_busy, dec_done;

    mode_selector u_mode_selector (
        .command(command), .start(core_start),
        .enc_result(enc_out), .enc_done(enc_done),
        .dec_result(dec_out), .dec_done(dec_done),
        .is_encrypt(is_encrypt),
        .enc_start(enc_start), .dec_start(dec_start),
        .core_done(core_done), .core_result(core_result)
    );

    aes_encrypt u_encrypt (                       // Member 1
        .clk(clk), .reset(reset), .start(enc_start),
        .data_in(data), .round_keys(round_keys),
        .data_out(enc_out), .busy(enc_busy), .done(enc_done)
    );

    aes_decrypt u_decrypt (                       // Member 2
        .clk(clk), .rst(reset), .start(dec_start),
        .ciphertext(data), .round_keys(round_keys),
        .plaintext(dec_out), .busy(dec_busy), .done(dec_done)
    );

    // ---------------- Output side ----------------
    output_registers u_output_registers (
        .clk(clk), .reset(reset),
        .capture_result(capture_result), .capture_error(capture_error),
        .core_result(core_result),
        .status(status), .result(result)
    );

    status_leds #(.HEARTBEAT_BITS(HEARTBEAT_BITS)) u_status_leds (
        .clk(clk), .reset(reset), .busy(busy),
        .request_start(load_inputs), .request_error(capture_error),
        .result_ready(capture_result),
        .led_busy(busy_led), .led_error(error_led),
        .led_done(done_led), .led_heartbeat(heartbeat_led)
    );

    assign display_value = result[127:104];
    assign display_blank = !done_led;
endmodule
