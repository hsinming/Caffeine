# Module_GuiBasics.md
<!-- DOMAIN: GUI — window object, controls, events -->
<!-- SCOPE: Gui() construction, window methods/properties, Add* control methods, GuiControl methods/properties, OnEvent callbacks and binding, Submit(), Hide vs Destroy, Gui lifetime. Not covered: ListView/TreeView/StatusBar/Tab (Module_GuiListViewTreeView.md), owner/owned and modal dialogs (Module_GuiOwnedWindows.md), positioning/resizing/GuiForm layout (Module_GuiLayout.md), screen overlays (Module_ScreenOverlays.md). -->
<!-- TRIGGERS: Gui(), Add(), AddText(), AddEdit(), AddButton(), AddCheckBox(), AddRadio(), AddDropDownList(), AddComboBox(), Submit(), OnEvent(), .Bind(), GuiFromHwnd(), GuiCtrlFromHwnd(), .Value, .Text, "make a window", "add a button", "create a form", "dialog", "button click handler", "read form values" -->
<!-- CONSTRAINTS: No v1 Gui command syntax. Gui has no Close() method — use Hide() or Destroy(). A fat-arrow body is one expression, not a statement block. A method reference passed as a callback needs its receiver bound (.Bind(this) / ObjBindMethod). Submit() hides the window unless Submit(false). Map() for dynamic control storage is a repo convention, not a language limit. -->
<!-- CROSS-REF: Module_GuiListViewTreeView.md, Module_GuiOwnedWindows.md, Module_GuiLayout.md, Module_ScreenOverlays.md, Module_ClassBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `Gui, Add, Text,, Hello World!` | `myGui.AddText(, "Hello World!")` | v1 command syntax is not valid v2; the Gui is an object and controls are added with methods |
| `Gui, Show` / `Gui, Hide` / `Gui, Destroy` | `myGui.Show()` / `myGui.Hide()` / `myGui.Destroy()` | Same — every Gui sub-command became a method or property |
| `GuiControl, Disable, ctrl` | `ctrl.Enabled := false` or `ctrl.Opt("+Disabled")` | There is no GuiControl command; use the GuiControl object |
| `GuiControl,, ctrl, newText` | `ctrl.Value := newText` (or `ctrl.Text := …`) | Use the object's properties |
| `Gui, Submit, NoHide` | `myGui.Submit(false)` | `Submit()` takes a Boolean `Hide` parameter (default true) |
| `Gui, +Owner%hwnd%` | `myGui.Opt("+Owner" hwnd)` | `%var%` in v2 is a double-deref, not text interpolation; build the option string by concatenation |
| `gLabel` in control options | `ctrl.OnEvent("Click", Callback)` | Event handlers cannot be set in Options; register them with `OnEvent` |
| `new MyGui()` | `MyGui()` | v2 creates instances by calling the class (`Classname()`, formerly `new Classname()`) |
| `myGui.Close()` | `myGui.Hide()` or `myGui.Destroy()` | `Gui` has no `Close` method → `MethodError` |

## API QUICK-REFERENCE

