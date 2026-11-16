// mode_selector.v - Routes the request to the encrypt or decrypt core.
// command 01 = encrypt, 02 = decrypt (the parser only passes these two).
// start   : one-clock start pulse from the controller; it goes to one core.
// core_done / core_result : the selected core's done pulse and output block.
module mode_selector (
    input  wire [7:0]   command,
    input  wire         start,
    input  wire [127:0] enc_result,
    input  wire         enc_done,
    input  wire [127:0] dec_result,
    input  wire         dec_done,
    output wire         is_encrypt,
    output wire         enc_start,
    output wire         dec_start,
    output wire         core_done,
    output wire [127:0] core_result
);
    localparam [7:0] CMD_ENCRYPT = 8'h01;

    assign is_encrypt  = (command == CMD_ENCRYPT);
    assign enc_start   = start &&  is_encrypt;
    assign dec_start   = start && !is_encrypt;
    assign core_done   = is_encrypt ? enc_done   : dec_done;
    assign core_result = is_encrypt ? enc_result : dec_result;
endmodule
