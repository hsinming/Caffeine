# Module_ControlInteraction.md
<!-- DOMAIN: Controls in other programs' windows -->
<!-- SCOPE: Control identifiers (ClassNN, text, HWND), ControlClick, ControlSend/ControlSendText, ControlFocus/GetFocus, ControlGetPos/Hwnd, text get/set, ListBox/ComboBox/Tab item functions, checkbox state. Not covered: windows themselves (Module_WindowManagement.md), controls of the script's own Gui (use GuiControl — Module_GuiBasics.md), UI Automation for modern apps (ahk-ctx-uia). -->
<!-- TRIGGERS: ControlClick, ControlSend, ControlSendText, ControlGetText, ControlSetText, ControlFocus, ControlGetFocus, ControlGetHwnd, ControlGetPos, ControlChooseIndex, ControlChooseString, ControlGetIndex, ControlGetItems, ControlFindItem, ControlAddItem, ControlDeleteItem, ControlGetChecked, ControlSetChecked, ClassNN, "click button in background", "send keys to background window", "select combobox item", "read edit box" -->
<!-- CONSTRAINTS: Control* functions throw TargetError when the window or control is missing (and for item functions, when the class is not a Combo/List[/Tab] control). Item indexes are 1-based; ControlChooseIndex(0, …) deselects all (invalid for Tab). ControlClick/ControlGetPos coordinates are client-area relative and do not follow CoordMode. ControlFindItem needs a full (case-insensitive) match and throws Error when none matches. -->
<!-- CROSS-REF: Module_WindowManagement.md, Module_SendAndInputHook.md, Module_GuiBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern | v2 correct form | Consequence |
|------------|-----------------|-------------|
| `ControlClick, Button1, WinTitle` | `ControlClick("Button1", winTitle)` | v1 comma-command line is not valid v2 |
| `ControlGetText, out, Edit1, T` | `out := ControlGetText("Edit1", t)` | Functions return values; no output-variable first parameter |
| `Control, Choose, 2, ComboBox1` | `ControlChooseIndex(2, "ComboBox1", t)` | `Control` sub-commands became separate functions |
| `ControlGet, list, List,, ListBox1` | `items := ControlGetItems("ListBox1", t)` | Returns an Array |
| `if ErrorLevel` after a Control command | `try … catch TargetError` | v2 throws |

## API QUICK-REFERENCE

Every function below ends with `WinTitle?, WinText?, ExcludeTitle?, ExcludeText?`; omitted window parameters mean the Last Found Window. `Control` is required except for `ControlSend`/`ControlSendText`/`ControlClick` (omitting it elsewhere is a load-time "Too few parameters" error). `Control` may be a ClassNN (`"Edit1"`), control text, an HWND, or an object with `.Hwnd`.

### Interaction