### Gui Constructor and Window Methods

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `Gui()` | `Gui(Options?, Title?, EventObj?)` | Gui | With `EventObj`, `OnEvent` may take method *names* of that object |
| `.Show()` | `.Show(Options?)` | — | e.g. `"w400 h300"`, `"Center"`, `"AutoSize"`, `"NoActivate"`, `"Hide"` (move/resize without showing) |
| `.Hide()` | `.Hide()` | — | Hides; Gui object and controls stay valid |
| `.Destroy()` | `.Destroy()` | — | Removes the window and all controls and releases all event callbacks |
| `.Submit()` | `.Submit(Hide := true)` | Object | One own property per *named* input-capable control (see Submit rules below) |
| `.Opt()` | `.Opt(Options)` | — | `"+Resize"`, `"+AlwaysOnTop"`, `"-Caption"`, `"+Disabled"`, `"+Owner" hwnd`, `"-DPIScale"` |
| `.SetFont()` | `.SetFont(Options?, FontName?)` | — | Affects controls added after the call, e.g. `"s10 bold"`, `"s9 norm cRed"` |
| `.OnEvent()` | `.OnEvent(EventName, Callback, AddRemove?)` | — | Window events: `Close`, `ContextMenu`, `DropFiles`, `Escape`, `Size` |
| `.Add()` | `.Add(ControlType, Options?, Text?)` | GuiControl | `AddText(…)`, `AddEdit(…)`, … are equivalent typed forms |
| `.Flash()` | `.Flash(Blink := true)` | — | `true` blinks window/taskbar button once; `false` restores original colors |
| `.Maximize()` / `.Minimize()` / `.Restore()` | `()` | — | Unhide and change state |
| `.Move()` | `.Move(X?, Y?, W?, H?)` | — | Screen coordinates; omitted params stay unchanged; DPI-scaled unless `-DPIScale` |
| `.GetPos()` / `.GetClientPos()` | `(&X?, &Y?, &W?, &H?)` | — | Window rect / client-area rect; W/H are DPI-scaled unless `-DPIScale` |
| `.__Enum()` | `for ctrl in myGui` | Enumerator | Enumerates the window's controls |

### Gui Properties

| Property | Access | Notes |
|----------|--------|-------|
| `.Hwnd` | read-only Integer | Window handle; usable directly as a WinTitle |
| `.Title` | get/set | Title-bar text |
| `.Name` | get/set | Custom name for the window (informational) |
| `.BackColor` | get/set | Color name, RGB hex (`"FFFFAA"`, `0xFFFFAA`), or `"Default"`/`""` |
| `.MarginX` / `.MarginY` | get/set | Margins used by automatic positioning |
| `.FocusedCtrl` | read-only | Focused GuiControl |
| `.MenuBar` | get/set | Attach a `MenuBar` object |
| `.__Item` | `myGui[NameOrTextOrClassNNOrHwnd]` | Built-in control lookup by name, text, ClassNN or HWND |

### Control Add Methods (common)

