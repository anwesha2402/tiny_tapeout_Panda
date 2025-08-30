`timescale 1ns / 1ps

module iz_data_loader (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire serial_data_in,
    input wire load_enable,
    output reg signed [15:0] param_a,
    output reg signed [15:0] param_b,
    output reg signed [15:0] param_c,
    output reg signed [15:0] param_d,
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
reg [15:0] shift_reg;
reg [4:0] bit_count;  // 5 bits to handle 16-bit parameters
reg [2:0] state;
reg load_enable_prev;

// Edge detection
wire load_enable_rising = load_enable & ~load_enable_prev;

// Default IZ parameters (Regular Spiking neuron)
localparam signed [15:0] DEFAULT_A = 16'sd51;      // 0.2 * 256
localparam signed [15:0] DEFAULT_B = 16'sd51;      // 0.2 * 256  
localparam signed [15:0] DEFAULT_C = -16'sd16640;  // -65 * 256
localparam signed [15:0] DEFAULT_D = 16'sd512;     // 2 * 256

always @(posedge clk) begin
    if (reset)
        load_enable_prev <= 1'b0;
    else
        load_enable_prev <= load_enable;
end

// Corrected state machine with proper 16-bit loading
always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        shift_reg <= 16'd0;
        bit_count <= 5'd0;
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
                    bit_count <= 5'd0;
                    shift_reg <= 16'd0;
                    params_ready <= 1'b0;
//                    $display("LOADER: Starting parameter loading");
                end
            end
            
            LOAD_A: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[14:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 5'd15) begin
                        param_a <= {shift_reg[14:0], serial_data_in};
                        state <= LOAD_B;
                        bit_count <= 5'd0;
                        shift_reg <= 16'd0;
//                        $display("LOADER: param_a loaded = %d", {shift_reg[14:0], serial_data_in});
                    end
                end
            end
            
            LOAD_B: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[14:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 5'd15) begin
                        param_b <= {shift_reg[14:0], serial_data_in};
                        state <= LOAD_C;
                        bit_count <= 5'd0;
                        shift_reg <= 16'd0;
//                        $display("LOADER: param_b loaded = %d", {shift_reg[14:0], serial_data_in});
                    end
                end
            end
            
            LOAD_C: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[14:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 5'd15) begin
                        param_c <= {shift_reg[14:0], serial_data_in};
                        state <= LOAD_D;
                        bit_count <= 5'd0;
                        shift_reg <= 16'd0;
                        $display("LOADER: param_c loaded = %d", $signed({shift_reg[14:0], serial_data_in}));
                    end
                end
            end
            
            LOAD_D: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[14:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 5'd15) begin
                        param_d <= {shift_reg[14:0], serial_data_in};
                        state <= READY;
                        params_ready <= 1'b1;
//                        $display("LOADER: param_d loaded = %d", {shift_reg[14:0], serial_data_in});
//                        $display("LOADER: All parameters loaded!");
                    end
                end
            end
            
            READY: begin
                if (load_enable_rising) begin
                    state <= LOAD_A;
                    bit_count <= 5'd0;
                    shift_reg <= 16'd0;
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
