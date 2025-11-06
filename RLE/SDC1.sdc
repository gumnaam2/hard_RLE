#------------------------------------------------------------
# Minimal SDC for RLE design
# Clock: 10 MHz
#------------------------------------------------------------

# Create primary clock on clk port
create_clock -name clk -period 20 -waveform {0 20} [get_ports clk]


# Optional: specify input and output delays if known
# set_input_delay -clock clk 0 [get_ports data_in start reset]
# set_output_delay -clock clk 0 [get_ports data_out done]

# End of SDC