| Method | Signature | Value semantics (`.Value`) |
|--------|-----------|----------------------------|
| `.AddText()` | `(Options?, Text?)` | Text (same as `.Text`) |
| `.AddEdit()` | `(Options?, Text?)` | Contents; multi-line Value uses `` `n `` line breaks |
| `.AddButton()` | `(Options?, Text?)` | Not value-capable; `"Default"` option = Enter activates it |
| `.AddCheckBox()` / `.AddRadio()` | `(Options?, Text?)` | `1` checked, `0` unchecked, `-1` indeterminate (`Check3`) |
| `.AddDropDownList()` / `.AddListBox()` | `(Options?, ItemsArray?)` | Index of selected item, `0` if none; multi-select ListBox → Array of indexes |
| `.AddComboBox()` | `(Options?, ItemsArray?)` | Index of the item that fully matches the edit text, else `0`; use `.Text` for the typed text |
| `.AddSlider()` / `.AddProgress()` | `(Options?, Value?)` | Current position (Progress range defaults to 0–100) |
| `.AddHotkey()` | `(Options?, Hotkey?)` | Hotkey string such as `"^!c"` (only `^ ! +` modifiers) |
| `.AddPicture()` | `(Options?, FileName?)` | File name as originally given |
| `.AddGroupBox()` | `(Options?, Text?)` | Frame only; it does not contain or position other controls |

ListView, TreeView, StatusBar and Tab3 → `Module_GuiListViewTreeView.md`.

### GuiControl Methods

| Method | Signature | Notes |
|--------|-----------|-------|
| `.OnEvent()` | `.OnEvent(EventName, Callback, AddRemove?)` | `Change`, `Click`, `DoubleClick`, `Focus`, `LoseFocus`, `ContextMenu`, `ItemSelect`, … (depends on type) |
| `.Opt()` | `.Opt(Options)` | `"+Disabled"`, `"-Visible"`, `"+ReadOnly"`, `"-Redraw"` |
| `.Move()` | `.Move(X?, Y?, W?, H?)` | Client-area coordinates; **omit** a parameter to leave it unchanged |
| `.GetPos()` | `.GetPos(&X?, &Y?, &W?, &H?)` | Relative to the client area |
| `.Focus()` | `.Focus()` | Give keyboard focus |
| `.Redraw()` | `.Redraw()` | Repaint the control's region |
| `.SetFont()` | `.SetFont(Options?, FontName?)` | Font for this control only |
| `.Choose()` | `.Choose(Value)` | Select item/tab by index or leading text (DDL/ComboBox/ListBox/Tab) |

### GuiControl Properties

| Property | Notes |
|----------|-------|
| `.Value` | Type depends on the control (table above); not value-capable controls return `""` and throw on assignment |
| `.Text` | Caption / display text; for DDL/ComboBox/ListBox the selected item text |
| `.Enabled` / `.Visible` | `1`/`0`; settable |
| `.Name` | Name from the `v` option (`"vUserName"` → `"UserName"`); `""` if none; settable |
| `.Hwnd`, `.ClassNN`, `.Type`, `.Gui`, `.Focused` | Read-only |

### Helper Functions

| Function | Signature | Returns |
|----------|-----------|---------|
| `GuiFromHwnd()` | `GuiFromHwnd(Hwnd, RecurseParent := false)` | Gui or `""`; `RecurseParent` = search **parent** windows of a non-GUI child |
| `GuiCtrlFromHwnd()` | `GuiCtrlFromHwnd(Hwnd)` | GuiControl or `""` |

## EVENTS AND CALLBACKS

- Callback parameters: the first is the Gui or GuiControl that raised the event, followed by event-specific values (e.g. `Size` → `GuiObj, MinMax, Width, Height`).
- A callback may declare fewer parameters only if it ends with `*` (e.g. `OnClick(ctrl, *)`); extra event values are then ignored.
- A function created by a **method** definition has a hidden `this` parameter. Passing `this.HandleClick` directly makes the Gui/control land in `this`. Bind the receiver: `this.HandleClick.Bind(this)` or `ObjBindMethod(this, "HandleClick")`. Exception: with `Gui(,, eventObj)` you may pass the method *name* as a string and `this` is the event sink.
- Each event callback runs in a **new thread**, so settings such as `SendMode` and `CoordMode` start at their defaults (or the values set during startup).
- `Close`: by default the window is hidden after the callback returns; return `true` from the callback to keep it open.
- A fat-arrow function is `(params) => expression`. Several actions fit in one comma expression: `(*) => (saved := g.Submit(), MsgBox(saved.Name))`. Statement blocks (`if`, loops, `return`) need a named function or method.

### Submit Rules

- Only named (`v` option), input-capable controls are included; Text, Picture, GroupBox, Button, Progress, Link, StatusBar, ListView, TreeView, ActiveX and Custom are excluded.
- DropDownList, ComboBox, ListBox and Tab store the **item text** unless the control has `AltSubmit` (then the index). A ComboBox whose edit text matches no item still stores its text.
- If only one Radio in a group is named, Submit stores the number of the selected button (0 if none).

### Lifetime

- The window is destroyed automatically when the Gui object's reference count reaches zero; `Show()` holds an extra reference while the window is visible, released when it is hidden.
- `Destroy()` releases all event callbacks; prefer `Hide()` when the same window will be shown again.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 form from V1 → V2 BREAKING CHANGES remains: `Gui,` / `GuiControl,` command syntax, `gLabel` options, `new`, `myGui.Close()` (choose Hide or Destroy deliberately).
- **Repository convention (not a language limit):** put GUIs with state or several handlers in a class; simple stateless GUIs may be plain functions.
- **Repository convention:** store controls you create dynamically in a `Map()` (`this.controls["save"] := btn`). The built-in `myGui["Name"]` lookup is also valid for `v`-named controls.
- Bind method callbacks, or register them by name with an event sink; callbacks that ignore trailing event values end their parameter list with `*` (see `## EVENTS AND CALLBACKS`).
  ✗ `btn.OnEvent("Click", this.Save)` → ✓ `btn.OnEvent("Click", this.Save.Bind(this))`
