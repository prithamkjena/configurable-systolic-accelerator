/*
 * Standalone self-test for the three IHP SG13G2 64x16 SRAM macros.
 * The macro instance names SRAM_A, SRAM_B and SRAM_C intentionally match
 * the fixed locations in the project's LibreLane configuration.
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

    // The host data pins are unused: the BIST runs automatically after reset.
    wire _unused_inputs = ena ^ (^ui_in) ^ (^uio_in);

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_WRITE     = 3'd1;
    localparam [2:0] ST_READ      = 3'd2;
    localparam [2:0] ST_READ_LAST = 3'd3;
    localparam [2:0] ST_DONE      = 3'd4;

    reg [2:0] state;
    reg [5:0] addr;
    reg [5:0] pending_addr;
    reg [1:0] pattern_id;
    reg       read_valid;
    reg       fail_a;
    reg       fail_b;
    reg       fail_c;

    // Patterns cover all-zero, all-one, checkerboard and address-dependent data.
    // The address-dependent pattern makes every address distinguishable, while
    // different bank constants ensure the three macros do not share test data.
    function [15:0] make_pattern;
        input [5:0] address;
        input [1:0] pattern_sel;
        input [1:0] bank_sel;
        reg [15:0] address_pattern;
        begin
            address_pattern = {address, address, address[3:0]};
            case (pattern_sel)
                2'd0: make_pattern = 16'h0000;
                2'd1: make_pattern = 16'hFFFF;
                2'd2: begin
                    case (bank_sel)
                        2'd0: make_pattern = 16'hAAAA;
                        2'd1: make_pattern = 16'h5555;
                        default: make_pattern = 16'h9696;
                    endcase
                end
                default: begin
                    case (bank_sel)
                        2'd0: make_pattern = address_pattern ^ 16'hA5C3;
                        2'd1: make_pattern = address_pattern ^ 16'h3C5A;
                        default: make_pattern = address_pattern ^ 16'h5AA5;
                    endcase
                end
            endcase
        end
    endfunction


    wire [15:0] sram_a_dout;
    wire [15:0] sram_b_dout;
    wire [15:0] sram_c_dout;

    wire        sram_wen = (state == ST_WRITE);
    wire        sram_ren = (state == ST_READ) || (state == ST_READ_LAST);

    wire [15:0] sram_a_din = make_pattern(addr, pattern_id, 2'd0);
    wire [15:0] sram_b_din = make_pattern(addr, pattern_id, 2'd1);
    wire [15:0] sram_c_din = make_pattern(addr, pattern_id, 2'd2);

    // Keep these instance names identical to config.json's MACROS.instances.
    RM_IHPSG13_1P_64x16_c2 SRAM_A (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (sram_wen),
        .A_REN  (sram_ren),
        .A_ADDR (addr),
        .A_DIN  (sram_a_din),
        .A_DLY  (1'b1),
        .A_DOUT (sram_a_dout)
    );

    RM_IHPSG13_1P_64x16_c2 SRAM_B (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (sram_wen),
        .A_REN  (sram_ren),
        .A_ADDR (addr),
        .A_DIN  (sram_b_din),
        .A_DLY  (1'b1),
        .A_DOUT (sram_b_dout)
    );

    RM_IHPSG13_1P_64x16_c2 SRAM_C (
        .A_CLK  (clk),
        .A_MEN  (1'b1),
        .A_WEN  (sram_wen),
        .A_REN  (sram_ren),
        .A_ADDR (addr),
        .A_DIN  (sram_c_din),
        .A_DLY  (1'b1),
        .A_DOUT (sram_c_dout)
    );

    // Status pins:
    // uo_out[0] = BIST complete
    // uo_out[1] = SRAM_A readback failure
    // uo_out[2] = SRAM_B readback failure
    // uo_out[3] = SRAM_C readback failure
    // uo_out[5:4] = current pattern pass (0 through 3)
    assign uo_out  = {2'b00, pattern_id, fail_c, fail_b, fail_a,
                      (state == ST_DONE)};
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            addr         <= 6'd0;
            pending_addr <= 6'd0;
            pattern_id   <= 2'd0;
            read_valid   <= 1'b0;
            fail_a       <= 1'b0;
            fail_b       <= 1'b0;
            fail_c       <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    addr         <= 6'd0;
                    pending_addr <= 6'd0;
                    pattern_id   <= 2'd0;
                    read_valid   <= 1'b0;
                    state        <= ST_WRITE;
                end

                // Write all 64 addresses in all three macros for this pattern.
                ST_WRITE: begin
                    if (addr == 6'd63) begin
                        addr         <= 6'd0;
                        pending_addr <= 6'd0;
                        read_valid   <= 1'b0;
                        state        <= ST_READ;
                    end else begin
                        addr <= addr + 1'b1;
                    end
                end

                // Synchronous-read pipeline: compare the previous address while
                // the SRAMs return the data for the currently presented address.
                ST_READ: begin
                    if (read_valid) begin
                        if (sram_a_dout !== make_pattern(pending_addr, pattern_id, 2'd0))
                            fail_a <= 1'b1;
                        if (sram_b_dout !== make_pattern(pending_addr, pattern_id, 2'd1))
                            fail_b <= 1'b1;
                        if (sram_c_dout !== make_pattern(pending_addr, pattern_id, 2'd2))
                            fail_c <= 1'b1;
                    end

                    read_valid   <= 1'b1;
                    pending_addr <= addr;
                    if (addr == 6'd63) begin
                        state <= ST_READ_LAST;
                    end else begin
                        addr <= addr + 1'b1;
                    end
                end

                // Check address 63 after its synchronous SRAM read completes.
                ST_READ_LAST: begin
                    if (sram_a_dout !== make_pattern(pending_addr, pattern_id, 2'd0))
                        fail_a <= 1'b1;
                    if (sram_b_dout !== make_pattern(pending_addr, pattern_id, 2'd1))
                        fail_b <= 1'b1;
                    if (sram_c_dout !== make_pattern(pending_addr, pattern_id, 2'd2))
                        fail_c <= 1'b1;

                    if (pattern_id == 2'd3) begin
                        state <= ST_DONE;
                    end else begin
                        pattern_id <= pattern_id + 1'b1;
                        addr       <= 6'd0;
                        read_valid <= 1'b0;
                        state      <= ST_WRITE;
                    end
                end

                ST_DONE: begin
                    state <= ST_DONE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
