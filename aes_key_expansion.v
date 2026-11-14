// aes_key_expansion.v - Combinational AES-128 key expansion (shared with Member 2).
// Words w[0..43]; w[0] = key[127:96] (bytes 0..3, byte 0 in MSB).
// K[r] = {w[4r], w[4r+1], w[4r+2], w[4r+3]} placed at round_keys[128*r +: 128].
// Dependencies: aes_sbox.v
module aes_key_expansion (
    input  wire [127:0]  key,
    output wire [1407:0] round_keys
);
    wire [31:0] w [0:43];

    // Rcon for round 1..10 (only the MSB byte is nonzero)
    function [7:0] rcon;
        input integer rnd;
        begin
            case (rnd)
                1:  rcon = 8'h01;
                2:  rcon = 8'h02;
                3:  rcon = 8'h04;
                4:  rcon = 8'h08;
                5:  rcon = 8'h10;
                6:  rcon = 8'h20;
                7:  rcon = 8'h40;
                8:  rcon = 8'h80;
                9:  rcon = 8'h1B;
                10: rcon = 8'h36;
                default: rcon = 8'h00;
            endcase
        end
    endfunction

    assign w[0] = key[127:96];
    assign w[1] = key[95:64];
    assign w[2] = key[63:32];
    assign w[3] = key[31:0];

    genvar r;
    generate
        for (r = 1; r <= 10; r = r + 1) begin : g_round
            wire [31:0] rot_word = {w[4*r-1][23:0], w[4*r-1][31:24]};  // RotWord
            wire [31:0] sub_word;                                       // SubWord

            aes_sbox u_sb0 (.data_in(rot_word[31:24]), .data_out(sub_word[31:24]));
            aes_sbox u_sb1 (.data_in(rot_word[23:16]), .data_out(sub_word[23:16]));
            aes_sbox u_sb2 (.data_in(rot_word[15:8]),  .data_out(sub_word[15:8]));
            aes_sbox u_sb3 (.data_in(rot_word[7:0]),   .data_out(sub_word[7:0]));

            assign w[4*r]   = w[4*r-4] ^ (sub_word ^ {rcon(r), 24'h000000});
            assign w[4*r+1] = w[4*r-3] ^ w[4*r];
            assign w[4*r+2] = w[4*r-2] ^ w[4*r+1];
            assign w[4*r+3] = w[4*r-1] ^ w[4*r+2];

            assign round_keys[128*r +: 128] = {w[4*r], w[4*r+1], w[4*r+2], w[4*r+3]};
        end
    endgenerate

    assign round_keys[127:0] = key;  // K0
endmodule
