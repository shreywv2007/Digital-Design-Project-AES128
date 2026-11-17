// aes_controller.v - Main state machine: one request in, one reply out.
//
//   IDLE    : wait for packet_valid (-> load_inputs) or packet_error
//             (-> capture_error, reply with status 01).
//   EXPAND  : expand_keys = 1, round keys are stored in input_registers.
//   START   : core_start = 1 for exactly one clock.
//   RUN     : wait for core_done, then capture_result.
//   RESPOND : response_start once the UART sender is idle.
//   WAIT_TX : wait for response_done (all 19 bytes sent), back to IDLE.
//
// packet_valid / packet_error outside IDLE are ignored: the host protocol
// allows only one outstanding request. All outputs are decoded from state
// (single-clock pulses), reset is synchronous and active high.
module aes_controller (
    input  wire clk,
    input  wire reset,
    input  wire packet_valid,
    input  wire packet_error,
    input  wire core_done,
    input  wire response_busy,
    input  wire response_done,
    output wire load_inputs,
    output wire expand_keys,
    output wire core_start,
    output wire capture_result,
    output wire capture_error,
    output wire response_start,
    output wire busy
);
    localparam [2:0] S_IDLE    = 3'd0;
    localparam [2:0] S_EXPAND  = 3'd1;
    localparam [2:0] S_START   = 3'd2;
    localparam [2:0] S_RUN     = 3'd3;
    localparam [2:0] S_RESPOND = 3'd4;
    localparam [2:0] S_WAIT_TX = 3'd5;

    reg [2:0] state;

    assign load_inputs    = (state == S_IDLE) && packet_valid;
    assign capture_error  = (state == S_IDLE) && !packet_valid && packet_error;
    assign expand_keys    = (state == S_EXPAND);
    assign core_start     = (state == S_START);
    assign capture_result = (state == S_RUN) && core_done;
    assign response_start = (state == S_RESPOND) && !response_busy;
    assign busy           = (state != S_IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
        end else begin
            case (state)
                S_IDLE:    if (load_inputs)        state <= S_EXPAND;
                           else if (capture_error) state <= S_RESPOND;
                S_EXPAND:                          state <= S_START;
                S_START:                           state <= S_RUN;
                S_RUN:     if (core_done)          state <= S_RESPOND;
                S_RESPOND: if (!response_busy)     state <= S_WAIT_TX;
                S_WAIT_TX: if (response_done)      state <= S_IDLE;
                default:                           state <= S_IDLE;
            endcase
        end
    end
endmodule
