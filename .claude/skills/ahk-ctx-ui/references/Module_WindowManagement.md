# Module_WindowManagement.md
<!-- DOMAIN: Window detection and manipulation -->
<!-- SCOPE: WinTitle criteria (ahk_id, pure HWND, ahk_class, ahk_exe, ahk_pid, ahk_group), SetTitleMatchMode, DetectHiddenWindows, Win* existence/wait/state/metadata/mutation functions, window groups, batch operations, an HWND-anchored wrapper class. Not covered: Control* functions (Module_ControlInteraction.md), SetWinEventHook (Module_WinEventHook.md), mouse/CoordMode (Module_SendAndInputHook.md, Module_ScreenCoordinates.md). -->
<!-- TRIGGERS: WinExist, WinActive, WinActivate, WinWait, WinWaitActive, WinWaitClose, WinClose, WinGetTitle, WinGetClass, WinGetProcessName, WinGetPID, WinGetPos, WinGetList, WinGetMinMax, WinMove, WinHide, WinShow, WinMinimize, WinSetAlwaysOnTop, WinSetTransparent, GroupAdd, GroupActivate, SetTitleMatchMode, DetectHiddenWindows, ahk_id, ahk_class, ahk_exe, HWND, "check if window is open", "wait for window", "batch minimize", "window group" -->
<!-- CONSTRAINTS: Most Win* functions throw TargetError when no window matches; WinExist/WinActive/WinWait*/WinGetList do not. HWNDs are Integers. SetTitleMatchMode and DetectHiddenWindows are per-thread settings (each hotkey/timer/GUI thread starts with the startup defaults). `%var%` inside a quoted string is literal text in v2. -->
<!-- CROSS-REF: Module_ControlInteraction.md, Module_WinEventHook.md, Module_ScreenCoordinates.md, Module_ExceptionHandling.md, Module_ClassBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `WinActivate, ahk_id %hwnd%` | `WinActivate("ahk_id " hwnd)` or `WinActivate(hwnd)` | v1 command syntax; inside a v2 quoted string `%hwnd%` is literal text, so the title never matches → `TargetError` |
| `IfWinExist, Title` / `IfWinActive` | `if WinExist("Title")` / `if WinActive("Title")` | v1 `IfWin…` commands do not exist |
| `WinGet, list, List` | `hwnds := WinGetList(WinTitle?)` | Returns an Array of HWNDs |
| `WinGetPos, X, Y, W, H, Title` | `WinGetPos(&x, &y, &w, &h, "Title")` | Output parameters take `&` references |
| `if ErrorLevel` after `WinWait` | `if !WinWait("Title",, 5)` | No ErrorLevel; WinWait returns the HWND or 0 on timeout |
| No error handling needed (v1 set ErrorLevel) | `try … catch TargetError` or a `WinExist` pre-check | v2 Win* functions throw `TargetError` when the window is missing |

## API QUICK-REFERENCE

### WinTitle Criteria

| Form | Meaning |
|------|---------|
| `"Untitled - Notepad"` | Title match per `SetTitleMatchMode` (default 2 = contains); titles are case-sensitive |
| `"ahk_class Notepad"`, `"ahk_exe notepad.exe"`, `"ahk_pid " pid` | Class / process name or path / process ID |
| `"ahk_id " hwnd` | Window by handle; obeys `DetectHiddenWindows` for top-level windows |
| `hwnd` (Integer) or an object with `.Hwnd` (e.g. a Gui) | Pure HWND; hidden windows are **always** detected (except by WinWait/WinWaitClose) |
| `"ahk_group Name"` | Members of a group made with `GroupAdd` |
| `"A"` | The active window |
| Combined | `"Untitled ahk_exe notepad.exe"` — all criteria must match |

