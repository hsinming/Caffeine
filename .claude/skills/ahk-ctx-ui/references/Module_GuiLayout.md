# Module_GuiLayout.md
<!-- DOMAIN: GUI — layout and positioning -->
<!-- SCOPE: Automatic positioning options (xm, x+n, xp, xs/ys, Section), margins, DPI scaling of Gui coordinates, resizable windows via the Size event, the GuiForm/currentY explicit-coordinate pattern, calculated grids and button rows, a small LayoutCalculator. Not covered: Gui/GuiControl API and events (Module_GuiBasics.md), ListView/TreeView (Module_GuiListViewTreeView.md), owned dialogs (Module_GuiOwnedWindows.md). -->
<!-- TRIGGERS: "gui layout", "position controls", "xm", "x+10", "Section", "xs", "ys", "two columns", "button row", "resizable window", "OnEvent Size", "+MinSize", "GuiForm", "currentY", "padding", "LayoutCalculator", "align buttons right", "DPIScale" -->
<!-- CONSTRAINTS: After an x+n control, a following control with no X/Y goes beneath the PREVIOUS control, not back to the left margin — use xm. Size-event Width/Height are client-area sizes. GuiForm, the single-pad rule and LayoutCalculator are repository conventions, not language features. -->
<!-- CROSS-REF: Module_GuiBasics.md, Module_GuiListViewTreeView.md, Module_GuiOwnedWindows.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Position Options (Gui.Add Options string)

| Option | Meaning (official docs) |
|--------|-------------------------|
| `x10 y20` | Absolute position in the client area |
| `x+n` / `y+n` | Relative to the previous control's right / bottom edge (`x+-10` for a negative offset) |
| `xp±n` / `yp±n` | Relative to the previous control's left / top edge |
| `xm±n` / `ym±n` | Left / top window margin |
| `Section` | Starts a new section and saves this control's position for `xs`/`ys` (the first control always starts a section) |
| `xs±n` / `ys±n` | Relative to the saved section position |
| `w`, `h`, `r` | Width, height in pixels, or height in rows of text (`r3`) |

Defaults when an axis is omitted:

| Given | Default for the other axis |
|-------|---------------------------|
| neither X nor Y | Beneath the previous control, using the margin (consecutive Text/Link get extra vertical padding) |
| `xn` or `xm` | Y = beneath **all** previous controls |
| `xs` | Y = beneath all controls since the last `Section` |
| `x+n` or `xp+nonzero` | Y = same top edge as the previous control (same row) |
| `yn` or `ym` | X = right of all previous controls |
| `ys` | X = right of all controls since the last `Section` |

### Window Sizing and Scaling

| Item | Notes |
|------|-------|
| `myGui.MarginX` / `MarginY` | Margin used by automatic positioning |
| `Gui("+Resize")` | Lets the user resize the window |
| `myGui.Opt("+MinSize640x480")` / `"+MaxSize…"` | Limits in client-area pixels (decimal, `WxH`); `+MinSize` alone = current size |
| `Show("AutoSize")` | Size the window to fit its controls |
| DPI scaling | On by default: coordinates and sizes passed to or read from Gui/GuiControl methods are scaled by `A_ScreenDPI / 96`. Turn off with `myGui.Opt("-DPIScale")`. `WinMove`/`WinGetPos` are not scaled. |
| `Size` event | `Gui_Size(GuiObj, MinMax, Width, Height)` — `MinMax`: `-1` minimized, `0` normal, `1` maximized; `Width`/`Height` = new **client-area** size |
| `ctrl.Move(X?, Y?, W?, H?)` | Omit a parameter to leave it unchanged |
| `ctrl.Opt("-Redraw")` / `"+Redraw"` | Suspend repainting during bulk changes |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- After `x+n` controls in a row, start the next row with `xm` (or `xs`): with no X/Y the next control is placed beneath the **previous** control, i.e. under the last button in the row.
  ✗ `AddButton("x+10 …")` then `AddText(, …)` → ✓ `AddText("xm", …)`
