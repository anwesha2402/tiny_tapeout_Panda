
`timescale 1ns / 1ps

module lif_data_loader (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Serial data input
    input wire serial_data_in,
    input wire load_enable,
    
    // Outputs to LIF neuron
    output reg [2:0] weight,      // w parameter
    output reg [1:0] leak_config,   // leak configuration
    output reg [7:0] threshold, // minimum threshold
    output reg params_ready         // Parameters loaded and ready
);

// State machine for parameter loading
parameter IDLE = 3'b000;
parameter LOAD_W = 3'b001;
parameter LOAD_LEAK = 3'b010;
parameter LOAD_THR = 3'b011;
parameter READY = 3'b100;

// Internal registers
reg [7:0] shift_reg;
reg [2:0] bit_count;
reg [2:0] current_state;

// Edge detection for load_enable
reg load_enable_prev;
wire load_enable_rising;

// Default parameter values
parameter DEFAULT_W = 3'd2;        // Default weight 
parameter DEFAULT_LEAK = 2'd1;      // Default leak rate
parameter DEFAULT_THR = 8'd30;      // Default threshold

assign load_enable_rising = load_enable & ~load_enable_prev;

always @(posedge clk) begin
    if (reset) begin
        load_enable_prev <= 1'b0;
    end else begin
        load_enable_prev <= load_enable;
    end
end

// State machine and serial loading logic
always @(posedge clk) begin
    if (reset) begin
        current_state <= IDLE;
        shift_reg <= 8'd0;
        bit_count <= 3'd0;
        weight <= DEFAULT_W;
        leak_config <= DEFAULT_LEAK;
        threshold <= DEFAULT_THR;
        params_ready <= 1'b1;  // Default params ready
    end else if (enable) begin
        case (current_state)
            IDLE: begin
                if (load_enable_rising) begin
                    current_state <= LOAD_W;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                end
            end

            LOAD_W: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        weight <= shift_reg[2:0]; // Use lower 3 bits
                        current_state <= LOAD_LEAK;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            
            LOAD_LEAK: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        leak_config <= shift_reg[1:0]; // Use lower 2 bits
                        current_state <= LOAD_THR;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end

            LOAD_THR: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        threshold <= shift_reg; // Full 8 bits
                        current_state <= READY;
                        params_ready <= 1'b1;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
                        
            
            READY: begin
                if (load_enable_rising) begin
                    current_state <= LOAD_W;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                end else if (!load_enable) begin
                    current_state <= IDLE;
                end
            end
            
            default: begin
                current_state <= IDLE;
            end
        endcase
    end
end

endmodule