| Setting | Notes |
|---------|-------|
| `SetTitleMatchMode(1 \| 2 \| 3 \| "RegEx")` | 1 starts-with, 2 contains (default), 3 exact, RegEx (also applies to `ahk_class`/`ahk_exe`). Returns the previous setting. Per thread. |
| `DetectHiddenWindows(true)` | Detect hidden windows by title/`ahk_id`. Per thread. |

### Existence, Wait and State

| Function | Signature | Returns | Throws |
|----------|-----------|---------|--------|
| `WinExist()` | `WinExist(WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)` | HWND or 0 (also sets the Last Found Window) | — |
| `WinActive()` | same | HWND of the active window if it matches, else 0 | — |
| `WinWait()` | `WinWait(WinTitle?, WinText?, Timeout?, …)` | HWND or 0 on timeout | — |
| `WinWaitActive()` | same | HWND or 0 on timeout | — |
| `WinWaitClose()` | same | 1, or 0 on timeout (returns 1 at once if nothing matches) | — |
| `WinActivate()` | `WinActivate(WinTitle?, …)` | — | TargetError |
| `WinClose()` | `WinClose(WinTitle?, WinText?, SecondsToWait?, …)` | — | TargetError (not in group mode); no error if the window refuses to close |
| `WinGetMinMax()` | `WinGetMinMax(WinTitle?, …)` | -1 minimized, 0 normal, 1 maximized | TargetError |
| `WinMinimize` / `WinMaximize` / `WinRestore` / `WinHide` / `WinShow` | `(WinTitle?, …)` | — | TargetError (Minimize/Hide/Show/Restore/Maximize: not in group mode) |

### Metadata

| Function | Returns | Throws |
|----------|---------|--------|
| `WinGetTitle` / `WinGetClass` / `WinGetProcessName` / `WinGetProcessPath` | String | TargetError (`WinGetClass` also OSError) |
| `WinGetPID` / `WinGetID` / `WinGetIDLast` / `WinGetCount` | Integer | WinGetPID/ID: TargetError |
| `WinGetPos(&X?, &Y?, &W?, &H?, WinTitle?, …)` / `WinGetClientPos(…)` | — (fills refs; screen coordinates, not DPI-scaled) | TargetError |
| `WinGetList(WinTitle?, …)` | Array of HWNDs, topmost first; empty Array if none | — |
| `WinGetStyle` / `WinGetExStyle` | Integer bitmask | TargetError |
| `WinGetControls` / `WinGetControlsHwnd` | Array of ClassNN / HWNDs | TargetError |

### Mutation

| Function | Notes | Throws |
|----------|-------|--------|
| `WinMove(X?, Y?, W?, H?, WinTitle?, …)` | Omitted values unchanged | TargetError, OSError |
| `WinSetAlwaysOnTop(NewSetting := 1, WinTitle?, …)` | 1 on, 0 off, -1 toggle | TargetError, OSError |
| `WinSetTransparent(N, WinTitle?, …)` | 0–255, or `"Off"` (prefer `"Off"` over 255: may improve performance) | TargetError, OSError |
| `WinSetTransColor("RRGGBB [N]", WinTitle?, …)` | One color fully transparent, optional overall alpha | TargetError, OSError |
| `WinSetTitle(NewTitle, WinTitle?, …)` | | TargetError, OSError |
| `WinRedraw(WinTitle?, …)` | Repaint | TargetError |

### Window Groups

| Function | Notes |
|----------|-------|
| `GroupAdd(Name, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)` | Adds a *specification*; groups are matched when used, not snapshotted |
| `GroupActivate(Name, Mode?)` | Activates the oldest window in the series; `"R"` = activate the newest (most recently active) window, only if no member is active. Returns the HWND or 0 |
| `GroupDeactivate(Name, Mode?)` | Activates the next window that is **not** in the group |
| `GroupClose(Name, Mode?)` | Closes the active window if it was just activated by GroupActivate/GroupDeactivate; `"A"` closes all members |
| `"ahk_group Name"` in WinTitle | `WinMinimize`, `WinMaximize`, `WinRestore`, `WinHide`, `WinShow`, `WinClose`, `WinKill` act on **all** members; other functions act on the topmost member |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 form from V1 → V2 BREAKING CHANGES remains: command syntax, `%var%` inside a string, `IfWin…`, `ErrorLevel`.
- Check each function's error contract: `WinExist`, `WinActive`, `WinWait*` and `WinGetList` return 0/empty — test them as 0 vs HWND; most other Win* functions throw `TargetError`. A window can close between two statements, so wrap follow-up calls in `try`/`catch TargetError` when that matters.
  ✗ `WinGetTitle(t)` after a stale existence check → ✓ `try … catch TargetError`
  ✗ `while !WinExist("X")` + `Sleep` → ✓ `WinWait("X",, timeout)`
