---
name: ahk-ctx-script-debugging
description: >
  Any AutoHotkey v2 (.ahk) script or fenced AHK example that isn't behaving: it won't compile, a
  hotkey does nothing when pressed with no error box, an error popup appears from a hotkey, timer,
  or GUI callback, the same compile error keeps moving to a new line every time you fix it, or a
  syntax check hangs the terminal. Covers the bundled runner and in-process probe (validate,
  run with structured errors instead of popups, fire hotkeys, detect hangs and crashes), the
  one-error-per-run fix loop, and assertions for silent logic bugs. Use for "why won't my hotkey
  fire", "auto-fix this AutoHotkey error", "debug this ahk script", "syntax-check this without
  hanging", pasted AHK error text, "Property is read-only" or two names that differ only by case,
  or "audit this example with ErrorStdOut". Also the App Drive core: start a WebView2 app from an
  isolated copy, operate its page and keep evidence. Not for writing a new script from scratch, converting
  v1 to v2, or conceptual syntax questions when nothing is broken.
metadata:
  version: "2026.10.16"
---

# Debugging AutoHotkey v2 Scripts

## Trigger Phrase Routing

| Signal | Read first |
|---|---|
| won't compile, syntax error, `/ErrorStdOut`, `/Validate` | `## Step 1 — Validate` |
| `Property is read-only`, a variable or member spelled with different case, local named like a function or class | `### Name-case check` |
| runtime error, error popup after startup, hotkey/timer/GUI callback throws | `## Step 2 — Run with the probe` |
| exit code, verdict, hang, crash | `### Reading the verdict` |
| same error moves, one-error-per-run | `## Step 3 — The fix loop` |
| compiles but hotkey does nothing, silent logic bug | `## Step 4 — Silent logic bugs` |
| include/project entry point, multi-file | `### Multi-file projects` |
| App Drive, operate a real WebView2 app, screenshot its page | `## App Drive` |
| no PowerShell, Git Bash, MSYS | `## Without PowerShell` |

