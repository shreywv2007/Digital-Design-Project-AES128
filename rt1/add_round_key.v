// add_round_key.v - AES AddRoundKey: bitwise XOR of state with one 128-bit round key.
// Dependencies: none
module add_round_key (
    input  wire [127:0] data_in,
    input  wire [127:0] round_key,
    output wire [127:0] data_out
);
    assign data_out = data_in ^ round_key;
endmodule
