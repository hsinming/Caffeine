<#
.SYNOPSIS
    Run one Live Drive (ahk-home-repo ADR 0002): one real system, one feature, after the user permitted that one run.

.DESCRIPTION
    Refuses (BLOCKED, exit 6) without the single-use marker that LiveDriveHook.mjs leaves when the user is asked to
    allow this command, or when the marker names another system or feature or is over 15 minutes old. An agent with
    no such hook (Codex) cannot run a Live Drive.

    Run it in the app's repo. Its tools\drive\live.json names each system:
        { "runner": "tools/drive/walk.mjs",
          "systems": { "<System>": { "hospital": true, "features": ["<feature>"],
                                     "credentials": { "<NAME>": { "ini": "settings.ini", "section": "<s>", "key": "<k>" } } } } }
    It reads the credentials (this command alone does) and runs: node <runner> <feature> --live <System>, with
    APPDRIVE_LIVE=<System> and APPDRIVE_SECRET_<NAME> for each credential; Invoke-AhkProbe.ps1 keeps those from the app.
    A hospital system also gets APPDRIVE_LIVE_HOSPITAL=1 (no DevTools port) and APPDRIVE_EVIDENCE_ROOT=<repo>\live-results,
    which the repo must ignore and its deny rules must keep from the agent.

    Output, one JSON line per runner line. For a hospital system, masked: verdict (PASS, FAIL or ERROR) and steps, each
    {name, ok, ms, length, code}. A name must be written, quoted, in the runner's source; a code is an HL7 code (QBP_Z12_Z02-003)
    or an HTTP status; anything else is dropped. The runner's stderr goes to the evidence root, not here.
    For another system the runner's lines as they are. Either way, a credential found in the evidence deletes that file
    and fails the drive.

.EXAMPLE
    pwsh -File <skill>\scripts\Invoke-LiveDrive.ps1 -System AI -Feature recipe
#>
param(
    [Parameter(Mandatory)] [string] $System,
    [Parameter(Mandatory)] [string] $Feature
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

function Stop-Drive([string] $why) {
    [ordered]@{ verdict = 'BLOCKED'; system = $System; feature = $Feature; error = $why } | ConvertTo-Json -Compress
    exit 6
}

# Single use: gone before it is judged, so a refused run cannot try again with it.
$markerFile = Join-Path $env:LOCALAPPDATA 'AppDrive\live-marker.json'
if (-not (Test-Path $markerFile)) { Stop-Drive 'no permission: run this command alone, so that the Live Drive hook asks the user' }
$marker = Get-Content $markerFile -Raw | ConvertFrom-Json
Remove-Item $markerFile -Force
if ($marker.system -cne $System -or $marker.feature -cne $Feature) { Stop-Drive "the permission was for $($marker.system) / $($marker.feature)" }
$age = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - [long] $marker.created
if ($age -lt 0 -or $age -gt 15 * 60 * 1000) { Stop-Drive 'the permission is over 15 minutes old' }

$repo = git rev-parse --show-toplevel
if ($LASTEXITCODE) { Stop-Drive 'run it in the app repository' }
$repo = [IO.Path]::GetFullPath($repo)
$liveFile = Join-Path $repo 'tools\drive\live.json'
if (-not (Test-Path $liveFile)) { Stop-Drive 'the app has no tools\drive\live.json' }
$live = Get-Content $liveFile -Raw | ConvertFrom-Json
$spec = $live.systems.$System
if (-not $spec) { Stop-Drive "live.json has no system $System" }
if ($Feature -cnotin $spec.features) { Stop-Drive "live.json has no feature $Feature for $System" }
$runner = Join-Path $repo $live.runner

$secrets = @{}
foreach ($credential in $(if ($spec.credentials) { $spec.credentials.PSObject.Properties })) {
    $from = $credential.Value
    $section = ''
    $value = foreach ($line in Get-Content (Join-Path $repo $from.ini) -ErrorAction SilentlyContinue) {
        if ($line -match '^\s*\[(.+?)\]') { $section = $Matches[1] }
        elseif ($section -eq $from.section -and $line -match "^\s*$([regex]::Escape($from.key))\s*=\s*`"?(.*?)`"?\s*$") { $Matches[1] }
    }
    if (-not "$value") { Stop-Drive "no credential $($credential.Name) in $($from.ini) [$($from.section)] $($from.key)" }
    $secrets["APPDRIVE_SECRET_$($credential.Name)"] = "$value"
}

$hospital = [bool] $spec.hospital
$evidenceRoot = Join-Path $repo 'live-results'
if ($hospital) {
    git -C $repo check-ignore -q -- (Join-Path $evidenceRoot 'x')
    if ($LASTEXITCODE) { Stop-Drive 'the app repository must ignore live-results' }
    $null = New-Item -ItemType Directory -Force $evidenceRoot
}

$env:APPDRIVE_LIVE = $System
foreach ($name in $secrets.Keys) { [Environment]::SetEnvironmentVariable($name, $secrets[$name]) }
if ($hospital) { $env:APPDRIVE_LIVE_HOSPITAL = '1'; $env:APPDRIVE_EVIDENCE_ROOT = $evidenceRoot }
$started = Get-Date
Push-Location $repo
try {
    if ($hospital) { $lines = & node $runner $Feature --live $System 2>> (Join-Path $evidenceRoot 'runner-stderr.log') }
    else { $lines = & node $runner $Feature --live $System }
    $code = $LASTEXITCODE
} finally { Pop-Location }

# No credential stays in evidence of this run.
$leaked = @()
foreach ($root in @((Join-Path $repo 'drive-results'), $evidenceRoot)) {
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -ge $started | ForEach-Object {
        $bytes = [IO.File]::ReadAllBytes($_.FullName)
        $texts = [Text.Encoding]::UTF8.GetString($bytes), [Text.Encoding]::Unicode.GetString($bytes)
        foreach ($secret in $secrets.Values) {
            if ($texts | Where-Object { $_.Contains($secret) }) { $leaked += $_.FullName.Substring($repo.Length + 1); Remove-Item $_.FullName -Force; break }
        }
    }
}

$source = Get-Content $runner -Raw
$codePattern = '^([A-Z][A-Z0-9]*_[A-Z0-9_]+(-\d{3})?|\d{3})$'
foreach ($line in $lines) {
    if (-not $hospital) { $line; continue }
    try { $out = $line | ConvertFrom-Json } catch { continue }
    $steps = foreach ($step in @($out.steps)) {
        $written = $step.name -is [string] -and ($source.Contains("'$($step.name)'") -or $source.Contains("`"$($step.name)`""))
        $masked = [ordered]@{ name = if ($written) { $step.name } else { '(masked)' }; ok = $step.ok -eq $true }
        foreach ($number in 'ms', 'length') {   # PSObject, not $step.length: every PowerShell object has a Length of 1
            $value = $step.PSObject.Properties[$number].Value
            if ($value -is [long] -or $value -is [int]) { $masked[$number] = $value }
        }
        if ($step.code -is [string] -and $step.code -cmatch $codePattern) { $masked.code = $step.code }
        $masked
    }
    [ordered]@{ verdict = if ($out.verdict -cin 'PASS', 'FAIL', 'ERROR') { $out.verdict } else { 'ERROR' }; system = $System; feature = $Feature
        steps = @($steps); evidence = 'live-results (for the user alone)' } | ConvertTo-Json -Compress -Depth 4
}
if ($leaked) {
    [ordered]@{ verdict = 'FAIL'; system = $System; feature = $Feature; error = 'a credential was in the evidence; those files are deleted'; files = $leaked } | ConvertTo-Json -Compress
    exit 1
}
exit $code
