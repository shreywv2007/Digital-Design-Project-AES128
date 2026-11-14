// shift_rows.v - AES ShiftRows on column-major state (byte index = 4*col + row).
// Row r is rotated left by r columns: out(r,c) = in(r,(c+r) mod 4).
// Dependencies: none
module shift_rows (
    input  wire [127:0] data_in,
    output wire [127:0] data_out
);
    genvar c, r;
    generate
        for (c = 0; c < 4; c = c + 1) begin : g_col
            for (r = 0; r < 4; r = r + 1) begin : g_row
                // destination byte index 4*c+r <- source byte index 4*((c+r)%4)+r
                assign data_out[127-8*(4*c+r) -: 8] =
                       data_in[127-8*(4*((c+r)%4)+r) -: 8];
            end
        end
    endgenerate
endmodule
