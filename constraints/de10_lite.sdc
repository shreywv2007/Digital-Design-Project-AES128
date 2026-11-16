# Timing constraints for de10_lite_top (50 MHz board clock)
create_clock -name clk50 -period 20.000 [get_ports {MAX10_CLK1_50}]
derive_clock_uncertainty
# Buttons and UART pins are asynchronous and synchronised inside the design
set_false_path -from [get_ports {KEY[*] UART_RXD}]
set_false_path -to   [get_ports {LEDR[*] UART_TXD}]
