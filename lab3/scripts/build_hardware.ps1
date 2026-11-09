param(
    [string]$QuartusRoot = 'C:\altera\13.0sp1\quartus',
    [string]$BuildDirectory = 'C:\altera\lab3',
    [switch]$RunSimulation
)

$ErrorActionPreference = 'Stop'
$labDirectory = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $labDirectory 'fpga'
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$qsysScript = Join-Path $QuartusRoot 'sopc_builder\bin\qsys-script.exe'
$qsysGenerate = Join-Path $QuartusRoot 'sopc_builder\bin\qsys-generate.exe'
$ipGenerate = Join-Path $QuartusRoot 'sopc_builder\bin\ip-generate.exe'
$quartusShell = Join-Path $QuartusRoot 'bin\quartus_sh.exe'
$niosRoot = Join-Path (Split-Path -Parent $QuartusRoot) 'nios2eds'
$sdkBin = Join-Path $niosRoot 'sdk2\bin'
$gnuBin = Join-Path $niosRoot 'bin\gnu\H-i686-mingw32\bin'
$cygwinBin = Join-Path $QuartusRoot 'bin\cygwin\bin'
$bspCreate = Join-Path $sdkBin 'nios2-bsp-create-settings.exe'
$appMakefile = Join-Path $sdkBin 'nios2-app-generate-makefile.exe'
$make = Join-Path $cygwinBin 'make.exe'
foreach ($tool in @($qsysScript, $qsysGenerate, $ipGenerate, $quartusShell, $bspCreate, $appMakefile, $make)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Tool not found: $tool" }
}

New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
foreach ($name in @('create_system.tcl', 'lab3_top.sv', 'lab3.qpf', 'lab3.qsf', 'lab3.sdc',
        'tb_traffic_light.sv', 'run_simulation.do')) {
    Copy-Item -LiteralPath (Join-Path $sourceDirectory $name) -Destination $BuildDirectory -Force
}
foreach ($directory in @('app', 'sim_app', 'bsp')) {
    New-Item -ItemType Directory -Path (Join-Path $BuildDirectory $directory) -Force | Out-Null
}

function Invoke-BuildTool {
    param([string]$Tool, [string[]]$ToolArguments, [string]$LogName)
    & $Tool @ToolArguments 2>&1 | Tee-Object -FilePath $LogName
    if ($LASTEXITCODE -ne 0) { throw "Build failed. See $LogName" }
}

Push-Location $BuildDirectory
$savedQuartusRoot = $env:QUARTUS_ROOTDIR
$savedNiosRoot = $env:SOPC_KIT_NIOS2
$savedShellOptions = $env:SHELLOPTS
$savedPath = $env:PATH
try {
    $env:QUARTUS_ROOTDIR = $QuartusRoot
    $env:SOPC_KIT_NIOS2 = $niosRoot
    $env:SHELLOPTS = 'igncr'
    $env:PATH = @((Join-Path $QuartusRoot 'bin'), $cygwinBin, $gnuBin, $sdkBin,
        (Join-Path $niosRoot 'bin'), $savedPath) -join [IO.Path]::PathSeparator
    Invoke-BuildTool $qsysScript @('--script=create_system.tcl') 'create_system.log'
    Invoke-BuildTool $qsysGenerate @('nios_system.qsys', '--synthesis=VERILOG') 'generate_system.log'
    Invoke-BuildTool $bspCreate @('--sopc', 'nios_system.sopcinfo', '--type', 'hal',
        '--settings', 'bsp/settings.bsp', '--bsp-dir', 'bsp',
        '--script', (Join-Path $sdkBin 'bsp-set-defaults.tcl'),
        '--set', 'hal.enable_small_c_library', 'true',
        '--set', 'hal.enable_reduced_device_drivers', 'true',
        '--set', 'hal.linker.enable_alt_load', 'false',
        '--set', 'hal.linker.enable_alt_load_copy_rwdata', 'false',
        '--set', 'hal.make.bsp_cflags_optimization', '-Os',
        '--set', 'hal.sys_clk_timer', 'none') 'build_bsp.log'
    foreach ($app in @('app', 'sim_app')) {
        $flags = if ($app -eq 'sim_app') { '-DLAB3_FAST_SIMULATION' } else { '' }
        Copy-Item -LiteralPath (Join-Path $labDirectory 'src\traffic_light.c') -Destination $app -Force
        Invoke-BuildTool $appMakefile @('--bsp-dir', 'bsp', '--app-dir', $app,
            '--elf-name', 'traffic_light.elf', '--src-files', "$app/traffic_light.c") "generate_$app.log"
        Invoke-BuildTool $make @('-C', $app, 'ABS_BSP_ROOT=.', 'APP_CFLAGS_OPTIMIZATION=-Os',
            "APP_CFLAGS_USER_FLAGS=$flags", 'all', 'mem_init_generate') "build_$app.log"
        if (-not (Test-Path -LiteralPath "$app/mem_init/nios_system_onchip_memory.hex")) {
            throw "Firmware memory image was not generated for $app."
        }
    }
    $memoryImage = 'app/mem_init/nios_system_onchip_memory.hex'
    Copy-Item -LiteralPath $memoryImage -Destination 'nios_system/synthesis/submodules/' -Force
    New-Item -ItemType Directory -Path 'nios_system/simulation' -Force | Out-Null
    $simulationSettings = 'set_instance_parameter_value timer period 4; set_instance_parameter_value timer periodUnits USEC; save_system nios_system/simulation/nios_system.qsys'
    Invoke-BuildTool $qsysScript @('--package-version=13.0', '--system-file=nios_system.qsys',
        "--cmd=$simulationSettings") 'create_simulation.log'
    Invoke-BuildTool $ipGenerate @('--project-directory=.', '--component-file=nios_system/simulation/nios_system.qsys',
        '--output-directory=nios_system/simulation', '--file-set=SIM_VERILOG',
        '--system-info=DEVICE_FAMILY=Cyclone II', '--system-info=DEVICE=EP2C20F484C7') 'generate_simulation.log'
    Invoke-BuildTool $quartusShell @('--flow', 'compile', 'lab3') 'compile_hardware.log'
    Write-Output "Hardware project: $BuildDirectory\lab3.qpf"
    Write-Output "Firmware: $BuildDirectory\app\traffic_light.elf"
    Write-Output "FPGA image: $BuildDirectory\output_files\lab3.sof"
    if ($RunSimulation) {
        $modelSimBin = Join-Path (Split-Path -Parent $QuartusRoot) 'modelsim_ase\win32aloem'
        $env:PATH = $modelSimBin + [IO.Path]::PathSeparator + $env:PATH
        $nativeLink = Join-Path $QuartusRoot 'common\tcl\internal\nativelink\qnativesim.tcl'
        Invoke-BuildTool $quartusShell @('-t', $nativeLink, '--rtl_sim', '--no_gui', 'lab3', 'lab3') 'simulation.log'
        if (-not (Select-String -Path 'simulation.log' -SimpleMatch 'PASS: Nios II firmware')) {
            throw 'The simulation did not complete successfully. See simulation.log.'
        }
    }
} finally {
    $env:QUARTUS_ROOTDIR = $savedQuartusRoot
    $env:SOPC_KIT_NIOS2 = $savedNiosRoot
    $env:SHELLOPTS = $savedShellOptions
    $env:PATH = $savedPath
    Pop-Location
}
