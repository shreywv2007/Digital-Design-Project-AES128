// XOR is its own inverse: (A ^ K) ^ K == A.
// This file is optional if you reuse Member 1's add_round_key module.
// AddRoundKey is its own inverse: XOR with the selected round key.
module inv_add_round_key(input wire [127:0] state_in,
                         input wire [127:0] round_key,
                         output wire [127:0] state_out);
    assign state_out = state_in ^ round_key;
endmodule
