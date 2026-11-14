// Member 3 UART wrapper. PROPOSED HANDOFF: MEMBER 4 APPROVAL PENDING.
// All controls are active high; reset is synchronous to clk.
// Member 4 connects aes_top's clk/reset/uart_rx_pin/uart_tx_pin directly here
// and forwards its actual CLK_FREQ_HZ and BAUD_RATE parameters (115200 default).
// The specification's 50000000 default is ONLY a placeholder, including for
// the user's DE10-Lite: the actual connected system clock must be confirmed.
//
// To controller/input_registers:
//   command[7:0], key[127:0], data[127:0], packet_valid (one clk).
//   Capture valid fields in IDLE/CAPTURE; never launch AES on packet_error.
//   packet_error (one clk) means invalid command; key/data are zero.
// From controller/output_registers:
//   status[7:0], result[127:0], response_start (one clk, !response_busy).
//   On packet_error while ready, enter ERROR and request status != 0 with
//   result=0. Suggested invalid-command status is 8'h01 (team must agree).
// To controller:
//   response_busy covers all 19 bytes; response_done pulses after final stop.
//   It describes transmission ONLY, not AES processing or system readiness.
//
// No request queue/backpressure: host sends one request and awaits its reply.
// Controller must handle packet_valid/packet_error while ready and retain
// the captured key/data throughout AES. Parser outputs must not drive cores
// directly. Traffic while the controller is busy is outside this contract.
// No autonomous error sender: controller owns every response_start.
// No receive timeout/checksum/framing-error port is added to fixed contracts.
//
// MEMBER 3 + MEMBER 4 DECISIONS BEFORE FINAL HANDOFF:
// 1. Approve the proposed packet_error port and complete wrapper port list.
//    IDLE must handle packet_error as well as packet_valid. Agree the nonzero
//    invalid-command status and pulse response_start once with !response_busy.
// 2. Decide interrupted-packet recovery: current implementation needs a reset
//    after traffic stops. Agree who resets the FPGA and how the host/operator
//    knows it is ready. Any future timeout value/error-abort signal requires
//    explicit agreement; there is no automatic payload-abort mechanism now.
// 3. Agree synchronization after rejected requests: immediate search is the
//    current behavior, including in the rejected frame's remaining payload.
//    Discuss false sync there versus a discard policy swallowing a following
//    request after truncation. No new discard or delimiter rule is assumed.
// 4. Confirm one outstanding request, and the controller's policy for valid
//    or error events while busy; no request queue or ready input exists here.
// 5. Confirm the actual connected CLK_FREQ_HZ, synchronous reset integration,
//    and the logical/physical way to perform recovery on the DE10-Lite.
// Dependencies: uart_rx, uart_tx, uart_packet_parser, uart_packet_sender,
// baud_generator. No dependency on a teammate's AES implementation.
module uart_interface #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire         clk,
    input  wire         reset,
    input  wire         uart_rx_pin,
    output wire         uart_tx_pin,
    output wire [7:0]   command,
    output wire [127:0] key,
    output wire [127:0] data,
    output wire         packet_valid,
    output wire         packet_error,
    input  wire [7:0]   status,
    input  wire [127:0] result,
    input  wire         response_start,
    output wire         response_busy,
    output wire         response_done
);
    wire [7:0] rx_data;
    wire rx_valid;
    wire [7:0] tx_data;
    wire tx_start;
    wire tx_busy;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk(clk), .reset(reset), .rx_serial(uart_rx_pin),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    uart_packet_parser u_uart_packet_parser (
        .clk(clk), .reset(reset), .rx_data(rx_data), .rx_valid(rx_valid),
        .command(command), .key(key), .data(data),
        .packet_valid(packet_valid), .packet_error(packet_error)
    );

    uart_packet_sender u_uart_packet_sender (
        .clk(clk), .reset(reset), .status(status), .result(result),
        .response_start(response_start), .response_busy(response_busy),
        .response_done(response_done), .tx_data(tx_data),
        .tx_start(tx_start), .tx_busy(tx_busy)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk), .reset(reset), .tx_data(tx_data), .tx_start(tx_start),
        .tx_serial(uart_tx_pin), .tx_busy(tx_busy)
    );
endmodule
