# Module_HotkeysAndHotstrings.md
<!-- DOMAIN: Hotkeys, hotstrings, context sensitivity -->
<!-- SCOPE: Double-colon hotkeys and hotstrings, prefix symbols (~ $ * & up), the Hotkey() function, HotIf()/HotIfWin…() and #HotIf, variants, keyboard/mouse hook facts, class-based hotkey registration. Not covered: sending keys, mouse clicks, GetKeyState/KeyWait, InputHook (Module_SendAndInputHook.md); GUI control events (Module_GuiBasics.md); SetTimer (Module_Timers.md). -->
<!-- TRIGGERS: Hotkey(), HotIf(), HotIfWinActive(), #HotIf, Hotstring(), A_ThisHotkey, A_PriorHotkey, A_TimeSincePriorHotkey, "bind key", "keyboard shortcut", "context-sensitive hotkey", "only works in this app", "remap key", "hotstring", "key chord", "CapsLock &", "double tap" -->
<!-- CONSTRAINTS: Multi-line hotkey/hotstring bodies need braces. Callbacks for Hotkey()/HotIf() receive one parameter (the hotkey name) — declare it or end with `*`. A string Action is a hotkey name or On/Off/Toggle/AltTab, never a function or label name. HotIf()/HotIfWin… apply to the current thread only, and an object passed to HotIf() is never freed — create criteria once. #HotIf is positional until the next #HotIf. -->
<!-- CROSS-REF: Module_SendAndInputHook.md, Module_GuiBasics.md, Module_Timers.md, Module_ClassLifecycle.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `^l::` / `Send Text` / `return` on following lines | `^l:: {` … `}` or one action on the `::` line | v2 hotkey bodies are functions; multi-line bodies need braces |
| `#IfWinActive ahk_exe notepad.exe` | `#HotIf WinActive("ahk_exe notepad.exe")` | `#IfWin…` directives do not exist in v2 |
| `Hotkey, ^c, MyLabel` | `Hotkey("^c", MyFunc)` | Labels are not callbacks; a string Action is treated as a hotkey name or special value |
| `Hotkey, IfWinActive, Title` | `HotIfWinActive("Title")` | Replaced by HotIf / HotIfWin… functions |
| `Hotkey("F1", () => Action())` | `Hotkey("F1", (*) => Action())` | The callback is called with one parameter (the hotkey name) |
| `Hotkey("a", this.Method)` | `Hotkey("a", ObjBindMethod(this, "Method"))` | The method's hidden `this` would receive the hotkey name; a method that needs more parameters than the hotkey supplies is rejected by `Hotkey()` with `ValueError` ("Invalid callback function") |

## API QUICK-REFERENCE

### Hotkey Syntax

| Form | Meaning |
|------|---------|
| `^j::Send("Hi")` | One-line action |
| `^k:: {` … `}` | Function body; the hidden parameter is `ThisHotkey` |
| `^a::` stacked above `^b::Action()` | Stacked hotkeys share one action |
| `~` | Native key event is not blocked; for keyboard hotkeys this forces the keyboard hook |
| `$` | Forces the keyboard hook so `Send` cannot trigger the hotkey (no effect on mouse hotkeys) |
| `*` | Wildcard: fires even with extra modifiers held (always uses the hook) |
| `a & b::` | Custom combination; `a` becomes a prefix key (always uses the hook) |
| `F1 up::` | Fires on release (always uses the hook) |
| `::btw::by the way` | Auto-replace hotstring |
| `::/time:: {` … `}` | Hotstring that runs code |
| `:*:`, `:?:`, `:C:`, `:X:` | Hotstring options: no ending char, inside words, case-sensitive, execute |

### Hotkey() and HotIf()

| Function | Signature | Notes |
|----------|-----------|-------|
| `Hotkey()` | `Hotkey(KeyName, Action?, Options?)` | Action: callback (1 parameter), a hotkey name, or `"On"`/`"Off"`/`"Toggle"`/`"AltTab"`…; Options: `"On"`, `"Off"`, `"B"`, `"Pn"`, `"S"`, `"Tn"`, `"In"` |
| `HotIf()` | `HotIf("Expression"?)` or `HotIf(Callback?)` | Criteria for hotkeys created/modified **later in this thread**; no argument = global. A string must match an existing `#HotIf` expression |
| `HotIfWinActive()` / `HotIfWinExist()` / `HotIfWinNotActive()` / `HotIfWinNotExist()` | `(WinTitle?, WinText?)` | Strings only; evaluated with the startup `SetTitleMatchMode`/`DetectHiddenWindows` |
| `#HotIf` | `#HotIf Expression` | Positional directive: applies to every hotkey/hotstring below it until the next `#HotIf` |
| `Hotstring()` | `Hotstring(String, Replacement?, OnOffToggle?)` | Create/modify hotstrings at run time |

