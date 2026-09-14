`timescale 1ns / 1ps

module PE(
    input clk,
    input rst,
    input os_mode, // Instead of sending entire df_policy, we just check if OS or not (Logic differs only with this)
    
    input signed [7:0] A_in,
    input signed [7:0] B_in,
    input signed [31:0] psum_in,
    output reg signed [31:0] accum,
    output reg signed [7:0] A_out,
    output reg signed [7:0] B_out
);
    wire signed [31:0] mac_result;
    assign mac_result = psum_in + (A_in * B_in);

    always @(posedge clk) begin
        if (rst) begin // Always reset at beginning
            accum <= 0;
            A_out <= 0;
            B_out <= 0;
        end
        else begin
            A_out <= A_in;
            B_out <= B_in;
            if (os_mode) begin
                // OS: accumulate partial sums
                accum <= accum + mac_result;
            end
            else begin
                // WS / IS: replace partial sum
                accum <= mac_result;         
            end
        end 
    end
endmodule
