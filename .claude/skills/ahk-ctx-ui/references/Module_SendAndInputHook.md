# Module_SendAndInputHook.md
<!-- DOMAIN: Simulated input and input capture -->
<!-- SCOPE: Send/SendText/SendInput/SendEvent/SendPlay, SendMode, SetKeyDelay, BlockInput, Click/MouseMove/MouseClick/MouseClickDrag/MouseGetPos, GetKeyState, KeyWait, InputHook (options, properties, events). Not covered: defining hotkeys/hotstrings and #HotIf (Module_HotkeysAndHotstrings.md); CoordMode, monitors and DPI (Module_ScreenCoordinates.md); keystrokes to background controls (Module_ControlInteraction.md). -->
<!-- TRIGGERS: Send(), SendText(), SendInput(), SendEvent(), SendPlay(), SendMode(), SetKeyDelay(), BlockInput(), Click(), MouseMove(), MouseClick(), MouseClickDrag(), MouseGetPos(), GetKeyState(), KeyWait(), InputHook(), A_KeyDelay, "press key", "type text", "send keystrokes", "click at", "wait for keypress", "is key down", "capture typing", "block input" -->
<!-- CONSTRAINTS: Default SendMode is Input; SetKeyDelay is ignored by SendInput. SendPlay is deprecated (often fails with UAC; may have no effect on Windows 11). No ErrorLevel: KeyWait returns 1/0, InputHook reports EndReason. Key names and mode letters are strings. Send/Click settings are per thread. -->
<!-- CROSS-REF: Module_HotkeysAndHotstrings.md, Module_ScreenCoordinates.md, Module_ControlInteraction.md, Module_Timers.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `Send %myVariable%` | `Send(myVariable)` | In v2 `%myVariable%` is a double-deref: it sends the contents of the variable *named by* myVariable |
| `GetKeyState(CapsLock, T)` | `GetKeyState("CapsLock", "T")` | Unquoted words are variable references |
| `KeyWait, Enter, D` | `KeyWait("Enter", "D")` | v1 command syntax |
| `KeyWait` then `if ErrorLevel` | `if !KeyWait("Enter", "D T5")` | No ErrorLevel; return value 1 = success, 0 = timeout |
| `Input, var, L5 T3` | `ih := InputHook("L5 T3")`, `ih.Start()`, `ih.Wait()` | The `Input` command was replaced by the InputHook object |
| `SetKeyDelay` then default `Send` | `SendEvent(…)` or `SendMode("Event")` | SendInput (the default) ignores SetKeyDelay |

## API QUICK-REFERENCE

### Sending Keys

| Function | Signature | Notes |
|----------|-----------|-------|
| `Send()` | `Send(Keys)` | Uses the current SendMode (default Input). `{Enter}`, `^a`, `+{Tab}`, `{Raw}`, `{Text}`, `{Blind}` |
| `SendText()` | `SendText(Text)` | Sends literal text (no `^ ! + # {}` interpretation) |
| `SendInput()` / `SendEvent()` / `SendPlay()` | `(Keys)` | Force a specific method regardless of SendMode |
| `SendMode()` | `SendMode("Input" \| "Event" \| "Play" \| "InputThenPlay")` | Also sets the mode of Click/MouseMove/MouseClick/MouseClickDrag |
| `SetKeyDelay()` | `SetKeyDelay(Delay?, PressDuration?, "Play"?)` | Applies to SendEvent (and ControlSend); with `"Play"` applies to SendPlay. Default SendEvent delay 10 ms |
| `A_KeyDelay`, `A_KeyDuration` (`…Play`) | read/write | Current SendEvent (SendPlay) delay settings |
| `A_SendMode` | read | Current mode |
| `BlockInput()` | `BlockInput("On" \| "Off" \| "Send" \| "Mouse" \| "SendAndMouse" \| "Default" \| "MouseMove" \| "MouseMoveOff")` | `"Send"`/`"Mouse"` block only during SendEvent-style sends/clicks |

Mode facts (SendMode page): SendInput is the fastest and default; it buffers user keystrokes typed during the send. If another program has a low-level keyboard hook, SendInput reverts to SendEvent (using `SetKeyDelay -1, 0`). The script's own hook is removed during SendInput, so SendInput generally cannot trigger the script's own hook hotkeys or InputHooks. SendPlay sends events directly to the active window and does not trigger hotkeys or hotstrings; it is deprecated and may not work with UAC or on Windows 11.

