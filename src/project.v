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

    // Prevent unused input lint warning
    wire _unused_ena = ena;

    // -------------------------------------------------------------
    // SRAM Signals
    // -------------------------------------------------------------
    wire [5:0]  sram_a_addr;
    wire [15:0] sram_a_din;
    wire        sram_a_wen;
    wire        sram_a_ren;
    wire [15:0] sram_a_dout;

    wire [5:0]  sram_b_addr;
    wire [15:0] sram_b_din;
    wire        sram_b_wen;
    wire        sram_b_ren;
    wire [15:0] sram_b_dout;

    wire [5:0]  sram_c_addr;
    wire [15:0] sram_c_din;
    wire        sram_c_wen;
    wire        sram_c_ren;
    wire [15:0] sram_c_dout;

    // -------------------------------------------------------------
    // Controller <-> Bridge Signals
    // -------------------------------------------------------------
    wire        bridge_start;
    wire [1:0]  df_policy;
    wire        bridge_busy;
    wire        bridge_done;

    // Controller SRAM interfaces
    wire [5:0]  sram_a_addr_io;
    wire [15:0] sram_a_din_io;
    wire        sram_a_wen_io;
    wire        sram_a_ren_io;

    wire [5:0]  sram_b_addr_io;
    wire [15:0] sram_b_din_io;
    wire        sram_b_wen_io;
    wire        sram_b_ren_io;

    wire [5:0]  sram_c_addr_io;
    wire        sram_c_ren_io;

    // Bridge SRAM interfaces
    wire [5:0]  sram_a_addr_br;
    wire        sram_a_ren_br;

    wire [5:0]  sram_b_addr_br;
    wire        sram_b_ren_br;

    wire [5:0]  sram_c_addr_br;
    wire [15:0] sram_c_din_br;
    wire        sram_c_wen_br;

    // Bridge <-> Systolic Core Signals
    wire         acc_start;
    wire [1:0]   acc_df_policy;
    wire [127:0] acc_A;
    wire [127:0] acc_B;
    wire [287:0] acc_C;
    wire         acc_done;

    // -------------------------------------------------------------
    // SRAM Arbitration MUX
    // -------------------------------------------------------------
    // When bridge_busy: bridge has full access to SRAMs
    // When !bridge_busy: host io_controller has access to SRAMs
    assign sram_a_addr = bridge_busy ? sram_a_addr_br : sram_a_addr_io;
    assign sram_a_din  = bridge_busy ? 16'd0          : sram_a_din_io;
    assign sram_a_wen  = bridge_busy ? 1'b0           : sram_a_wen_io;
    assign sram_a_ren  = bridge_busy ? sram_a_ren_br  : sram_a_ren_io;

    assign sram_b_addr = bridge_busy ? sram_b_addr_br : sram_b_addr_io;
    assign sram_b_din  = bridge_busy ? 16'd0          : sram_b_din_io;
    assign sram_b_wen  = bridge_busy ? 1'b0           : sram_b_wen_io;
    assign sram_b_ren  = bridge_busy ? sram_b_ren_br  : sram_b_ren_io;

    assign sram_c_addr = bridge_busy ? sram_c_addr_br : sram_c_addr_io;
    assign sram_c_din  = bridge_busy ? sram_c_din_br  : 16'd0;
    assign sram_c_wen  = bridge_busy ? sram_c_wen_br  : 1'b0;
    assign sram_c_ren  = bridge_busy ? 1'b0           : sram_c_ren_io;

    // -------------------------------------------------------------
    // Submodule Instantiations
    // -------------------------------------------------------------
    io_controller ctrl (
        .clk            (clk),
        .rst_n          (rst_n),
        .ui_in          (ui_in),
        .uo_out         (uo_out),
        .uio_in         (uio_in),
        .uio_out        (uio_out),
        .uio_oe         (uio_oe),
        .sram_a_addr_io (sram_a_addr_io),
        .sram_a_din_io  (sram_a_din_io),
        .sram_a_wen_io  (sram_a_wen_io),
        .sram_a_ren_io  (sram_a_ren_io),
        .sram_a_dout    (sram_a_dout),
        .sram_b_addr_io (sram_b_addr_io),
        .sram_b_din_io  (sram_b_din_io),
        .sram_b_wen_io  (sram_b_wen_io),
        .sram_b_ren_io  (sram_b_ren_io),
        .sram_b_dout    (sram_b_dout),
        .sram_c_addr_io (sram_c_addr_io),
        .sram_c_ren_io  (sram_c_ren_io),
        .sram_c_dout    (sram_c_dout),
        .bridge_start   (bridge_start),
        .df_policy      (df_policy),
        .bridge_busy    (bridge_busy),
        .bridge_done    (bridge_done)
    );

    sram_acc_bridge bridge (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (bridge_start),
        .df_policy     (df_policy),
        .busy          (bridge_busy),
        .done          (bridge_done),
        .sram_a_addr   (sram_a_addr_br),
        .sram_a_ren    (sram_a_ren_br),
        .sram_a_dout   (sram_a_dout),
        .sram_b_addr   (sram_b_addr_br),
        .sram_b_ren    (sram_b_ren_br),
        .sram_b_dout   (sram_b_dout),
        .sram_c_addr   (sram_c_addr_br),
        .sram_c_din    (sram_c_din_br),
        .sram_c_wen    (sram_c_wen_br),
        .acc_start     (acc_start),
        .acc_df_policy (acc_df_policy),
        .acc_A         (acc_A),
        .acc_B         (acc_B),
        .acc_C         (acc_C),
        .acc_done      (acc_done)
    );

    systolic_acc_top systolic_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (acc_start),
        .df_policy (acc_df_policy),
        .A         (acc_A),
        .B         (acc_B),
        .C         (acc_C),
        .done      (acc_done)
    );

    // -------------------------------------------------------------
    // SRAM Macro Instantiations
    // -------------------------------------------------------------
    RM_IHPSG13_1P_64x16_c2 SRAM_A (
        .A_ADDR (sram_a_addr),
        .A_DIN  (sram_a_din),
        .A_WEN  (sram_a_wen),
        .A_MEN  (1'b1),
        .A_REN  (sram_a_ren),
        .A_CLK  (clk),
        .A_DOUT (sram_a_dout),
        .A_DLY  (1'b1)
    );

    RM_IHPSG13_1P_64x16_c2 SRAM_B (
        .A_ADDR (sram_b_addr),
        .A_DIN  (sram_b_din),
        .A_WEN  (sram_b_wen),
        .A_MEN  (1'b1),
        .A_REN  (sram_b_ren),
        .A_CLK  (clk),
        .A_DOUT (sram_b_dout),
        .A_DLY  (1'b1)
    );

    RM_IHPSG13_1P_64x16_c2 SRAM_C (
        .A_ADDR (sram_c_addr),
        .A_DIN  (sram_c_din),
        .A_WEN  (sram_c_wen),
        .A_MEN  (1'b1),
        .A_REN  (sram_c_ren),
        .A_CLK  (clk),
        .A_DOUT (sram_c_dout),
        .A_DLY  (1'b1)
    );

endmodule