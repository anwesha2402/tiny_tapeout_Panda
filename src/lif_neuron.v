`timescale 1ns / 1ps
module izh_neuron_core (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire signed [7:0] stimulus_in,
    input wire signed [11:0] param_a,  // Reduced from 16-bit to 12-bit
    input wire signed [11:0] param_b,  // Reduced from 16-bit to 12-bit
    input wire signed [11:0] param_c,  // Reduced from 16-bit to 12-bit
    input wire signed [11:0] param_d,  // Reduced from 16-bit to 12-bit
    input wire params_ready,
    output reg spike_out,
    output wire [7:0] membrane_out
);
    
// Fixed-point scaling
localparam SCALE = 256;
localparam V_THRESH = 30 * SCALE;        // 30mV spike threshold  
localparam V_REST = -70 * SCALE;         // -70mV resting potential
localparam CONST_140 = 140 * SCALE;      // Constant 140

// State variables
reg signed [15:0] v;  // Membrane potential
reg signed [15:0] u;  // Recovery variable

// Computation signals
wire signed [31:0] v_squared;
wire signed [31:0] stimulus_scaled;
wire signed [31:0] dv_full, du_full;
wire signed [15:0] dv, du;

// Spike detection
wire spike_detect = (v >= V_THRESH);

// IZ equation: dv = 0.04v² + 5v + 140 - u + I
assign v_squared = (v * v) >>> 8;  // Scale down to prevent overflow
assign stimulus_scaled = stimulus_in * SCALE;
assign dv_full = (v_squared >>> 6) +     // 0.04v² term (approximated)
                 (v * 5) +               // 5v term
                 CONST_140 -             // 140 constant
                 u +                     // -u term
                 stimulus_scaled;        // +I term

// du = a(bv - u) with 12-bit parameters
assign du_full = (param_a * ((param_b * v - (u << 8)) >>> 8)) >>> 8;

// Limit derivatives
assign dv = (dv_full > 32767) ? 16'sd32767 : 
           (dv_full < -32768) ? -16'sd32768 : dv_full[15:0];
           
assign du = (du_full > 32767) ? 16'sd32767 : 
           (du_full < -32768) ? -16'sd32768 : du_full[15:0];

// Output membrane potential
wire signed [15:0] v_normalized = (v - V_REST) >>> 8;
assign membrane_out = spike_detect ? 8'd255 : 
                     (v_normalized < 0) ? 8'd0 : 
                     (v_normalized > 255) ? 8'd255 : v_normalized[7:0];

// Main neuron dynamics
always @(posedge clk) begin
    if (reset) begin
        v <= V_REST;
        u <= 16'sd0;
        spike_out <= 1'b0;
    end else if (enable && params_ready) begin
        if (spike_detect) begin
            // Spike occurred - apply reset
            v <= param_c;
            u <= u + param_d;
            spike_out <= 1'b1;
        end else begin
            // Normal integration
            v <= v + (dv >>> 6);  // Integrate with smaller timestep
            u <= u + (du >>> 6);
            spike_out <= 1'b0;
        end
    end else begin
        spike_out <= 1'b0;
    end
end
endmodule
