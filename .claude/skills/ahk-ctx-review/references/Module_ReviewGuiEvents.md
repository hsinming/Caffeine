# Module_ReviewGuiEvents.md
<!-- DOMAIN: Code Review — Dimension 4: GUI & Event Binding -->
<!-- SCOPE: Review checklist for Gui construction, OnEvent callbacks and their receivers, fat-arrow callbacks, g-label residue, SetTimer callbacks, and GUI lifetime/cleanup. Control creation, layout, and the full event list are in Module_GuiLayout.md (ahk-ctx-ui); timer patterns are in ahk-ctx-logic. -->
<!-- TRIGGERS: "button does nothing", "this is wrong in my handler", "event handler", "callback", Gui(), .Add(), .OnEvent(), .Bind(), SetTimer(), "g-label", "OnClose", "Destroy", "GUI review" -->
<!-- CONSTRAINTS: OnEvent passes the Gui or GuiControl as the first explicit parameter; a method callback also has an implicit `this`, so a bare `this.Method` receives the control as `this` and its parameters shift. Bind the method, use a fat-arrow wrapper, or give Gui() an event sink and pass the method name as a string. A fat-arrow function evaluates one expression. All GUI windows are destroyed automatically when the script exits. -->
<!-- CROSS-REF: Module_ReviewFramework.md, Module_ReviewV2Syntax.md, Module_GuiBasics.md, Module_ClassBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

- **`Gui(Options?, Title?, EventObj?)`** — with `EventObj`, `OnEvent` may take a method **name** (String); that method's `this` receives the event sink (lib/GuiOnEvent.htm)
- **`GuiObj.Add(ControlType, Options?, Text?)`** — returns a GuiControl; it can also be found later with `GuiObj["Name"]` or `GuiCtrlFromHwnd()`
- **`Obj.OnEvent(EventName, Callback, AddRemove?)`** — Callback is a function object, or a method name when the Gui has an event sink. Extra event parameters beyond those declared are ignored; the callback may declare more parameters only if they are optional
- **`FuncObj.Bind(Params*)`** — returns a BoundFunc that prepends the bound arguments
- **`SetTimer(Function?, Period?, Priority?)`** — needs a function object; labels and function names are not accepted in v2
- **`GuiObj.Destroy()`** — destroys the window. Without it, the window is destroyed when the Gui object is deleted; `Show` holds an extra reference while the window is visible; all GUI windows are destroyed when the script exits (lib/Gui.htm)

## AHK V2 CONSTRAINTS

- **Method callbacks need their receiver.** OnEvent always passes the Gui or
  GuiControl first. A method defined with `OnClick(ctrl, info)` really takes
  `(this, ctrl, info)`, so `btn.OnEvent("Click", this.OnClick)` puts the control in
  `this` and needs one more parameter than the Click event supplies. Flag it as
  **🔴 Critical** (convention severity). Fixes:
  - `this.OnClick.Bind(this)`
  - `(ctrl, info) => this.OnClick(ctrl, info)`
  - `Gui(, , this)` plus `btn.OnEvent("Click", "OnClick")`
- A plain function (not a method) needs no binding.
- **Fat-arrow callbacks** evaluate one expression. Use a named function, or the
  comma operator inside parentheses: `(*) => (DoA(), DoB())`.
- **g-labels** were removed; every event is registered with `OnEvent()`.
- **Timers:** store the BoundFunc when you need to stop a method timer later; a
  new `.Bind()` call creates a different object.
- **Cleanup:** `Destroy()` immediately before `ExitApp()` is redundant (windows are
  destroyed at exit). Call `Destroy()` when the script keeps running and the window
  will not be reused, or when an event sink holds a reference cycle with the Gui.

## TIER 4 — GUI & Event Binding
> METHODS COVERED: `Gui()` · `.Add()` · `.OnEvent()` · `.Bind()` · `.Show()` · `.Destroy()` · `SetTimer()`

