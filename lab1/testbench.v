`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/11 00:21:48
// Design Name: 
// Module Name: testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module testbench(

    );
reg clk;
reg resetn;
initial
begin
    clk = 0;
    resetn = 1'b0;
    #200;
    resetn = 1'b1;
end
    always #5 clk <= ~clk;
    
    led #(
        .CNT_1S(  27'd100 )
    ) u_led (
        .clk(clk),
        .resetn(resetn),
        .led()
    );
endmodule
