/*
 * Copyright (c) 2026 Pritham Kumar Jena
 * SPDX-License-Identifier: Apache-2.0
 */

module sram_16x8 (
    input  wire       clk,
    input  wire       rst_n,

    // Write interface
    input  wire       write_en,
    input  wire [3:0] write_addr,
    input  wire [7:0] write_data,

    // Read interface
    input  wire       read_en,
    input  wire [3:0] read_addr,
    output reg  [7:0] read_data
);

    // 16 entries x 8 bits = 128 bits.
    reg [7:0] mem [0:15];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1)
                mem[i] <= 8'b0;

            read_data <= 8'b0;
        end
        else begin
            if (write_en)
                mem[write_addr] <= write_data;

            if (read_en)
                read_data <= mem[read_addr];
        end
    end

endmodule