```ahk
; CHECK 1: Keep a reference when the control is used later
myGui := Gui("+Resize", "My App")
myBtn := myGui.Add("Button", "w120", "Click Me")
myEdit := myGui.Add("Edit", "w200 vUserInput")
; Not storing a control you never touch again is fine; myGui["UserInput"] also works.

; ----------------------------------------------------------------
; CHECK 2: Method callbacks must keep their receiver
; ✗ this.btn.OnEvent("Click", this.OnClick)
;     → 'this' becomes the Button; OnClick needs one parameter more than Click passes
class AppController {
    status := "ready"
    __New() {
        this.ui := Gui()
        this.btn := this.ui.Add("Button", , "Run")
        this.btn.OnEvent("Click", this.OnClick.Bind(this))   ; ✓
        this.ui.Show()
    }
    OnClick(ctrl, info) {
        MsgBox(this.status)
    }
}

; ✓ Alternative: event sink + method name
class SinkController {
    __New() {
        this.ui := Gui(, "Sink", this)
        this.ui.Add("Button", , "Run").OnEvent("Click", "OnClick")
    }
    OnClick(ctrl, info) => MsgBox("clicked " ctrl.Text)
}

; ----------------------------------------------------------------
; CHECK 3: Fat-arrow callbacks — one expression
; ✗ myBtn.OnEvent("Click", (*) => {
;       DoSomething()
;       DoOther()
;   })
; ✓
myBtn.OnEvent("Click", (*) => MsgBox("Clicked"))
myBtn.OnEvent("Click", (*) => (DoSomething(), DoOther()))
; ✓ Or a named function
HandleBtnClick(ctrl, info) {
    DoSomething()
    DoOther()
}
myBtn.OnEvent("Click", HandleBtnClick)

; ----------------------------------------------------------------
; CHECK 4: g-label residue
; ✗ myGui.Add("Button", "gMyAction w120", "Run")   ; v1 g-label
; ✓ register with OnEvent (see CHECK 3)

; ----------------------------------------------------------------
; CHECK 5: SetTimer takes a function object
; ✗ SetTimer, UpdateDisplay, 1000      ; load-time error: no comma after the function name
; ✓
UpdateDisplay() {
    ToolTip(A_Now)
}
SetTimer(UpdateDisplay, 1000)

; ----------------------------------------------------------------
; CHECK 6: Cleanup
; ✗ (redundant) myGui.OnEvent("Close", (*) => (myGui.Destroy(), ExitApp()))
; ✓ Exit: windows are destroyed automatically
myGui.OnEvent("Close", (*) => ExitApp())
; ✓ Long-running script, window not reused: destroy it
; settingsGui.OnEvent("Close", (g) => g.Destroy())

DoSomething() {
}
DoOther() {
}
```

## RUNTIME ERROR MAPPING

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `PropertyError` on `this.someField` in a handler | Unbound method that does register (e.g. `OnClick(ctrl)`): `this` is the GuiControl | Bind, fat-arrow wrapper, or event sink |
| `ValueError` "Invalid callback function" at the `OnEvent()` call | Unbound method needs more parameters than the event supplies once its implicit `this` is counted (e.g. `OnClick(ctrl, info)` for Click) | Same as above |
| Button does nothing | v1 g-label option, or `OnEvent` never called | `OnEvent("Click", fn)` |
| Timer cannot be stopped | `SetTimer(this.Tick.Bind(this), 0)` creates a new BoundFunc | Store the BoundFunc once and reuse it |

## DROP-IN RECIPES

```ahk
; Recipe 3: BoundGuiController — class-based GUI with explicit lifecycle.
; Use when a reviewed GUI needs instance state; simple GUIs need not use it.
class GuiController {
    __New(title := "My App") {
        this.ui   := Gui("+Resize +MinSize320x200", title)
        this.edit := this.ui.Add("Edit", "w300 r5 vUserInput")
        this.btn  := this.ui.Add("Button", "w100", "Submit")
        this.btn.OnEvent("Click", this.OnSubmit.Bind(this))
        this.ui.OnEvent("Close", this.OnClose.Bind(this))
        this.ui.Show()
    }
    OnSubmit(ctrl, info) {
        val := this.edit.Value
        if (val = "")
            return
        MsgBox("Submitted: " val, "Info")
    }
    OnClose(guiObj) {
        ExitApp()           ; windows are destroyed at exit; no Destroy() needed
    }
}
app := GuiController("My Tool")
```

Note: binding `this` into the Gui's own callbacks creates a reference cycle
(Gui → BoundFunc → controller → Gui). That is harmless when the script exits on
close; in a long-running script call `this.ui.Destroy()` in `OnClose` to release it.

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| Unbound method callback | `btn.OnEvent("Click", this.OnClick)` | `this.OnClick.Bind(this)` or event sink | Other languages bind methods automatically |
| Block-bodied fat arrow | `(*) => { A()`↵`B() }` | Named function or `(*) => (A(), B())` | JavaScript habits |
| Destroy before ExitApp | `(*) => (g.Destroy(), ExitApp())` | `(*) => ExitApp()` | Belief that windows leak at exit |
| Flagging unstored controls | `🟠 no reference to the button` when it is never used | No finding | Checklist over evidence |

## SEE ALSO

- `Module_ReviewFramework.md` — severity scale and report format
- `Module_ReviewV2Syntax.md` — v1 residue (g-labels, SetTimer labels)
- `Module_GuiBasics.md` (ahk-ctx-ui) — controls, layout, and the full event list
