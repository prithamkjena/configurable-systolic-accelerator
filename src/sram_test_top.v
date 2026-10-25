/*
 * Standalone self-test for two IHP SG13G2 512x32 SRAM macros.
 * SRAM_A and SRAM_B intentionally retain their physical instance names.
 */
`default_nettype none

module tt_um_prithamkjena (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ------------------------------------------------------------
    // SRAM interface
    // ------------------------------------------------------------

    reg         sram_wen;
    reg         sram_ren;
    reg  [8:0]  sram_addr;
    reg  [31:0] sram_din;
    wire [31:0] sram_a_dout;
    wire [31:0] sram_b_dout;

    wire [31:0] sram_bm = 32'hFFFFFFFF;

    // ------------------------------------------------------------
    // SRAM A: 512 words x 32 bits
    // ------------------------------------------------------------

    RM_IHPSG13_1P_512x32_c2_bm_bist SRAM_A (
        .A_CLK       (clk),
        .A_MEN       (sram_ren | sram_wen),
        .A_WEN       (sram_wen),
        .A_REN       (sram_ren),
        .A_ADDR      (sram_addr),
        .A_DIN       (sram_din),
        .A_DLY       (1'b1),
        .A_DOUT      (sram_a_dout),
        .A_BM        (sram_bm),
        .A_BIST_CLK  (1'b0),
        .A_BIST_EN   (1'b0),
        .A_BIST_MEN  (1'b0),
        .A_BIST_WEN  (1'b0),
        .A_BIST_REN  (1'b0),
        .A_BIST_ADDR (9'b0),
        .A_BIST_DIN  (32'b0),
        .A_BIST_BM   (32'b0)
    );

    // ------------------------------------------------------------
    // SRAM B: 512 words x 32 bits
    // ------------------------------------------------------------

    RM_IHPSG13_1P_512x32_c2_bm_bist SRAM_B (
        .A_CLK       (clk),
        .A_MEN       (sram_ren | sram_wen),
        .A_WEN       (sram_wen),
        .A_REN       (sram_ren),
        .A_ADDR      (sram_addr),
        .A_DIN       (sram_din),
        .A_DLY       (1'b1),
        .A_DOUT      (sram_b_dout),
        .A_BM        (sram_bm),
        .A_BIST_CLK  (1'b0),
        .A_BIST_EN   (1'b0),
        .A_BIST_MEN  (1'b0),
        .A_BIST_WEN  (1'b0),
        .A_BIST_REN  (1'b0),
        .A_BIST_ADDR (9'b0),
        .A_BIST_DIN  (32'b0),
        .A_BIST_BM   (32'b0)
    );

    // ------------------------------------------------------------
    // Test controller
    // ------------------------------------------------------------

    localparam [2:0]
        ST_WRITE = 3'd0,
        ST_READ  = 3'd1,
        ST_CHECK = 3'd2,
        ST_DONE  = 3'd3;

    reg [2:0] state;
    reg [8:0] test_addr;
    reg [1:0] pattern;

    reg fail_a;
    reg fail_b;

    // Expected data for each test pattern.
    function [31:0] expected_data;
        input [8:0]  addr;
        input [1:0]  pat;
        begin
            case (pat)
                2'd0: expected_data = 32'h00000000;
                2'd1: expected_data = 32'hFFFFFFFF;
                2'd2: expected_data = 32'hAAAAAAAA;
                2'd3: expected_data = {
                    7'b0, addr, 7'b0, ~addr
                };
                default: expected_data = 32'h00000000;
            endcase
        end
    endfunction

    // Drive the SRAM interface from the current controller state.
    always @(*) begin
        sram_wen  = 1'b0;
        sram_ren  = 1'b0;
        sram_addr = test_addr;
        sram_din  = expected_data(test_addr, pattern);

        case (state)
            ST_WRITE: sram_wen = 1'b1;
            ST_READ:  sram_ren = 1'b1;
            default: begin
                sram_wen = 1'b0;
                sram_ren = 1'b0;
            end
        endcase
    end

    // ------------------------------------------------------------
    // BIST sequence
    //
    // For each pattern:
    //   1. Write all 512 addresses.
    //   2. Read all 512 addresses.
    //   3. Check each synchronous read result.
    //
    // SRAM_A and SRAM_B are checked independently.
    // ------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_WRITE;
            test_addr <= 9'd0;
            pattern   <= 2'd0;
            fail_a    <= 1'b0;
            fail_b    <= 1'b0;
        end else begin
            case (state)

                ST_WRITE: begin
                    if (test_addr == 9'd511) begin
                        test_addr <= 9'd0;
                        state     <= ST_READ;
                    end else begin
                        test_addr <= test_addr + 1'b1;
                    end
                end

                ST_READ: begin
                    // The SRAM captures this address on this clock.
                    // Check its registered output in the next state.
                    state <= ST_CHECK;
                end

                ST_CHECK: begin
                    if (sram_a_dout !== expected_data(test_addr, pattern))
                        fail_a <= 1'b1;

                    if (sram_b_dout !== expected_data(test_addr, pattern))
                        fail_b <= 1'b1;

                    if (test_addr == 9'd511) begin
                        test_addr <= 9'd0;

                        if (pattern == 2'd3) begin
                            state <= ST_DONE;
                        end else begin
                            pattern <= pattern + 1'b1;
                            state   <= ST_WRITE;
                        end
                    end else begin
                        test_addr <= test_addr + 1'b1;
                        state     <= ST_READ;
                    end
                end

                ST_DONE: begin
                    state <= ST_DONE;
                end

                default: begin
                    state <= ST_WRITE;
                    test_addr <= 9'd0;
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // Tiny Tapeout output mapping
    //
    // uo_out[0]   = BIST done
    // uo_out[1]   = SRAM_A failure
    // uo_out[2]   = SRAM_B failure
    // uo_out[4:3] = Current pattern
    // ------------------------------------------------------------

    assign uo_out[0]   = (state == ST_DONE);
    assign uo_out[1]   = fail_a;
    assign uo_out[2]   = fail_b;
    assign uo_out[4:3] = pattern;
    assign uo_out[7:5] = 3'b000;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule

`default_nettype wire