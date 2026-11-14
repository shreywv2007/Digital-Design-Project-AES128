// mix_columns.v - AES MixColumns over GF(2^8), polynomial x^8+x^4+x^3+x+1.
// Column c holds bytes 4c..4c+3 (top byte = row 0), i.e. data[127-32*c -: 32].
// Dependencies: none
module mix_columns (
    input  wire [127:0] data_in,
    output wire [127:0] data_out
);
    // Multiply by 2 in GF(2^8)
    function [7:0] xtime;
        input [7:0] b;
        begin
            xtime = {b[6:0], 1'b0} ^ (b[7] ? 8'h1B : 8'h00);
        end
    endfunction

    genvar c;
    generate
        for (c = 0; c < 4; c = c + 1) begin : g_col
            wire [7:0] a0 = data_in[127-32*c -: 8];
            wire [7:0] a1 = data_in[119-32*c -: 8];
            wire [7:0] a2 = data_in[111-32*c -: 8];
            wire [7:0] a3 = data_in[103-32*c -: 8];

            // 3*a = xtime(a) ^ a
            assign data_out[127-32*c -: 8] = xtime(a0) ^ (xtime(a1) ^ a1) ^ a2 ^ a3;
            assign data_out[119-32*c -: 8] = a0 ^ xtime(a1) ^ (xtime(a2) ^ a2) ^ a3;
            assign data_out[111-32*c -: 8] = a0 ^ a1 ^ xtime(a2) ^ (xtime(a3) ^ a3);
            assign data_out[103-32*c -: 8] = (xtime(a0) ^ a0) ^ a1 ^ a2 ^ xtime(a3);
        end
    endgenerate
endmodule
