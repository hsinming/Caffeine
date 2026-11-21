# Module_ProcessAndSystem.md
<!-- DOMAIN: System — clipboard, launching and waiting for processes, window waits, registry, environment variables -->
<!-- SCOPE: A_Clipboard, ClipWait, ClipboardAll, Run, RunWait, A_ComSpec, ProcessExist, ProcessWait, ProcessWaitClose, ProcessClose, ProcessSetPriority, WinExist/WinWait/WinWaitActive/WinWaitClose/WinActivate (system-level waits only), RegRead, RegWrite, RegDelete, RegDeleteKey, Loop Reg, EnvGet, EnvSet. COM automation (Excel, WMI, events) is in Module_COMAutomation.md. Detailed window/control manipulation is in Module_ControlInteraction.md, Module_WindowManagement.md. DllCall-level process work is in Module_DllCallBasics.md. -->
<!-- TRIGGERS: A_Clipboard, ClipWait, ClipboardAll, Run, RunWait, A_ComSpec, ProcessExist, ProcessWait, ProcessWaitClose, ProcessClose, ProcessSetPriority, WinWait, WinWaitActive, WinWaitClose, RegRead, RegWrite, RegDelete, RegDeleteKey, "Loop Reg", EnvGet, EnvSet, "start application", "launch program", "exit code", "wait for process", "kill process", "clipboard text", "copy and paste", "read registry", "write registry", "environment variable", "process priority" -->
<!-- CONSTRAINTS: Use A_Clipboard — the v1 Clipboard variable does not exist. Clear A_Clipboard before a copy and check ClipWait's return value (1 = data arrived, 0 = timeout). RunWait returns the exit code; ErrorLevel was removed. Run/RunWait throw if the target cannot be launched. ProcessWait/WinWait return 0 on timeout and wait forever when Timeout is omitted. RegRead accepts a Default (third parameter) and throws OSError only when Default is omitted. EnvSet changes only the script's own environment, inherited by programs it launches afterwards. -->
<!-- CROSS-REF: Module_COMAutomation.md, Module_ControlInteraction.md, Module_WindowManagement.md, Module_ExceptionHandling.md, Module_ScriptLifecycle.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `Clipboard` variable | `A_Clipboard` | `Clipboard` is just an unassigned variable in v2 — load-time VarUnset warning, `UnsetError` when read |
| `ClipWait` + `if ErrorLevel` | `if ClipWait(2)` | ClipWait returns 1/0; ErrorLevel was removed. `ClipWait(0)` is now the shortest wait, not 0.5 s |
| `RunWait, cmd` then `ErrorLevel` | `exitCode := RunWait(cmd)` | ErrorLevel was removed; the exit code is the return value |
| `Run, %path%, , Hide` | `Run(path, , "Hide")` | Command syntax is a syntax error |
| `RegRead, OutVar, Key, Value` | `val := RegRead(Key, Value, Default?)` | Function form; OSError when missing and no Default |
| `EnvGet, OutVar, Name` | `val := EnvGet("Name")` | Function form |
| `RegEnumKey`-style enumeration | `Loop Reg KeyName, "KVR"` with `A_LoopRegName` | Use the registry loop |

## API QUICK-REFERENCE

### Clipboard

| Item | Signature | Returns | Notes |
|------|-----------|---------|-------|
| `A_Clipboard` | read/write variable | String | Text view of the clipboard; copied files appear as their full paths. Assigning a ClipboardAll object restores all formats |
| `ClipWait()` | `ClipWait(Timeout?, WaitFor := 0)` | 1 data present, 0 timeout | Timeout in seconds (float allowed); omitted = wait forever. `WaitFor` 0 = text/files, 1 = any data |
| `ClipboardAll()` | `ClipboardAll(Data?, Size?)` | ClipboardAll object (Buffer-like) | Snapshot of all formats; formats that cannot be read are skipped |

### Process and Execution

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `Run()` | `Run(Target, WorkingDir?, Options?, &OutputVarPID?)` | — | Options: `Max`, `Min`, `Hide`. PID is blank when a verb, document or shortcut is launched. Throws if `Target` cannot be launched |
| `RunWait()` | same parameters | Exit code (signed 32-bit) | Blocks this thread (other threads can still run). Some programs return at once because they spawn another process |
| `A_ComSpec` | variable | Path of cmd.exe | From the ComSpec environment variable |
| `ProcessExist()` | `ProcessExist(PIDOrName?)` | PID or 0 | Omitted = the script's own process |
| `ProcessWait()` | `ProcessWait(PIDOrName, Timeout?)` | PID, or 0 on timeout | Timeout in seconds; omitted = forever; checks every 100 ms |
| `ProcessWaitClose()` | `ProcessWaitClose(PIDOrName, Timeout?)` | 0 when all matching processes closed, or the PID still running on timeout | |
| `ProcessClose()` | `ProcessClose(PIDOrName)` | PID, or 0 if not found / not closable | Forced termination |
| `ProcessSetPriority()` | `ProcessSetPriority(Level, PIDOrName?)` | PID, or 0 on failure | `Low`/`L`, `BelowNormal`/`B`, `Normal`/`N`, `AboveNormal`/`A`, `High`/`H`, `Realtime`/`R` |

