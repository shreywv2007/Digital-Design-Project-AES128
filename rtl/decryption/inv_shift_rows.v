// AES InvShiftRows: rotates row 0 by 0, row 1 right 1,
// row 2 right 2, row 3 right 3 byte positions.
// Bytes are indexed in AES COLUMN-major order. Byte 0 is [127:120].
// All assignments are combinational; no clock is needed.
module inv_shift_rows(input wire [127:0] state_in, output wire [127:0] state_out);
    assign state_out[127-8*0 -: 8] = state_in[127-8*0 -: 8];
    assign state_out[127-8*1 -: 8] = state_in[127-8*13 -: 8];
    assign state_out[127-8*2 -: 8] = state_in[127-8*10 -: 8];
    assign state_out[127-8*3 -: 8] = state_in[127-8*7 -: 8];
    assign state_out[127-8*4 -: 8] = state_in[127-8*4 -: 8];
    assign state_out[127-8*5 -: 8] = state_in[127-8*1 -: 8];
    assign state_out[127-8*6 -: 8] = state_in[127-8*14 -: 8];
    assign state_out[127-8*7 -: 8] = state_in[127-8*11 -: 8];
    assign state_out[127-8*8 -: 8] = state_in[127-8*8 -: 8];
    assign state_out[127-8*9 -: 8] = state_in[127-8*5 -: 8];
    assign state_out[127-8*10 -: 8] = state_in[127-8*2 -: 8];
    assign state_out[127-8*11 -: 8] = state_in[127-8*15 -: 8];
    assign state_out[127-8*12 -: 8] = state_in[127-8*12 -: 8];
    assign state_out[127-8*13 -: 8] = state_in[127-8*9 -: 8];
    assign state_out[127-8*14 -: 8] = state_in[127-8*6 -: 8];
    assign state_out[127-8*15 -: 8] = state_in[127-8*3 -: 8];
endmodule
