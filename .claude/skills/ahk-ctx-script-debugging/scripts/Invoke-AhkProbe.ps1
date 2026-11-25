<#
.SYNOPSIS
    Run or validate an AutoHotkey v2 script with a timeout and PID-only kill, and report a verdict as JSON.
    Method adapted from ahkh (https://github.com/owhs/AHKTestHarness).

.DESCRIPTION
    -Mode Validate : AutoHotkey /Validate. Parses the script and exits, even for persistent scripts.
    -Mode Run      : injects AhkProbe.ahk with /include (the target file is never edited), so uncaught
                     runtime errors arrive as structured AHKPROBE|error lines on stdout, not as popups.
    -Mode Drive    : Run for an App Drive. Starts an isolated copy (git's tracked and unignored files only,
                     LOCALAPPDATA redirected, AIH_DEVTOOLS_PORT set to a free port) and stays up until
                     AppDrive.mjs stop, or the app exits. -EvidenceDir receives session.json, the app log
                     and result.json. -StandIn starts the stand-ins for the outside systems first, with Node on
                     the same desktop: node <script> <app copy> <ready file>. It writes the ready file once, as a
                     JSON object of environment variables for the app, then stays up until the drive ends it.

    The target runs on a private Win32 desktop inside a kill-on-close Job Object: no window reaches the
    user's screen, no focus is stolen, and a hotkey or #SingleInstance in the target cannot touch the
    user's own running copy. A dialog the target opens stays on that desktop and is listed in "windows".
    -VisibleDesktop runs on the user's desktop instead.

    Verdicts, worst first, and exit codes:
        CRASH 4 . HUNG 5 . ERROR 2 . FAIL 1 . TIMEOUT 3 . PASS 0     (BLOCKED 6: not started)
    PASS includes "resident": a persistent script that stayed responsive for -TimeoutSec.

.EXAMPLE
    .\Invoke-AhkProbe.ps1 -Script C:\proj\app.ahk -Mode Validate
    .\Invoke-AhkProbe.ps1 -Script C:\proj\app.ahk -Persistent -Hotkey 0 -StubDialogs
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Script,
    [ValidateSet('Run', 'Validate', 'Drive')] [string] $Mode = 'Run',
    [int] $TimeoutSec = 10,
    [switch] $Persistent,          # expected to stay resident: observe for TimeoutSec, then judge
    [int[]] $Hotkey = @(),         # hotkey indexes (definition order, from 0) to fire with WM_HOTKEY after ready
    [switch] $StubDialogs,         # MsgBox/InputBox answered with the safe choice, no window
    [ValidateSet('exit', 'continue')] [string] $OnError = 'exit',
    [switch] $VisibleDesktop,      # run on the user's desktop (windows show; collision check applies)
    [switch] $AllowCollision,      # with -VisibleDesktop: run although the same script is already running
    [string] $EvidenceDir,         # Drive: a new folder that the app's repo ignores
    [string] $StandIn,             # Drive: the app repo's stand-in script (.mjs)
    [string] $AhkExe
)
$ErrorActionPreference = 'Stop'