### Mouse

| Function | Signature | Notes |
|----------|-----------|-------|
| `Click()` | `Click(Options*)` | Components in any params: coords, button (`Left`/`Right`/`Middle`/`X1`/`X2`), count, `Down`/`Up`, `Rel`. `Click(100, 200)`, `Click("Right")`, `Click(500, 600, 2)`, `Click("100 200 0")` (move only) |
| `MouseMove()` | `MouseMove(X, Y, Speed?, Relative?)` | `"R"` for relative |
| `MouseClick()` | `MouseClick(WhichButton?, X?, Y?, ClickCount?, Speed?, DownOrUp?, Relative?)` | Click is usually simpler |
| `MouseClickDrag()` | `MouseClickDrag(WhichButton, X1, Y1, X2, Y2, Speed?, Relative?)` | |
| `MouseGetPos()` | `MouseGetPos(&X?, &Y?, &Win?, &Control?, Flag?)` | Win = HWND; Control = ClassNN (HWND with flag 2) |

Coordinates follow `CoordMode("Mouse", …)`; the default is the active window's **client area**. See `Module_ScreenCoordinates.md`.

### Key State

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `GetKeyState()` | `GetKeyState(KeyName, Mode?)` | 1/0 (axis: 0–100; undetected controller button: `""`) | Mode `"P"` physical, `"T"` toggle state; `ValueError` for an invalid key name |
| `KeyWait()` | `KeyWait(KeyName, Options?)` | 1, or 0 on timeout | Default waits for **physical release**; `"D"` wait for press; `"L"` logical state; `"T3"` timeout seconds |

### InputHook

| Member | Notes |
|--------|-------|
| `InputHook(Options?, EndKeys?, MatchList?)` | Options: `B` (Backspace ignored), `C` (case-sensitive MatchList), `I` (ignore low send level), `L#` (length limit, default 1023; `L0` = no text collection), `M`, `T#` (timeout s), `V` (visible: keys not blocked), `*` (wildcard MatchList), `E` (end keys by char) |
| `.Start()` / `.Stop()` / `.Wait(MaxTime?)` | `Wait` returns `EndReason`; if MaxTime elapses the Input keeps running |
| `.Input` | Text collected since the last `Start` |
| `.EndReason` | `"Stopped"` (also before the first Start), `"Max"`, `"Timeout"`, `"Match"`, `"EndKey"`; `""` while in progress |
| `.EndKey`, `.EndMods`, `.Match`, `.InProgress` | Details of the end |
| `.KeyOpt(Keys, KeyOptions)` | Per-key `+E` end key, `+I` ignore, `+N` notify, `+S` suppress, `+V` visible; `{All}` |
| `.OnEnd`, `.OnChar`, `.OnKeyDown`, `.OnKeyUp` | Callbacks; `OnEnd(ih)` runs in a new thread |
| `.Timeout`, `.BackspaceIsUndo`, `.CaseSensitive`, `.MinSendLevel`, `.VisibleText`, `.VisibleNonText` | Settable properties |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 form from V1 → V2 BREAKING CHANGES remains: `%var%` in Send, unquoted key names and mode letters, command syntax, `ErrorLevel`, the `Input` command.
- `SetKeyDelay` affects SendEvent only (SendPlay with `"Play"`); under the default SendInput there is no delay between keystrokes. Delays use SendEvent (or `SendMode("Event")`); the SendInput wrong form is in V1 → V2 BREAKING CHANGES.
- Use `SendText` for literal user text; `Send` interprets `+ ^ ! # {`.
  ✗ `Send(userText)` → ✓ `SendText(userText)`
- Try SendInput/SendEvent before relying on SendPlay.
  ✗ `SendMode("Play")` for games → ✓ try SendInput/SendEvent first
- `SendMode`, `SetKeyDelay`, `CoordMode`, … are per thread: each hotkey/timer/GUI thread starts with the startup defaults. A function call does not start a new thread, so a function that changes them affects its caller — restore saved values if that matters. Set `CoordMode` where mouse coordinates are screen-absolute.
- `KeyWait` without `"D"` waits for release; check its return value.
- Read `.EndReason` before trusting `.Input`; test `InputHook.Wait` results.
- Avoid `GetKeyState` polling loops when `KeyWait` or an InputHook can wait for you.
  ✗ `Loop { if GetKeyState("Enter", "P") … Sleep 10 }` → ✓ `KeyWait("Enter", "D")`

