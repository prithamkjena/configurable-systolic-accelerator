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

  // Reserved IHP 64x16 SRAM macro.
  // Keep the macro instantiated but inactive for now.
  (* keep *) wire [15:0] sram_dout_unused;

  (* keep *)
  RM_IHPSG13_1P_64x16_c2 i_sram (
      .A_CLK  (clk),
      .A_MEN  (1'b0),
      .A_WEN  (1'b0),
      .A_REN  (1'b0),
      .A_ADDR (6'b0),
      .A_DIN  (16'b0),
      .A_DLY  (1'b1),
      .A_DOUT (sram_dout_unused)
  );

  assign uo_out = ui_in + uio_in;
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;
  
endmodule
