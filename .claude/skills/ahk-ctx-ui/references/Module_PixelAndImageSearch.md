# Module_PixelAndImageSearch.md
<!-- DOMAIN: Pixel and image recognition on screen -->
<!-- SCOPE: PixelGetColor, PixelSearch, ImageSearch (options *n, *TransN, *wN *hN, *IconN, HBITMAP), color comparison, region scoping, timed wait loops, multi-monitor search. Not covered: CoordMode/monitor details (Module_ScreenCoordinates.md), drawing results on screen (Module_ScreenOverlays.md), GDI+ capture (Module_DllCallBasics.md in ahk-ctx-system), UI Automation (ahk-ctx-uia). -->
<!-- TRIGGERS: PixelGetColor(), PixelSearch(), ImageSearch(), "pixel color", "find image on screen", "wait for pixel", "image recognition", "visual automation", "color tolerance", "*TransBlack" -->
<!-- CONSTRAINTS: PixelSearch/ImageSearch return 1/0 — no ErrorLevel. Image options are prefixes inside the ImageFile string. Default coordinates are relative to the active window's client area — set CoordMode("Pixel", "Screen") in the thread for screen coordinates. On no match the output variables are made blank (""). The region must be visible on screen. -->
<!-- CROSS-REF: Module_ScreenCoordinates.md, Module_ScreenOverlays.md, Module_SendAndInputHook.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern | v2 correct form | Consequence |
|------------|-----------------|-------------|
| `ImageSearch, X, Y, 0, 0, W, H, img` then `if ErrorLevel = 0` | `if ImageSearch(&x, &y, 0, 0, w, h, img)` | Returns 1/0; ErrorLevel does not exist; failures to search throw |
| `PixelSearch, X, Y, …` then `if !ErrorLevel` | `if PixelSearch(&x, &y, x1, y1, x2, y2, color, variation)` | Same |
| `PixelGetColor, c, X, Y, RGB` | `c := PixelGetColor(x, y)` | Always RGB; returns a hex string like `"0x800080"` |
| `ImageSearch(&x, &y, x1, y1, x2, y2, 20, img)` | `ImageSearch(&x, &y, x1, y1, x2, y2, "*20 " img)` | ImageSearch has 7 parameters; options belong in the ImageFile string |

## API QUICK-REFERENCE

| Function | Signature | Returns | Throws |
|----------|-----------|---------|--------|
| `PixelGetColor()` | `PixelGetColor(X, Y, Mode?)` | Hex numeric string `"0xRRGGBB"` | `OSError` |
| `PixelSearch()` | `PixelSearch(&OutX, &OutY, X1, Y1, X2, Y2, ColorID, Variation := 0)` | 1 found / 0 not found | `OSError` if the search could not be done |
| `ImageSearch()` | `ImageSearch(&OutX, &OutY, X1, Y1, X2, Y2, ImageFile)` | 1 found / 0 not found (Out = top-left of match) | `ValueError` (invalid parameter or image could not be loaded), `OSError` |

- `PixelGetColor` Mode: `"Alt"` (about 10 % slower; for windows where the normal method gives wrong colors), `"Slow"` (about 3× slower; may work in some full-screen apps; takes precedence over Alt).
- `Variation` / `*n`: 0–255 shades of variation per R, G, B channel.
- PixelSearch scans row by row from (X1, Y1); if X1 > X2 or Y1 > Y2 the direction reverses.
- ImageSearch options (prefixes, separated by a single space or tab before the file name): `*n` variation, `*TransN` (a color that matches anything, e.g. `*TransBlack`, `*TransFFFFAA`, `*Trans0xFFFFAA`), `*wN`/`*hN` scale (`-1` keeps aspect ratio), `*IconN`. A `"HBITMAP:*" handle` or `"HICON:*" handle` can replace the file name.
- Image formats: ANI, BMP (16-bit+), CUR, EMF, Exif, GIF, ICO, JPG, PNG, TIF, WMF, plus icons from EXE/DLL/CPL/SCR.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Branch on the return value; never on ErrorLevel. ImageSearch options belong in the ImageFile string. Both wrong forms are in V1 → V2 BREAKING CHANGES.
- Check that the image file exists, or catch `ValueError` (see `ImageSearch()` in API QUICK-REFERENCE).
- On no match the output variables are set to `""` (blank) — not unset. Use them only in the found branch.
  ✗ `Click(fx, fy)` outside the found branch → ✓ only inside `if ImageSearch(…)`
- Coordinates (inputs and outputs) follow `CoordMode("Pixel", …)`; default is the active window's client area. `CoordMode` is per thread (see `Module_ScreenCoordinates.md`).
  ✗ `PixelSearch` with screen bounds in the default client mode → ✓ `CoordMode("Pixel", "Screen")` in that thread
