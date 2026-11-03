param([string]$Compiler = '')

$ErrorActionPreference = 'Stop'
$labDirectory = Split-Path -Parent $PSScriptRoot

if (-not $Compiler) {
    $gcc = Get-Command gcc -ErrorAction SilentlyContinue
    if ($gcc) {
        $Compiler = $gcc.Source
    } else {
        foreach ($candidate in @('C:\msys64\ucrt64\bin\gcc.exe',
                                  'C:\msys64\mingw64\bin\gcc.exe')) {
            if (Test-Path -LiteralPath $candidate) {
                $Compiler = $candidate
                break
            }
        }
    }
}

if (-not $Compiler) {
    throw 'GCC was not found. Pass its path using -Compiler.'
}

$compilerCommand = Get-Command $Compiler -ErrorAction Stop
$compilerDirectory = Split-Path -Parent $compilerCommand.Source
$buildDirectory = Join-Path ([IO.Path]::GetTempPath()) 'sapr-lab3-tests'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
$executable = Join-Path $buildDirectory ('traffic-tests-' + [guid]::NewGuid() + '.exe')
$savedPath = $env:PATH

try {
    $env:PATH = $compilerDirectory + [IO.Path]::PathSeparator + $savedPath
    $sourceDirectory = Join-Path $labDirectory 'src'
    $testSource = Join-Path $labDirectory 'tests\test_traffic_light.c'
    & $Compiler -std=c99 -Wall -Wextra -Werror -pedantic -I $sourceDirectory `
        (Join-Path $sourceDirectory 'traffic_light.c') $testSource -o $executable
    if ($LASTEXITCODE -ne 0) { throw 'C compilation failed.' }

    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'Traffic light tests failed.' }
} finally {
    $env:PATH = $savedPath
}
