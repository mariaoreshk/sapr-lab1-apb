onerror {quit -f -code 1}
set project_dir [pwd]
while {![file exists [file join $project_dir lab3.qpf]]} {
    set parent [file dirname $project_dir]
    if {$parent eq $project_dir} { error "Run from the built lab3 project directory" }
    set project_dir $parent
}

set model_dir [file join $project_dir nios_system simulation]
set sim_dir [file join $project_dir simulation modelsim]
file mkdir $sim_dir
cd $sim_dir

foreach pattern {*.hex *.mif *.dat} {
    foreach data [glob -nocomplain -directory [file join $model_dir submodules] $pattern] {
        file copy -force $data .
    }
}
file copy -force [file join $project_dir sim_app mem_init nios_system_onchip_memory.hex] .

if {![file isdirectory work]} { vlib work }
eval [linsert [glob -directory [file join $model_dir submodules] *.v *.sv] 0 vlog -sv]
vlog -sv [file join $model_dir nios_system.v] [file join $project_dir lab3_top.sv] \
    [file join $project_dir tb_traffic_light.sv]
vsim -onfinish stop -voptargs=+acc -L altera_ver -L altera_mf_ver -L lpm_ver -L sgate_ver -L cycloneii_ver work.tb_traffic_light
add wave -radix hexadecimal /tb_traffic_light/leds
add wave /tb_traffic_light/reset_n
run -all
