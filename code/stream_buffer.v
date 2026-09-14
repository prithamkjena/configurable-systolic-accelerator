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

    // Generate the 7-element stream to be loaded
    always @(*) begin
        // Default: all zeros
        load_data = 56'b0;

        if (transpose == 1'b0) begin
            // Row-wise streaming
            case (stream_idx)
                2'd0:
                    load_data = {
                        matrix[127:120],
                        matrix[119:112],
                        matrix[111:104],
                        matrix[103:96],
                        24'b0
                    };

                2'd1:
                    load_data = {
                        8'b0,
                        matrix[95:88],
                        matrix[87:80],
                        matrix[79:72],
                        matrix[71:64],
                        16'b0
                    };

                2'd2:
                    load_data = {
                        16'b0,
                        matrix[63:56],
                        matrix[55:48],
                        matrix[47:40],
                        matrix[39:32],
                        8'b0
                    };

                2'd3:
                    load_data = {
                        24'b0,
                        matrix[31:24],
                        matrix[23:16],
                        matrix[15:8],
                        matrix[7:0]
                    };

                default: load_data = 56'b0;
            endcase
        end
        else begin
            // Column-wise streaming
            case (stream_idx)
                2'd0:
                    load_data = {
                        matrix[127:120],
                        matrix[95:88],
                        matrix[63:56],
                        matrix[31:24],
                        24'b0
                    };

                2'd1:
                    load_data = {
                        8'b0,
                        matrix[119:112],
                        matrix[87:80],
                        matrix[55:48],
                        matrix[23:16],
                        16'b0
                    };

                2'd2:
                    load_data = {
                        16'b0,
                        matrix[111:104],
                        matrix[79:72],
                        matrix[47:40],
                        matrix[15:8],
                        8'b0
                    };

                2'd3:
                    load_data = {
                        24'b0,
                        matrix[103:96],
                        matrix[71:64],
                        matrix[39:32],
                        matrix[7:0]
                    };

                default: load_data = 56'b0;
            endcase
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
