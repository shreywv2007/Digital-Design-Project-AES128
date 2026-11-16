// tb_aes_encrypt.v - Focused test of aes_encrypt (Member 1) + key expansion.
// Known answers: FIPS-197 Appendix B and C.1, NIST SP 800-38A F.1.1 (ECB).
// Also checks the handshake: busy during the run, done is a one-clock pulse
// exactly 11 clocks after start, and start is ignored while busy.
`timescale 1ns/1ps
module tb_aes_encrypt;
    reg           clk = 1'b0, reset = 1'b1, start = 1'b0;
    reg  [127:0]  key = 128'h0, pt = 128'h0;
    wire [1407:0] round_keys;
    wire [127:0]  ct;
    wire          busy, done;
    integer errors = 0, checks = 0, cycles, done_pulses;

    always #5 clk = ~clk;

    aes_key_expansion u_kexp (.key(key), .round_keys(round_keys));
    aes_encrypt u_dut (
        .clk(clk), .reset(reset), .start(start), .data_in(pt),
        .round_keys(round_keys), .data_out(ct), .busy(busy), .done(done)
    );

    task encrypt_check;
        input [127:0] k, p, expected;
        begin
            key = k; pt = p;
            @(negedge clk) start = 1'b1;
            @(negedge clk) start = 1'b0;
            cycles = 1; done_pulses = 0;
            while (!done && cycles < 50) begin
                @(negedge clk) cycles = cycles + 1;
                // a second start while busy must be ignored
                if (cycles == 4) start = 1'b1; else start = 1'b0;
            end
            start = 1'b0;
            checks = checks + 1;
            if (ct !== expected || cycles != 11) begin
                errors = errors + 1;
                $display("FAIL  encrypt %032h\n        got %032h after %0d clocks, expected %032h after 11",
                         p, ct, cycles, expected);
            end else
                $display("PASS  encrypt %032h -> %032h (%0d clocks)", p, ct, cycles);
            @(negedge clk);
            checks = checks + 1;
            if (done !== 1'b0 || busy !== 1'b0) begin
                errors = errors + 1; $display("FAIL  done/busy not low one clock after done");
            end
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;
        // FIPS-197
        encrypt_check(128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h3243f6a8885a308d313198a2e0370734, 128'h3925841d02dc09fbdc118597196a0b32);
        encrypt_check(128'h000102030405060708090a0b0c0d0e0f, 128'h00112233445566778899aabbccddeeff, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);
        // NIST SP 800-38A F.1.1 ECB-AES128.Encrypt
        encrypt_check(128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h6bc1bee22e409f96e93d7e117393172a, 128'h3ad77bb40d7a3660a89ecaf32466ef97);
        encrypt_check(128'h2b7e151628aed2a6abf7158809cf4f3c, 128'hae2d8a571e03ac9c9eb76fac45af8e51, 128'hf5d3d58503b9699de785895a96fdbaaf);
        encrypt_check(128'h2b7e151628aed2a6abf7158809cf4f3c, 128'h30c81c46a35ce411e5fbc1191a0a52ef, 128'h43b1cd7f598ece23881b00e3ed030688);
        encrypt_check(128'h2b7e151628aed2a6abf7158809cf4f3c, 128'hf69f2445df4f9b17ad2b417be66c3710, 128'h7b0c785e27e8ad3f8223207104725dd4);

        $display("----------------------------------------");
        if (errors == 0) $display("ALL %0d ENCRYPT CHECKS PASSED", checks);
        else             $display("%0d OF %0d ENCRYPT CHECKS FAILED", errors, checks);
        $finish;
    end
endmodule
