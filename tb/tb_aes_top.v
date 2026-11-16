// tb_aes_top.v - End-to-end test of aes_top through the real UART pins.
// The testbench acts like the host PC (host/aes_uart_demo.py): it sends
// 35-byte requests bit by bit on uart_rx_pin and decodes the 19-byte
// response from uart_tx_pin. A slow sim clock/baud keeps the run short;
// the logic is identical to the 50 MHz / 115200 board build.
`timescale 1ns/1ps
module tb_aes_top;
    localparam integer CLK_FREQ_HZ = 1600000;
    localparam integer BAUD_RATE   = 100000;          // 16 clocks per bit
    localparam integer CLK_NS      = 10;
    localparam integer BIT_NS      = CLK_NS * (CLK_FREQ_HZ / BAUD_RATE);

    reg  clk = 1'b0;
    reg  reset = 1'b1;
    reg  host_tx = 1'b1;           // -> DUT uart_rx_pin (idle high)
    wire dut_tx;                   // <- DUT uart_tx_pin
    wire busy_led, error_led;

    always #(CLK_NS/2) clk = ~clk;

    aes_top #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .reset(reset),
        .uart_rx_pin(host_tx), .uart_tx_pin(dut_tx),
        .busy_led(busy_led), .error_led(error_led)
    );

    integer errors = 0;
    integer checks = 0;

    reg [7:0]   resp [0:18];
    integer     resp_count;
    reg         rx_timeout;

    // ---------------- host -> FPGA ----------------
    task send_byte;
        input [7:0] b;
        integer k;
        begin
            host_tx = 1'b0; #(BIT_NS);                     // start bit
            for (k = 0; k < 8; k = k + 1) begin
                host_tx = b[k]; #(BIT_NS);                 // LSB first
            end
            host_tx = 1'b1; #(BIT_NS);                     // stop bit
        end
    endtask

    task send_request;
        input [7:0]   cmd;
        input [127:0] key;
        input [127:0] data;
        integer k;
        begin
            send_byte(8'hA5);
            send_byte(8'h5A);
            send_byte(cmd);
            for (k = 15; k >= 0; k = k - 1) send_byte(key[8*k +: 8]);
            for (k = 15; k >= 0; k = k - 1) send_byte(data[8*k +: 8]);
        end
    endtask

    // ---------------- FPGA -> host ----------------
    task receive_response;
        input integer timeout_bits;
        integer n, k, waited;
        reg [7:0] b;
        begin
            resp_count = 0;
            rx_timeout = 1'b0;
            for (n = 0; n < 19 && !rx_timeout; n = n + 1) begin
                waited = 0;
                while (dut_tx === 1'b1 && waited < timeout_bits * 16) begin
                    #(BIT_NS/16); waited = waited + 1;
                end
                if (dut_tx === 1'b1) rx_timeout = 1'b1;
                else begin
                    #(BIT_NS/2);                           // middle of start bit
                    for (k = 0; k < 8; k = k + 1) begin
                        #(BIT_NS); b[k] = dut_tx;
                    end
                    #(BIT_NS);                             // stop bit
                    if (dut_tx !== 1'b1) $display("  warning: framing error on response byte %0d", n);
                    resp[n] = b;
                    resp_count = resp_count + 1;
                end
            end
        end
    endtask

    function [127:0] resp_result;
        input dummy;
        integer k;
        begin
            for (k = 0; k < 16; k = k + 1)
                resp_result[127 - 8*k -: 8] = resp[3 + k];
        end
    endfunction

    task expect_response;
        input [255:0] name;
        input [7:0]   status;
        input [127:0] result;
        reg   [127:0] got;
        begin
            checks = checks + 1;
            got = resp_result(1'b0);
            if (resp_count != 19) begin
                errors = errors + 1;
                $display("FAIL  %0s: only %0d/19 response bytes", name, resp_count);
            end else if (resp[0] !== 8'h5A || resp[1] !== 8'hA5) begin
                errors = errors + 1;
                $display("FAIL  %0s: bad sync %02h %02h", name, resp[0], resp[1]);
            end else if (resp[2] !== status || got !== result) begin
                errors = errors + 1;
                $display("FAIL  %0s\n        got      status %02h result %032h\n        expected status %02h result %032h",
                         name, resp[2], got, status, result);
            end else
                $display("PASS  %0s: status %02h result %032h", name, resp[2], got);
        end
    endtask

    // Send a request and listen for the reply at the same time (full duplex).
    task transact;
        input [7:0]   cmd;
        input [127:0] key;
        input [127:0] data;
        begin
            fork
                send_request(cmd, key, data);
                receive_response(400);
            join
        end
    endtask

    task check_flag;
        input [511:0] name;
        input got;
        input expected;
        begin
            checks = checks + 1;
            if (got === expected) $display("PASS  %0s", name);
            else begin errors = errors + 1; $display("FAIL  %0s (got %b)", name, got); end
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        reset = 1'b0;
        #(BIT_NS * 4);

        // 1. FIPS-197 C.1 encrypt
        transact(8'h01, 128'h000102030405060708090a0b0c0d0e0f,
                        128'h00112233445566778899aabbccddeeff);
        expect_response("UART encrypt (C.1)", 8'h00, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);

        // 2. FIPS-197 C.1 decrypt
        transact(8'h02, 128'h000102030405060708090a0b0c0d0e0f,
                        128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        expect_response("UART decrypt (C.1)", 8'h00, 128'h00112233445566778899aabbccddeeff);

        // 3. FIPS-197 Appendix B encrypt
        transact(8'h01, 128'h2b7e151628aed2a6abf7158809cf4f3c,
                        128'h3243f6a8885a308d313198a2e0370734);
        expect_response("UART encrypt (B)", 8'h00, 128'h3925841d02dc09fbdc118597196a0b32);
        #(BIT_NS);   // receiver stops mid stop-bit; let the FPGA finish sending
        check_flag("busy LED off when idle", busy_led, 1'b0);

        // 4. Invalid command -> status 01, zero result (payload has no A5 bytes)
        transact(8'h07, 128'h11111111111111111111111111111111,
                        128'h22222222222222222222222222222222);
        expect_response("invalid command 07", 8'h01, 128'h0);
        check_flag("error LED on after invalid command", error_led, 1'b1);
        #(BIT_NS * 20);

        // 5. Normal request still works after the error
        transact(8'h02, 128'h2b7e151628aed2a6abf7158809cf4f3c,
                        128'h3925841d02dc09fbdc118597196a0b32);
        expect_response("UART decrypt after error (B)", 8'h00, 128'h3243f6a8885a308d313198a2e0370734);
        check_flag("error LED cleared by valid request", error_led, 1'b0);

        // 6. Line noise before a request is skipped by the sync search
        send_byte(8'h00); send_byte(8'hFF); send_byte(8'hA5); send_byte(8'h00);
        transact(8'h01, 128'h000102030405060708090a0b0c0d0e0f,
                        128'h00112233445566778899aabbccddeeff);
        expect_response("encrypt after junk bytes", 8'h00, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);

        $display("----------------------------------------");
        if (errors == 0) $display("ALL %0d SYSTEM CHECKS PASSED", checks);
        else             $display("%0d OF %0d SYSTEM CHECKS FAILED", errors, checks);
        $finish;
    end

    // Safety net so a hang never runs forever
    initial begin
        #(BIT_NS * 10 * 600);
        $display("FAIL  simulation watchdog expired");
        $finish;
    end
endmodule