- HWNDs are Integers. `if !hwnd` is the idiomatic falsy test. (`hwnd = "0"` also works — a number compared with a numeric string is compared numerically — but `!hwnd` is the repo convention.)
- `SetTitleMatchMode`, `DetectHiddenWindows`, `DetectHiddenText`, `SetWinDelay` are per thread: every hotkey, timer, menu or GUI-event thread starts with the startup defaults. Set them during startup to change the default, or at the top of the callback that needs a different value.
  ✗ `SetTitleMatchMode(3)` in a helper, expected in hotkeys → ✓ set at startup or inside each callback thread
- Calling a function does not start a new thread, so a setting changed inside a function stays changed for its caller.
- `WinGetList` returns HWNDs from topmost to bottommost; iterate the cached Array rather than calling it per item.
- Group operations use `"ahk_group Name"` for all-member actions instead of manual loops where possible. `GroupActivate`'s `"R"` mode is not "previous" (see `### Window Groups`).
  ✗ `for h in WinGetList("ahk_group G") WinMinimize(h)` → ✓ `WinMinimize("ahk_group G")`
  ✗ `GroupActivate(g, "R")` for "previous" → ✓ `"R"` = newest member when none is active

## RUNTIME ERROR MAPPING

| Error | Trigger | Fix |
|-------|---------|-----|
| `TargetError` | Window not found (closed, hidden, wrong title, wrong match mode) | Pre-check with `WinExist`, or `try … catch TargetError` |
| `OSError` | `WinSetTransparent` / `WinSetTitle` / … could not apply the change | Check privileges (UIPI: elevated target windows) |
| Wrong window matched | Default match mode 2 (contains) | Use `ahk_exe` / `ahk_class` / `ahk_id`, or `SetTitleMatchMode(3)` |

## TIER 1 — Existence, Activation, Waiting

```ahk
#Requires AutoHotkey v2.0

if hwnd := WinExist("ahk_exe notepad.exe") {
    if WinGetMinMax(hwnd) = -1
        WinRestore(hwnd)
    WinActivate(hwnd)
    if !WinWaitActive(hwnd,, 3)
        MsgBox("Activation timed out.")
} else {
    Run("notepad.exe")
    if !hwnd := WinWait("ahk_exe notepad.exe",, 10)
        MsgBox("Notepad did not appear.")
}

CloseWindow(winTitle) {
    try {
        WinClose(winTitle)
        return WinWaitClose(winTitle,, 5)       ; 1 = closed, 0 = still open after 5 s
    } catch TargetError {
        return true                              ; nothing to close
    }
}
```

## TIER 2 — Metadata and Enumeration

```ahk
#Requires AutoHotkey v2.0

DescribeWindow(winTitle) {
    if !hwnd := WinExist(winTitle)
        return "Not found: " winTitle
    WinGetPos(&x, &y, &w, &h, hwnd)
    return Format("HWND {}  class {}  exe {}  pid {}`n{}  @{},{}  {}x{}",
        hwnd, WinGetClass(hwnd), WinGetProcessName(hwnd), WinGetPID(hwnd),
        WinGetTitle(hwnd), x, y, w, h)
}

