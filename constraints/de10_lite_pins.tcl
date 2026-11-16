# DE10-Lite pin assignments for de10_lite_top.v
# In Quartus: Tools > Tcl Scripts... > run this file (project must be open),
# or paste these lines into the project's .qsf file.
# Double-check every pin against the DE10-Lite User Manual before programming.

set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_top

set_location_assignment PIN_P11 -to MAX10_CLK1_50
set_location_assignment PIN_B8  -to KEY[0]
set_location_assignment PIN_A7  -to KEY[1]

set_location_assignment PIN_A8  -to LEDR[0]
set_location_assignment PIN_A9  -to LEDR[1]
set_location_assignment PIN_A10 -to LEDR[2]
set_location_assignment PIN_B10 -to LEDR[3]
set_location_assignment PIN_D13 -to LEDR[4]
set_location_assignment PIN_C13 -to LEDR[5]
set_location_assignment PIN_E14 -to LEDR[6]
set_location_assignment PIN_D14 -to LEDR[7]
set_location_assignment PIN_A11 -to LEDR[8]
set_location_assignment PIN_B11 -to LEDR[9]

# GPIO header: GPIO[0] = header pin 1, GPIO[1] = header pin 2
set_location_assignment PIN_V10 -to UART_RXD
set_location_assignment PIN_W10 -to UART_TXD

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to MAX10_CLK1_50
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to KEY[0]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to KEY[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_RXD
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to UART_TXD
# Keep the receive line idle-high if the adapter is unplugged
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to UART_RXD