- `Section` only saves a position for `xs`/`ys`; it does not change how `w`/`h` work. (Earlier versions of this module claimed `"Section w300"` causes drift — the official docs do not support that.)
- In a `Size` handler, return early when `MinMax = -1`; the reported size is not useful for layout while minimized. (Repository convention.) Lay out with the passed client width/height.
  ✗ `Move()` with `Width/Height` while `MinMax = -1` → ✓ early `return`
- A `Size` handler with several statements must be a named function or bound method; a fat-arrow body is one expression.
  ✗ `OnEvent("Size", (g, m, w, h) => { … })` → ✓ named method + `.Bind(this)`
- To leave a `Move` axis unchanged, omit the parameter; `""` is not "omitted".
  ✗ `ctrl.Move(x, y, "", h)` → ✓ `ctrl.Move(x, y,, h)`
- Consider DPI scaling when mixing Gui coordinates with `WinMove`/`WinGetPos` (see `### Window Sizing and Scaling`).
- **Repository convention (GuiForm pattern):** derive every position from one `pad` value and a running `currentY`; the window height is `currentY + pad`. AHK does not require this — automatic positioning (`xm`, `x+n`, `Section`) is equally valid and adapts to font changes. Explicit-coordinate layouts compute widths once before loops.
  ✗ `"x10 y47"`, `"x10 y74"` … hard-coded everywhere → ✓ `currentY` accumulation or automatic positioning

## TIER 1 — Automatic Positioning with Sections

```ahk
#Requires AutoHotkey v2.0

g := Gui(, "Settings")
g.SetFont("s10")
g.AddText("Section", "First name:")         ; saves this position
g.AddText(, "Last name:")                    ; beneath previous control
g.AddEdit("ys w180 vFirst")                  ; new column at the section's top
g.AddEdit("w180 vLast")                      ; beneath the previous Edit
g.AddCheckBox("xm vNotify", "Enable notifications")   ; back to the left margin
g.AddButton("xm w90 Default", "Save")        ; row starts at margin
g.AddButton("x+10 w90", "Cancel")            ; same row, 10 px to the right
g.AddText("xm", "Status: ready")             ; xm needed — otherwise it lands under "Cancel"
g.Show()
```

## TIER 2 — Resizable Window (Size Event)

```ahk
#Requires AutoHotkey v2.0

LogWindow()

class LogWindow {
    __New() {
        this.pad := 10
        this.gui := Gui("+Resize +MinSize300x200", "Log")
        this.log := this.gui.AddEdit("w580 h330 ReadOnly -Wrap")
        this.status := this.gui.AddText("w580 h20 Border", "Ready")
        this.clear := this.gui.AddButton("w80 h28", "Clear")
        this.clear.OnEvent("Click", (*) => (this.log.Value := ""))
        this.gui.OnEvent("Size", this.OnSize.Bind(this))
        this.gui.Show("w600 h420")
    }

    OnSize(guiObj, minMax, width, height) {
        if minMax = -1                          ; minimized: nothing to lay out
            return
        p := this.pad
        logH := height - 3 * p - 20 - 28 - p
        this.log.Move(p, p, width - 2 * p, logH)
        this.status.Move(p, p + logH + p, width - 2 * p)    ; height omitted = unchanged
        this.clear.Move(width - p - 80, p + logH + p + 20 + p)
    }
}
```

## TIER 3 — GuiForm Explicit Coordinates (repository pattern)

