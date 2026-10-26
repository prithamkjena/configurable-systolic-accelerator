/*
 * Copyright (c) 2026 Pritham Kumar Jena
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module sram_acc_bridge (
    input wire clk,
    input wire rst_n,

    // Control from io_controller
    input wire        start,
    input wire [1:0]  df_policy,
    output reg        busy,
    output reg        done,

    // SRAM A read interface
    output reg [5:0]  sram_a_addr,
    output reg        sram_a_ren,
    input wire [15:0] sram_a_dout,

    // SRAM B read interface
    output reg [5:0]  sram_b_addr,
    output reg        sram_b_ren,
    input wire [15:0] sram_b_dout,

    // SRAM C write interface
    output reg [5:0]  sram_c_addr,
    output reg [15:0] sram_c_din,
    output reg        sram_c_wen,

    // Interface to systolic_acc_top
    output reg         acc_start,
    output reg [1:0]   acc_df_policy,
    output reg [127:0] acc_A,
    output reg [127:0] acc_B,
    input wire [287:0] acc_C,
    input wire         acc_done
);

    localparam S_IDLE      = 3'd0;
    localparam S_LOAD_SRAM = 3'd1;
    localparam S_START_ACC = 3'd2;
    localparam S_WAIT_ACC  = 3'd3;
    localparam S_WRITE_C   = 3'd4;
    localparam S_DONE      = 3'd5;

    reg [2:0] state;
    reg [5:0] count;
    reg [287:0] c_reg;

    // Helper to format an 18-bit signed element into two 16-bit SRAM C words
    function [15:0] get_sram_c_word;
        input [287:0] c_data;
        input [4:0] word_idx;
        reg [3:0] e_idx;
        begin
            e_idx = word_idx[4:1];
            if (word_idx[0] == 1'b0)
                get_sram_c_word = c_data[18*e_idx +: 16];
            else
                get_sram_c_word = {{14{c_data[18*e_idx + 17]}}, c_data[18*e_idx + 16 +: 2]};
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            count         <= 6'd0;
            sram_a_addr   <= 6'd0;
            sram_a_ren    <= 1'b0;
            sram_b_addr   <= 6'd0;
            sram_b_ren    <= 1'b0;
            sram_c_addr   <= 6'd0;
            sram_c_din    <= 16'd0;
            sram_c_wen    <= 1'b0;
            acc_start     <= 1'b0;
            acc_df_policy <= 2'b00;
            acc_A         <= 128'd0;
            acc_B         <= 128'd0;
            c_reg         <= 288'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    sram_a_ren <= 1'b0;
                    sram_b_ren <= 1'b0;
                    sram_c_wen <= 1'b0;
                    acc_start  <= 1'b0;
                    count      <= 6'd0;

                    if (start) begin
                        busy        <= 1'b1;
                        done        <= 1'b0;
                        state       <= S_LOAD_SRAM;
                        // Present address 0 to SRAM A and B
                        sram_a_addr <= 6'd0;
                        sram_a_ren  <= 1'b1;
                        sram_b_addr <= 6'd0;
                        sram_b_ren  <= 1'b1;
                        count       <= 6'd0;
                    end
                end

                S_LOAD_SRAM: begin
                    case (count)
                        6'd0: begin
                            // SRAMs are sampling addr 0; advance address to 1
                            sram_a_addr <= 6'd1;
                            sram_b_addr <= 6'd1;
                            count       <= 6'd1;
                        end
                        6'd1: begin
                            // SRAMs sampled addr 0 on previous edge, sram_dout now has word 0
                            // Latch word 0 and advance address to 2
                            acc_A[127:112] <= sram_a_dout;
                            acc_B[127:112] <= sram_b_dout;
                            sram_a_addr    <= 6'd2;
                            sram_b_addr    <= 6'd2;
                            count          <= 6'd2;
                        end
                        6'd2: begin
                            // Latch word 1 and advance address to 3
                            acc_A[111:96] <= sram_a_dout;
                            acc_B[111:96] <= sram_b_dout;
                            sram_a_addr   <= 6'd3;
                            sram_b_addr   <= 6'd3;
                            count         <= 6'd3;
                        end
                        6'd3: begin
                            // Latch word 2 and advance address to 4
                            acc_A[95:80] <= sram_a_dout;
                            acc_B[95:80] <= sram_b_dout;
                            sram_a_addr  <= 6'd4;
                            sram_b_addr  <= 6'd4;
                            count        <= 6'd4;
                        end
                        6'd4: begin
                            // Latch word 3 and advance address to 5
                            acc_A[79:64] <= sram_a_dout;
                            acc_B[79:64] <= sram_b_dout;
                            sram_a_addr  <= 6'd5;
                            sram_b_addr  <= 6'd5;
                            count        <= 6'd5;
                        end
                        6'd5: begin
                            // Latch word 4 and advance address to 6
                            acc_A[63:48] <= sram_a_dout;
                            acc_B[63:48] <= sram_b_dout;
                            sram_a_addr  <= 6'd6;
                            sram_b_addr  <= 6'd6;
                            count        <= 6'd6;
                        end
                        6'd6: begin
                            // Latch word 5 and advance address to 7
                            acc_A[47:32] <= sram_a_dout;
                            acc_B[47:32] <= sram_b_dout;
                            sram_a_addr  <= 6'd7;
                            sram_b_addr  <= 6'd7;
                            count        <= 6'd7;
                        end
                        6'd7: begin
                            // Latch word 6; all 8 addresses have been requested, deassert ren
                            acc_A[31:16] <= sram_a_dout;
                            acc_B[31:16] <= sram_b_dout;
                            sram_a_ren   <= 1'b0;
                            sram_b_ren   <= 1'b0;
                            count        <= 6'd8;
                        end
                        6'd8: begin
                            // Latch final word 7; start accelerator computation
                            acc_A[15:0]   <= sram_a_dout;
                            acc_B[15:0]   <= sram_b_dout;
                            count         <= 6'd0;
                            acc_start     <= 1'b1;
                            acc_df_policy <= df_policy;
                            state         <= S_START_ACC;
                        end
                        default: begin
                            state <= S_IDLE;
                        end
                    endcase
                end

                S_START_ACC: begin
                    acc_start <= 1'b0;
                    state     <= S_WAIT_ACC;
                end

                S_WAIT_ACC: begin
                    if (acc_done) begin
                        c_reg       <= acc_C;
                        count       <= 6'd0;
                        sram_c_addr <= 6'd0;
                        sram_c_din  <= get_sram_c_word(acc_C, 5'd0);
                        sram_c_wen  <= 1'b1;
                        state       <= S_WRITE_C;
                    end
                end

                S_WRITE_C: begin
                    // Write words 0 to 31 into SRAM C
                    if (count < 6'd31) begin
                        count       <= count + 1'b1;
                        sram_c_addr <= count + 1'b1;
                        sram_c_din  <= get_sram_c_word(c_reg, count[4:0] + 5'd1);
                        sram_c_wen  <= 1'b1;
                    end else begin
                        sram_c_wen <= 1'b0;
                        state      <= S_DONE;
                    end
                end

                S_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
