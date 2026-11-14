// sub_bytes.v - Applies the AES S-box to all 16 bytes of the state.
// Byte i = data[127-8*i -: 8]; no reordering is performed.
// Dependencies: aes_sbox.v
module sub_bytes (
    input  wire [127:0] data_in,
    output wire [127:0] data_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : g_sbox
            aes_sbox u_sbox (
                .data_in  (data_in[127-8*i -: 8]),
                .data_out (data_out[127-8*i -: 8])
            );
        end
    endgenerate
endmodule
