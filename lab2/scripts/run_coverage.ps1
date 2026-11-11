param(
    [string]$Python = "python",
    [string]$Vsim = "vsim"
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo = (Resolve-Path (Join-Path $project '..')).Path
$vsimExe = (Get-Command $Vsim -ErrorAction Stop).Source
$pythonExe = (Get-Command $Python -ErrorAction Stop).Source
$runDir = Join-Path ([IO.Path]::GetTempPath()) ("lab2-cov-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runDir | Out-Null
Copy-Item (Join-Path $project 'tb/tb_alu.sv'),(Join-Path $project 'tb/tb_lab1_master.sv'),(Join-Path $repo 'src/apb_master.sv') $runDir
$helper = Join-Path $PSScriptRoot 'branch_coverage.py'
& $pythonExe $helper instrument (Join-Path $project 'rtl/apb_alu_slave.sv') (Join-Path $runDir 'apb_alu_slave.sv')
if ($LASTEXITCODE) { throw 'RTL instrumentation failed' }
Push-Location $runDir
try {
    @'
onerror {quit -code 1}
vlib work
vlog -sv apb_alu_slave.sv apb_master.sv tb_alu.sv tb_lab1_master.sv
quit -code 0
'@ | Set-Content build.do -Encoding ascii
    & $vsimExe -c -do build.do *> build.log
    if ($LASTEXITCODE) { Get-Content build.log; throw 'Compilation failed' }
    foreach ($test in 'tb_lab1_master','tb_alu') {
        @"
onerror {quit -code 1}
vsim -onfinish stop work.$test
run -all
quit -code 0
"@ | Set-Content run.do -Encoding ascii
        & $vsimExe -c -do run.do -l "$test.log" *> "$test-console.log"
        if ($LASTEXITCODE) { Get-Content "$test-console.log" -Tail 25; throw "$test failed" }
    }
    & $pythonExe $helper report tb_lab1_master.log tb_alu.log
    if ($LASTEXITCODE) { throw 'Coverage summary failed' }
    Write-Output "Logs: $runDir"
} finally {
    Pop-Location
}
