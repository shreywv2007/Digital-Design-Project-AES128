// tb_aes_cores.v - Unit tests for key expansion, aes_encrypt and aes_decrypt.
// Known-answer vectors from FIPS-197 (Appendix A.1, B and C.1), plus
// encrypt->decrypt round trips. Prints PASS/FAIL per check and a summary.
`timescale 1ns/1ps
module tb_aes_cores;
    reg          clk = 1'b0;
    reg          reset = 1'b1;
    reg  [127:0] key;
    reg  [127:0] enc_in, dec_in;
    reg          enc_start = 1'b0, dec_start = 1'b0;
    wire [1407:0] round_keys;
    wire [127:0] enc_out, dec_out;
    wire         enc_busy, enc_done, dec_busy, dec_done;

    integer errors = 0;
    integer checks = 0;
    integer i;
    integer cycles;

    always #5 clk = ~clk;

    aes_key_expansion u_kexp (.key(key), .round_keys(round_keys));

    aes_encrypt u_enc (
        .clk(clk), .reset(reset), .start(enc_start), .data_in(enc_in),
        .round_keys(round_keys), .data_out(enc_out),
        .busy(enc_busy), .done(enc_done)
    );

    aes_decrypt u_dec (
        .clk(clk), .rst(reset), .start(dec_start), .ciphertext(dec_in),
        .round_keys(round_keys), .plaintext(dec_out),
        .busy(dec_busy), .done(dec_done)
    );

    task check;
        input [255:0] name;
        input [127:0] got;
        input [127:0] expected;
        begin
            checks = checks + 1;
            if (got === expected)
                $display("PASS  %0s = %032h", name, got);
            else begin
                errors = errors + 1;
                $display("FAIL  %0s\n        got      %032h\n        expected %032h",
                         name, got, expected);
            end
        end
    endtask

    task run_encrypt;
        input  [127:0] pt;
        output [127:0] ct;
        begin
            @(negedge clk); enc_in = pt; enc_start = 1'b1;
            @(negedge clk); enc_start = 1'b0;
            cycles = 1;
            while (!enc_done && cycles < 100) begin @(negedge clk); cycles = cycles + 1; end
            if (!enc_done) begin errors = errors + 1; $display("FAIL  encrypt timed out"); end
            ct = enc_out;
        end
    endtask

    task run_decrypt;
        input  [127:0] ct;
        output [127:0] pt;
        begin
            @(negedge clk); dec_in = ct; dec_start = 1'b1;
            @(negedge clk); dec_start = 1'b0;
            cycles = 1;
            while (!dec_done && cycles < 100) begin @(negedge clk); cycles = cycles + 1; end
            if (!dec_done) begin errors = errors + 1; $display("FAIL  decrypt timed out"); end
            pt = dec_out;
        end
    endtask

    reg [127:0] result, back, pt_rand;

    initial begin
        key = 128'h0; enc_in = 128'h0; dec_in = 128'h0;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        // ---- Key expansion (FIPS-197 A.1) ----
        key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        #1;
        check("K0  (A.1)", round_keys[127:0],      128'h2b7e151628aed2a6abf7158809cf4f3c);
        check("K1  (A.1)", round_keys[255:128],    128'ha0fafe1788542cb123a339392a6c7605);
        check("K10 (A.1)", round_keys[1407:1280],  128'hd014f9a8c9ee2589e13f0cc8b6630ca6);

        // ---- Encrypt / decrypt, FIPS-197 Appendix B ----
        run_encrypt(128'h3243f6a8885a308d313198a2e0370734, result);
        check("encrypt (B)", result, 128'h3925841d02dc09fbdc118597196a0b32);
        $display("      encrypt latency: %0d cycles after start", cycles);
        run_decrypt(128'h3925841d02dc09fbdc118597196a0b32, result);
        check("decrypt (B)", result, 128'h3243f6a8885a308d313198a2e0370734);
        $display("      decrypt latency: %0d cycles after start", cycles);

        // ---- Encrypt / decrypt, FIPS-197 Appendix C.1 ----
        key = 128'h000102030405060708090a0b0c0d0e0f;
        run_encrypt(128'h00112233445566778899aabbccddeeff, result);
        check("encrypt (C.1)", result, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        run_decrypt(128'h69c4e0d86a7b0430d8cdb78070b4c55a, result);
        check("decrypt (C.1)", result, 128'h00112233445566778899aabbccddeeff);

        // ---- Round trips with pseudo-random keys/data ----
        for (i = 0; i < 8; i = i + 1) begin
            key     = {$random, $random, $random, $random};
            pt_rand = {$random, $random, $random, $random};
            run_encrypt(pt_rand, result);
            run_decrypt(result, back);
            check("round trip", back, pt_rand);
        end

        // ---- Reset in the middle of an operation ----
        @(negedge clk); enc_in = 128'h1; enc_start = 1'b1;
        @(negedge clk); enc_start = 1'b0;
        repeat (3) @(negedge clk);
        reset = 1'b1; @(negedge clk); reset = 1'b0;
        checks = checks + 1;
        if (enc_busy !== 1'b0) begin errors = errors + 1; $display("FAIL  encrypt busy after reset"); end
        else $display("PASS  encrypt idle after mid-operation reset");
        key = 128'h000102030405060708090a0b0c0d0e0f;
        run_encrypt(128'h00112233445566778899aabbccddeeff, result);
        check("encrypt after reset", result, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);

        $display("----------------------------------------");
        if (errors == 0) $display("ALL %0d CORE CHECKS PASSED", checks);
        else             $display("%0d OF %0d CORE CHECKS FAILED", errors, checks);
        $finish;
    end
endmodule
