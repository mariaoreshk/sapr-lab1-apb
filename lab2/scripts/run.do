onerror {quit -code 1}
if {![file exists work]} {vlib work}
vlog -sv ../rtl/apb_alu_slave.sv ../tb/tb_alu.sv
vsim -voptargs=+acc work.tb_alu
onbreak {quit -code 1}
log -r /*
run -all
quit -code 0
