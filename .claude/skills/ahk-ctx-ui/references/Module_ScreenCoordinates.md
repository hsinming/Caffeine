# Module_ScreenCoordinates.md
<!-- DOMAIN: Screen coordinates, monitors, DPI -->
<!-- SCOPE: CoordMode (all target types), A_ScreenWidth/Height/DPI, MonitorGet/MonitorGetWorkArea/MonitorGetCount/MonitorGetPrimary/MonitorGetName, virtual-desktop bounds, finding the monitor under the cursor, centering windows, resolution-independent (scaled / fractional) coordinates. Not covered: pixel/image search (Module_PixelAndImageSearch.md), overlays (Module_ScreenOverlays.md), Click/MouseMove details (Module_SendAndInputHook.md), Gui DPI scaling (Module_GuiLayout.md). -->
<!-- TRIGGERS: CoordMode(), A_ScreenWidth, A_ScreenHeight, A_ScreenDPI, MonitorGet(), MonitorGetWorkArea(), MonitorGetCount(), MonitorGetPrimary(), SysGet(78), "screen coordinates", "multi-monitor", "second monitor", "screen resolution", "work area", "taskbar", "DPI scaling", "center window on monitor", "which monitor" -->
<!-- CONSTRAINTS: Default CoordMode is the active window's client area for every target type. CoordMode is per thread (each hotkey/timer/GUI thread starts with the default) but a function call does NOT reset it. A_ScreenWidth/Height are the primary monitor only. MonitorGet's N is 1-based; omit it for the primary monitor. -->
<!-- CROSS-REF: Module_PixelAndImageSearch.md, Module_ScreenOverlays.md, Module_SendAndInputHook.md, Module_WindowManagement.md, Module_GuiLayout.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern | v2 correct form | Consequence |
|------------|-----------------|-------------|
| `CoordMode, Pixel, Screen` | `CoordMode("Pixel", "Screen")` | v1 command syntax |
| `SysGet, Mon, Monitor, 2` | `MonitorGet(2, &l, &t, &r, &b)` | Monitor sub-commands became Monitor* functions |
| `SysGet, n, MonitorCount` | `MonitorGetCount()` | |
| `new ScreenHelper()` | `ScreenHelper()` | v2 instantiates by calling the class |

## API QUICK-REFERENCE

| Function / variable | Signature / type | Notes |
|---------------------|------------------|-------|
| `CoordMode()` | `CoordMode(TargetType, RelativeTo := "Screen")` | TargetType `"ToolTip"`, `"Pixel"`, `"Mouse"`, `"Caret"`, `"Menu"`; RelativeTo `"Screen"`, `"Window"`, `"Client"`. Returns the previous setting |
| `A_CoordModeMouse` (…`Pixel`, …) | read/write | Current setting per target type |
| `A_ScreenWidth` / `A_ScreenHeight` | Integer | **Primary** monitor size |
| `A_ScreenDPI` | Integer | Pixels per logical inch (96 = 100 %); for the primary display **at program start** |
| `SysGet(78)` / `SysGet(79)` | Integer | Virtual desktop width/height (all monitors) |
| `MonitorGetCount()` | Integer | Number of monitors |
| `MonitorGetPrimary()` | Integer | Primary monitor number |
| `MonitorGet()` | `MonitorGet(N?, &Left?, &Top?, &Right?, &Bottom?)` | Full bounds; N omitted = primary. Returns N. Throws on failure (outputs unchanged) |
| `MonitorGetWorkArea()` | same | Bounds minus taskbar and registered desktop toolbars |
| `MonitorGetName()` | `MonitorGetName(N?)` | Device name |

Default, when `CoordMode` was never called in the thread: coordinates are relative to the **active window's client area** (exceptions are documented per function, e.g. `WinMove` uses screen coordinates).

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- `CoordMode` is a per-thread setting: every newly launched thread (hotkey, hotstring, timer, menu item, GUI event) starts with the default (or with what the startup code set). Calling a function does **not** reset it — a function inherits its caller's setting and any change it makes stays in effect for the caller. (Earlier versions of this module said CoordMode "does not propagate between function scopes"; that is wrong.) Each thread that uses screen-absolute coordinates sets `CoordMode` for the right target type (`Mouse`, `Pixel`, `ToolTip`, …).
  ✗ `CoordMode(…)` in a helper called after startup, expected in hotkeys → ✓ set at startup (auto-execute) or per callback thread
  ✗ re-setting it in every function as a language requirement → ✓ functions inherit the caller's thread setting
