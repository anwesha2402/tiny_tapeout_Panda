// lif_neuron.v
// A Leaky Integrate-and-Fire (LIF) neuron model with single input channel
// The threshold is fixed and does not adapt

`timescale 1ns / 1ps

module lif_neuron (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Input channels - INCREASED PRECISION
    input wire [5:0] chan_a,  // 6-bit precision (0-63)

    // Configuration from loader
    input wire [2:0] weight,
    input wire [1:0] leak_config,
    input wire [7:0] threshold,
    input wire params_ready,
    
    // Outputs
    output reg spike_out,
    output wire [6:0] v_mem_out  // 7-bit membrane potential output
);

// LIF parameters (adjusted for higher precision inputs)
parameter V_BITS = 8;
parameter REFRAC_PERIOD = 4'd4; // Fixed refractory period

// State registers
reg [V_BITS-1:0] v_mem = 0;           // Membrane potential 0-255
// reg [V_BITS-1:0] threshold = threshold;           // threshold
reg [3:0] refr_cnt = 0;               // Refractory counter

// Decode leak rate from configuration
reg [2:0] leak_rate;
always @(*) begin

    case (leak_config)
        2'b00: leak_rate = 3'd0; // No leak
        2'b01: leak_rate = 3'd2; // Minimal leak
        2'b10: leak_rate = 3'd4; // Moderate leak
        default: leak_rate = 3'd1; // Default leak
    endcase
end

wire [2:0] eff_weight = weight; // No depression for single channel
wire [6:0] weighted_sum = chan_a * eff_weight; // Single channel contribution
// Membrane potential output (map to 7 bits)
assign v_mem_out = v_mem[7:1]; // Upper 7 bits for output
reg [8:0] new_v; // 9-bit temporary for overflow prevention

// Main LIF dynamics
always @(posedge clk) begin
    if (reset) begin
        v_mem <= 8'd0;
        // threshold <= threshold;
        refr_cnt <= 4'd0;
        spike_out <= 1'b0;
    end else if (enable && params_ready) begin
        // Refractory period handling
        if (refr_cnt != 0) begin
            refr_cnt <= refr_cnt - 1;
            spike_out <= 1'b0;
            
            // Apply leak during refractory
            if (v_mem > leak_rate)
                v_mem <= v_mem - leak_rate;
            else
                v_mem <= 8'd0;
        end else begin
            // Normal operation: integrate and leak
            
            // Integration with leak - ADJUSTED FOR HIGHER INPUT PRECISION
            new_v = v_mem + weighted_sum - leak_rate;
            
            // Prevent underflow
            if (new_v[8]) // Negative (underflow)
                new_v = 9'd0;
            
            // Prevent overflow
            if (new_v > 255)
                new_v = 255;
            
            // Spike detection
            if (new_v >= threshold) begin
                spike_out <= 1'b1;
                v_mem <= 8'd0;  // Reset membrane potential
                refr_cnt <= REFRAC_PERIOD;
                                
            end else begin
                spike_out <= 1'b0;
                v_mem <= new_v[7:0];
                               
            end
        end
    end else begin
        // Hold state when disabled or params not ready
        spike_out <= 1'b0;
    end
end

endmodule


