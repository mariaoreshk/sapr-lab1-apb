onerror {quit -code 1}
if {![file exists work]} {vlib work}
vlog -sv ../../src/apb_master.sv ../rtl/apb_alu_slave.sv ../tb/tb_lab1_master.sv
vsim -voptargs=+acc work.tb_lab1_master
onbreak {quit -code 1}
run -all
quit -code 0
