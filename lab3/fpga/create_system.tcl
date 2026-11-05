package require -exact qsys 13.0

create_system nios_system
set_project_property DEVICE_FAMILY "Cyclone II"
set_project_property DEVICE EP2C20F484C7

add_instance clk_0 clock_source 13.0
set_instance_parameter_value clk_0 clockFrequency 50000000
set_instance_parameter_value clk_0 clockFrequencyKnown true
set_instance_parameter_value clk_0 resetSynchronousEdges DEASSERT

add_instance cpu altera_nios2_qsys 13.0
set_instance_parameter_value cpu impl Tiny
set_instance_parameter_value cpu debug_level Level1
set_instance_parameter_value cpu icache_size 0
set_instance_parameter_value cpu dcache_size 0
set_instance_parameter_value cpu resetSlave onchip_memory.s1
set_instance_parameter_value cpu resetOffset 0
set_instance_parameter_value cpu exceptionSlave onchip_memory.s1
set_instance_parameter_value cpu exceptionOffset 32
set_instance_parameter_value cpu breakSlave cpu.jtag_debug_module
set_instance_parameter_value cpu breakOffset 32

add_instance onchip_memory altera_avalon_onchip_memory2 13.0.1.99.2
set_instance_parameter_value onchip_memory memorySize 16384
set_instance_parameter_value onchip_memory dataWidth 32
set_instance_parameter_value onchip_memory writable true
set_instance_parameter_value onchip_memory dualPort false
set_instance_parameter_value onchip_memory initMemContent true

add_instance switches altera_avalon_pio 13.0.1.99.2
set_instance_parameter_value switches width 8
set_instance_parameter_value switches direction Input
set_instance_parameter_value switches generateIRQ false

add_instance leds altera_avalon_pio 13.0.1.99.2
set_instance_parameter_value leds width 8
set_instance_parameter_value leds direction Output
# Bits 0 and 3 are the two red signals.
set_instance_parameter_value leds resetValue 9

add_instance timer altera_avalon_timer 13.0.1.99.2
set_instance_parameter_value timer period 1
set_instance_parameter_value timer periodUnits MSEC
set_instance_parameter_value timer fixedPeriod true
set_instance_parameter_value timer alwaysRun false

add_instance jtag_uart altera_avalon_jtag_uart 13.0.1.99.2

foreach sink {cpu.clk onchip_memory.clk1 switches.clk leds.clk timer.clk jtag_uart.clk} {
    add_connection clk_0.clk $sink
}
foreach sink {cpu.reset_n onchip_memory.reset1 switches.reset leds.reset timer.reset jtag_uart.reset} {
    add_connection clk_0.clk_reset $sink
    add_connection cpu.jtag_debug_module_reset $sink
}

# The instruction and data masters share RAM and the debug module.
foreach master {cpu.instruction_master cpu.data_master} {
    add_connection $master onchip_memory.s1
    set_connection_parameter_value $master/onchip_memory.s1 baseAddress 0x00000000
    add_connection $master cpu.jtag_debug_module
    set_connection_parameter_value $master/cpu.jtag_debug_module baseAddress 0x00010800
}
foreach {slave address} {
    timer.s1                 0x00010000
    jtag_uart.avalon_jtag_slave 0x00010020
    switches.s1              0x00010030
    leds.s1                  0x00010040
} {
    add_connection cpu.data_master $slave
    set_connection_parameter_value cpu.data_master/$slave baseAddress $address
}

add_connection cpu.d_irq timer.irq
set_connection_parameter_value cpu.d_irq/timer.irq irqNumber 0
add_connection cpu.d_irq jtag_uart.irq
set_connection_parameter_value cpu.d_irq/jtag_uart.irq irqNumber 1

add_interface clk clock sink
set_interface_property clk EXPORT_OF clk_0.clk_in
add_interface reset reset sink
set_interface_property reset EXPORT_OF clk_0.clk_in_reset
add_interface switches conduit end
set_interface_property switches EXPORT_OF switches.external_connection
add_interface leds conduit end
set_interface_property leds EXPORT_OF leds.external_connection

save_system nios_system.qsys