```ahk
#Requires AutoHotkey v2.0

; Repository helper: builds "x.. y.. w.. h.." plus extra options
GuiForm(x, y, w, h, extra := "") {
    opts := Format("x{} y{} w{} h{}", x, y, w, h)
    return extra ? opts " " extra : opts
}

CreateSettingsGui() {
    g := Gui(, "Settings")
    pad := 10, currentY := pad
    winW := 500, contentW := winW - 2 * pad, labelW := 80

    g.SetFont("s12 bold")
    g.Add("Text", GuiForm(pad, currentY, contentW, 25, "Center"), "Application Settings")
    currentY += 25 + 2 * pad
    g.SetFont("s9 norm")

    for field in [["Name:", "vName"], ["Email:", "vEmail"]] {   ; Array keeps the written field order
        g.Add("Text", GuiForm(pad, currentY, labelW, 23), field[1])
        g.Add("Edit", GuiForm(pad + labelW + pad, currentY, contentW - labelW - pad, 23, field[2]))
        currentY += 23 + pad
    }

    ; GroupBox is only a frame: inner controls get their own offsets
    groupH := 75
    g.Add("GroupBox", GuiForm(pad, currentY, contentW, groupH), "Preferences")
    g.Add("CheckBox", GuiForm(2 * pad, currentY + 20, contentW - 2 * pad, 23, "vAutoSave"), "Auto-save")
    g.Add("CheckBox", GuiForm(2 * pad, currentY + 45, contentW - 2 * pad, 23, "vDark"), "Dark mode")
    currentY += groupH + pad

    currentY := ButtonRow(g, ["OK", "Cancel", "Apply"], currentY, winW, pad, "right")
    g.Show(Format("w{} h{}", winW, currentY))     ; currentY already includes the bottom pad
    return g
}

; align: "right" | "center" | "fill"
ButtonRow(g, labels, y, winW, pad, align := "right", btnW := 90, btnH := 28) {
    n := labels.Length
    if align = "fill"
        btnW := (winW - 2 * pad - pad * (n - 1)) // n
    totalW := n * btnW + (n - 1) * pad
    if align = "right"
        startX := winW - pad - totalW
    else if align = "center"
        startX := (winW - totalW) // 2
    else
        startX := pad
    for i, label in labels
        g.Add("Button", GuiForm(startX + (i - 1) * (btnW + pad), y, btnW, btnH), label)
    return y + btnH + pad
}

CreateSettingsGui()
```

## TIER 4 — N Equal Columns and a Validating Layout Calculator (repository pattern)

```ahk
#Requires AutoHotkey v2.0

; Column x positions for n equal columns inside contentW
ColumnXs(n, pad, contentW) {
    colW := (contentW - pad * (n - 1)) / n
    xs := []
    Loop n
        xs.Push(Round(pad + (A_Index - 1) * (colW + pad)))
    return {xs: xs, w: Round(colW)}
}

; Stacks elements vertically and reports boundary problems
class LayoutCalculator {
    static Stack(winW, winH, pad, elements) {
        layout := Map(), problems := [], y := pad
        for el in elements {
            w := el.Has("w") ? el["w"] : winW - 2 * pad
            layout[el["id"]] := {x: pad, y: y, w: w, h: el["h"]}
            if pad + w > winW
                problems.Push(el["id"] " exceeds right edge")
            if y + el["h"] > winH
                problems.Push(el["id"] " exceeds bottom edge")
            y += el["h"] + pad
        }
        return {layout: layout, problems: problems}
    }
}

g := Gui(, "Columns")
cols := ColumnXs(3, 10, 480)
for i, x in cols.xs
    g.AddListView(Format("x{} y10 w{} h150", x, cols.w), ["Column " i])

res := LayoutCalculator.Stack(500, 300, 10, [Map("id", "title", "h", 25), Map("id", "body", "h", 400)])
if res.problems.Length
    MsgBox("Layout problems:`n" res.problems[1])
g.Show("w500 h170")
```

## SEE ALSO

- `Module_GuiBasics.md` — Gui/GuiControl API and callback binding.
- `Module_GuiListViewTreeView.md` — list controls that usually need resizing.
- `Module_ScreenCoordinates.md` — monitor bounds and `A_ScreenDPI`.
