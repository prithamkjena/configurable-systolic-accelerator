`timescale 1ns / 1ps

module PE(
    input clk,
    input rst,
    input [1:0] df_policy, // WS? IS? OS?
    
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
            if (df_policy == 2'b00) begin // OS
                accum <= accum + mac_result;
            end
            else begin // WS / IS (01 / 10)
                accum <= mac_result;         
            end
        end 
    end
endmodule
