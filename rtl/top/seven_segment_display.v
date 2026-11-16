// seven_segment_display.v - Shows a 24-bit value as 6 hex digits on the
// DE10-Lite HEX5..HEX0 displays (common anode: segment ON = 0).
// hex5 shows value[23:20] (left-most), hex0 shows value[3:0] (right-most).
// aes_top feeds it the first 3 bytes of the last result, so after the
// FIPS-197 C.1 encrypt demo the board shows "69C4E0".
// blank = 1 turns every segment off. Decimal points are always off.
// Segment order in each output: {dp, g, f, e, d, c, b, a}.
module seven_segment_display (
    input  wire [23:0] value,
    input  wire        blank,
    output wire [7:0]  hex0,
    output wire [7:0]  hex1,
    output wire [7:0]  hex2,
    output wire [7:0]  hex3,
    output wire [7:0]  hex4,
    output wire [7:0]  hex5
);
    // Returns active-low {g,f,e,d,c,b,a} for one hex digit.
    function [6:0] seg;
        input [3:0] digit;
        begin
            case (digit)
                4'h0: seg = 7'b1000000;
                4'h1: seg = 7'b1111001;
                4'h2: seg = 7'b0100100;
                4'h3: seg = 7'b0110000;
                4'h4: seg = 7'b0011001;
                4'h5: seg = 7'b0010010;
                4'h6: seg = 7'b0000010;
                4'h7: seg = 7'b1111000;
                4'h8: seg = 7'b0000000;
                4'h9: seg = 7'b0010000;
                4'hA: seg = 7'b0001000;
                4'hB: seg = 7'b0000011;
                4'hC: seg = 7'b1000110;
                4'hD: seg = 7'b0100001;
                4'hE: seg = 7'b0000110;
                default: seg = 7'b0001110;   // F
            endcase
        end
    endfunction

    assign hex0 = blank ? 8'hFF : {1'b1, seg(value[3:0])};
    assign hex1 = blank ? 8'hFF : {1'b1, seg(value[7:4])};
    assign hex2 = blank ? 8'hFF : {1'b1, seg(value[11:8])};
    assign hex3 = blank ? 8'hFF : {1'b1, seg(value[15:12])};
    assign hex4 = blank ? 8'hFF : {1'b1, seg(value[19:16])};
    assign hex5 = blank ? 8'hFF : {1'b1, seg(value[23:20])};
endmodule