### Window Waits (system-level)

| Function | Returns | Notes |
|----------|---------|-------|
| `WinExist(WinTitle?, ...)` | HWND or 0 | No exception when absent |
| `WinActivate(WinTitle?, ...)` | — | Throws `TargetError` if the window is not found |
| `WinWait(WinTitle?, WinText?, Timeout?, ...)` | HWND, or 0 on timeout | Omitted Timeout = forever |
| `WinWaitActive(WinTitle?, WinText?, Timeout?, ...)` | HWND, or 0 on timeout | |
| `WinWaitClose(WinTitle?, WinText?, Timeout?, ...)` | 1, or 0 on timeout | Returns 1 at once if no window matches |

### Registry

| Function | Signature | Returns / Throws | Notes |
|----------|-----------|------------------|-------|
| `RegRead()` | `RegRead(KeyName?, ValueName?, Default?)` | String or Integer; `OSError` if missing **and** no Default, or on permission errors | Blank `ValueName` = the key's default value. Supports REG_SZ, REG_EXPAND_SZ, REG_MULTI_SZ (items end in `` `n ``), REG_DWORD (always positive), REG_BINARY (hex string) |
| `RegWrite()` | `RegWrite(Value, ValueType, KeyName, ValueName?)` | `OSError` | Creates missing keys. REG_MULTI_SZ items separated by `` `n `` with no blank items |
| `RegDelete()` | `RegDelete(KeyName?, ValueName?)` | `OSError` | Deletes one value (blank = the default value) |
| `RegDeleteKey()` | `RegDeleteKey(KeyName?)` | `OSError` | Deletes a key with all subkeys and values |
| `RegCreateKey()` | `RegCreateKey(KeyName?)` | `OSError` | Creates a key without writing a value |
| `SetRegView()` | `SetRegView(64)` | — | Access the 64-bit view from a 32-bit script (or vice versa) |

Key names start with `HKLM`, `HKU`, `HKCU`, `HKCR` or `HKCC` (or the long forms). All registry functions set `A_LastError`.

### Environment Variables

| Function | Signature | Returns / Throws | Notes |
|----------|-----------|------------------|-------|
| `EnvGet()` | `EnvGet(EnvVar)` | Value, or `""` if empty or missing | Never throws for a missing variable |
| `EnvSet()` | `EnvSet(EnvVar, Value?)` | `OSError` on failure | Omitted `Value` deletes the variable. Visible only to programs the script launches afterwards |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No `Clipboard` or `ErrorLevel` — `A_Clipboard` and return values only (V1 → V2 BREAKING CHANGES).
- Before triggering a copy, set `A_Clipboard := ""`, then `if ClipWait(timeout)` — otherwise ClipWait can return at once on old content.
  ✗ `Send("^c"), Sleep(200)` → ✓ clear, `Send("^c")`, `ClipWait(2)`
- `RunWait` returns the exit code; there is no ErrorLevel (V1 → V2 BREAKING CHANGES). `Run`/`RunWait` throw when the target cannot be launched — wrap in `try` when that is a normal outcome.
- `WinWait`, `WinWaitActive`, `WinWaitClose`, `ProcessWait` and `ProcessWaitClose` wait forever when Timeout is omitted. Always passing a timeout (or commenting an intentional indefinite wait) is a **repo convention** to avoid silent hangs; the return value 0 means timeout.
- `WinActivate` throws `TargetError` when no window matches — wait for the window (`WinWait`) or check `WinExist` first.
  ✗ `Run(p)` then `WinActivate(t)` → ✓ `WinWait(t,, 5)` first
- `RegRead(Key, Value, Default)` returns `Default` instead of throwing when the key or value is missing; permission problems still throw `OSError`. Use a Default where absence is normal; put registry writes/deletes in `try` where failure is expected.
  ✗ `try v := RegRead(k, n) catch v := ""` → ✓ `v := RegRead(k, n, "")`
- `EnvSet` does not change the system or user environment and does not affect already-running programs.
  ✗ `EnvSet("PATH", ...)` to change the system PATH → ✓ edit the registry environment keys deliberately
- Office/COM constants are covered in Module_COMAutomation.md.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| Error from `Run`/`RunWait` | Target missing, bad verb, UAC cancelled | `e.Message`; `A_LastError` | `try`/`catch`; check the path; quote paths with spaces |
| `TargetError` | `WinActivate` on a window that does not exist yet | `e is TargetError` | `WinWait(title,, 5)` first |
| `OSError` | `RegRead` without Default on a missing key/value; registry permission errors; `EnvSet` failure | `e.Number` = Win32 error code | Supply Default; check `A_IsAdmin` before HKLM writes |
| `UnsetError` | Reading v1 `Clipboard` | VarUnset warning at load | Use `A_Clipboard` |

## TIER 1 — Clipboard and Application Launch
> METHODS COVERED: A_Clipboard · ClipWait · ClipboardAll · Run · WinWaitActive · Send

```ahk
#Requires AutoHotkey v2.0
A_Clipboard := ""                      ; ✓ clear so ClipWait detects the new copy
Send("^c")
if ClipWait(2) {                       ; 1 = text arrived, 0 = timed out
    A_Clipboard := StrUpper(A_Clipboard)
    Send("^v")
} else {
    MsgBox("Copy timed out.")
}