`Hotkey()` errors: `ValueError` (invalid key name, unsupported prefix), `TargetError` (modifying a hotkey or variant that does not exist for the current HotIf criteria), `Error` (more than 32762 hotkeys).

### Built-in Variables

| Variable | Notes |
|----------|-------|
| `A_ThisHotkey` / `ThisHotkey` param | Name of the running hotkey/hotstring |
| `A_PriorHotkey`, `A_TimeSincePriorHotkey` | Previous hotkey and ms since it fired (double-tap detection) |
| `A_TimeSinceThisHotkey` | ms since the current hotkey fired |
| `A_EndChar` | Ending character of the most recent non-auto-replace hotstring |

## FACTS ABOUT HOOKS AND #HotIf

- A script has at most one keyboard hook and one mouse hook. They are installed only when needed (hotstrings, hook hotkeys, active InputHooks, …); together they use at least 500 KB of memory. Adding more `$` hotkeys does not add more hooks.
- Keyboard hotkeys use the hook when they have `~`, `*`, `$`, are key-up or custom combinations, or are eclipsed by a wildcard; mouse hotkeys always use the mouse hook. `ListHotkeys()` shows which mechanism each hotkey uses.
- A `#HotIf` expression is evaluated when the hotkey's key is pressed (and possibly at other times, e.g. for a prefix key). Keyboard/mouse input is buffered until evaluation finishes, so slow expressions (file or network I/O) delay input. Simple `WinActive(…)`/`WinExist(…)` expressions are optimized and evaluated without running script code.
- If several variants of a hotkey are eligible, the one closest to the top of the script fires; the global (no-criteria) variant always has the lowest precedence (this exception does not apply to hotstrings).
- Every hotkey/hotstring runs in a new thread with default settings (`SendMode`, `SetTitleMatchMode`, `CoordMode`, …) unless changed during startup.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 form from V1 → V2 BREAKING CHANGES remains: `#IfWin…`, `Hotkey, …` command syntax, label strings, `return`-terminated bodies.
- Use `{ }` for multi-statement hotkey and hotstring bodies.
- Callbacks: `MyHotkey(ThisHotkey)` or `MyHotkey(*)`; bind methods with `ObjBindMethod(this, "Name")` / `this.Name.Bind(this)`. The zero-parameter and unbound wrong forms are in V1 → V2 BREAKING CHANGES.
- `HotIf(Callback)`: the callback object is kept forever. Create each criterion once (e.g. at startup) and reuse the same object to reach that variant later; calling `HotIf((*) => …)` with a new closure each time creates a new variant.
  ✗ `HotIf((*) => cond)` inside a hotkey that runs repeatedly → ✓ create the criterion once
- After using `HotIf…` to create context hotkeys, call `HotIf()` to return to global criteria for later `Hotkey()` calls in the same thread.
- Keep `#HotIf` expressions cheap (no disk/network I/O); see `## FACTS ABOUT HOOKS AND #HotIf`.
  ✗ `#HotIf FileExist("flag.txt")` → ✓ cache in a variable updated elsewhere
- Use `$` when needed; more `$` hotkeys do not add more hooks (see `## FACTS ABOUT HOOKS AND #HotIf`).
- **Repository convention:** close every `#HotIf` group with a bare `#HotIf` line so later hotkeys are visibly global.
- **Repository convention:** to remove class-registered hotkeys, call an explicit `Dispose()` that turns them `"Off"`. `Hotkey()` keeps a reference to the bound callback (which references the object), so `__Delete` will not run while the hotkeys exist.
  ✗ `obj := ""` expecting `__Delete` to unregister → ✓ `obj.Dispose()`

## RUNTIME ERROR MAPPING

| Error | Trigger | Fix |
|-------|---------|-----|
| `ValueError` ("Invalid callback function") | Zero-parameter callback, or an unbound method that needs more parameters than the hotkey supplies; raised by `Hotkey()`/`HotIf()` at registration | `(*) =>` / `Name(*)`; bind the method |
| `ValueError` | Invalid key name (e.g. `"Entre"`) or unsupported prefix | Check spelling with `GetKeyName`; see KeyList |
| `TargetError` "Nonexistent hotkey variant" | `Hotkey(k, "Off")` while a different HotIf criterion (or a new closure) is current | Select the same criterion object/expression with `HotIf` first |
| `ValueError` ("Parameter #2 of Hotkey is invalid") | `Hotkey("^c", "MyLabel")` — a string Action is read as a hotkey name or special value, not a function | Pass a function object |

