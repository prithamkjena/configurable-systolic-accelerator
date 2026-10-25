`timescale 1ns / 1ps

module output_buffer(
    input clk,
    input rst_n,
    input store_output,
    input [1:0] df_policy,

    input [287:0] accum,
    
    input signed [17:0] psum1_out,
    input signed [17:0] psum2_out,
    input signed [17:0] psum3_out,
    input signed [17:0] psum4_out,

    output reg [287:0] C
);

    localparam OS = 2'b00;
    localparam WS = 2'b01;
    localparam IS = 2'b10;

    reg [2:0] output_diag;

    always @(posedge clk) begin
        if (!rst_n) begin
            C <= 0;
            output_diag <= 0;
        end
        else if (store_output) begin

            case (df_policy)

                OS: begin
                    // OS: all 16 accumulators are available simultaneously
                    C <= accum;
                end

                WS: begin
                    // WS: column-oriented diagonals
                    case (output_diag)
                        3'd0: begin
                            C[0*18 +: 18] <= psum1_out;
                        end
                        3'd1: begin
                            C[4*18 +: 18] <= psum1_out;
                            C[1*18 +: 18] <= psum2_out;
                        end
                        3'd2: begin
                            C[8*18 +: 18] <= psum1_out;
                            C[5*18 +: 18] <= psum2_out;
                            C[2*18 +: 18] <= psum3_out;
                        end
                        3'd3: begin
                            C[12*18 +: 18] <= psum1_out;
                            C[9*18  +: 18] <= psum2_out;
                            C[6*18  +: 18] <= psum3_out;
                            C[3*18  +: 18] <= psum4_out;
                        end
                        3'd4: begin
                            C[13*18 +: 18] <= psum2_out;
                            C[10*18 +: 18] <= psum3_out;
                            C[7*18  +: 18] <= psum4_out;
                        end
                        3'd5: begin
                            C[14*18 +: 18] <= psum3_out;
                            C[11*18 +: 18] <= psum4_out;
                        end
                        3'd6: begin
                            C[15*18 +: 18] <= psum4_out;
                        end
                        default: begin
                            // No C update
                        end

                    endcase
                    output_diag <= output_diag + 1'b1;
                end

                IS: begin
                    case (output_diag)
                        // IS: row-oriented diagonals
                        3'd0: begin
                            C[0*18 +: 18] <= psum1_out;
                        end
                        3'd1: begin
                            C[1*18 +: 18] <= psum1_out;
                            C[4*18 +: 18] <= psum2_out;
                        end
                        3'd2: begin
                            C[2*18 +: 18] <= psum1_out;
                            C[5*18 +: 18] <= psum2_out;
                            C[8*18 +: 18] <= psum3_out;
                        end
                        3'd3: begin
                            C[3*18  +: 18] <= psum1_out;
                            C[6*18  +: 18] <= psum2_out;
                            C[9*18  +: 18] <= psum3_out;
                            C[12*18 +: 18] <= psum4_out;
                        end
                        3'd4: begin
                            C[7*18  +: 18] <= psum2_out;
                            C[10*18 +: 18] <= psum3_out;
                            C[13*18 +: 18] <= psum4_out;
                        end
                        3'd5: begin
                            C[11*18 +: 18] <= psum3_out;
                            C[14*18 +: 18] <= psum4_out;
                        end
                        3'd6: begin
                            C[15*18 +: 18] <= psum4_out;
                        end
                        default: begin
                            // No C update
                        end

                    endcase
                    output_diag <= output_diag + 1'b1;
                end

                default: begin
                    // Invalid dataflow policy
                end

            endcase
        end
        else begin
            output_diag <= 0;
        end
    end

endmodule
