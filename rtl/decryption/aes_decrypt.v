// AES-128 decryption datapath + controller; Verilog-2001.
// NOTE: Member 1 owns AES key expansion. This module consumes its round keys.
// Pack keys as: round_keys[127:0] = K0, [255:128] = K1, ...
//               round_keys[1407:1280] = K10.
// Keep round_keys stable from start until done.
// Ciphertext is captured on the accepted start pulse.
// Data byte 0 is in [127:120] (AES column-major state order).
module aes_decrypt (
    input  wire          clk,
    input  wire          rst,       // synchronous active-high
    input  wire          start,     // 1-cycle pulse while idle
    input  wire [127:0]  ciphertext,
    input  wire [1407:0] round_keys,
    output reg  [127:0]  plaintext,
    output wire          busy,
    output wire          done
);
    wire step;
    wire [3:0] round_index;

    reg  [127:0] ciphertext_reg;
    reg  [127:0] state_reg;
    reg  [127:0] round_key;

    wire [127:0] shifted;
    wire [127:0] substituted;
    wire [127:0] xor_input;
    wire [127:0] added;
    wire [127:0] mixed;
    wire [127:0] next_state;

    aes_decrypt_controller u_controller (
        .clk(clk), .rst(rst), .start(start),
        .busy(busy), .done(done),
        .step(step), .round_index(round_index)
    );

    // This selector walks backward through the AES-128 round keys.
    // Explicit case statement keeps the byte/round ordering easy to audit.
    always @* begin
        case (round_index)
            4'd0:  round_key = round_keys[1407:1280]; // K10
            4'd1:  round_key = round_keys[1279:1152]; // K9
            4'd2:  round_key = round_keys[1151:1024]; // K8
            4'd3:  round_key = round_keys[1023:896];  // K7
            4'd4:  round_key = round_keys[895:768];   // K6
            4'd5:  round_key = round_keys[767:640];   // K5
            4'd6:  round_key = round_keys[639:512];   // K4
            4'd7:  round_key = round_keys[511:384];   // K3
            4'd8:  round_key = round_keys[383:256];   // K2
            4'd9:  round_key = round_keys[255:128];   // K1
            4'd10: round_key = round_keys[127:0];     // K0
            default: round_key = 128'b0;
        endcase
    end

    inv_shift_rows u_shift (
        .state_in(state_reg), .state_out(shifted)
    );
    inv_sub_bytes u_sub (
        .state_in(shifted), .state_out(substituted)
    );

    // Initial step only: ciphertext XOR K10, without inverse substitutions.
    assign xor_input = (round_index == 4'd0) ? ciphertext_reg : substituted;

    inv_add_round_key u_add (
        .state_in(xor_input), .round_key(round_key), .state_out(added)
    );
    inv_mix_columns u_mix (
        .state_in(added), .state_out(mixed)
    );

    // Skip InvMixColumns at step 0 and the final step (round key K0).
    assign next_state = ((round_index == 4'd0) || (round_index == 4'd10))
                        ? added : mixed;

    always @(posedge clk) begin
        if (rst) begin
            ciphertext_reg <= 128'b0;
            state_reg      <= 128'b0;
            plaintext      <= 128'b0;
        end else begin
            // Busy is low precisely when the controller is in IDLE.
            if (start && !busy)
                ciphertext_reg <= ciphertext;
            if (step) begin
                state_reg <= next_state;
                if (round_index == 4'd10)
                    plaintext <= next_state;
            end
        end
    end
endmodule
