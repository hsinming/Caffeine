# Runs the smoke test and every tests\*_test.ahk headless, writes test-result.json,
# and exits 0 when everything passes, 1 otherwise.
$ErrorActionPreference = "Stop"

$Root       = $PSScriptRoot
$ResultPath = Join-Path $Root "test-result.json"
$TimeoutMs  = 30000

$Ahk = @(
    (Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey64.exe"),
    (Join-Path $env:ProgramFiles "AutoHotkey\v2\AutoHotkey.exe"),
    (Join-Path $env:LocalAppData "Programs\AutoHotkey\v2\AutoHotkey64.exe"),
    (Join-Path $env:LocalAppData "Programs\AutoHotkey\v2\AutoHotkey.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Ahk) {
    Write-Error "AutoHotkey v2 not found. Install AutoHotkey v2 first."
    exit 1
}

$Clock    = [Diagnostics.Stopwatch]::StartNew()
$Total    = 0
$Failures = New-Object System.Collections.ArrayList
$Syntax   = $null

function Add-Failure($suite, $test, $expected, $actual, $file) {
    [void]$Failures.Add([ordered]@{
        suite = $suite; test = $test; expected = $expected; actual = $actual
        file = $file; line = $null; stack = $null
    })
}

# Runs one AHK process; $script is the file reported when the process itself fails.
function Invoke-Ahk($suite, $script, [string[]]$ahkArgs) {
    $psi = New-Object Diagnostics.ProcessStartInfo $Ahk
    $psi.Arguments = "/ErrorStdOut=UTF-8 " + (($ahkArgs | ForEach-Object { "`"$_`"" }) -join " ")
    $psi.WorkingDirectory = $Root
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8

    $p = [Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEndAsync()

    $script:Total++
    if (-not $p.WaitForExit($TimeoutMs)) {
        $p.Kill()
        $p.WaitForExit()
        Add-Failure $suite "(timeout)" "exit within $($TimeoutMs / 1000) s" "killed after $($TimeoutMs / 1000) s" $script
        return
    }
    $p.WaitForExit() # flush the async readers

    if ($err.Result -match '(?s)^(.+?) \((\d+)\) : ==> (.+)$') {
        if (-not $script:Syntax) {
            $script:Syntax = [ordered]@{ file = $Matches[1].Trim(); line = [int]$Matches[2]; message = ($Matches[3] -split "`r?`n")[0].Trim() }
        }
        return
    }

    $reported = 0
    $json = $out.Result.Trim()
    if ($json) {
        $r = $json | ConvertFrom-Json
        $script:Total += $r.total - 1 # the process itself was counted above
        foreach ($f in $r.failures) { [void]$Failures.Add($f); $reported++ }
    }
    if ($p.ExitCode -ne 0 -and $reported -eq 0) {
        Add-Failure $suite "(process)" "exit code 0" "exit code $($p.ExitCode): $($err.Result.Trim())" $script
    }
}

$Tray  = Join-Path $Root "caffeine.ahk"
$Smoke = Join-Path $Root "tests\smoke.ahk"
Invoke-Ahk "smoke" $Tray @("/include", $Smoke, $Tray)

foreach ($t in Get-ChildItem (Join-Path $Root "tests") -Filter "*_test.ahk") {
    Invoke-Ahk $t.BaseName $t.FullName @($t.FullName)
}

$Result = [ordered]@{
    passed      = (-not $Syntax) -and $Failures.Count -eq 0
    summary     = [ordered]@{ total = $Total; failed = $Failures.Count; durationMs = $Clock.ElapsedMilliseconds }
    syntaxError = $Syntax
    failures    = @($Failures)
}
[IO.File]::WriteAllText($ResultPath, (ConvertTo-Json $Result -Depth 5))

if ($Result.passed) {
    Write-Host "PASS: $Total tests. See $ResultPath"
    exit 0
}
Write-Host "FAIL: $($Failures.Count) of $Total failed$(if ($Syntax) { ', syntax error' }). See $ResultPath"
exit 1
