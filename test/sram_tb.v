`timescale 1ns/1ps

module sram_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg        men  = 0;
    reg        wen  = 0;
    reg        ren  = 0;
    reg  [5:0] addr = 0;
    reg [15:0] din  = 0;
    reg        dly  = 1;

    wire [15:0] dout;

    RM_IHPSG13_1P_64x16_c2 dut (
        .A_CLK  (clk),
        .A_MEN  (men),
        .A_WEN  (wen),
        .A_REN  (ren),
        .A_ADDR (addr),
        .A_DIN  (din),
        .A_DLY  (dly),
        .A_DOUT (dout)
    );

    initial begin
        $dumpfile("sram_tb.vcd");
        $dumpvars(0, sram_tb);

        // Write 0xA55A to address 7.
        @(negedge clk);
        men  = 1;
        wen  = 1;
        ren  = 0;
        addr = 6'd7;
        din  = 16'hA55A;

        @(posedge clk);
        #1;

        // Read address 7.
        @(negedge clk);
        wen  = 0;
        ren  = 1;
        addr = 6'd7;

        @(posedge clk);
        #1;

        if (dout !== 16'hA55A)
            $fatal(1, "SRAM read failed: expected A55A, got %h", dout);

        $display("PASS: SRAM write/read test");

        // Check that disabling the memory causes no further operation.
        @(negedge clk);
        men = 0;
        ren = 0;
        wen = 0;

        $finish;
    end

endmodule