- No statement-block arrows: every arrow callback body is a single expression.
  ✗ `(*) => { a(); b() }` is a load-time error → ✓ named method (+ `.Bind(this)`), or `(*) => (a(), b())`
- ComboBox/DDL code reads `.Text` when it needs text and `.Value` when it needs the index (see `### Control Add Methods (common)`).
  ✗ `cb.Value` expecting text → ✓ `cb.Text`
- `Submit()` already hides the window; calling `Hide()` after it is redundant. Use `Submit(false)` to keep it visible.
- **Repository convention:** build controls once (e.g. in `__New`) and toggle with `Show()`/`Hide()`; calling an add-controls method on every `Show()` duplicates controls.

## RUNTIME ERROR MAPPING

| Error | Trigger | Fix |
|-------|---------|-----|
| `MethodError` | `myGui.Close()` or another non-existent method | Use `Hide()` / `Destroy()`; check the Gui/GuiControl method lists |
| `UnsetItemError` | `this.controls["key"]` for a key never stored in the Map | Guard with `.Has()` or `.Get(key, default)` |
| `ValueError` ("Invalid callback function") | Zero-parameter callback (raised by `OnEvent`), a callback that declares fewer parameters than the event passes without `*` (raised when the event fires), or an unbound method whose parameter count does not fit | Add `*`; bind the method |
| Load-time error | `=> { … }` statement block, v1 `Gui,` command line | Rewrite as named function / method calls |

## TIER 1 — Minimal Window

```ahk
#Requires AutoHotkey v2.0

myGui := Gui(, "My Dialog")
myGui.SetFont("s10")
myGui.AddText(, "Hello World!")
myGui.AddButton("Default w100", "OK").OnEvent("Click", (*) => myGui.Hide())
myGui.OnEvent("Escape", (*) => myGui.Hide())
myGui.Show()
```

## TIER 2 — Class-Based Form with Bound Handlers

```ahk
#Requires AutoHotkey v2.0

FormGui()

class FormGui {
    __New() {
        this.gui := Gui("+Resize", "Input Form")
        this.controls := Map()                  ; repo convention
        this.gui.SetFont("s10")
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())

        this.gui.AddText(, "Full Name:")
        this.controls["name"] := this.gui.AddEdit("vUserName w200")
        this.gui.AddText(, "Email:")
        this.controls["email"] := this.gui.AddEdit("vUserEmail w200")
        this.gui.AddText(, "Role:")
        this.controls["role"] := this.gui.AddDropDownList("vRole w200 Choose1", ["User", "Admin"])

        btn := this.gui.AddButton("Default w200", "Submit")
        btn.OnEvent("Click", this.HandleSubmit.Bind(this))   ; bind the receiver
        this.gui.Show()
    }

    HandleSubmit(ctrl, *) {
        saved := this.gui.Submit()          ; hides the window and collects named values
        ; DDL without AltSubmit → Submit stores the item text
        MsgBox("Name: " saved.UserName "`nEmail: " saved.UserEmail "`nRole: " saved.Role)
    }
}
```

## TIER 3 — Show/Hide Toggle from a Hotkey

```ahk
#Requires AutoHotkey v2.0

panel := TogglePanel()
^m::panel.Toggle()

class TogglePanel {
    __New() {
        this.gui := Gui(, "Panel")
        this.gui.AddText("w200", "Press Ctrl+M to toggle.")
    }

    Toggle() {
        ; "ahk_id" obeys DetectHiddenWindows (off by default), so a hidden Gui is not found
        if WinExist("ahk_id " this.gui.Hwnd)
            this.gui.Hide()
        else
            this.gui.Show()
    }
}
```

## SEE ALSO

- `Module_GuiListViewTreeView.md` — ListView, TreeView, StatusBar, Tab3.
- `Module_GuiOwnedWindows.md` — owner/owned windows, modal dialogs, `+OwnDialogs`.
- `Module_GuiLayout.md` — positioning options, Section/xm, Size event, GuiForm and calculated layouts.
- `Module_ClassBasics.md` (ahk-ctx-core) — class design, `__New`/`__Delete`.
- `Module_ExceptionHandling.md` (ahk-ctx-logic) — try/catch and error classes.