saved := ClipboardAll()                ; snapshot of every format
; ... work that overwrites the clipboard ...
A_Clipboard := saved                   ; restore
saved := ""                            ; free the snapshot

Run("notepad.exe")
if WinWaitActive("ahk_exe notepad.exe", , 5)   ; ✓ timeout
    Send("Loaded.")

; ✗ text := Clipboard                  ; v1 name — UnsetError in v2
; ✗ Run("notepad.exe"), WinActivate("ahk_exe notepad.exe")   ; TargetError if not open yet
```

## TIER 2 — Exit Codes, Registry, Environment
> METHODS COVERED: RunWait · A_ComSpec · RegWrite · RegRead · RegDelete · EnvGet · EnvSet

```ahk
#Requires AutoHotkey v2.0
RunCmd(cmd) => RunWait(A_ComSpec ' /c "' cmd '"', , "Hide")   ; ✓ returns the exit code
code := RunCmd("dir C:\ >nul")

runKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
try RegWrite('"' A_ScriptFullPath '"', "REG_SZ", runKey, "MyAHKScript")
catch OSError as e
    MsgBox("Registry write failed: " e.Message)

startup := RegRead(runKey, "MyAHKScript", "")    ; ✓ Default → no throw when missing
try RegDelete(runKey, "MyAHKScript")              ; absence is acceptable here

javaHome := EnvGet("JAVA_HOME")                   ; "" when not set
if javaHome != ""
    Run('"' javaHome '\bin\java.exe" -version', , "Hide")

EnvSet("MY_APP_MODE", "debug")    ; visible to programs launched after this line only
; ✗ RunWait(cmd), code := ErrorLevel   ; ErrorLevel does not exist in v2
```

## TIER 3 — Process and Window State
> METHODS COVERED: ProcessExist · Run (&PID) · WinWait · WinExist · WinActivate · WinWaitActive · ProcessSetPriority · ProcessClose · ProcessWaitClose

```ahk
#Requires AutoHotkey v2.0
EnsureRunning(exeName, timeout := 10) {
    if pid := ProcessExist(exeName)
        return pid
    Run(exeName, , , &newPid)                     ; PID of the launched exe
    if !WinWait("ahk_pid " newPid, , timeout)     ; 0 = timeout
        throw Error("Window did not appear within " timeout " s", -1)
    return newPid
}

Focus(winTitle) {
    if !WinExist(winTitle)
        return false
    WinActivate(winTitle)
    return WinWaitActive(winTitle, , 3) != 0
}

Terminate(pidOrName) {
    ProcessClose(pidOrName)
    if ProcessWaitClose(pidOrName, 5)              ; non-zero PID = still running after 5 s
        MsgBox("Process did not close in time.")
}

if !ProcessSetPriority("High", "notepad.exe")       ; returns 0 on failure
    MsgBox("Priority change failed.")
```

### Performance Notes

- Process and window waits poll (every 100 ms for processes); hotkeys and timers can still run meanwhile.
- To enumerate or operate on several keys or values, the docs suggest a registry loop (`Loop Reg`) rather than repeated `RegRead` calls.

## DROP-IN RECIPES

```ahk
; SafeRunProcess — launch once, wait for a window, return the PID
SafeRunProcess(exePath, winTitle, timeoutSecs := 10) {
    SplitPath(exePath, &exeName)                      ; ProcessExist matches a PID or a name without path
    if pid := ProcessExist(exeName)
        return pid
    try Run(exePath, , , &newPid)
    catch as e
        throw Error("Run failed for '" exePath "': " e.Message, -1)
    if !WinWait(winTitle, , timeoutSecs)
        throw Error("'" winTitle "' did not appear within " timeoutSecs " s", -1)
    return newPid
}

; RegReadOr — registry read that never throws for a missing value
RegReadOr(keyName, valueName, default := "") {
    try return RegRead(keyName, valueName, default)   ; Default covers "missing"
    catch OSError
        return default                                ; permission errors too
}
```

## SEE ALSO

> This module does NOT cover: COM objects, Excel/Word automation, WMI, COM events → see Module_COMAutomation.md
> This module does NOT cover: ControlClick, ControlSend, SendMessage to controls, window geometry → see Module_ControlInteraction.md
> This module does NOT cover: DllCall-level process/handle APIs → see Module_DllCallBasics.md

- `Module_COMAutomation.md` — ComObject, ComObjActive, ComObjGet (WMI), ComObjConnect, Office teardown.
- `Module_WindowManagement.md` — window and control interaction beyond waiting and activation.
- `Module_ScriptLifecycle.md` — elevation with `*RunAs`, ProcessClose in exit handlers.
- `Module_ExceptionHandling.md` — OSError/TargetError handling patterns.
