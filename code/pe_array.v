`timescale 1ns / 1ps

module pe_array(
    input clk,
    input rst,
    input [1:0] df_policy,

    input signed [7:0] A1_in,
    input signed [7:0] A2_in,
    input signed [7:0] A3_in,
    input signed [7:0] A4_in,   
    input signed [7:0] B1_in,
    input signed [7:0] B2_in,
    input signed [7:0] B3_in,
    input signed [7:0] B4_in,
    
    output signed [31:0] psum1_out,
    output signed [31:0] psum2_out,
    output signed [31:0] psum3_out,
    output signed [31:0] psum4_out,
    
    input [127:0] stationary,
    output [511:0] accum
);
    localparam OS = 2'b00;
    localparam WS = 2'b01;
    localparam IS = 2'b10;

    wire os_mode;
    assign os_mode = (df_policy == OS);
    
    wire signed [7:0] A_wire [0:3][0:4]; // Row : Column
    wire signed [7:0] B_wire [0:3][0:4]; // Column : Row
    wire signed [31:0] psum_wire [0:3][0:4]; // Column : Row
    wire signed [31:0] accum_wire [0:3][0:3]; // Row : Column
    
    genvar i, j;
    generate
        for (i=0; i<=3; i=i+1) begin : PE_ROW
            for (j=0; j<=3; j=j+1) begin : PE_COL
                wire signed [31:0] pe_accum;
                PE pe(
                    .A_in(A_wire[i][j]),
                    .B_in(
                        os_mode ? B_wire[j][i] : stationary[127 - 8*(i*4+j) -: 8] // OS : WS/IS
                    ),
                    .psum_in(
                        os_mode ? 0 : psum_wire[j][i] // OS : WS/IS
                    ),
                    .accum(pe_accum),
                    .A_out(A_wire[i][j+1]),
                    .B_out(B_wire[j][i+1]),
                    .os_mode(os_mode),
                    .clk(clk),
                    .rst(rst)
                );
                assign accum_wire[i][j] = os_mode ? pe_accum : 0;
                assign psum_wire[j][i+1] = os_mode ? 0 : pe_accum;
            end
        end
    endgenerate
    
    // A inputs from left to right
    assign A_wire[0][0] = A1_in;
    assign A_wire[1][0] = A2_in;
    assign A_wire[2][0] = A3_in;
    assign A_wire[3][0] = A4_in;

    // B inputs from top to down
    assign B_wire[0][0] = B1_in;
    assign B_wire[1][0] = B2_in;
    assign B_wire[2][0] = B3_in;
    assign B_wire[3][0] = B4_in;
    
    // Outputs from down
    assign psum1_out = psum_wire[0][4];
    assign psum2_out = psum_wire[1][4];
    assign psum3_out = psum_wire[2][4];
    assign psum4_out = psum_wire[3][4];
    
    // psum of outer boundary
    assign psum_wire[0][0] = 0;
    assign psum_wire[1][0] = 0;
    assign psum_wire[2][0] = 0;
    assign psum_wire[3][0] = 0;
    
    // ROW Wise filling of accumulator outputs to 512 bit reg (R4C4 -> R0C0)
    genvar m, n;
    generate
        for (m = 0; m < 4; m = m + 1) begin : ACCUM_ROW
            for (n = 0; n < 4; n = n + 1) begin : ACCUM_COL
                assign accum[32*(m*4+n) +: 32] = accum_wire[m][n];
            end
        end
    endgenerate
endmodule
