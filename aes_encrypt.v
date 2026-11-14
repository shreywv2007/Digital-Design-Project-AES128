// aes_encrypt.v - Iterative AES-128 encryption core (one round per clock).
// Timing: start accepted in IDLE (busy=0): state <= data_in ^ K0 (1 cycle),
//         then rounds 1..10 (10 cycles), then done pulses for 1 cycle.
// round_keys must stay stable while busy=1. K[r] = round_keys[128*r +: 128].
// Dependencies: sub_bytes.v, shift_rows.v, mix_columns.v, add_round_key.v, aes_sbox.v
module aes_encrypt (
    input  wire          clk,
    input  wire          reset,
    input  wire          start,
    input  wire [127:0]  data_in,
    input  wire [1407:0] round_keys,
    output reg  [127:0]  data_out,
    output reg           busy,
    output reg           done
);
    reg [127:0] state_reg;
    reg [3:0]   round_counter;   // current round to execute: 1..10

    wire [127:0] sb_out;
    wire [127:0] sr_out;
    wire [127:0] mc_out;
    wire [127:0] mc_sel;
    wire [127:0] round_key_cur;
    wire [127:0] ark_out;
    wire [127:0] key0;

    assign key0          = round_keys[127:0];
    assign round_key_cur = round_keys[{round_counter, 7'b0000000} +: 128];
    // Final round (10) skips MixColumns
    assign mc_sel        = (round_counter == 4'd10) ? sr_out : mc_out;

    sub_bytes      u_sub_bytes   (.data_in(state_reg), .data_out(sb_out));
    shift_rows     u_shift_rows  (.data_in(sb_out),    .data_out(sr_out));
    mix_columns    u_mix_columns (.data_in(sr_out),    .data_out(mc_out));
    add_round_key  u_add_rk      (.data_in(mc_sel), .round_key(round_key_cur), .data_out(ark_out));

    always @(posedge clk) begin
        if (reset) begin
            state_reg     <= 128'h0;
            round_counter <= 4'd0;
            data_out      <= 128'h0;
            busy          <= 1'b0;
            done          <= 1'b0;
        end else begin
            done <= 1'b0;  // default: one-cycle pulse
            if (!busy) begin
                if (start) begin
                    state_reg     <= data_in ^ key0;  // initial AddRoundKey
                    round_counter <= 4'd1;
                    busy          <= 1'b1;
                end
            end else begin
                state_reg <= ark_out;
                if (round_counter == 4'd10) begin
                    data_out      <= ark_out;
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    round_counter <= 4'd0;
                end else begin
                    round_counter <= round_counter + 4'd1;
                end
            end
        end
    end
endmodule
