`timescale 1ns / 1ps

module lif_neuron_single_dualleak_neuron (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    input wire input_enable,  // Input enable control
    
    // Single input channel
    input wire [5:0] chan_a,  // 3-bit precision (0-7)
    
    // Configuration from loader
    input wire [2:0] weight_a,
    input wire [7:0] leak_rate_1,         // Primary leak rate (conditional up/down)
    input wire [7:0] leak_rate_2,         // Secondary leak rate (conditional up/down)
    input wire [7:0] threshold,           // Fixed threshold (non-adaptive)
    input wire [3:0] leak_cycles_1,       // Cycles for primary leak
    input wire [3:0] leak_cycles_2,       // Cycles for secondary leak
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
reg [3:0] leak_counter_1 = 0;        // Counter for primary leak cycles
reg [3:0] leak_counter_2 = 0;        // Counter for secondary leak cycles

// Input contribution (single channel only - no subtraction)
wire signed [8:0] contrib_a = chan_a * weight_a;  // Direct weight usage - no depression
wire signed [8:0] weighted_sum = contrib_a;       // Simple assignment (no chan_b)

// Membrane potential output (map to 7 bits, ensure positive)
assign v_mem_out = (v_mem > 0) ? v_mem[6:0] : 7'd0;

// Temporary variable for membrane potential calculation
reg signed [V_BITS:0] new_v; // 9-bit signed temporary

// Dual leak application flags
wire apply_leak_1 = (leak_counter_1 >= leak_cycles_1);
wire apply_leak_2 = (leak_counter_2 >= leak_cycles_2);

// Main LIF dynamics with single channel, fixed threshold, and conditional dual leakage
always @(posedge clk) begin
    if (reset) begin
        v_mem <= 9'd0;
        refr_cnt <= 4'd0;
        spike_out <= 1'b0;
        leak_counter_1 <= 4'd0;
        leak_counter_2 <= 4'd0;
    end else if (enable && params_ready) begin
        // Increment leak counters
        leak_counter_1 <= leak_counter_1 + 1;
        leak_counter_2 <= leak_counter_2 + 1;
        
        // Reset counters when they reach their cycles
        if (apply_leak_1) leak_counter_1 <= 4'd0;
        if (apply_leak_2) leak_counter_2 <= 4'd0;
        
        // Refractory period handling - SIMPLIFIED
        if (refr_cnt != 0) begin
            refr_cnt <= refr_cnt - 1;
            spike_out <= 1'b0;
            // NO leakage, NO processing - pure silence
            
        end else if (input_enable) begin
            // Normal operation: integrate and conditional dual leak
            
            // Integration with input (single channel)
            new_v = v_mem + weighted_sum;
            
            // Apply conditional dual leakage
            if (apply_leak_1) begin
                if (new_v < (threshold >> 1)) begin  // Below threshold/2
                    new_v = new_v + leak_rate_1;     // Leak upward toward equilibrium
                end else begin                       // Above threshold/2
                    new_v = new_v - leak_rate_1;     // Leak downward toward equilibrium
                end
            end
            if (apply_leak_2) begin
                if (new_v < (threshold >> 1)) begin  // Below threshold/2
                    new_v = new_v + leak_rate_2;     // Leak upward toward equilibrium
                end else begin                       // Above threshold/2
                    new_v = new_v - leak_rate_2;     // Leak downward toward equilibrium
                end
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
