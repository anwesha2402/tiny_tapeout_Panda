`timescale 1ns / 1ps
module iz_data_loader (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire serial_data_in,
    input wire load_enable,
    output reg signed [11:0] param_a,  // Reduced from 16-bit to 12-bit
    output reg signed [11:0] param_b,  // Reduced from 16-bit to 12-bit
    output reg signed [11:0] param_c,  // Reduced from 16-bit to 12-bit
    output reg signed [11:0] param_d,  // Reduced from 16-bit to 12-bit
    output reg params_ready
);

// State machine
localparam IDLE = 3'b000;
localparam LOAD_A = 3'b001;
localparam LOAD_B = 3'b010;
localparam LOAD_C = 3'b011;
localparam LOAD_D = 3'b100;
localparam READY = 3'b101;

// Internal registers
reg [11:0] shift_reg;           // Reduced from 16-bit to 12-bit
reg [3:0] bit_count;           // Reduced from 5 bits to 4 bits (0-11)
reg [2:0] state;
reg load_enable_prev;

// Edge detection
wire load_enable_rising = load_enable & ~load_enable_prev;

// Default IZ parameters (Regular Spiking neuron) - scaled for 12-bit
localparam signed [11:0] DEFAULT_A = 12'sd51;      // 0.2 * 256 (12-bit)
localparam signed [11:0] DEFAULT_B = 12'sd51;      // 0.2 * 256 (12-bit)  
localparam signed [11:0] DEFAULT_C = -12'sd1280;   // -65 * 20 (scaled for 12-bit)
localparam signed [11:0] DEFAULT_D = 12'sd512;     // 2 * 256 (12-bit)

always @(posedge clk) begin
    if (reset)
        load_enable_prev <= 1'b0;
    else
        load_enable_prev <= load_enable;
end

// State machine with 12-bit loading
always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        shift_reg <= 12'd0;
        bit_count <= 4'd0;
        param_a <= DEFAULT_A;
        param_b <= DEFAULT_B;
        param_c <= DEFAULT_C;
        param_d <= DEFAULT_D;
        params_ready <= 1'b1;
    end else if (enable) begin
        case (state)
            IDLE: begin
                if (load_enable_rising) begin
                    state <= LOAD_A;
                    bit_count <= 4'd0;
                    shift_reg <= 12'd0;
                    params_ready <= 1'b0;
                end
            end
            
            LOAD_A: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[10:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 4'd11) begin  // Load 12 bits (0-11)
                        param_a <= {shift_reg[10:0], serial_data_in};
                        state <= LOAD_B;
                        bit_count <= 4'd0;
                        shift_reg <= 12'd0;
                    end
                end
            end
            
            LOAD_B: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[10:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 4'd11) begin
                        param_b <= {shift_reg[10:0], serial_data_in};
                        state <= LOAD_C;
                        bit_count <= 4'd0;
                        shift_reg <= 12'd0;
                    end
                end
            end
            
            LOAD_C: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[10:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 4'd11) begin
                        param_c <= {shift_reg[10:0], serial_data_in};
                        state <= LOAD_D;
                        bit_count <= 4'd0;
                        shift_reg <= 12'd0;
                    end
                end
            end
            
            LOAD_D: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[10:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 4'd11) begin
                        param_d <= {shift_reg[10:0], serial_data_in};
                        state <= READY;
                        params_ready <= 1'b1;
                    end
                end
            end
            
            READY: begin
                if (load_enable_rising) begin
                    state <= LOAD_A;
                    bit_count <= 4'd0;
                    shift_reg <= 12'd0;
                    params_ready <= 1'b0;
                end else if (!load_enable) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end
endmodule
