`timescale 1ns / 1ps

module output_buffer(
    input clk,
    input rst,
    input store_output,
    input [1:0] df_policy,

    input [511:0] accum,
    
    input signed [31:0] psum1_out,
    input signed [31:0] psum2_out,
    input signed [31:0] psum3_out,
    input signed [31:0] psum4_out,

    output reg [511:0] C
);

    localparam OS = 2'b00;
    localparam WS = 2'b01;
    localparam IS = 2'b10;

    reg [2:0] output_diag;

    always @(posedge clk) begin
        if (rst) begin
            C <= 0;
            output_diag <= 0;
        end
        else if (store_output) begin

            if (df_policy == OS) begin
                // OS: all 16 accumulators are available simultaneously
                C <= accum;
            end
            else if (df_policy == WS) begin
                // WS: column-oriented diagonals
                if (output_diag <= 3)
                    C[32*(output_diag*4) +: 32] <= psum1_out;
            
                if (output_diag >= 1 && output_diag <= 4)
                    C[32*((output_diag-1)*4 + 1) +: 32] <= psum2_out;
            
                if (output_diag >= 2 && output_diag <= 5)
                    C[32*((output_diag-2)*4 + 2) +: 32] <= psum3_out;
            
                if (output_diag >= 3 && output_diag <= 6)
                    C[32*((output_diag-3)*4 + 3) +: 32] <= psum4_out;
            
                output_diag <= output_diag + 1;
            end
            else begin
                // IS: row-oriented diagonals
                if (output_diag <= 3)
                    C[32*output_diag +: 32] <= psum1_out;
            
                if (output_diag >= 1 && output_diag <= 4)
                    C[32*(4 + output_diag - 1) +: 32] <= psum2_out;
            
                if (output_diag >= 2 && output_diag <= 5)
                    C[32*(8 + output_diag - 2) +: 32] <= psum3_out;
            
                if (output_diag >= 3 && output_diag <= 6)
                    C[32*(12 + output_diag - 3) +: 32] <= psum4_out;
            
                output_diag <= output_diag + 1;
            end 
        end
        else begin
            // Do nothing
        end
    end

endmodule