ListWindows(winTitle) {
    out := ""
    for hwnd in WinGetList(winTitle)            ; topmost first
        out .= hwnd " | " WinGetTitle(hwnd) "`n"
    return out
}

WS_CAPTION := 0xC00000, WS_EX_TOPMOST := 0x8
if hwnd := WinExist("A") {
    MsgBox(DescribeWindow(hwnd))
    hasCaption := !!(WinGetStyle(hwnd) & WS_CAPTION)
    isTopmost := !!(WinGetExStyle(hwnd) & WS_EX_TOPMOST)
    MsgBox("Caption: " hasCaption "  Topmost: " isTopmost)
}
```

## TIER 3 — Groups and Batch Operations

```ahk
#Requires AutoHotkey v2.0

GroupAdd("Editors", "ahk_exe notepad.exe")
GroupAdd("Editors", "ahk_exe code.exe")        ; specifications, matched at use time

^!Tab::GroupActivate("Editors")                ; cycle through members
^!+Tab::GroupActivate("Editors", "R")          ; newest member, if no member is active
^!m::WinMinimize("ahk_group Editors")          ; group mode: all members, no TargetError
^!r::WinRestore("ahk_group Editors")

TileLeft(winTitle) {
    hwnds := WinGetList(winTitle)
    if !hwnds.Length
        return
    h := A_ScreenHeight // hwnds.Length         ; primary monitor; see Module_ScreenCoordinates.md
    for i, hwnd in hwnds {
        try WinMove(0, (i - 1) * h, A_ScreenWidth // 2, h, hwnd)
        catch TargetError
            continue                             ; closed meanwhile
    }
}
```

## TIER 4 — HWND-Anchored Wrapper Class

```ahk
#Requires AutoHotkey v2.0

class WindowRef {
    __New(winTitle) {
        this.hwnd := WinExist(winTitle)
        if !this.hwnd
            throw TargetError("Window not found", -1, winTitle)
    }

    Exists => WinExist(this.hwnd) != 0         ; pure HWND: hidden windows count as existing
    Title  => WinGetTitle(this.hwnd)

    Activate(timeout := 3) {
        WinActivate(this.hwnd)
        return WinWaitActive(this.hwnd,, timeout)
    }

    Close(timeout := 3) {
        WinClose(this.hwnd)
        return WinWaitClose(this.hwnd,, timeout)
    }

    Move(x?, y?, w?, h?) => WinMove(x?, y?, w?, h?, this.hwnd)
}

try {
    win := WindowRef("ahk_class Notepad")
    MsgBox(win.Title)
} catch TargetError as e {
    MsgBox("No window: " e.Extra)
}
```

## DROP-IN RECIPES

```ahk
; WaitAndActivate — wait (no polling), restore, activate, confirm. Returns HWND or throws.
WaitAndActivate(winTitle, timeout := 10) {
    if !hwnd := WinWait(winTitle,, timeout)
        throw TargetError("Window never appeared", -1, winTitle)
    if WinGetMinMax(hwnd) = -1
        WinRestore(hwnd)
    WinActivate(hwnd)
    if !WinWaitActive(hwnd,, 3)
        throw TargetError("Activation timed out", -1, winTitle)
    return hwnd
}

; ForEachWindow — apply fn(hwnd) to each match; skips windows that close meanwhile.
ForEachWindow(winTitle, fn) {
    done := 0
    for hwnd in WinGetList(winTitle) {
        try {
            fn(hwnd)
            done++
        } catch TargetError {
            continue
        }
    }
    return done
}
; ForEachWindow("ahk_exe notepad.exe", WinMinimize)
```

## SEE ALSO

- `Module_ControlInteraction.md` — ControlClick/ControlSend and list/checkbox data in other programs.
- `Module_WinEventHook.md` — event-driven window monitoring instead of polling.
- `Module_ScreenCoordinates.md` — multi-monitor bounds for tiling and centering.
- `Module_ExceptionHandling.md` (ahk-ctx-logic) — TargetError handling patterns.
