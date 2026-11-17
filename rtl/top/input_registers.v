// input_registers.v - Holds one request steady while the AES core works.
// load   : capture command/key/data from the UART parser (one clk pulse).
// expand : capture the 11 round keys produced from the stored key.
// The parser outputs must never drive the cores directly; these registers
// keep key, data and round keys stable from start until done.
module input_registers (
    input  wire          clk,
    input  wire          reset,
    input  wire          load,
    input  wire [7:0]    command_in,
    input  wire [127:0]  key_in,
    input  wire [127:0]  data_in,
    input  wire          expand,
    input  wire [1407:0] round_keys_in,
    output reg  [7:0]    command,
    output reg  [127:0]  key,
    output reg  [127:0]  data,
    output reg  [1407:0] round_keys
);
    always @(posedge clk) begin
        if (reset) begin
            command    <= 8'h00;
            key        <= 128'h0;
            data       <= 128'h0;
            round_keys <= 1408'h0;
        end else begin
            if (load) begin
                command <= command_in;
                key     <= key_in;
                data    <= data_in;
            end
            if (expand)
                round_keys <= round_keys_in;
        end
    end
endmodule
