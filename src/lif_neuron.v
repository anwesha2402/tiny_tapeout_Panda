`timescale 1ns / 1ps

module lif_basic_single_neuron (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    input wire input_enable,  // Input enable control
    
    // Single input channel
    input wire [5:0] chan_a,  // 6-bit precision (0-7)
    
    // Configuration from loader
    input wire [2:0] weight_a,
    input wire [7:0] leak_rate,           // Single leak rate
    input wire [7:0] threshold,           // Fixed threshold (non-adaptive)
    input wire [3:0] leak_cycles,         // Cycles for leak operation
    input wire params_ready,
    
    // Outputs
    output reg spike_out,
    output wire [6:0] v_mem_out  // 7-bit membrane potential output
);

// LIF parameters
parameter V_BITS = 8;
parameter REFRAC_PERIOD = 4'd4;    // Fixed refractory period

// State registers
reg signed [V_BITS:0] v_mem = 0;     // Membrane potential (9-bit signed)
reg [3:0] refr_cnt = 0;              // Refractory counter
reg [3:0] leak_counter = 0;          // Counter for leak cycles

// Input contribution (single channel only - no subtraction)
wire signed [8:0] contrib_a = chan_a * weight_a;  // Direct weight usage - no depression
wire signed [8:0] weighted_sum = contrib_a;       // Simple assignment (no chan_b)

// Membrane potential output (map to 7 bits, ensure positive)
assign v_mem_out = (v_mem > 0) ? v_mem[6:0] : 7'd0;

// Temporary variable for membrane potential calculation
reg signed [V_BITS:0] new_v; // 9-bit signed temporary

// Single leak application flag
wire apply_leak = (leak_counter >= leak_cycles);

// Main LIF dynamics with single channel, fixed threshold, and single leakage
always @(posedge clk) begin
    if (reset) begin
        v_mem <= 9'd0;
        refr_cnt <= 4'd0;
        spike_out <= 1'b0;
        leak_counter <= 4'd0;
    end else if (enable && params_ready) begin
        // Increment leak counter
        leak_counter <= leak_counter + 1;
        
        // Reset counter when it reaches leak_cycles
        if (apply_leak) leak_counter <= 4'd0;
        
        // Refractory period handling - SIMPLIFIED
        if (refr_cnt != 0) begin
            refr_cnt <= refr_cnt - 1;
            spike_out <= 1'b0;
            // NO leakage, NO processing - pure silence
            
        end else if (input_enable) begin
            // Normal operation: integrate and leak
            
            // Integration with input (single channel)
            new_v = v_mem + weighted_sum;
            
            // Apply single leakage
            if (apply_leak) begin
                new_v = new_v - leak_rate;
            end
            
            // Prevent underflow (negative membrane potential)
            if (new_v < 0)
                new_v = 9'd0;
            
            // Prevent overflow
            if (new_v > 255)
                new_v = 255;
            
            // Spike detection (FIXED THRESHOLD - NO ADAPTATION)
            if (new_v >= threshold) begin
                spike_out <= 1'b1;
                v_mem <= 9'd0;  // Reset membrane potential
                refr_cnt <= REFRAC_PERIOD;
            end else begin
                spike_out <= 1'b0;
                v_mem <= new_v;
            end
        end else begin
            // input_enable is low, hold current state
            spike_out <= 1'b0;
        end
    end else begin
        // Hold state when disabled or params not ready
        spike_out <= 1'b0;
    end
end

endmodule