| Function | Signature | Returns | Throws / Notes |
|----------|-----------|---------|----------------|
| `ControlClick()` | `ControlClick(Control-or-Pos?, WinTitle?, WinText?, WhichButton?, ClickCount?, Options?, …)` | — | TargetError. `"x10 y20"` as first param = client-area position; options `"NA"` (avoids activating the target's input; may improve reliability), `"D"`/`"U"`, `"Pos"` |
| `ControlSend()` | `ControlSend(Keys, Control?, WinTitle?, …)` | — | TargetError. Same key syntax as `Send` (`{Enter}`, `^a`); window need not be active |
| `ControlSendText()` | `ControlSendText(Text, Control?, WinTitle?, …)` | — | TargetError. Sends text literally |
| `ControlFocus()` | `ControlFocus(Control, WinTitle?, …)` | — | TargetError |
| `ControlGetFocus()` | `ControlGetFocus(WinTitle?, …)` | HWND or 0 | TargetError, OSError. Only the active window can have a focused control |
| `ControlGetHwnd()` | `ControlGetHwnd(Control, WinTitle?, …)` | HWND | TargetError |
| `ControlGetClassNN()` | `ControlGetClassNN(Control, WinTitle?, …)` | String | TargetError |
| `ControlGetPos()` | `ControlGetPos(&X?, &Y?, &W?, &H?, Control, WinTitle?, …)` | — | TargetError. Relative to the window's client area |
| `ControlMove()` / `ControlHide()` / `ControlShow()` / `ControlSetEnabled()` | | — | TargetError |

### Text and Item Data

| Function | Returns | Notes |
|----------|---------|-------|
| `ControlGetText(Control, WinTitle?, …)` | String | |
| `ControlSetText(NewText, Control, WinTitle?, …)` | — | Most controls expect `` `r`n `` line breaks |
| `ControlChooseIndex(N, Control, WinTitle?, …)` | — | 1 = first item/tab; `0` deselects all (throws for Tab). Raises the control's Change/DoubleClick notification |
| `ControlChooseString(String, Control, WinTitle?, …)` | Index selected | Leading-part match, case-insensitive; first match wins |
| `ControlGetIndex(Control, WinTitle?, …)` | Index, 0 if none | Also works for Tab |
| `ControlGetChoice(Control, WinTitle?, …)` | Selected item text | Throws `Error` when nothing is selected |
| `ControlGetItems(Control, WinTitle?, …)` | Array of strings | ListBox, ComboBox, DropDownList |
| `ControlFindItem(String, Control, WinTitle?, …)` | Index | **Full**-text, case-insensitive match; throws `Error` if not found |
| `ControlAddItem(String, Control, WinTitle?, …)` | Index of the new item | |
| `ControlDeleteItem(N, Control, WinTitle?, …)` | — | 1-based |
| `ControlGetChecked(Control, WinTitle?, …)` | 1 / 0 | Checkbox or radio |
| `ControlSetChecked(NewSetting, Control, WinTitle?, …)` | — | 1 check, 0 uncheck, -1 toggle |

Item functions throw `TargetError` when the window/control is missing or the control's class does not contain "Combo" or "List" (plus "Tab" where tabs are supported), and `Error`/`OSError` when the change fails. A short delay follows each call (`SetControlDelay`).

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Each control call that may fail is in `try`/`catch TargetError` or follows a fresh existence check. The v1 command and `ErrorLevel` wrong forms are in V1 → V2 BREAKING CHANGES.
  ✗ `ControlChooseIndex("ComboBox1", 2, t)` (v1 argument order) → ✓ `ControlChooseIndex(2, "ComboBox1", t)`
- Indexes are 1-based. Use `0` with `ControlChooseIndex` only to clear the selection (not for Tab controls).
  ✗ `ControlChooseIndex(0, …)` to pick the first item → ✓ `ControlChooseIndex(1, …)`
- `ControlFindItem` needs a full-text match and throws `Error` when none matches (see `### Text and Item Data`); handle it with `catch Error`.
  ✗ `ControlFindItem("Opt", …)` expecting "Option B" → ✓ `ControlChooseString` (leading text) or scan `ControlGetItems`
- Use `ControlSendText` for literal text and `ControlSend` when `{Keys}`/modifiers must be interpreted.
- `CoordMode` does not apply here: `ControlClick` positions and `ControlGetPos` results are relative to the target window's client area. Add no CoordMode for ControlClick positions.
  ✗ `CoordMode("Mouse", "Screen")` then `ControlClick("x10 y10", t)` → ✓ ControlClick positions are always client-relative
- These functions are meant for other programs' (non-Gui) controls. For the script's own Gui use the GuiControl object (`ctrl.Choose()`, `ctrl.Value`), which—unlike `ControlChooseIndex`—does not raise a Change event.
  ✗ `ControlSetText(…, myEdit)` → ✓ `myEdit.Value := …`
- Custom-drawn or modern UI (Chromium, WPF, UWP) often has no standard child controls; use UI Automation (ahk-ctx-uia) instead.
- **Repository convention:** cache `WinExist(...)` into an HWND and pass it as WinTitle for follow-up calls.

## RUNTIME ERROR MAPPING

| Error | Trigger | Fix |
|-------|---------|-----|
| `TargetError` | Window/control not found, or wrong control class for an item function | Verify ClassNN with Window Spy; guard with `try` |
| `Error` | `ControlFindItem` with no full match; item add/delete/choose failed | `catch Error`; fall back to `ControlGetItems` scan |
| `OSError` | Message could not be sent (e.g. elevated target, UIPI) | Run the script with matching privileges |

## TIER 1 — Click, Send, Focus

```ahk
#Requires AutoHotkey v2.0

if hwnd := WinExist("ahk_exe notepad.exe") {
    ControlSend("Hello from AHK v2{Enter}", "Edit1", hwnd)   ; keys interpreted
    ControlSendText("a+b=c {literal}", "Edit1", hwnd)        ; sent as-is
    ControlFocus("Edit1", hwnd)
    ControlGetPos(&cx, &cy, &cw, &ch, "Edit1", hwnd)         ; client-area coordinates
    MsgBox("Edit1 at " cx "," cy " size " cw "x" ch)
}

ClickButton(winTitle, ctrl := "Button1") {
    try {
        ControlClick(ctrl, winTitle,, "Left", 1, "NA")
        return true
    } catch TargetError {
        return false
    }
}
```

## TIER 2 — ListBox / ComboBox / Checkbox Data

```ahk
#Requires AutoHotkey v2.0

; Select an item by exact text; fall back to a substring scan when allowed.
SelectItem(winTitle, ctrl, text, allowPartial := false) {
    try {
        idx := ControlFindItem(text, ctrl, winTitle)         ; full, case-insensitive
    } catch TargetError {
        throw                                                 ; window/control missing
    } catch Error {
        idx := 0
        if allowPartial
            for i, item in ControlGetItems(ctrl, winTitle)
                if InStr(item, text) {
                    idx := i
                    break
                }
    }
    if idx
        ControlChooseIndex(idx, ctrl, winTitle)
    return idx                                                ; 0 = not found
}

ReadState(winTitle) {
    return {
        selected: ControlGetIndex("ComboBox1", winTitle),     ; 0 = none
        items:    ControlGetItems("ComboBox1", winTitle),
        checked:  ControlGetChecked("Button1", winTitle),
        text:     ControlGetText("Edit1", winTitle)
    }
}

; ControlChooseIndex(0, "ListBox1", t)   ; clears the selection
; ControlSetChecked(-1, "Button1", t)    ; toggles a checkbox
```

## SEE ALSO

- `Module_WindowManagement.md` — finding and waiting for the target window.
- `Module_SendAndInputHook.md` — `Send` key syntax shared by `ControlSend`.
- `Module_GuiBasics.md` — GuiControl API for the script's own windows.
