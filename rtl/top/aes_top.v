// aes_top.v - Member 4 system integration: UART <-> controller <-> AES cores.
//
// Request  (35 bytes): A5 5A CMD KEY[16] DATA[16]   CMD 01=encrypt, 02=decrypt
// Response (19 bytes): 5A A5 STATUS RESULT[16]
//   STATUS 00 = success, 01 = invalid command (result is all zero).
//
// Controller flow (one request at a time, no queue):
//   IDLE    : wait for packet_valid (capture cmd/key/data) or packet_error.
//   EXPAND  : register the 11 round keys from the shared key expansion so
//             they stay stable while the core is busy (both cores need this).
//   START   : one-clock start pulse to the selected core.
//   RUN     : wait for that core's done pulse, capture its output.
//   RESPOND : pulse response_start once the sender is idle.
//   WAIT_TX : wait for response_done (all 19 bytes sent), then back to IDLE.
// packet_valid / packet_error arriving outside IDLE are ignored (the host
// protocol allows only one outstanding request).
//
// reset is synchronous and active high. Byte 0 of every block is [127:120].
module aes_top #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE   = 115200
)(
    input  wire clk,
    input  wire reset,
    input  wire uart_rx_pin,
    output wire uart_tx_pin,
    output wire busy_led,     // high while a request is being processed
    output reg  error_led     // set by an invalid command, cleared by next valid one
);
    localparam [7:0] CMD_ENCRYPT = 8'h01;
    localparam [7:0] CMD_DECRYPT = 8'h02;
    localparam [7:0] STATUS_OK          = 8'h00;
    localparam [7:0] STATUS_BAD_COMMAND = 8'h01;

    localparam [2:0] S_IDLE    = 3'd0;
    localparam [2:0] S_EXPAND  = 3'd1;
    localparam [2:0] S_START   = 3'd2;
    localparam [2:0] S_RUN     = 3'd3;
    localparam [2:0] S_RESPOND = 3'd4;
    localparam [2:0] S_WAIT_TX = 3'd5;

    // ---------------- UART side ----------------
    wire [7:0]   rx_command;
    wire [127:0] rx_key;
    wire [127:0] rx_data;
    wire         packet_valid;
    wire         packet_error;
    wire         response_start;
    wire         response_busy;
    wire         response_done;

    reg  [2:0]   state;
    reg  [7:0]   cmd_reg;
    reg  [127:0] key_reg;
    reg  [127:0] data_reg;
    reg  [1407:0] round_keys_reg;
    reg  [7:0]   status_reg;
    reg  [127:0] result_reg;

    uart_interface #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)
    ) u_uart (
        .clk(clk), .reset(reset),
        .uart_rx_pin(uart_rx_pin), .uart_tx_pin(uart_tx_pin),
        .command(rx_command), .key(rx_key), .data(rx_data),
        .packet_valid(packet_valid), .packet_error(packet_error),
        .status(status_reg), .result(result_reg),
        .response_start(response_start),
        .response_busy(response_busy), .response_done(response_done)
    );

    // ---------------- AES side ----------------
    wire [1407:0] round_keys_comb;
    wire [127:0]  enc_out, dec_out;
    wire          enc_busy, enc_done, dec_busy, dec_done;
    wire          is_encrypt = (cmd_reg == CMD_ENCRYPT);

    aes_key_expansion u_key_expansion (
        .key(key_reg), .round_keys(round_keys_comb)
    );

    aes_encrypt u_encrypt (
        .clk(clk), .reset(reset),
        .start((state == S_START) && is_encrypt),
        .data_in(data_reg), .round_keys(round_keys_reg),
        .data_out(enc_out), .busy(enc_busy), .done(enc_done)
    );

    aes_decrypt u_decrypt (
        .clk(clk), .rst(reset),
        .start((state == S_START) && !is_encrypt),
        .ciphertext(data_reg), .round_keys(round_keys_reg),
        .plaintext(dec_out), .busy(dec_busy), .done(dec_done)
    );

    assign response_start = (state == S_RESPOND) && !response_busy;
    assign busy_led       = (state != S_IDLE);

    // ---------------- Controller ----------------
    always @(posedge clk) begin
        if (reset) begin
            state          <= S_IDLE;
            cmd_reg        <= 8'h00;
            key_reg        <= 128'h0;
            data_reg       <= 128'h0;
            round_keys_reg <= 1408'h0;
            status_reg     <= STATUS_OK;
            result_reg     <= 128'h0;
            error_led      <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (packet_valid) begin
                        cmd_reg   <= rx_command;
                        key_reg   <= rx_key;
                        data_reg  <= rx_data;
                        error_led <= 1'b0;
                        state     <= S_EXPAND;
                    end else if (packet_error) begin
                        status_reg <= STATUS_BAD_COMMAND;
                        result_reg <= 128'h0;
                        error_led  <= 1'b1;
                        state      <= S_RESPOND;
                    end
                end
                S_EXPAND: begin
                    round_keys_reg <= round_keys_comb;
                    state          <= S_START;
                end
                S_START: begin
                    state <= S_RUN;   // start pulse is driven combinationally above
                end
                S_RUN: begin
                    if (is_encrypt && enc_done) begin
                        result_reg <= enc_out;
                        status_reg <= STATUS_OK;
                        state      <= S_RESPOND;
                    end else if (!is_encrypt && dec_done) begin
                        result_reg <= dec_out;
                        status_reg <= STATUS_OK;
                        state      <= S_RESPOND;
                    end
                end
                S_RESPOND: begin
                    if (!response_busy)
                        state <= S_WAIT_TX;
                end
                S_WAIT_TX: begin
                    if (response_done)
                        state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
