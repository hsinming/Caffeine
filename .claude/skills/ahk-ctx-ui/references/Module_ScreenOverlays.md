# Module_ScreenOverlays.md
<!-- DOMAIN: On-screen overlays and visual debugging -->
<!-- SCOPE: Borderless always-on-top click-through Gui overlays, chroma-key transparency (WinSetTransColor) vs uniform alpha (WinSetTransparent), drawing rectangles/crosshairs with Text controls, auto-hide with SetTimer, overlays spanning monitors. Not covered: Gui API basics (Module_GuiBasics.md), pixel/image search (Module_PixelAndImageSearch.md), monitor math (Module_ScreenCoordinates.md), GDI+ drawing (ahk-ctx-system). -->
<!-- TRIGGERS: WinSetTransColor(), WinSetTransparent(), "+E0x20", "click-through window", "transparent overlay", "highlight region on screen", "draw rectangle on screen", "debug overlay", "on-screen display", "OSD" -->
<!-- CONSTRAINTS: WinSetTransColor makes one color fully transparent (clicks on those pixels fall through); WinSetTransparent applies one alpha to the whole window. A Gui object passed as WinTitle is a pure HWND, so hidden windows are found. Gui coordinates are DPI-scaled unless -DPIScale. Overlays need an explicit cleanup path (Hide/Destroy). -->
<!-- CROSS-REF: Module_GuiBasics.md, Module_PixelAndImageSearch.md, Module_ScreenCoordinates.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

| Item | Notes |
|------|-------|
| `Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")` | Borderless, topmost, no taskbar button; `E0x20` = WS_EX_TRANSPARENT (mouse passes through) |
| `myGui.BackColor := "000001"` | Background color to key out |
| `WinSetTransColor("000001 [N]", myGui)` | Makes that color fully transparent; optional `N` (0–255) also sets overall alpha. `"Off"` or `""` turns transparency off. Throws TargetError / OSError |
| `WinSetTransparent(N \| "Off", myGui)` | Uniform alpha for the whole window including controls. `"Off"` differs from 255 (may improve performance and resource use). Throws TargetError / OSError |
| `myGui.AddText("x… y… w… h… Background" color)` | Solid rectangle |
| `myGui.Show("x0 y0 w… h… NoActivate")` | Show without stealing focus |
| `myGui.Opt("-DPIScale")` | Use raw pixel coordinates so overlay rectangles match screen coordinates on scaled displays |
| `SetTimer(callback, -ms)` | One-shot timer for auto-hide |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Include `+E0x20` when the overlay must not block clicks, and show it with `NoActivate` (see API QUICK-REFERENCE).
  ✗ `Show()` → ✓ `Show("NoActivate")`
- Choose the transparency tool by intent: chroma key (`WinSetTransColor`) keeps colored marks fully opaque while the background disappears; `WinSetTransparent` fades everything.
  ✗ `WinSetTransparent(200, overlay)` → ✓ `WinSetTransColor(bg " 200", overlay)`
- To change an existing TransColor it may be necessary to turn transparency off first (`WinSetTransColor("Off", …)`).
- Screen coordinates from `ImageSearch`/`MouseGetPos` (CoordMode Screen) are raw pixels; Gui positions are DPI-scaled by default — use `-DPIScale` for overlays.
- `A_ScreenWidth` covers the primary monitor only; size an overlay for all monitors with `SysGet(76…79)` / `MonitorGet`.
  ✗ full-screen overlay sized by `A_ScreenWidth` → ✓ `SysGet(76…79)` / `MonitorGet`
- A visible Gui is kept alive by `Show()`; a hidden overlay with no reference is destroyed automatically. **Repository convention:** give every overlay an explicit `Hide()`/`Destroy()` path (timer or method) rather than relying on object deletion.
- A fat-arrow timer callback can call one method (`(*) => this.Clear()`); bound methods (`ObjBindMethod(this, "Clear")`) work equally.
  ✗ `SetTimer(() => { … }, -2000)` → ✓ one-call arrow or a named method

## RUNTIME ERROR MAPPING

| Error / symptom | Trigger | Fix |
|-----------------|---------|-----|
| Marks offset/scaled on 125–200 % displays | Gui DPI scaling | `Opt("-DPIScale")` |
| Overlay blocks clicks | Missing `+E0x20`, or clicking an opaque mark | Add `+E0x20` |
| Whole overlay faded | Used `WinSetTransparent` | Use `WinSetTransColor` with the background color |
| `OSError` from WinSetTrans* | Change could not be applied | Retry after `Show()`; check the window exists |

## TIER 1 — Overlay Class

```ahk
#Requires AutoHotkey v2.0

class ScreenOverlay {
    static Key := "000001"                       ; near-black chroma key

    __New() {
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
        this.gui.BackColor := ScreenOverlay.Key
        WinSetTransColor(ScreenOverlay.Key, this.gui)   ; Gui object = pure HWND: works while hidden
    }

    Rect(x, y, w, h, color := "FF0000", t := 3) {      ; hollow rectangle from four bars
        this.Bar(x, y, w, t, color), this.Bar(x, y + h - t, w, t, color)
        this.Bar(x, y, t, h, color), this.Bar(x + w - t, y, t, h, color)
    }

    Cross(x, y, color := "FFFF00", len := 20) {
        this.Bar(x - len // 2, y - 1, len, 3, color)
        this.Bar(x - 1, y - len // 2, 3, len, color)
    }

    Bar(x, y, w, h, color) => this.gui.AddText(Format("x{} y{} w{} h{} Background{}", x, y, w, h, color))

    ; Show over a screen region; the region's top-left becomes overlay (0,0)
    ShowRegion(x, y, w, h, alpha := 255) {
        WinSetTransColor(ScreenOverlay.Key " " alpha, this.gui)
        this.gui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    }

    HideAfter(ms) => SetTimer((*) => this.gui.Destroy(), -ms)
}

^F8:: {
    CoordMode("Pixel", "Screen")
    ov := ScreenOverlay()
    img := A_ScriptDir "\assets\target.png"
    if FileExist(img) && ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*20 " img) {
        ov.Rect(fx - 4, fy - 4, 88, 88, "00FF00")
        ov.Cross(fx, fy)
    } else {
        ov.Rect(0, 0, A_ScreenWidth, A_ScreenHeight, "FF0000", 6)   ; show searched area
    }
    ov.ShowRegion(0, 0, A_ScreenWidth, A_ScreenHeight, 220)
    ov.HideAfter(3000)
}
```

## TIER 2 — Overlay Across All Monitors

```ahk
#Requires AutoHotkey v2.0

; Virtual desktop bounds (can start at negative coordinates)
^F9:: {
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    g.BackColor := "000001"
    Loop MonitorGetCount() {                     ; outline each monitor
        MonitorGet(A_Index, &l, &t, &r, &b)
        g.AddText(Format("x{} y{} w{} h{} Border BackgroundTrans", l - vx, t - vy, r - l, b - t))
    }
    WinSetTransColor("000001", g)
    g.Show(Format("x{} y{} w{} h{} NoActivate", vx, vy, vw, vh))
    SetTimer((*) => g.Destroy(), -2000)
}
```

## SEE ALSO

- `Module_GuiBasics.md` — Gui object and lifetime.
- `Module_PixelAndImageSearch.md` — producing the coordinates to mark.
- `Module_ScreenCoordinates.md` — monitor and virtual-desktop bounds.
