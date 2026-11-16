// output_registers.v - Holds the status byte and result block for the reply.
// capture_result : core finished -> status 00, result = core output.
// capture_error  : invalid command -> status 01, result = all zero.
// Values stay put while the 19-byte UART reply is being sent, and the last
// result stays visible (7-segment display) until the next request finishes.
module output_registers (
    input  wire         clk,
    input  wire         reset,
    input  wire         capture_result,
    input  wire         capture_error,
    input  wire [127:0] core_result,
    output reg  [7:0]   status,
    output reg  [127:0] result
);
    localparam [7:0] STATUS_OK          = 8'h00;
    localparam [7:0] STATUS_BAD_COMMAND = 8'h01;

    always @(posedge clk) begin
        if (reset) begin
            status <= STATUS_OK;
            result <= 128'h0;
        end else if (capture_result) begin
            status <= STATUS_OK;
            result <= core_result;
        end else if (capture_error) begin
            status <= STATUS_BAD_COMMAND;
            result <= 128'h0;
        end
    end
endmodule
