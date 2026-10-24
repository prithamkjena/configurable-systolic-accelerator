/*
 * Copyright (c) 2026 Pritham Kumar Jena
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_prithamkjena (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // =========================================================
    // SRAM A
    // Write data comes from ui_in.
    // Read interface is available for future modules.
    // =========================================================

    reg [3:0] addr_a;

    wire       sram_a_read_en;
    wire [3:0] sram_a_read_addr;
    wire [7:0] sram_a_read_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            addr_a <= 4'd0;
        else if (ena)
            addr_a <= addr_a + 1'b1;
    end

    // Temporary read-interface tie-offs.
    // Replace these with connections to your consuming module later.
    assign sram_a_read_en = ena;
    assign sram_a_read_addr = addr_a;

    (* keep *) sram_16x8 SRAM_A (
        .clk       (clk),
        .rst_n     (rst_n),

        .write_en  (ena),
        .write_addr(addr_a),
        .write_data(ui_in),

        .read_en   (sram_a_read_en),
        .read_addr (sram_a_read_addr),
        .read_data (sram_a_read_data)
    );


    // =========================================================
    // SRAM B
    // Write data comes from uio_in.
    // Read interface is available for future modules.
    // =========================================================

    reg [3:0] addr_b;

    wire       sram_b_read_en;
    wire [3:0] sram_b_read_addr;
    wire [7:0] sram_b_read_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            addr_b <= 4'd0;
        else if (ena)
            addr_b <= addr_b + 1'b1;
    end

    // Temporary read-interface tie-offs.
    assign sram_b_read_en = ena;
    assign sram_b_read_addr = addr_b;

    (* keep *) sram_16x8 SRAM_B (
        .clk       (clk),
        .rst_n     (rst_n),

        .write_en  (ena),
        .write_addr(addr_b),
        .write_data(uio_in),

        .read_en   (sram_b_read_en),
        .read_addr (sram_b_read_addr),
        .read_data (sram_b_read_data)
    );


    // =========================================================
    // SRAM C
    // Write interface reserved for future modules.
    // Read data is exposed through uo_out.
    // =========================================================

    wire c_write_en = ena;
    wire [3:0] c_write_addr = addr_c;
    wire [7:0] c_write_data = ui_in ^ uio_in;

    reg [3:0] addr_c;
    wire [7:0] sram_c_read_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            addr_c <= 4'd0;
        else if (ena)
            addr_c <= addr_c + 1'b1;
    end

    (* keep *) sram_16x8 SRAM_C (
        .clk       (clk),
        .rst_n     (rst_n),

        .write_en  (c_write_en),
        .write_addr(c_write_addr),
        .write_data(c_write_data),

        .read_en   (ena),
        .read_addr (addr_c),
        .read_data (sram_c_read_data)
    );


    // =========================================================
    // TinyTapeout outputs
    // =========================================================

    assign uo_out = sram_a_read_data
              ^ sram_b_read_data
              ^ sram_c_read_data;
    // All bidirectional GPIOs remain inputs.
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule