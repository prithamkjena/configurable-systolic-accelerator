module systolic_acc_top(
    input clk,
    input rst_n,
    input start,
    input [1:0] df_policy,

    input [127:0] A,
    input [127:0] B,
    output wire signed [17:0] result_data,
    output wire [3:0] result_idx,
    output wire result_valid,
    input  wire result_ready,
    output done
);
    localparam OS = 2'b00;
    localparam WS = 2'b01;
    localparam IS = 2'b10;
    
    wire load_buffers_A, load_buffers_B, store_output; // Control Lines
    systolic_acc_control control(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .df_policy(df_policy),
        .load_buffers_A(load_buffers_A),
        .load_buffers_B(load_buffers_B),
        .store_output(store_output),
        .done(done)
    );
    
    wire signed [7:0] data_out_A [0:3];
    wire signed [7:0] data_out_B [0:3];
    genvar i;
    generate
        for (i=1; i<=4; i=i+1) begin: SB
            wire [1:0] s_idx = i[1:0] - 2'd1;
            stream_buffer A_buffer(
                .clk(clk),
                .rst_n(rst_n),
                .load(load_buffers_A),
                .matrix((df_policy == IS) ? B : A),
                .stream_idx(s_idx),
                .transpose(
                    (df_policy == WS) ? 1'b1 : 1'b0
                ),
                .data_out(data_out_A[i-1])
            );
            stream_buffer B_buffer(
                .clk(clk),
                .rst_n(rst_n),
                .load(load_buffers_B),
                .matrix(B),
                .stream_idx(s_idx),
                .transpose(1'b1),
                .data_out(data_out_B[i-1])
            );
        end
    endgenerate
    
    wire [287:0] accum;
    wire signed [17:0] psum1_out, psum2_out, psum3_out, psum4_out;
    wire [127:0] A_transpose;

    assign A_transpose = {
        A[127:120], // A00
        A[95:88],   // A10
        A[63:56],   // A20
        A[31:24],   // A30
    
        A[119:112], // A01
        A[87:80],   // A11
        A[55:48],   // A21
        A[23:16],   // A31
    
        A[111:104], // A02
        A[79:72],   // A12
        A[47:40],   // A22
        A[15:8],    // A32
    
        A[103:96],  // A03
        A[71:64],   // A13
        A[39:32],   // A23
        A[7:0]      // A33
    };
    
    pe_array datapath(
        .clk(clk),
        .rst_n(rst_n),
        .clear_accum(load_buffers_A),
        .df_policy(df_policy),
        .A1_in(data_out_A[0]),
        .A2_in(data_out_A[1]),
        .A3_in(data_out_A[2]),
        .A4_in(data_out_A[3]),
        .B1_in(data_out_B[0]),
        .B2_in(data_out_B[1]),
        .B3_in(data_out_B[2]),
        .B4_in(data_out_B[3]),
        .psum1_out(psum1_out),
        .psum2_out(psum2_out),
        .psum3_out(psum3_out),
        .psum4_out(psum4_out),
        .stationary(
            (df_policy == IS) ? A_transpose : B 
        ),
        .accum(accum)
    );
    
endmodule
