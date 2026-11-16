// AES inverse-round controller: sequentially schedules 11 steps.
// Step 0: initial XOR with K10.
// Steps 1..9: InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns.
// Step 10: final InvShiftRows -> InvSubBytes -> AddRoundKey K0.
// The start input must be a one-clock pulse when busy=0.
// done is high for one full clock cycle after the final step.
module aes_decrypt_controller (
    input  wire       clk,
    input  wire       rst,     // Synchronous active-high reset
    input  wire       start,
    output wire       busy,
    output reg        done,
    output wire       step,
    output wire [3:0] round_index
);
    localparam IDLE = 1'b0;
    localparam RUN  = 1'b1;

    reg state;
    reg [3:0] step_count;

    assign busy        = (state == RUN);
    assign step        = (state == RUN);
    assign round_index = step_count;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            step_count <= 4'd0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        step_count <= 4'd0;
                        state      <= RUN;
                    end
                end
                RUN: begin
                    if (step_count == 4'd10) begin
                        state <= IDLE;
                        done  <= 1'b1;
                    end else begin
                        step_count <= step_count + 4'd1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
