// Synchronized 8-N-1 receiver. UART bits arrive LSB first within each byte.
// Valid pulses only after a low start bit and a high stop bit are sampled.
// False starts and framing errors are discarded; a break waits for idle high.
// Dependencies: baud_generator. Override the placeholder CLK_FREQ_HZ.
// CLK_FREQ_HZ must be >= 2*BAUD_RATE; a much faster system clock is expected.
module uart_rx #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       rx_serial,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_START = 3'd1;
    localparam [2:0] STATE_DATA = 3'd2;
    localparam [2:0] STATE_STOP = 3'd3;
    localparam [2:0] STATE_WAIT_HIGH = 3'd4;

    reg rx_meta;
    reg rx_sync;
    reg [2:0] state_reg;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;
    reg half_phase;
    wire timer_enable;
    wire half_bit_tick;

    assign timer_enable = (state_reg == STATE_START) ||
                          (state_reg == STATE_DATA) ||
                          (state_reg == STATE_STOP);

    baud_generator #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(2 * BAUD_RATE)
    ) u_baud_generator (
        .clk(clk), .reset(reset), .enable(timer_enable),
        .tick(half_bit_tick)
    );

    always @(posedge clk) begin
        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_serial;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state_reg <= STATE_IDLE;
            bit_index <= 3'd0;
            shift_reg <= 8'h00;
            half_phase <= 1'b0;
            rx_data <= 8'h00;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (state_reg)
                STATE_IDLE: begin
                    bit_index <= 3'd0;
                    half_phase <= 1'b0;
                    if (!rx_sync)
                        state_reg <= STATE_START;
                end
                STATE_START: begin
                    if (half_bit_tick) begin
                        if (!rx_sync) begin
                            half_phase <= 1'b0;
                            state_reg <= STATE_DATA;
                        end else begin
                            state_reg <= STATE_IDLE;
                        end
                    end
                end
                STATE_DATA: begin
                    if (half_bit_tick) begin
                        half_phase <= !half_phase;
                        if (half_phase) begin
                            shift_reg[bit_index] <= rx_sync;
                            if (bit_index == 3'd7)
                                state_reg <= STATE_STOP;
                            else
                                bit_index <= bit_index + 3'd1;
                        end
                    end
                end
                STATE_STOP: begin
                    if (half_bit_tick) begin
                        half_phase <= !half_phase;
                        if (half_phase) begin
                            if (rx_sync) begin
                                rx_data <= shift_reg;
                                rx_valid <= 1'b1;
                                state_reg <= STATE_IDLE;
                            end else begin
                                state_reg <= STATE_WAIT_HIGH;
                            end
                        end
                    end
                end
                STATE_WAIT_HIGH: begin
                    if (rx_sync)
                        state_reg <= STATE_IDLE;
                end
                default: state_reg <= STATE_IDLE;
            endcase
        end
    end
endmodule