if (-not ('AhkProbeSandbox' -as [type])) {
    # C# 5 only: Windows PowerShell 5.1 compiles this with its own csc.
    Add-Type -TypeDefinition @'
using System; using System.Collections.Concurrent; using System.Collections.Generic; using System.IO;
using System.Runtime.InteropServices; using System.Text; using System.Threading; using Microsoft.Win32.SafeHandles;

// One target process on a private desktop, inside a kill-on-close Job Object. It owns the pipes,
// so output is read on its own threads and the only process it can ever kill is the one it started.
public sealed class AhkProbeSandbox : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError; }
    [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }
    [StructLayout(LayoutKind.Sequential)] struct JOB_BASIC { public long PerProcessUserTimeLimit, PerJobUserTimeLimit; public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize; public uint ActiveProcessLimit; public UIntPtr Affinity; public uint PriorityClass, SchedulingClass; }
    [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong a, b, c, d, e, f; }
    [StructLayout(LayoutKind.Sequential)] struct JOB_EXTENDED { public JOB_BASIC Basic; public IO_COUNTERS Io;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed; }
    delegate bool EnumProc(IntPtr h, IntPtr l);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CreatePipe(out IntPtr r, out IntPtr w, ref SECURITY_ATTRIBUTES sa, uint size);
    [DllImport("kernel32.dll")] static extern bool SetHandleInformation(IntPtr h, uint mask, uint flags);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr h);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr h, uint code);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObjectW(IntPtr sa, string name);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job, int cls, ref JOB_EXTENDED info, int size);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr proc);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr CreateDesktopW(string name, IntPtr dev, IntPtr dm, uint flags, uint access, IntPtr sa);
    [DllImport("user32.dll")] static extern bool CloseDesktop(IntPtr h);
    [DllImport("user32.dll")] static extern bool EnumDesktopWindows(IntPtr desk, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint m, IntPtr w, IntPtr l, uint f, uint ms, out IntPtr r);

    IntPtr hDesk, hJob, hProc; string desktop; bool guest; Thread outThread, errThread;
    readonly StringBuilder err = new StringBuilder();
    public readonly ConcurrentQueue<string> Lines = new ConcurrentQueue<string>();
    public int Pid;

    // host: start on that sandbox's desktop and in its job; the host must be disposed last.
    public int Start(string exe, string args, string workDir, bool hidden, AhkProbeSandbox host) {
        if (host != null) { guest = true; hDesk = host.hDesk; hJob = host.hJob; desktop = host.desktop; }
        else Isolate(hidden);
        return Launch(exe, args, workDir);
    }

    void Isolate(bool hidden) {
        if (hidden) {
            string name = "ahkprobe-" + Guid.NewGuid().ToString("N").Substring(0, 8);
            hDesk = CreateDesktopW(name, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000, IntPtr.Zero);   // GENERIC_ALL
            if (hDesk == IntPtr.Zero) throw new InvalidOperationException("CreateDesktop failed: " + Marshal.GetLastWin32Error());
            desktop = "WinSta0\\" + name;
        }
        hJob = CreateJobObjectW(IntPtr.Zero, null);
        var lim = new JOB_EXTENDED(); lim.Basic.LimitFlags = 0x2000;                                // KILL_ON_JOB_CLOSE
        if (!SetInformationJobObject(hJob, 9, ref lim, Marshal.SizeOf(typeof(JOB_EXTENDED)))) throw new InvalidOperationException("SetInformationJobObject failed");
    }

    int Launch(string exe, string args, string workDir) {
        var sa = new SECURITY_ATTRIBUTES(); sa.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)); sa.bInheritHandle = true;
        IntPtr outR, outW, errR, errW;
        if (!CreatePipe(out outR, out outW, ref sa, 0) || !CreatePipe(out errR, out errW, ref sa, 0)) throw new InvalidOperationException("CreatePipe failed");
        SetHandleInformation(outR, 1, 0); SetHandleInformation(errR, 1, 0);                         // read ends are not inherited

        var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        si.dwFlags = 0x100; si.hStdOutput = outW; si.hStdError = errW; si.lpDesktop = desktop;      // STARTF_USESTDHANDLES
        PROCESS_INFORMATION pi;
        var cmd = new StringBuilder("\"" + exe + "\" " + args);
        if (!CreateProcessW(null, cmd, IntPtr.Zero, IntPtr.Zero, true, 0x4 | 0x08000000, IntPtr.Zero, workDir, ref si, out pi))   // SUSPENDED | NO_WINDOW
            throw new InvalidOperationException("CreateProcess failed: " + Marshal.GetLastWin32Error());
        hProc = pi.hProcess; Pid = pi.dwProcessId;
        bool assigned = AssignProcessToJobObject(hJob, hProc);
        if (!assigned) { TerminateProcess(hProc, 1); throw new InvalidOperationException("AssignProcessToJobObject failed: " + Marshal.GetLastWin32Error()); }
        ResumeThread(pi.hThread); CloseHandle(pi.hThread); CloseHandle(outW); CloseHandle(errW);

        outThread = new Thread(() => Pump(outR, s => Lines.Enqueue(s))); outThread.IsBackground = true; outThread.Start();
        errThread = new Thread(() => Pump(errR, s => { lock (err) err.AppendLine(s); })); errThread.IsBackground = true; errThread.Start();
        return Pid;
    }

    static void Pump(IntPtr h, Action<string> onLine) {
        using (var r = new StreamReader(new FileStream(new SafeFileHandle(h, true), FileAccess.Read, 4096, false), new UTF8Encoding(false))) {
            string line; while ((line = r.ReadLine()) != null) onLine(line);
        }
    }

    public bool HasExited() { return WaitForSingleObject(hProc, 0) == 0; }
    public bool WaitExit(int ms) { return WaitForSingleObject(hProc, (uint)ms) == 0; }
    public int ExitCode() { uint c; GetExitCodeProcess(hProc, out c); return unchecked((int)c); }
    public void Kill() { TerminateProcess(hProc, 1); }
    public string Stderr() { lock (err) return err.ToString(); }
    public void DrainOutput(int ms) { if (outThread != null) outThread.Join(ms); if (errThread != null) errThread.Join(ms); }

    // Top-level windows of the target's desktop (the user's desktop when not hidden).
    void Each(EnumProc cb) { EnumDesktopWindows(hDesk, cb, IntPtr.Zero); }      // hDesk 0 = this thread's desktop
    public IntPtr MainWindow() {
        IntPtr found = IntPtr.Zero; int pid = Pid;
        Each((h, l) => {
            uint owner; GetWindowThreadProcessId(h, out owner);
            if (owner != (uint)pid) return true;
            var s = new StringBuilder(64); GetClassNameW(h, s, 64);
            if (s.ToString() == "AutoHotkey") { found = h; return false; }
            return true;
        });
        return found;
    }
    // "class|title" of every visible window the target owns: a dialog that would have stayed on screen.
    public string[] OpenWindows() {
        var list = new List<string>(); int pid = Pid;
        Each((h, l) => {
            uint owner; GetWindowThreadProcessId(h, out owner);
            if (owner != (uint)pid || !IsWindowVisible(h)) return true;
            var c = new StringBuilder(128); GetClassNameW(h, c, 128);
            var t = new StringBuilder(256); GetWindowTextW(h, t, 256);
            list.Add(c + "|" + t); return true;
        });
        return list.ToArray();
    }
    public bool FireHotkey(IntPtr h, int index) { return PostMessageW(h, 0x312, (IntPtr)index, IntPtr.Zero); }
    public bool Responsive(IntPtr h, uint ms) { IntPtr r; return SendMessageTimeoutW(h, 0, IntPtr.Zero, IntPtr.Zero, 2, ms, out r) != IntPtr.Zero; }

    public void Dispose() {
        if (hProc != IntPtr.Zero && !HasExited()) Kill();
        if (guest) hJob = hDesk = IntPtr.Zero;                                   // the host's
        if (hJob != IntPtr.Zero) { CloseHandle(hJob); hJob = IntPtr.Zero; }      // kill-on-close ends any child the target started
        if (hProc != IntPtr.Zero) { CloseHandle(hProc); hProc = IntPtr.Zero; }
        if (hDesk != IntPtr.Zero) { CloseDesktop(hDesk); hDesk = IntPtr.Zero; }
    }
}
'@
}