## TIER 1 — Static Hotkeys and Hotstrings

```ahk
#Requires AutoHotkey v2.0

^j::Send("Hello World{Enter}")          ; one-line action

^k:: {                                   ; multi-line body needs braces
    Send("Line 1{Enter}")
    Sleep(100)
    Send("Line 2{Enter}")
}

::btw::by the way                       ; auto-replace hotstring
::/date:: {                             ; hotstring that runs code
    SendText(FormatTime(, "yyyy-MM-dd"))
}

CapsLock & a::MsgBox("CapsLock+A chord")   ; custom combination

~LButton:: {                            ; click still reaches the window
    ToolTip("Clicked")
    SetTimer(() => ToolTip(), -800)
}
```

## TIER 2 — Dynamic Hotkeys with Hotkey()

```ahk
#Requires AutoHotkey v2.0

ShowName(hk) => MsgBox("You pressed " hk)

Hotkey("F1", ShowName)                  ; named function, receives the hotkey name
Hotkey("F2", (*) => Send("inline"))     ; * absorbs the hotkey name
Hotkey("F3", ToggleF1)

ToggleF1(*) {
    static enabled := true
    enabled := !enabled
    Hotkey("F1", enabled ? "On" : "Off")
}

; Test whether a variant exists for the current HotIf criteria
try Hotkey("^!p")
catch TargetError
    TrayTip("^!p does not exist")
```

## TIER 3 — Context Sensitivity: #HotIf and HotIf()

```ahk
#Requires AutoHotkey v2.0

#HotIf WinActive("ahk_exe notepad.exe")       ; optimized simple expression
^s::MsgBox("Saving in Notepad")
#HotIf                                        ; later hotkeys are global

#HotIf !WinActive("ahk_exe Teams.exe")
^Space::MsgBox("Everywhere except Teams")
#HotIf

; Runtime context: create the criterion ONCE and reuse it
customMode := false
IsCustomMode := (*) => customMode             ; reads the global variable
HotIf(IsCustomMode)
Hotkey("Space", (*) => Send("[custom]"))
HotIf()                                       ; back to global criteria

F4:: {
    global customMode := !customMode
    ToolTip("Custom mode: " (customMode ? "ON" : "OFF"))
    SetTimer(() => ToolTip(), -1500)
}

; Later: reach the same variant by selecting the same criterion object
DisableCustomSpace() {
    HotIf(IsCustomMode)
    Hotkey("Space", "Off")
    HotIf()
}
```

## TIER 4 — Class-Managed Hotkeys

```ahk
#Requires AutoHotkey v2.0

class HotkeySet {
    __New() {
        this.keys := []
    }

    Bind(keyName, methodName) {
        Hotkey(keyName, ObjBindMethod(this, methodName), "On")
        this.keys.Push(keyName)
    }

    ; Explicit cleanup: Hotkey() keeps the bound callback (and therefore this object) alive
    Dispose() {
        for keyName in this.keys
            Hotkey(keyName, "Off")
        this.keys := []
    }

    Greet(hk) => MsgBox("Triggered by " hk)
}

hs := HotkeySet()
hs.Bind("^!g", "Greet")
^!x::hs.Dispose()
```

## DROP-IN RECIPES

```ahk
; ContextHotkey — hotkey active only in one exe; returns a function that turns it off.
ContextHotkey(keyName, exeName, action) {
    criterion := (*) => WinActive("ahk_exe " exeName)    ; kept by HotIf for the process lifetime
    HotIf(criterion)
    Hotkey(keyName, action, "On")
    HotIf()
    return Off
    Off() {
        HotIf(criterion)                                 ; same object = same variant
        Hotkey(keyName, "Off")
        HotIf()
    }
}
; offFn := ContextHotkey("^s", "notepad.exe", (*) => MsgBox("saved"))
; offFn()
```

## SEE ALSO

- `Module_SendAndInputHook.md` — Send modes, GetKeyState/KeyWait, InputHook, mouse clicks.
- `Module_Timers.md` (ahk-ctx-logic) — SetTimer patterns.
- `Module_ClassLifecycle.md` (ahk-ctx-core) — binding and object lifetime.
