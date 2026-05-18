$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source     = Join-Path $ScriptDir "caffeine.ahk"
$Output     = Join-Path $ScriptDir "Caffeine.exe"

$Ahk2Exe = @(
    (Join-Path $env:LocalAppData "Programs\AutoHotkey\Compiler\Ahk2Exe.exe"),
    (Join-Path $env:ProgramFiles "AutoHotkey\Compiler\Ahk2Exe.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "AutoHotkey\Compiler\Ahk2Exe.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Ahk2Exe) {
    Write-Error "Ahk2Exe.exe not found. Install AutoHotkey v2 first."
    exit 1
}

Write-Host "Compiler : $Ahk2Exe"
Write-Host "Source   : $Source"
Write-Host "Output   : $Output"

& $Ahk2Exe /in $Source /out $Output

if (Test-Path $Output) {
    Write-Host "Build succeeded: $Output"
} else {
    Write-Error "Build failed."
    exit 1
}