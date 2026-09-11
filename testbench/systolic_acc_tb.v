`timescale 1ns / 1ps

module systolic_acc_tb();
    reg clk;
    reg rst;
    reg start;
    reg [1:0] df_policy;
    reg [127:0] A;
    reg [127:0] B;
    wire [511:0] C;
    
    systolic_acc_top dut(
        .clk(clk),
        .rst(rst),
        .start(start),
        .df_policy(df_policy),
        .A(A),
        .B(B),
        .C(C)
    );
    
    localparam OS = 2'b00;
    localparam WS = 2'b01;
    localparam IS = 2'b10;
    
    task set_matrix_A;
        input signed [7:0] a00, a01, a02, a03;
        input signed [7:0] a10, a11, a12, a13;
        input signed [7:0] a20, a21, a22, a23;
        input signed [7:0] a30, a31, a32, a33;
        begin
            A = {
                a00, a01, a02, a03,
                a10, a11, a12, a13,
                a20, a21, a22, a23,
                a30, a31, a32, a33
            };
        end
    endtask
    
    task set_matrix_B;
        input signed [7:0] b00, b01, b02, b03;
        input signed [7:0] b10, b11, b12, b13;
        input signed [7:0] b20, b21, b22, b23;
        input signed [7:0] b30, b31, b32, b33;
        begin
            B = {
                b00, b01, b02, b03,
                b10, b11, b12, b13,
                b20, b21, b22, b23,
                b30, b31, b32, b33
            };
        end
    endtask
    
    task print_C;
        integer i, j;
        begin
            $display("Output Matrix C:");
            for (i = 0; i < 4; i = i + 1) begin
                $write("[ ");
                for (j = 0; j < 4; j = j + 1) begin
                    $write("%6d ", $signed(C[32*(i*4+j) +: 32]));
                end
                $display("]");
            end
            $display("");
        end
    endtask
    
    always #5 clk = ~clk; // Clock generation
    
    initial begin
        // Initial values
        clk = 0;
        rst = 1;
        start = 0;
        df_policy = OS;
        set_matrix_A(
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        );
        set_matrix_B(
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        );
        #20;
        
        // TEST 1
        $display("TEST 1: Output Stationary");
        @(negedge clk); // Wait for next negedge
        set_matrix_A(
            1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16
        );
        
        set_matrix_B(
            1, 1, 1, 1,
            1, 1, 1, 1,
            1, 1, 1, 1,
            1, 1, 1, 1
        );
        
        rst = 0;
        df_policy = OS;
        // Give a start pulse (like a button press)
        start = 1;
        @(posedge clk);
        #1 start = 0;
        
        repeat (15) @(posedge clk); // Wait 15 clock cycles
        print_C;
        
        
        // TEST 2
        $display("TEST 2: Weight Stationary");
        rst = 1;
        @(posedge clk);
        rst = 0;
        df_policy = WS;
        // Give a start pulse (like a button press)
        start = 1;
        @(posedge clk);
        #1 start = 0;
        
        repeat (15) @(posedge clk); // Wait 15 clock cycles
        print_C;
        
        // TEST 3
        $display("TEST 3: Input Stationary");
        rst = 1;
        @(posedge clk);
        rst = 0;
        df_policy = IS;
        // Give a start pulse (like a button press)
        start = 1;
        @(posedge clk);
        #1 start = 0;
        
        repeat (15) @(posedge clk); // Wait 15 clock cycles
        print_C;
        
        $finish;
    end
endmodule
