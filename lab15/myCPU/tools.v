module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module encoder_16_4(
    input  [15:0] in,
    output [ 3:0] out
);

assign out = {4{in[ 0]}} & 4'h0
           | {4{in[ 1]}} & 4'h1
           | {4{in[ 2]}} & 4'h2
           | {4{in[ 3]}} & 4'h3
           | {4{in[ 4]}} & 4'h4
           | {4{in[ 5]}} & 4'h5
           | {4{in[ 6]}} & 4'h6
           | {4{in[ 7]}} & 4'h7
           | {4{in[ 8]}} & 4'h8
           | {4{in[ 9]}} & 4'h9
           | {4{in[10]}} & 4'ha
           | {4{in[11]}} & 4'hb
           | {4{in[12]}} & 4'hc
           | {4{in[13]}} & 4'hd
           | {4{in[14]}} & 4'he
           | {4{in[15]}} & 4'hf;

endmodule