function Find-AhkExe {
    if ($AhkExe) { return $AhkExe }
    $cmd = Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $default = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
    if (Test-Path $default) { return $default }
    throw 'AutoHotkey64.exe not found; pass -AhkExe.'
}

$Script = (Resolve-Path $Script).Path
$drive = $Mode -eq 'Drive'
$sb = $standInBox = $spawnedPid = $work = $result = $null
# A drive that fails on the way leaves no app and no unused copy, and tells AppDrive.mjs why.
trap {
    if ($drive) {
        if ($sb) { $sb.Dispose() }
        if ($standInBox) { Stop-StandIn }
        if ($work -and -not $spawnedPid) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
        if ($result.evidence) { $result.stderr = "$_"; Finish 'ERROR' }
    }
    break
}
if ($drive) {
    if (-not $EvidenceDir) { throw '-Mode Drive needs -EvidenceDir.' }
    if ($VisibleDesktop) { throw '-Mode Drive runs on the hidden desktop only.' }
    if ($StandIn) { $StandIn = (Resolve-Path $StandIn).Path }
    $EvidenceDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($EvidenceDir)
    if (Test-Path $EvidenceDir) { throw "Evidence folder already exists: $EvidenceDir" }
    # --show-cdup is relative, so no non-ASCII path crosses the console encoding.
    $up = git -C (Split-Path $Script) rev-parse --show-cdup
    if ($LASTEXITCODE) { throw "Not in a git repository: $Script" }
    $repo = [IO.Path]::GetFullPath((Join-Path (Split-Path $Script) "$up")).TrimEnd('\')
    if ($StandIn -and -not $StandIn.StartsWith("$repo\", 'OrdinalIgnoreCase')) { throw "The stand-in must be in the app's repository: $StandIn" }
    git -C $repo check-ignore -q -- (Join-Path $EvidenceDir 'x')
    if ($LASTEXITCODE) { throw "The app's repository must ignore the evidence folder: $EvidenceDir" }
}
$exe = Find-AhkExe
$result = [ordered]@{ verdict = 'PASS'; mode = $Mode; script = $Script; desktop = $(if ($VisibleDesktop) { 'visible' } else { 'hidden' })
    exitCode = $null; timedOut = $false; resident = $false; responsive = $null; hotkeysFired = @(); errors = @(); asserts = @(); steps = @()
    dialogs = @(); windows = @(); warnings = @(); logs = @(); done = $null; output = @(); stderr = '' }

# Renamed into place, so a reader never sees half a file.
function Write-DriveJson([string] $name, $data) {
    $path = Join-Path $EvidenceDir $name
    [IO.File]::WriteAllText("$path.tmp", ($data | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move("$path.tmp", $path)
}

# The job ends the stand-in and everything it started; its output is kept as evidence.
function Stop-StandIn {
    if (-not $standInBox.HasExited()) { $standInBox.Kill() }
    $standInBox.DrainOutput(2000)
    $text = ($standInBox.Lines.ToArray() -join "`n") + "`n" + $standInBox.Stderr()
    [IO.File]::WriteAllText((Join-Path $EvidenceDir 'stand-in.log'), $text, [Text.UTF8Encoding]::new($false))
    $standInBox.Dispose()
}

function Finish([string] $verdict) {
    $result.verdict = $verdict
    if ($drive) { Write-DriveJson 'result.json' $result }
    $result | ConvertTo-Json -Depth 6
    exit (@{ PASS = 0; FAIL = 1; ERROR = 2; TIMEOUT = 3; CRASH = 4; HUNG = 5; BLOCKED = 6 })[$verdict]
}

# On the user's desktop another copy of this script (the user's live instance) could lose its hotkeys or be
# replaced by #SingleInstance. A private desktop has its own hotkeys and its own window list, so no check there.
if ($VisibleDesktop -and $Mode -eq 'Run' -and -not $AllowCollision) {
    $escaped = [regex]::Escape($Script)
    $running = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" | Where-Object { $_.CommandLine -match $escaped })
    if ($running.Count) {
        $result.stderr = "Already running as PID $($running.ProcessId -join ', '). Isolate the test or pass -AllowCollision."
        Finish 'BLOCKED'
    }
}

# No real credentials in the copy: git's ignored files stay out, and so does an untracked file that looks like one.
$credentialFile = '(^|/)(settings[^/]*\.ini[^/]*|license\.cache[^/]*|\.env[^/]*)$'
function Copy-App([string] $from, [string] $to) {
    $encoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    try {
        $tracked = git -C $from ls-files -z --cached
        $code = $LASTEXITCODE
        $untracked = git -C $from ls-files -z --others --exclude-standard
        if ($code -or $LASTEXITCODE) { throw "git ls-files failed in $from" }
    } finally { [Console]::OutputEncoding = $encoding }
    $names = @("$tracked" -split "`0") + @("$untracked" -split "`0" | Where-Object { $_ -notmatch $credentialFile })
    foreach ($name in $names | Where-Object { $_ } | Sort-Object -Unique -CaseSensitive) {
        $source = Join-Path $from $name
        if (-not [IO.File]::Exists($source)) { continue }      # deleted in the working tree
        $target = Join-Path $to $name
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::Copy($source, $target, $true)
    }
}

$probeDir = $PSScriptRoot
$keepWork = $false
$work = Join-Path ([IO.Path]::GetTempPath()) ("ahkprobe-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$argList = @('/ErrorStdOut')
if ($Mode -eq 'Validate') {
    $argList += '/Validate'
} else {
    # AutoHotkey honours exactly one /include, so merge everything into one prelude.
    $prelude = @('#Requires AutoHotkey v2.0', '#Warn All, StdOut', "#Include `"$probeDir\AhkProbe.ahk`"")
    if ($StubDialogs) { $prelude += "#Include `"$probeDir\AhkProbeDialogStubs.ahk`"" }
    $preludePath = Join-Path $work 'prelude.ahk'
    [IO.File]::WriteAllText($preludePath, ($prelude -join "`r`n") + "`r`n", [Text.UTF8Encoding]::new($true))
    $argList += @('/include', $preludePath)
}
$target = $Script
$childEnv = @{}
if ($drive) {
    $copy = Join-Path $work 'app'
    $localAppData = Join-Path $work 'local'
    $null = New-Item -ItemType Directory -Path $copy, $localAppData
    Copy-App $repo $copy
    $target = Join-Path $copy $Script.Substring($repo.Length + 1)
    if (-not (Test-Path $target)) { throw "git ignores the script: $Script" }
    # WEBVIEW2_USER_DATA_FOLDER does not isolate: the app passes its own folder, built from LOCALAPPDATA.
    $null = New-Item -ItemType Directory -Path $EvidenceDir
    $result.evidence = $EvidenceDir
    if ($StandIn) {
        $standInScript = Join-Path $copy $StandIn.Substring($repo.Length + 1)
        if (-not (Test-Path $standInScript)) { throw "git ignores the stand-in: $StandIn" }
        $readyFile = Join-Path $work 'stand-in.json'
        $node = (Get-Command node -CommandType Application | Select-Object -First 1).Source
        $box = [AhkProbeSandbox]::new()
        $null = $box.Start($node, "`"$standInScript`" `"$copy`" `"$readyFile`"", $copy, $true, $null)
        $standInBox = $box
        $end = (Get-Date).AddSeconds(30)
        while (-not (Test-Path $readyFile) -and -not $standInBox.HasExited() -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 50 }
        if (-not (Test-Path $readyFile) -or $standInBox.HasExited()) { $standInBox.DrainOutput(500); throw "The stand-in did not start: $($standInBox.Stderr())" }
        (Get-Content $readyFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $childEnv[$_.Name] = "$($_.Value)" }
    }
    # After the stand-in, so it is not one of its ports. fetch refuses its "bad ports" (6669, ...); the last is 10080.
    $port = 0
    for ($try = 0; -not $port -and $try -lt 50; $try++) {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, (Get-Random -Minimum 10081 -Maximum 65536))
        try { $listener.Start(); $port = $listener.LocalEndpoint.Port } catch { } finally { $listener.Stop() }
    }
    if (-not $port) { throw 'No free port for the DevTools protocol.' }
    # Last, so a stand-in cannot undo the isolation. AIH_DRIVE tells the app to refuse when it lacks a stand-in.
    $childEnv.LOCALAPPDATA = $localAppData
    $childEnv.AIH_DEVTOOLS_PORT = "$port"
    $childEnv.AIH_DRIVE = 'synthetic'
}
$argList += $target

$env:AHKPROBE_ONERROR = $OnError      # the target inherits it
$sb = [AhkProbeSandbox]::new()
$started = Get-Date
$workDir = if ($drive) { Split-Path $target } else { (Get-Location).ProviderPath }
$savedEnv = @{}
foreach ($name in $childEnv.Keys) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
    [Environment]::SetEnvironmentVariable($name, $childEnv[$name])
}
try { $spawnedPid = $sb.Start($exe, (($argList | ForEach-Object { "`"$_`"" }) -join ' '), $workDir, -not $VisibleDesktop, $standInBox) }   # the only process this script may ever kill
finally { foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name]) } }
if ($drive) {
    Write-DriveJson 'session.json' ([ordered]@{ pid = $spawnedPid; port = $port; desktop = $result.desktop; script = $target; workDir = $work; localAppData = $localAppData })
}
$lines = $sb.Lines
$deadline = $started.AddSeconds($TimeoutSec)

function Wait-Until([scriptblock] $cond) {
    while ((Get-Date) -lt $deadline -and -not $sb.HasExited()) {
        if (& $cond) { return $true }
        Start-Sleep -Milliseconds 25
    }
    return (& $cond)
}

if ($Mode -ne 'Validate' -and $Hotkey.Count) {
    $ready = Wait-Until { @($lines.ToArray() | Where-Object { $_ -like 'AHKPROBE|ready|*' }).Count -gt 0 }
    $hwnd = $sb.MainWindow()
    if ($ready -and $hwnd -ne [IntPtr]::Zero) {
        foreach ($i in $Hotkey) {
            if ($sb.FireHotkey($hwnd, $i)) { $result.hotkeysFired += $i }
            Start-Sleep -Milliseconds 100
        }
    }
}

if ($drive) {
    while (-not $sb.HasExited() -and -not (Test-Path (Join-Path $EvidenceDir 'stop'))) {
        if ($standInBox -and $standInBox.HasExited()) { $standInEnded = $true; break }
        Start-Sleep -Milliseconds 100
    }
} else {
    $null = Wait-Until { $false }
}
if (-not $sb.HasExited()) {
    $result.timedOut = $true
    $hwnd = $sb.MainWindow()
    $result.responsive = ($hwnd -ne [IntPtr]::Zero) -and $sb.Responsive($hwnd, 4000)
    $result.windows = @($sb.OpenWindows())
    $sb.Kill()
}
$null = $sb.WaitExit(5000)
$sb.DrainOutput(2000)
$result.exitCode = if ($result.timedOut) { $null } else { $sb.ExitCode() }
$result.stderr = $sb.Stderr().Trim()
$sb.Dispose()
if ($standInBox) { Stop-StandIn }
if ($standInEnded) { $result.stderr += "`nThe stand-in ended before the drive; see stand-in.log." }

foreach ($line in $lines.ToArray()) {
    if ($line -match '^AHKPROBE\|(\w+)\|(.*)$') {
        $data = $Matches[2] | ConvertFrom-Json
        switch ($Matches[1]) {
            'error'  { $result.errors += $data }
            'assert' { $result.asserts += $data }
            'step'   { $result.steps += $data }
            'dialog' { $result.dialogs += $data }
            'done'   { $result.done = $data }
            'ready'  { }
            default  { $result.logs += $data }
        }
    } elseif ($line -match '==> Warning:') {
        $result.warnings += $line
    } else {
        $result.output += $line
    }
}

# A crash while exiting can still leave exit code 0; Windows Error Reporting writes a local dump first.
$dump = Get-ChildItem @("$env:LOCALAPPDATA\CrashDumps"; if ($drive) { "$localAppData\CrashDumps" }) -Filter "*.$spawnedPid.dmp" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $started } | Select-Object -First 1
if ($drive) {
    $lost = $null
    Get-ChildItem (Split-Path $target) -Force | Where-Object { $_.Name -eq 'Logs' -or $_.Extension -eq '.log' } |
        Copy-Item -Destination $EvidenceDir -Recurse -ErrorAction SilentlyContinue -ErrorVariable lost
    if ($dump -and $dump.FullName.StartsWith($work)) { $dump = Copy-Item $dump.FullName $EvidenceDir -PassThru }
    if ($lost) { $result.stderr += "`nApp logs not copied, kept in ${work}: $lost"; $keepWork = $true }
}
# WebView2 processes release their profile a moment after the job ends them.
for ($try = 0; $try -lt 20 -and -not $keepWork -and (Test-Path $work); $try++) {
    if ($try) { Start-Sleep -Milliseconds 250 }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

if ($dump) { $result.crashDump = $dump.FullName; Finish 'CRASH' }
if ($result.timedOut -and -not $result.responsive) { Finish 'HUNG' }
if ($standInEnded) { Finish 'ERROR' }
if ($result.errors.Count -or $result.exitCode -in 2, 3 -or ($result.stderr -and $result.exitCode -ne 0)) { Finish 'ERROR' }
if (@($result.asserts).Count -or @($result.steps | Where-Object { -not $_.ok }).Count -or $result.exitCode -eq 1) { Finish 'FAIL' }
if ($result.timedOut -and -not $Persistent -and -not $drive) { Finish 'TIMEOUT' }
$result.resident = $result.timedOut
Finish 'PASS'
