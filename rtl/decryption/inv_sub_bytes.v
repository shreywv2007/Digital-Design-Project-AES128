// Instantiate 16 independent inverse S-boxes, one per state byte.
// The Verilog generate loop is expanded by the synthesis tool.
module inv_sub_bytes(input wire [127:0] state_in, output wire [127:0] state_out);
    genvar i;
    generate for (i = 0; i < 16; i = i + 1) begin : gen_inv_sbox
        aes_inv_sbox u_sbox(.in_byte(state_in[127-8*i -: 8]),
                             .out_byte(state_out[127-8*i -: 8]));
    end endgenerate
endmodule
