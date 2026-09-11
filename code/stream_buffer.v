`timescale 1ns / 1ps

module stream_buffer (
    input clk,
    input rst,
    input load,

    input [127:0] matrix,
    input [1:0] stream_idx, // which row/column of the matrix it is currently streaming
    input transpose,

    output signed [7:0] data_out
);

    reg signed [7:0] buffer [0:6];
    reg [55:0] load_data;

    integer k;
    integer row;
    integer col;
    integer matrix_idx;

    // Generate the 7-element stream to be loaded
    always @(*) begin
        load_data = 0;

        for (k = 0; k < 7; k = k + 1) begin

            // Delay = stream_idx
            if (k >= stream_idx && (k-stream_idx) < 4) begin

                matrix_idx = k - stream_idx;

                if (transpose == 0) begin
                    // Row-wise
                    row = stream_idx;
                    col = matrix_idx;
                end
                else begin
                    // Column-wise
                    row = matrix_idx;
                    col = stream_idx;
                end

                load_data[55 - 8*k -: 8] = matrix[127 - 8*(row*4 + col) -: 8];
            end
        end
    end

    // Shift buffer
    always @(posedge clk) begin
        if (rst) begin
            buffer[0] <= 0;
            buffer[1] <= 0;
            buffer[2] <= 0;
            buffer[3] <= 0;
            buffer[4] <= 0;
            buffer[5] <= 0;
            buffer[6] <= 0;
        end
        else if (load) begin
            buffer[0] <= load_data[55:48];
            buffer[1] <= load_data[47:40];
            buffer[2] <= load_data[39:32];
            buffer[3] <= load_data[31:24];
            buffer[4] <= load_data[23:16];
            buffer[5] <= load_data[15:8];
            buffer[6] <= load_data[7:0];
        end
        else begin
            buffer[0] <= buffer[1];
            buffer[1] <= buffer[2];
            buffer[2] <= buffer[3];
            buffer[3] <= buffer[4];
            buffer[4] <= buffer[5];
            buffer[5] <= buffer[6];
            buffer[6] <= 0;
        end
    end

    assign data_out = buffer[0];

endmodule