- **Repository convention:** set `CoordMode` at the top of each hotkey/timer callback (or once during startup) that uses screen coordinates; library functions that need a specific mode may set it explicitly and restore the previous value (`CoordMode` returns it).
- `A_ScreenWidth`/`A_ScreenHeight` describe the primary monitor only; secondary monitors can have negative coordinates. Use `MonitorGet`/`MonitorGetWorkArea` per monitor (loops run `1..MonitorGetCount()`), or `SysGet(76…79)` for the virtual desktop.
  ✗ `ImageSearch(…, 0, 0, A_ScreenWidth, A_ScreenHeight, …)` on monitor 2 → ✓ `MonitorGet(2, &l, &t, &r, &b)`
  ✗ `if x < 0` treated as off-screen → ✓ check against monitor bounds
- `A_ScreenDPI` does not change when the user changes scaling while the script runs and does not describe secondary monitors.

## RUNTIME ERROR MAPPING

| Error / symptom | Trigger | Fix |
|-----------------|---------|-----|
| Clicks/searches offset by the window position | Default client-relative CoordMode | `CoordMode("Mouse"/"Pixel", "Screen")` in that thread |
| Exception from `MonitorGet` | N out of range | Loop `MonitorGetCount()` |
| Wrong area on monitor 2 | Using `A_ScreenWidth/Height` | `MonitorGet(2, …)` |

## TIER 1 — CoordMode and Primary Screen

```ahk
#Requires AutoHotkey v2.0

^F1:: {
    CoordMode("Mouse", "Screen")                 ; this hotkey thread only
    MouseGetPos(&sx, &sy)
    CoordMode("Mouse", "Client")
    MouseGetPos(&cx, &cy)
    MsgBox(Format("Screen {},{}  Client {},{}  Primary {}x{} @ {} DPI",
        sx, sy, cx, cy, A_ScreenWidth, A_ScreenHeight, A_ScreenDPI))
}

; A helper that needs screen coordinates and restores the caller's mode
ClickScreen(x, y) {
    prev := CoordMode("Mouse", "Screen")
    Click(x, y)
    CoordMode("Mouse", prev)
}
```

## TIER 2 — Monitors and Work Areas

```ahk
#Requires AutoHotkey v2.0

GetMonitors() {
    mons := []
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
        mons.Push({n: A_Index, l: l, t: t, r: r, b: b, wl: wl, wt: wt, wr: wr, wb: wb})
    }
    return mons
}

MonitorFromPoint(x, y) {                         ; screen coordinates
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if x >= l && x < r && y >= t && y < b
            return A_Index
    }
    return 0
}

CenterOnMonitor(winTitle, n?) {
    MonitorGetWorkArea(n?, &l, &t, &r, &b)       ; n omitted → primary
    WinGetPos(,, &w, &h, winTitle)
    WinMove(l + (r - l - w) // 2, t + (b - t - h) // 2,,, winTitle)
}

VirtualDesktop() => ({x: SysGet(76), y: SysGet(77), w: SysGet(78), h: SysGet(79)})

^F2:: {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    MsgBox("Cursor is on monitor " MonitorFromPoint(mx, my) " of " MonitorGetCount())
    try CenterOnMonitor("A", MonitorFromPoint(mx, my))
}
```

## TIER 3 — Resolution-Independent Coordinates

```ahk
#Requires AutoHotkey v2.0

; Scale points recorded at a reference resolution to the current primary monitor
class ResolutionScaler {
    __New(refW := 1920, refH := 1080) {
        this.sx := A_ScreenWidth / refW
        this.sy := A_ScreenHeight / refH
    }
    Point(x, y) => [Round(x * this.sx), Round(y * this.sy)]
}

; Fractions of a window's size (0.5, 0.5 = centre), in screen coordinates
WindowFraction(winTitle, fx, fy) {
    WinGetPos(&x, &y, &w, &h, winTitle)
    return [x + Round(w * fx), y + Round(h * fy)]
}

^F3:: {
    CoordMode("Mouse", "Screen")
    p := ResolutionScaler().Point(960, 540)
    MouseMove(p[1], p[2])
    try {
        q := WindowFraction("A", 0.5, 0.1)
        MouseMove(q[1], q[2])
    }
}
```

## SEE ALSO

- `Module_PixelAndImageSearch.md` — PixelGetColor, PixelSearch, ImageSearch.
- `Module_ScreenOverlays.md` — drawing marks on screen.
- `Module_SendAndInputHook.md` — Click/MouseMove/MouseGetPos.
- `Module_GuiLayout.md` — Gui DPI scaling (`-DPIScale`).
