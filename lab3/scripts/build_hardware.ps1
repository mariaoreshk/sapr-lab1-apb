param(
    [string]$QuartusRoot = 'C:\altera\13.0sp1\quartus',
    [string]$BuildDirectory = 'C:\altera\lab3'
)

$ErrorActionPreference = 'Stop'
$sourceDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'fpga'
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$qsysScript = Join-Path $QuartusRoot 'sopc_builder\bin\qsys-script.exe'
$qsysGenerate = Join-Path $QuartusRoot 'sopc_builder\bin\qsys-generate.exe'
$quartusShell = Join-Path $QuartusRoot 'bin\quartus_sh.exe'
foreach ($tool in @($qsysScript, $qsysGenerate, $quartusShell)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Tool not found: $tool" }
}

New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
foreach ($name in @('create_system.tcl', 'lab3_top.sv', 'lab3.qpf', 'lab3.qsf', 'lab3.sdc')) {
    Copy-Item -LiteralPath (Join-Path $sourceDirectory $name) -Destination $BuildDirectory -Force
}

function Invoke-BuildTool {
    param([string]$Tool, [string[]]$ToolArguments, [string]$LogName)
    & $Tool @ToolArguments 2>&1 | Tee-Object -FilePath $LogName
    if ($LASTEXITCODE -ne 0) { throw "Build failed. See $LogName" }
}

Push-Location $BuildDirectory
$savedQuartusRoot = $env:QUARTUS_ROOTDIR
$savedPath = $env:PATH
try {
    $env:QUARTUS_ROOTDIR = $QuartusRoot
    $env:PATH = (Join-Path $QuartusRoot 'bin') + [IO.Path]::PathSeparator + $savedPath
    Invoke-BuildTool $qsysScript @('--script=create_system.tcl') 'create_system.log'
    Invoke-BuildTool $qsysGenerate @('nios_system.qsys', '--synthesis=VERILOG') 'generate_system.log'
    Invoke-BuildTool $quartusShell @('--flow', 'compile', 'lab3') 'compile_hardware.log'
    Write-Output "Hardware project: $BuildDirectory\lab3.qpf"
    Write-Output "System description: $BuildDirectory\nios_system.sopcinfo"
} finally {
    $env:QUARTUS_ROOTDIR = $savedQuartusRoot
    $env:PATH = $savedPath
    Pop-Location
}
