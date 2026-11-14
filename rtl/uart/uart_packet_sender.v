// Response: 5A A5 STATUS RESULT[16], exactly 19 raw bytes, MSB byte first.
// Snapshot inputs on response_start && !response_busy. Nonzero status sends
// sixteen zero bytes. No AES core is instantiated here.
// tx_data/tx_start/tx_busy connect directly to uart_tx. Wait for BOTH its
// busy assertion (acceptance) and deassertion (full stop-bit completion).
// response_done pulses after the last complete UART frame, then busy is low.
// Proposed ports are PENDING MEMBER 4 APPROVAL via uart_interface.
module uart_packet_sender (
    input  wire         clk,
    input  wire         reset,
    input  wire [7:0]   status,
    input  wire [127:0] result,
    input  wire         response_start,
    output reg          response_busy,
    output reg          response_done,
    output reg  [7:0]   tx_data,
    output reg          tx_start,
    input  wire         tx_busy
);
    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_ISSUE = 2'd1;
    localparam [1:0] STATE_WAIT_BUSY = 2'd2;
    localparam [1:0] STATE_WAIT_IDLE = 2'd3;

    reg [1:0] state_reg;
    reg [4:0] byte_index;
    reg [7:0] status_reg;
    reg [127:0] result_reg;

    always @(*) begin
        case (byte_index)
            5'd0: tx_data = 8'h5A;
            5'd1: tx_data = 8'hA5;
            5'd2: tx_data = status_reg;
            default: begin
                if ((byte_index >= 5'd3) && (byte_index <= 5'd18))
                    tx_data = result_reg[127 - ((byte_index - 5'd3) * 8) -: 8];
                else
                    tx_data = 8'h00;
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state_reg <= STATE_IDLE;
            byte_index <= 5'd0;
            status_reg <= 8'h00;
            result_reg <= 128'h0;
            response_busy <= 1'b0;
            response_done <= 1'b0;
            tx_start <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            response_done <= 1'b0;
            case (state_reg)
                STATE_IDLE: begin
                    if (response_start) begin
                        status_reg <= status;
                        result_reg <= (status == 8'h00) ? result : 128'h0;
                        byte_index <= 5'd0;
                        response_busy <= 1'b1;
                        state_reg <= STATE_ISSUE;
                    end
                end
                STATE_ISSUE: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        state_reg <= STATE_WAIT_BUSY;
                    end
                end
                STATE_WAIT_BUSY: begin
                    if (tx_busy)
                        state_reg <= STATE_WAIT_IDLE;
                end
                STATE_WAIT_IDLE: begin
                    if (!tx_busy) begin
                        if (byte_index == 5'd18) begin
                            response_busy <= 1'b0;
                            response_done <= 1'b1;
                            state_reg <= STATE_IDLE;
                        end else begin
                            byte_index <= byte_index + 5'd1;
                            state_reg <= STATE_ISSUE;
                        end
                    end
                end
                default: begin
                    state_reg <= STATE_IDLE;
                    response_busy <= 1'b0;
                end
            endcase
        end
    end
endmodule