The AHK v2 interpreter is the only ground truth for whether a script compiles and what a runtime
error was. This Skill runs it safely and repeatedly until the script converges. The method is
adapted from ahkh ([owhs/AHKTestHarness](https://github.com/owhs/AHKTestHarness)). Like ahkh, the
runner puts the target on a private desktop inside a kill-on-close Job Object, so no window reaches
the user's screen. ahkh adds screenshots, UIA trees and synthetic input; use it when those are needed.

Bundled tools, in `scripts/` next to this file:

| File | Role |
|---|---|
| `Invoke-AhkProbe.ps1` | Runner: validate or run on a hidden desktop, timeout, PID-only kill, hotkey firing, hang and crash detection, one JSON verdict |
| `AhkProbe.ahk` | Probe injected with `/include`: uncaught errors become `AHKPROBE\|error\|{json}` lines; `Assert`, `Expect`, `Step`, `WaitFor`, `Log`, `Mark`, `Done` for test scripts |
| `Test-AhkNameCase.ps1` | Static check for names that differ only by case (a collision the interpreter does not report at load): one JSON verdict, exit 1 on findings |
| `AppDrive.mjs` | Operates an app that the runner started with `-Mode Drive`: page evaluate, click, screenshot, stop (Node 22+) |
| `AhkProbeDialogStubs.ahk` | Optional: `MsgBox`/`InputBox` answered with the safe choice (No, Cancel, Abort, OK) and recorded, no window |

The host supplies the command runner and approval policy. If Windows AHK cannot run in the
current environment, report that and fall back to static inspection.

## Rules

1. **Launch AHK through a runner that owns a timeout.** A script that registers a hotkey, timer,
   GUI, or hook stays resident like it does for a real user, so a bare blocking call waits
   forever. Most real AHK tools are persistent by design.
2. **Kill only the PID you spawned.** More than one `AutoHotkey64.exe` is normally running (the
   user's live tool plus your test copy), and a kill by image name (`taskkill /IM`,
   `Stop-Process -Name`, `pkill -f`) can end the user's application. If the process handle is
   lost, recover the PID by matching `CommandLine` against the exact script path.
3. **Test the script as it is.** Inject instrumentation with `/include` (AutoHotkey honours exactly
   one; the runner merges everything into one prelude) and keep the target file unchanged. For a
   temporary code change, patch a copy in a temp folder.
4. **Wait on a condition, not a fixed sleep:** the probe's `ready` line, process exit, or
   `AhkProbe.WaitFor`.

## Step 1 — Validate

```powershell
& "<skill>\scripts\Invoke-AhkProbe.ps1" -Script C:\proj\app.ahk -Mode Validate
```

`/Validate` parses the script and exits, persistent or not, so this never waits for a timeout.
`ERROR` puts the interpreter text in `stderr`: `path (line) : ==> message`, often followed by
`Specifically: <code>`. Run it after every `.ahk` edit.

### Name-case check

AutoHotkey identifiers are case-insensitive, so `_Tick` and `_tick` are one name, and `/Validate`
stays clean when code treats them as two. Run the check after `/Validate` on every script that
defines classes or reuses variable names:

```powershell
& "<skill>\scripts\Test-AhkNameCase.ps1" -Path C:\proj\app.ahk      # a folder scans every *.ahk below it
```

It prints one JSON object (`findings[]`, each with `kind`, `severity`, `line`, `name`, `message`) and
exits 1 when anything is found.

| Kind | Severity | What it means |
|---|---|---|
| `class-member-collision` | error | A method or property and `this.X :=` differ only by case: `Property is read-only` at run time, or the method is overwritten |
| `shadowed-name` | error | A local or parameter has the name of a function or class that the same scope calls (`map := Map()`), or uses with other case as `Name.` or `Name(` (`json := JSON.Dump(x)`): that use goes to the local |
| `inconsistent-spelling` | warning | One local is spelled with different case within one function |
| `inconsistent-member-spelling` | warning | One class member is spelled with different case within one class |

Fix each finding by renaming so the names differ in spelling, not case (`_tick` to `_timerFn`), and
keep one spelling per name. The scan is line-based and reads one file at a time, so members of a
class defined in an `#Include`d file are not compared. Hotkey bodies and functions are separate
scopes, `static` and instance members are separate namespaces, and strings, comments and
continuation sections are ignored.

## Step 2 — Run with the probe

```powershell
& "<skill>\scripts\Invoke-AhkProbe.ps1" -Script C:\proj\app.ahk                      # expected to exit
& "<skill>\scripts\Invoke-AhkProbe.ps1" -Script C:\proj\app.ahk -Persistent -TimeoutSec 5 -Hotkey 0 -StubDialogs
```

| Option | Effect |
|---|---|
| `-Persistent` | The script is expected to stay resident: observe for `-TimeoutSec`, then judge |
| `-Hotkey 0,2` | After the probe is ready, post `WM_HOTKEY` with these indexes (definition order, from 0) to the AHK main window of the spawned PID only. Works for plain, `$`, and `~` hotkeys; it cannot simulate low-level hook input (mouse hotkeys, `GetKeyState`) |
| `-StubDialogs` | Load `AhkProbeDialogStubs.ahk` |
| `-OnError continue` | Report each uncaught error and keep running (default `exit`: report, then exit 3) |
| `-VisibleDesktop` | Run on the user's desktop: windows show, and the collision check below applies |
| `-AllowCollision` | With `-VisibleDesktop`: run although the same script path is already running (see Step 4) |

The prelude also sets `#Warn All, StdOut`, so load-time warnings land in `warnings`.

### Reading the verdict

The runner prints one JSON object and exits with the verdict's code:

| Verdict | Exit | Meaning |
|---|---|---|
| `CRASH` | 4 | Windows Error Reporting wrote a dump for the PID (`crashDump`), even if the exit code was 0 |
| `HUNG` | 5 | Still running at the timeout and its main window did not answer within 4 s: a blocking call (`DllCall`, COM, a modal wait) |
| `ERROR` | 2 | `errors[]` from the probe (type, message, what, file, line, stack), or a load error in `stderr` |
| `FAIL` | 1 | `asserts[]` or failed `steps[]` from probe assertions |
| `TIMEOUT` | 3 | Still running and responsive, but not run with `-Persistent` |
| `PASS` | 0 | Exited cleanly, or `resident: true` for a responsive `-Persistent` script |
| `BLOCKED` | 6 | Not started: the same script is already running |

`stdout` lines that are not probe events are in `output`; `dialogs[]` lists stubbed dialogs. On a
timeout, `windows[]` lists each visible window the target owned as `class|title`: `#32770|app.ahk`
is a `MsgBox` that nobody can answer on the hidden desktop, so rerun with `-StubDialogs`.
An AHK `Loop` keeps pumping messages, so an infinite loop reads as responsive: `TIMEOUT` (or
`PASS` with `-Persistent`), not `HUNG`. Check CPU with `Get-Process -Id <pid>` when a resident
script should have been idle.

## Step 3 — The fix loop

1. Run Step 1, then Step 2.
2. On `ERROR`, take the one file:line and message. AHK stops at the first load error, so the next
   run usually surfaces a different error further down: that is convergence, not a regression.
3. Make the smallest fix for that error, and only that error, so each run maps to one change.
4. Re-run until `PASS`.
5. Stop after 8-10 iterations on one file: the cause is probably structural (wrong `#Include`
   order, a misunderstanding of the intended logic). Reassess instead of patching symptoms.

When the gap is AHK v2 knowledge rather than the loop, load `ahk-ctx-core` for syntax and API facts,
or the domain Skill (`ahk-ctx-logic`, `ahk-ctx-system`, `ahk-ctx-ui`, `ahk-ctx-uia`).

The three failure classes give different amounts of signal:

- **Load errors** (exit 2): file, line, and message; one per run.
- **Runtime errors** (probe `errors[]`): type, message, line, and stack at the throw site. They
  describe the symptom, not why an upstream value was wrong, so read the surrounding code or add
  `Log`/`Mark` checkpoints.
- **Silent logic bugs**: nothing to report. Step 4.

## Step 4 — Silent logic bugs

### Check for a real collision first

On the hidden desktop (the default) a test copy has its own hotkeys, hooks and window list, so it
cannot steal the user's hotkeys or replace their copy through `#SingleInstance Force`: skip this
section. With `-VisibleDesktop`, the last hotkey registration wins and `#SingleInstance Force`
would replace the user's copy. The runner then returns `BLOCKED` when the same script path is
already running. Then:

1. Check whether the script registers anything global: hotkeys (`::`, `Hotkey(`), `#HotIf`,
   `OnClipboardChange`, hooks, tray entries. Nothing global means nothing to steal; rerun with
   `-AllowCollision`.
2. With a real collision surface, isolate the test: a separate test entry point, a test-only
   binding, or a distinctive `#HotIf`. Keep production hotkeys as they are.
3. Ask the user only when the collision is real, unavoidable, and the session is open-ended.

### Instrument and assert

- **Test script.** Write a throwaway script in a temp folder that `#Include`s the target's
  library files and `AhkProbe.ahk`, then checks behaviour:

  ```autohotkey
  #Requires AutoHotkey v2.0
  #Include C:\proj\lib\Parser.ahk
  #Include <skill>\scripts\AhkProbe.ahk
  AhkProbe.Expect(ParseCount("a,b,c"), 3, "three fields")
  AhkProbe.Step("quoted field parses", () => ParseCount('"a,b",c'))   ; fails if it throws
  AhkProbe.Done()   ; exit 1 when anything failed
  ```

  Run it with the runner; failures arrive as `asserts[]` and `steps[]` with file:line, and
  `expected`/`actual` for `Expect`.
- **Exercise the real entry point:** `-Persistent -Hotkey N` drives a hotkey with no keyboard;
  `Log`/`Mark` lines from a patched copy show which branch ran.
- **Live session fallback:** `OutputDebug("checkpoint: " value)` plus DebugView (Sysinternals)
  when the script must run interactively for the user.

Remove every temporary checkpoint, test script, and patched copy before finishing, then send the
fix back through Steps 1-3.

### Multi-file projects

AHK v2 resolves a global or function only when the line using it executes, so a module that
passes Step 1 alone may still throw when its real entry point calls it. A clean check on one
file proves it parses; run Steps 1-2 on the actual entry-point script as well.

## App Drive

Start the runner in the background; it stays up until `stop`, so `-TimeoutSec` does not apply.
Then run each step in the foreground:

```powershell
$e = "C:\proj\drive-results\$(Get-Date -Format yyyyMMdd-HHmmss)"     # new, and ignored by the app's repo
pwsh -File "<skill>\scripts\Invoke-AhkProbe.ps1" -Mode Drive -Script C:\proj\main.ahk -EvidenceDir $e -OnError continue -StubDialogs   # background
node "<skill>\scripts\AppDrive.mjs" $e doctor
node "<skill>\scripts\AppDrive.mjs" $e click '#save'
node "<skill>\scripts\AppDrive.mjs" $e eval 'document.body.innerText'
node "<skill>\scripts\AppDrive.mjs" $e screenshot after-save
node "<skill>\scripts\AppDrive.mjs" $e stop
```

- **Start every drive with `doctor`** and go on only when it is ok: it waits for the page and proves
  that the app uses the redirected WebView2 folder and not the user's.
- The copy holds the working tree with its uncommitted edits, without ignored files and without
  untracked `settings*.ini*`, `license.cache*` and `.env*`. To drive an older commit, pass the script of a
  `git worktree` at that commit.
- The app must open its CDP port from `AIH_DEVTOOLS_PORT` and build its WebView2 folder from
  `LOCALAPPDATA`. `WEBVIEW2_*` variables do not isolate it.
- `click` waits up to 5 s for the element to be enabled, still and uncovered, then sends real mouse
  input. With several pages open, add `--page <part of the URL>`.
- Every step exits 1 on failure and is added to `steps.jsonl`. The `stop` verdict in `result.json`
  judges the process (`errors[]`, hang, crash; `resident: false` means the app exited by itself); the steps judge the page. A drive passes when both do.
- Evidence kept: `steps.jsonl`, `*.png`, the `Logs` folder and `*.log` beside the script, `session.json`, `result.json`.
  If the runner itself is killed, the app ends with it; the logs stay in `workDir` of `session.json`.
- The clipboard, the registry, `%APPDATA%`, `%TEMP%` and the network are still the user's. The drive
  skill of each app must supply stand-ins for outside systems.

## Without PowerShell

Apply the same rules with the shell's own tools. In Git Bash or MSYS2, path conversion rewrites
`/ErrorStdOut` and `/Validate` into `C:/Program Files/Git/...`; AutoHotkey then treats it as the
script name and shows a "file not found" **dialog**, and broken and clean scripts both return
exit 2 with empty output. Disable the conversion and bound the call:

```bash
MSYS_NO_PATHCONV=1 timeout 15 "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut /Validate "path\to\script.ahk"
```

`timeout` signals only its own child, so it is PID-safe. Python's `subprocess.run(..., timeout=15)`
avoids the shell layer entirely.

## Quick checklist

- [ ] Every AHK launch went through the runner (or a PID-safe timeout), never a bare call.
- [ ] Every kill targeted the spawned PID, never an image name.
- [ ] The target file stayed unchanged; instrumentation came in through `/include` or a copy.
- [ ] `/Validate` is clean, `Test-AhkNameCase.ps1` reports no error, and the run verdict is `PASS`
      (resident counts for persistent tools).
- [ ] Each fix answered one interpreter-reported error.
- [ ] `BLOCKED` was resolved by isolation or a confirmed-safe `-AllowCollision`, not by killing
      the user's copy.
- [ ] Temporary checkpoints, test scripts, and patched copies are removed.
- [ ] For a multi-file project, the entry-point script was checked too.