- The searched region must be visible: pixels of a window covered by another window cannot be read. Translucent windows or windows with `WinSetTransColor` usually yield the colors behind them.
  ✗ searching while the target is behind another window → ✓ activate/restore the target first
- To match, the on-screen image must be the same size as the loaded image (after `*w`/`*h`), so display scaling changes break exact templates.
- `PixelGetColor` returns a numeric string, so `PixelGetColor(x, y) = 0xFF0000` compares numerically and works; comparing with the string `"0xFF0000"` is a case-insensitive string comparison, so it matches only when the text is identical. Pick one form consistently (repository convention: integer literals).
- Polling loops must `Sleep` between scans and have a timeout; large regions repeated at high frequency consume a lot of CPU (narrow the region to a window or monitor).
  ✗ `Loop { if ImageSearch(…) break }` → ✓ `Sleep` + timeout

## RUNTIME ERROR MAPPING

| Error / symptom | Trigger | Fix |
|-----------------|---------|-----|
| `ValueError` | Missing/unreadable image file or bad option string | `FileExist` check; fix the prefix syntax |
| `OSError` | Screen could not be read | Retry; try `"Alt"`/`"Slow"` for PixelGetColor |
| Load-time "too many parameters" | Variation passed as an 8th ImageSearch argument | Use the `"*n "` prefix |
| Never found | Wrong CoordMode, covered window, different scale | Screen CoordMode; bring the window forward; recapture the template |

## TIER 1 — Pixel Color

```ahk
#Requires AutoHotkey v2.0

^F5:: {
    CoordMode("Pixel", "Screen")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    color := PixelGetColor(x, y)                 ; e.g. "0x1E90FF"
    r := (color >> 16) & 0xFF                    ; numeric string works in math
    MsgBox(Format("{} at {},{}  red={}", color, x, y, r))
    if color = 0xFF0000                          ; numeric comparison
        MsgBox("Pure red")
}

; Wait until a pixel turns a color (with timeout)
WaitForPixel(x, y, color, timeoutMs := 5000, interval := 150) {
    CoordMode("Pixel", "Screen")
    deadline := A_TickCount + timeoutMs
    Loop {
        try {
            if PixelGetColor(x, y) = color
                return true
        } catch OSError {
            ; transient capture failure — retry
        }
        if A_TickCount >= deadline
            return false
        Sleep(interval)
    }
}
```

## TIER 2 — PixelSearch and ImageSearch

```ahk
#Requires AutoHotkey v2.0

^F6:: {
    CoordMode("Pixel", "Screen")
    if PixelSearch(&px, &py, 200, 100, 800, 600, 0x00FF00, 10)
        MsgBox("Green-ish pixel at " px "," py)
    else
        MsgBox("Not found (px is blank: '" px "')")

    img := A_ScriptDir "\assets\button.png"
    if !FileExist(img)
        return MsgBox("Missing " img)
    if ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*30 *TransBlack " img)
        MsgBox("Image at " fx "," fy)
}

; Search inside one window only (smaller region, fewer false positives)
FindInWindow(img, winTitle, variation := 15) {
    CoordMode("Pixel", "Screen")
    WinGetPos(&wx, &wy, &ww, &wh, winTitle)      ; TargetError if missing
    found := ImageSearch(&fx, &fy, wx, wy, wx + ww, wy + wh, "*" variation " " img)
    return found ? [fx, fy] : ""
}
```

## TIER 3 — Wait for an Image on Any Monitor

```ahk
#Requires AutoHotkey v2.0

; Returns {x, y, monitor} or "" on timeout. Throws ValueError for a bad file.
FindImageOnMonitors(img, variation := 15, timeoutMs := 0) {
    CoordMode("Pixel", "Screen")
    deadline := A_TickCount + timeoutMs
    Loop {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if ImageSearch(&x, &y, l, t, r, b, "*" variation " " img)
                return {x: x, y: y, monitor: A_Index}
        }
        if A_TickCount >= deadline
            return ""
        Sleep(250)
    }
}

^F7:: {
    CoordMode("Mouse", "Screen")                 ; hit.x/hit.y are screen coordinates
    if hit := FindImageOnMonitors(A_ScriptDir "\assets\target.png", 20, 5000)
        Click(hit.x, hit.y)
    else
        MsgBox("Not found within 5 s")
}
```

## SEE ALSO

- `Module_ScreenCoordinates.md` — CoordMode, monitor bounds.
- `Module_ScreenOverlays.md` — visualizing search regions and hits.
- `Module_DllCallBasics.md` (ahk-ctx-system) — GDI capture when PixelGetColor throughput is not enough.
