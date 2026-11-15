// AES-128 InvMixColumns: transforms each 4-byte state column independently.
// All arithmetic takes place in GF(2^8), not ordinary integer arithmetic.
// AES reduction polynomial is x^8 + x^4 + x^3 + x + 1 (0x11B).
module inv_mix_columns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    // Multiply by x and reduce modulo the AES polynomial.
    function [7:0] xtime;
        input [7:0] a;
        begin
            xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
        end
    endfunction

    // AES InvMixColumns requires multiplication only by 09, 0B, 0D, 0E.
    // Each is implemented using shifts (xtime) and XORs.
    function [7:0] gf_mul_const;
        input [7:0] a;
        input [7:0] factor;
        reg [7:0] a2, a4, a8;
        begin
            a2 = xtime(a);
            a4 = xtime(a2);
            a8 = xtime(a4);
            case (factor)
                8'h09: gf_mul_const = a8 ^ a;
                8'h0b: gf_mul_const = a8 ^ a2 ^ a;
                8'h0d: gf_mul_const = a8 ^ a4 ^ a;
                8'h0e: gf_mul_const = a8 ^ a4 ^ a2;
                default: gf_mul_const = 8'h00;
            endcase
        end
    endfunction

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : column
            wire [7:0] a0, a1, a2, a3;
            assign a0 = state_in[127-32*c -: 8];
            assign a1 = state_in[119-32*c -: 8];
            assign a2 = state_in[111-32*c -: 8];
            assign a3 = state_in[103-32*c -: 8];

            assign state_out[127-32*c -: 8] =
                gf_mul_const(a0, 8'h0e) ^ gf_mul_const(a1, 8'h0b) ^
                gf_mul_const(a2, 8'h0d) ^ gf_mul_const(a3, 8'h09);
            assign state_out[119-32*c -: 8] =
                gf_mul_const(a0, 8'h09) ^ gf_mul_const(a1, 8'h0e) ^
                gf_mul_const(a2, 8'h0b) ^ gf_mul_const(a3, 8'h0d);
            assign state_out[111-32*c -: 8] =
                gf_mul_const(a0, 8'h0d) ^ gf_mul_const(a1, 8'h09) ^
                gf_mul_const(a2, 8'h0e) ^ gf_mul_const(a3, 8'h0b);
            assign state_out[103-32*c -: 8] =
                gf_mul_const(a0, 8'h0b) ^ gf_mul_const(a1, 8'h0d) ^
                gf_mul_const(a2, 8'h09) ^ gf_mul_const(a3, 8'h0e);
        end
    endgenerate
endmodule
