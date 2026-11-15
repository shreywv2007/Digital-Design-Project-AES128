// 8-N-1 transmitter: low start, eight LSB-first data bits, high stop.
// Accept tx_start only on a clock edge with tx_busy=0; latch tx_data then.
// tx_busy stays high for the complete stop bit. Requests while busy are ignored.
// Dependencies: baud_generator. Override the placeholder CLK_FREQ_HZ.
module uart_tx #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_serial,
    output reg        tx_busy
);
    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_START = 2'd1;
    localparam [1:0] STATE_DATA = 2'd2;
    localparam [1:0] STATE_STOP = 2'd3;

    reg [1:0] state_reg;
    reg [7:0] data_reg;
    reg [2:0] bit_index;
    wire bit_tick;

    baud_generator #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)
    ) u_baud_generator (
        .clk(clk), .reset(reset), .enable(tx_busy), .tick(bit_tick)
    );

    always @(posedge clk) begin
        if (reset) begin
            state_reg <= STATE_IDLE;
            data_reg <= 8'h00;
            bit_index <= 3'd0;
            tx_serial <= 1'b1;
            tx_busy <= 1'b0;
        end else begin
            case (state_reg)
                STATE_IDLE: begin
                    tx_serial <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        data_reg <= tx_data;
                        bit_index <= 3'd0;
                        tx_serial <= 1'b0;
                        tx_busy <= 1'b1;
                        state_reg <= STATE_START;
                    end
                end
                STATE_START: begin
                    if (bit_tick) begin
                        tx_serial <= data_reg[0];
                        state_reg <= STATE_DATA;
                    end
                end
                STATE_DATA: begin
                    if (bit_tick) begin
                        if (bit_index == 3'd7) begin
                            tx_serial <= 1'b1;
                            state_reg <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                            tx_serial <= data_reg[bit_index + 3'd1];
                        end
                    end
                end
                STATE_STOP: begin
                    if (bit_tick) begin
                        tx_busy <= 1'b0;
                        state_reg <= STATE_IDLE;
                    end
                end
                default: begin
                    state_reg <= STATE_IDLE;
                    tx_serial <= 1'b1;
                    tx_busy <= 1'b0;
                end
            endcase
        end
    end
endmodule
