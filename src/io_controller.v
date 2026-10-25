/*
 * Copyright (c) 2026 Pritham Kumar Jena
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module io_controller (
    input wire clk,
    input wire rst_n,

    // Tiny Tapeout host interface
    input wire [7:0]  ui_in,
    output reg [7:0]  uo_out,
    input wire [7:0]  uio_in,
    output reg [7:0]  uio_out,
    output wire [7:0] uio_oe,

    // SRAM A interface (from host)
    output wire [5:0]  sram_a_addr_io,
    output wire [15:0] sram_a_din_io,
    output wire        sram_a_wen_io,
    output wire        sram_a_ren_io,
    input wire [15:0]  sram_a_dout,

    // SRAM B interface (from host)
    output wire [5:0]  sram_b_addr_io,
    output wire [15:0] sram_b_din_io,
    output wire        sram_b_wen_io,
    output wire        sram_b_ren_io,
    input wire [15:0]  sram_b_dout,

    // SRAM C interface (from host)
    output wire [5:0]  sram_c_addr_io,
    output wire        sram_c_ren_io,
    input wire [15:0]  sram_c_dout,

    // Accelerator bridge control
    output reg        bridge_start,
    output reg [1:0]  df_policy,
    input wire        bridge_busy,
    input wire        bridge_done
);

    // Keep bidirectional pins as inputs to avoid bus contention
    assign uio_oe = 8'h00;

    // Internal staging memories (16 bytes = 128 bits each)
    reg [7:0] mem_a [0:15];
    reg [7:0] mem_b [0:15];

    // Read tracking
    reg [1:0] read_source; // 0=status, 1=SRAM C, 2=SRAM A, 3=SRAM B
    reg       read_byte_sel;

    wire [3:0] opcode  = uio_in[7:4];
    wire [3:0] operand = uio_in[3:0];

    // Combinational SRAM A controls
    assign sram_a_ren_io  = (opcode == 4'h5);
    assign sram_a_wen_io  = (opcode == 4'h1);
    assign sram_a_addr_io = (opcode == 4'h5) ? {3'b000, operand[2:0]} : {3'b000, operand[3:1]};
    assign sram_a_din_io  = operand[0] ? {mem_a[{operand[3:1], 1'b0}], ui_in} : {ui_in, mem_a[{operand[3:1], 1'b1}]};

    // Combinational SRAM B controls
    assign sram_b_ren_io  = (opcode == 4'h6);
    assign sram_b_wen_io  = (opcode == 4'h2);
    assign sram_b_addr_io = (opcode == 4'h6) ? {3'b000, operand[2:0]} : {3'b000, operand[3:1]};
    assign sram_b_din_io  = operand[0] ? {mem_b[{operand[3:1], 1'b0}], ui_in} : {ui_in, mem_b[{operand[3:1], 1'b1}]};

    // Combinational SRAM C controls
    assign sram_c_ren_io  = (opcode == 4'h4);
    assign sram_c_addr_io = {1'b0, ui_in[0], operand};

    integer k;

    always @(posedge clk) begin
        if (!rst_n) begin
            df_policy     <= 2'b00;
            bridge_start  <= 1'b0;
            read_source   <= 2'd0;
            read_byte_sel <= 1'b0;

            for (k = 0; k < 16; k = k + 1) begin
                mem_a[k] <= 8'd0;
                mem_b[k] <= 8'd0;
            end
        end else begin
            bridge_start <= 1'b0;

            case (opcode)
                4'h0: begin // NOP / Status
                    read_source <= 2'd0;
                end

                4'h1: begin // Write Matrix A byte
                    read_source    <= 2'd0;
                    mem_a[operand] <= ui_in;
                end

                4'h2: begin // Write Matrix B byte
                    read_source    <= 2'd0;
                    mem_b[operand] <= ui_in;
                end

                4'h3: begin // Set Dataflow Policy
                    read_source <= 2'd0;
                    df_policy   <= ui_in[1:0];
                end

                4'h4: begin // Read SRAM C Word
                    read_source   <= 2'd1;
                    read_byte_sel <= ui_in[1];
                end

                4'h5: begin // Read SRAM A Word
                    read_source   <= 2'd2;
                    read_byte_sel <= ui_in[1];
                end

                4'h6: begin // Read SRAM B Word
                    read_source   <= 2'd3;
                    read_byte_sel <= ui_in[1];
                end

                4'h7: begin // Start Accelerator
                    read_source  <= 2'd0;
                    bridge_start <= 1'b1;
                end

                4'h8: begin // Explicit Poll Status
                    read_source <= 2'd0;
                end

                default: begin
                    read_source <= 2'd0;
                end
            endcase
        end
    end

    // Combinational Output Multiplexer
    always @(*) begin
        case (read_source)
            2'd1: begin // SRAM C read
                uio_out = sram_c_dout[15:8];
                uo_out  = read_byte_sel ? sram_c_dout[15:8] : sram_c_dout[7:0];
            end
            2'd2: begin // SRAM A read
                uio_out = sram_a_dout[15:8];
                uo_out  = read_byte_sel ? sram_a_dout[15:8] : sram_a_dout[7:0];
            end
            2'd3: begin // SRAM B read
                uio_out = sram_b_dout[15:8];
                uo_out  = read_byte_sel ? sram_b_dout[15:8] : sram_b_dout[7:0];
            end
            default: begin // Status output
                uio_out = 8'h00;
                uo_out  = {4'b0000, df_policy, bridge_busy, bridge_done};
            end
        endcase
    end

endmodule