## RUNTIME ERROR MAPPING

| Error / symptom | Trigger | Fix |
|-----------------|---------|-----|
| `ValueError` | `GetKeyState("NoSuchKey")` / invalid key in KeyWait | Use names from the key list |
| Delay ignored | `SetKeyDelay` + SendInput | `SendEvent` or `SendMode("Event")` |
| Text mangled | `Send("a+b")` (the `+` is Shift) | `SendText("a+b")` |
| Clicks land in wrong place | Default CoordMode is client-relative | `CoordMode("Mouse", "Screen")` |
| SendPlay does nothing | UAC / Windows 11 | Use SendInput or SendEvent |

## TIER 1 — Send Modes

```ahk
#Requires AutoHotkey v2.0

^j:: {
    Send("Dear team,{Enter}")                    ; SendInput by default
    SendText("Price: 5+3 = {8}")                 ; literal text
}

; Slow, timed typing for apps that drop fast input
SlowType(text, delay := 30, dur := 30) {
    prevMode := A_SendMode, prevDelay := A_KeyDelay, prevDur := A_KeyDuration
    SendMode("Event")
    SetKeyDelay(delay, dur)
    SendText(text)
    SetKeyDelay(prevDelay, prevDur)              ; restore for the caller
    SendMode(prevMode)
}

^k::SlowType("typed slowly")
^l::SendEvent("{Home}+{End}")                    ; SendEvent obeys SetKeyDelay without changing the mode
```

## TIER 2 — Mouse

```ahk
#Requires AutoHotkey v2.0

^m:: {
    CoordMode("Mouse", "Screen")                 ; this thread only
    MouseGetPos(&x, &y, &win, &ctrl)
    ToolTip(x "," y " over " WinGetClass(win) " / " ctrl)
    Click(100, 200)                              ; left click at screen 100,200
    Click("Right")                               ; right click at current position
    MouseClickDrag("Left", 300, 300, 500, 300)
    MouseMove(x, y)                              ; put the cursor back
    SetTimer(() => ToolTip(), -1500)
}
```

## TIER 3 — Key State and Waiting

```ahk
#Requires AutoHotkey v2.0

~Shift:: {
    if GetKeyState("CapsLock", "T")              ; toggle state
        ToolTip("CapsLock is ON")
    KeyWait("Shift")                             ; default: wait for physical release
    ToolTip()
}

^!w:: {
    ToolTip("Press Enter within 5 s…")
    ok := KeyWait("Enter", "D T5")               ; 1 = pressed, 0 = timed out
    ToolTip(ok ? "Enter pressed" : "Timed out")
    SetTimer(() => ToolTip(), -1500)
}

~Ctrl:: {                                        ; double-tap detection
    if A_PriorHotkey = "~Ctrl" && A_TimeSincePriorHotkey < 400
        MsgBox("Double-tapped Ctrl")
}
```

## TIER 4 — InputHook

```ahk
#Requires AutoHotkey v2.0

^!c:: {
    ih := InputHook("L5 T3", "{Esc}")            ; max 5 chars, 3 s, Esc ends
    ih.Start()
    reason := ih.Wait()
    switch reason {
        case "Max":     MsgBox("Captured: " ih.Input)
        case "Timeout": MsgBox("Timed out; partial: " ih.Input)
        case "EndKey":  MsgBox("Ended by " ih.EndKey)
    }
}

^!m:: {
    ih := InputHook("T5 V", , "yes,no,cancel")   ; V: typed keys still reach the window
    ih.Start()
    if ih.Wait() = "Match"
        MsgBox("Keyword: " ih.Match)
}

; Snippet expander: type a key word then Space/Enter
snippets := Map("sig", "Best regards,`nJohn Doe", "addr", "1 Main St")
F8:: {
    ih := InputHook("V T3", "{Space}{Enter}")
    ih.Start()
    if ih.Wait() = "EndKey" && snippets.Has(ih.Input) {
        Send("{Backspace " StrLen(ih.Input) + 1 "}")   ; erase word + ending key
        SendText(snippets[ih.Input])
    }
}
```

## SEE ALSO

- `Module_HotkeysAndHotstrings.md` — defining hotkeys and contexts.
- `Module_ScreenCoordinates.md` — CoordMode, monitors, DPI.
- `Module_ControlInteraction.md` — ControlSend to background windows.
