`timescale 1ns/1ps

module sram_16x8_tb;

    reg clk;

    reg A_MEN;
    reg A_WEN;
    reg A_REN;
    reg [3:0] A_ADDR;
    reg signed [7:0] A_DIN;
    reg A_DLY;

    wire signed [7:0] A_DOUT;

    reg signed [7:0] expected [0:15];

    integer i;

    sram_16x8 dut (
        .A_CLK  (clk),
        .A_MEN  (A_MEN),
        .A_WEN  (A_WEN),
        .A_REN  (A_REN),
        .A_ADDR (A_ADDR),
        .A_DIN  (A_DIN),
        .A_DLY  (A_DLY),
        .A_DOUT (A_DOUT)
    );

    // 100 MHz simulation clock.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin

        A_MEN  = 1'b0;
        A_WEN  = 1'b0;
        A_REN  = 1'b0;
        A_ADDR = 4'b0;
        A_DIN  = 8'b0;
        A_DLY  = 1'b1;

        // --------------------------------------------------
        // Phase 1: write all 16 memory locations.
        // --------------------------------------------------

        for (i = 0; i < 16; i = i + 1) begin

            @(negedge clk);

            A_MEN  = 1'b1;
            A_WEN  = 1'b1;
            A_REN  = 1'b0;
            A_ADDR = i;
            A_DIN  = (i * 16) - 120;

            expected[i] = (i * 16) - 120;

            @(posedge clk);
            #1;

        end

        // --------------------------------------------------
        // Phase 2: read all 16 locations and compare.
        // --------------------------------------------------

        for (i = 0; i < 16; i = i + 1) begin

            @(negedge clk);

            A_MEN  = 1'b1;
            A_WEN  = 1'b0;
            A_REN  = 1'b1;
            A_ADDR = i;

            @(posedge clk);
            #1;

            if (A_DOUT !== expected[i]) begin

                $display(
                    "FAIL: address=%0d expected=%0d got=%0d",
                    i,
                    expected[i],
                    A_DOUT
                );

                $fatal(1, "SRAM readback mismatch");

            end

        end

        $display("PASS: all 16 signed bytes written and read correctly");

        $finish;

    end

endmodule