// tb_uart.v - Focused test of the Member 3 UART block (uart_interface):
// receiver + packet parser, and packet sender + transmitter, without AES.
// Checks: a valid encrypt and decrypt packet are decoded byte-exactly,
// an unknown command gives packet_error (no packet_valid), junk before the
// sync bytes is skipped, a bad stop bit is ignored, and a response is sent
// as exactly 5A A5 STATUS RESULT[16] (zero result when status != 0).
`timescale 1ns/1ps
module tb_uart;
    localparam integer CLK_FREQ_HZ = 1600000;
    localparam integer BAUD_RATE   = 100000;            // 16 clocks per bit
    localparam integer CLK_NS      = 10;
    localparam integer BIT_NS      = CLK_NS * (CLK_FREQ_HZ / BAUD_RATE);

    reg          clk = 1'b0, reset = 1'b1;
    reg          host_tx = 1'b1;
    wire         dut_tx;
    wire [7:0]   command;
    wire [127:0] key, data;
    wire         packet_valid, packet_error;
    reg  [7:0]   status = 8'h00;
    reg  [127:0] result = 128'h0;
    reg          response_start = 1'b0;
    wire         response_busy, response_done;

    always #(CLK_NS/2) clk = ~clk;

    uart_interface #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .reset(reset), .uart_rx_pin(host_tx), .uart_tx_pin(dut_tx),
        .command(command), .key(key), .data(data),
        .packet_valid(packet_valid), .packet_error(packet_error),
        .status(status), .result(result), .response_start(response_start),
        .response_busy(response_busy), .response_done(response_done)
    );

    integer errors = 0, checks = 0;
    integer valid_count = 0, error_count = 0;
    reg [7:0]   cap_cmd;
    reg [127:0] cap_key, cap_data;

    // Record every parser event
    always @(posedge clk) begin
        if (packet_valid) begin
            valid_count <= valid_count + 1;
            cap_cmd <= command; cap_key <= key; cap_data <= data;
        end
        if (packet_error) begin
            error_count <= error_count + 1;
            cap_cmd <= command;
        end
    end

    task send_byte;
        input [7:0] b;
        input       good_stop;
        integer k;
        begin
            host_tx = 1'b0; #(BIT_NS);
            for (k = 0; k < 8; k = k + 1) begin host_tx = b[k]; #(BIT_NS); end
            host_tx = good_stop; #(BIT_NS);
            host_tx = 1'b1; #(BIT_NS);
        end
    endtask

    task send_packet;
        input [7:0] cmd;
        input [127:0] k, d;
        integer i;
        begin
            send_byte(8'hA5, 1'b1); send_byte(8'h5A, 1'b1); send_byte(cmd, 1'b1);
            for (i = 15; i >= 0; i = i - 1) send_byte(k[8*i +: 8], 1'b1);
            for (i = 15; i >= 0; i = i - 1) send_byte(d[8*i +: 8], 1'b1);
            #(BIT_NS * 4);
        end
    endtask

    task check;
        input [511:0] name;
        input ok;
        begin
            checks = checks + 1;
            if (ok) $display("PASS  %0s", name);
            else begin errors = errors + 1; $display("FAIL  %0s", name); end
        end
    endtask

    // Receive the 19-byte response and compare it
    reg [7:0] resp [0:18];
    task receive_and_check;
        input [511:0] name;
        input [7:0]   exp_status;
        input [127:0] exp_result;
        integer n, k, waited;
        reg ok;
        begin
            for (n = 0; n < 19; n = n + 1) begin
                waited = 0;
                while (dut_tx === 1'b1 && waited < 4000) begin #(BIT_NS/16); waited = waited + 1; end
                #(BIT_NS/2);
                for (k = 0; k < 8; k = k + 1) begin #(BIT_NS); resp[n][k] = dut_tx; end
                #(BIT_NS);
            end
            ok = (resp[0] == 8'h5A) && (resp[1] == 8'hA5) && (resp[2] == exp_status);
            for (n = 0; n < 16; n = n + 1)
                if (resp[3+n] !== exp_result[127-8*n -: 8]) ok = 1'b0;
            check(name, ok);
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        reset = 1'b0;
        #(BIT_NS * 4);

        send_packet(8'h01, 128'h000102030405060708090a0b0c0d0e0f, 128'h00112233445566778899aabbccddeeff);
        check("encrypt packet decoded",
              valid_count == 1 && cap_cmd == 8'h01 &&
              cap_key  == 128'h000102030405060708090a0b0c0d0e0f &&
              cap_data == 128'h00112233445566778899aabbccddeeff);

        send_packet(8'h02, 128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h3925841d02dc09fbdc118597196a0b32);
        check("decrypt packet decoded",
              valid_count == 2 && cap_cmd == 8'h02 &&
              cap_key  == 128'h2b7e151628aed2a6abf7158809cf4f3c &&
              cap_data == 128'h3925841d02dc09fbdc118597196a0b32);

        send_packet(8'h07, 128'h11111111111111111111111111111111, 128'h22222222222222222222222222222222);
        check("unknown command -> packet_error, no packet_valid",
              error_count == 1 && valid_count == 2 && cap_cmd == 8'h07);

        // Junk, then a byte with a bad stop bit, then a real packet
        send_byte(8'h00, 1'b1); send_byte(8'hA5, 1'b1); send_byte(8'h33, 1'b1);
        send_byte(8'hA5, 1'b0);                       // framing error: dropped
        send_packet(8'h01, 128'hffeeddccbbaa99887766554433221100, 128'h0123456789abcdeffedcba9876543210);
        check("junk + framing error skipped, next packet decoded",
              valid_count == 3 && error_count == 1 &&
              cap_key  == 128'hffeeddccbbaa99887766554433221100 &&
              cap_data == 128'h0123456789abcdeffedcba9876543210);

        // Response path: success
        status = 8'h00; result = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        @(negedge clk) response_start = 1'b1;
        @(negedge clk) response_start = 1'b0;
        check("response_busy goes high", response_busy === 1'b1);
        fork
            receive_and_check("success response bytes 5A A5 00 + result", 8'h00, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);
            begin @(posedge response_done); end
        join
        #(BIT_NS);
        check("response_busy low after response_done", response_busy === 1'b0);

        // Response path: error status forces a zero result
        status = 8'h01; result = 128'hdeadbeefdeadbeefdeadbeefdeadbeef;
        @(negedge clk) response_start = 1'b1;
        @(negedge clk) response_start = 1'b0;
        receive_and_check("error response bytes 5A A5 01 + zeros", 8'h01, 128'h0);

        $display("----------------------------------------");
        if (errors == 0) $display("ALL %0d UART CHECKS PASSED", checks);
        else             $display("%0d OF %0d UART CHECKS FAILED", errors, checks);
        $finish;
    end

    initial begin
        #(BIT_NS * 11 * 400);
        $display("FAIL  simulation watchdog expired");
        $finish;
    end
endmodule
