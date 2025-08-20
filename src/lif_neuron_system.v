`timescale 1ns / 1ps

module lif_neuron_system (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Input channels - INCREASED PRECISION (6 bits total)
    input wire [5:0] chan_a,  // 6-bit precision

    // Configuration interface
    input wire load_mode,
    input wire serial_data,
    
    // Outputs
    output wire spike_out,
    output wire [6:0] v_mem_out,
    output wire params_ready
);

// Internal parameter wires
wire [2:0] weight;
wire [1:0] leak_config;
wire [7:0] threshold;
wire loader_params_ready;

// Data loader instance (unchanged)
lif_data_loader loader (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .serial_data_in(serial_data),
    .load_enable(load_mode),
    .weight(weight),
    .leak_config(leak_config),
    .threshold(threshold),
    .params_ready(loader_params_ready)
);

// LIF neuron instance - UPDATED FOR 3-BIT CHANNELS
lif_neuron neuron (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .chan_a(chan_a),           // 6-bit input
    .weight(weight),
    .leak_config(leak_config),
    .threshold(threshold),
    .params_ready(loader_params_ready),
    .spike_out(spike_out),
    .v_mem_out(v_mem_out)
);

assign params_ready = loader_params_ready;

endmodule
