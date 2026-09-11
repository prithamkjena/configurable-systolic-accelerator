`timescale 1ns / 1ps

module systolic_acc_control(
    input clk,
    input rst,
    input start,
    input [1:0] df_policy,
    
    output reg load_buffers_A,
    output reg load_buffers_B,
    output reg store_output
);
    localparam OS = 2'b00;
    localparam WS = 2'b01;
    localparam IS = 2'b10;
    
    // FSM States
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam LOAD_BUFFERS = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b011;
    
    reg [3:0] compute_count;
    
    always @(*) begin
        load_buffers_A = 0;
        load_buffers_B = 0;
        store_output = 0;
        case(state) 
            IDLE: begin
            end
            LOAD_BUFFERS: begin
                if (df_policy == OS) begin
                    load_buffers_A = 1;
                    load_buffers_B = 1;
                end
                else begin
                    load_buffers_A = 1;
                end
            end
            COMPUTE: begin
                if (df_policy != OS && compute_count >= 4 && compute_count <= 10) begin
                    store_output = 1; // For WS/IS the output starts appearing from 4th clock cycle onwards...
                end
                else begin
                    store_output = 0;
                end
            end
            OUTPUT: begin
                store_output = 1; // For OS, the final output appears after all 10 clock cycles...
                                  // For WS/IS, one clock cycle extra to capture the cornermost element...
            end
            default: begin
            end
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            compute_count <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    compute_count <= 0;
                    if (!start) begin
                        state <= IDLE;
                    end
                    else begin
                        state <= LOAD_BUFFERS;
                    end
                end
                LOAD_BUFFERS: begin
                    state <= COMPUTE;
                end
                COMPUTE: begin
                    compute_count <= compute_count + 1;

                    if (compute_count == 4'd9)
                        state <= OUTPUT;
                    else
                        state <= COMPUTE;
                end
                OUTPUT: begin
                    compute_count <= 0;
                    state <= IDLE;
                end
                default: begin
                    compute_count <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
