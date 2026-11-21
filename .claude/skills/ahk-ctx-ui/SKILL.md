---
name: ahk-ctx-ui
description: >
  AutoHotkey v2 user interface and input. Use when writing, modifying, or reviewing .ahk code that
  involves Gui() windows and controls (ListView, TreeView, layout, owned dialogs), window and
  control automation (WinExist, ControlClick), hotkeys and hotstrings, Send and InputHook,
  multi-monitor coordinates, pixel and image search, or screen overlays.
metadata:
  version: "2026.10.16"
---

# AHK v2 UI Context

Read `../ahk-ctx-core/references/Module_Instructions.md` in full first; its `<how_to_use>` is the
flow for this Skill. Then load `../ahk-ctx-core/references/Module_CodeStyle.md` in full when writing
or editing AHK. Load these only when the condition holds:

- `../ahk-ctx-core/references/Module_ClassBasics.md`: GUI state, lifecycle, inheritance, or class callbacks.
- `../ahk-ctx-core/references/Module_FatArrowFunctions.md`: arrows, closures, descriptors, or callback binding semantics.
- `../ahk-ctx-logic/references/Module_ExceptionHandling.md`: the selected UI APIs can throw, or error recovery is part of the task.
- `../ahk-ctx-logic/references/Module_ValidationRules.md`: form or input validation.

## Router

Read the listed heading through the next `## ` heading. `references/SECTION_INDEX.md` lists every
heading per Module, including TIER examples. A task may touch several rows: load the matching
sections from each Module before writing code.

| Signal | Module | Heading |
|---|---|---|
| `Gui()`, controls, `.OnEvent`, `Submit`, `.Value`, dialog form | `Module_GuiBasics.md` | `## API QUICK-REFERENCE` + `## EVENTS AND CALLBACKS` |
| ListView, TreeView, StatusBar, Tab3 | `Module_GuiListViewTreeView.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| owner window, modal dialog, `+Owner`, `+OwnDialogs` | `Module_GuiOwnedWindows.md` | `## API QUICK-REFERENCE` + matching TIER |
| layout, `xm`/`x+n`/`Section`, resize, `Size` event, GuiForm | `Module_GuiLayout.md` | `## API QUICK-REFERENCE` + matching TIER |
| `WinExist`, `WinWait`, `WinActivate`, HWND, `ahk_exe`, `SetTitleMatchMode`, groups | `Module_WindowManagement.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `ControlClick`, `ControlSend`, `ControlGetText`, `ControlChooseIndex`, ClassNN | `Module_ControlInteraction.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `SetWinEventHook`, `CallbackCreate`, "detect when window opens" | `Module_WinEventHook.md` | `## AHK V2 CONSTRAINTS` + TIER 1 |
| hotkey, hotstring, `Hotkey()`, `#HotIf`, `HotIf()` | `Module_HotkeysAndHotstrings.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `Send`, `SendText`, `SetKeyDelay`, `Click`, `MouseMove`, `GetKeyState`, `KeyWait`, `InputHook` | `Module_SendAndInputHook.md` | `## API QUICK-REFERENCE` + matching TIER |
| `CoordMode`, `A_ScreenWidth`, `MonitorGet`, multi-monitor, DPI | `Module_ScreenCoordinates.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `PixelGetColor`, `PixelSearch`, `ImageSearch` | `Module_PixelAndImageSearch.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| transparent overlay, click-through window, `WinSetTransColor` | `Module_ScreenOverlays.md` | `## API QUICK-REFERENCE` + TIER 1 |
| GUI callback using instance state | `Module_GuiBasics.md` + `../ahk-ctx-core/references/Module_ClassBasics.md` | `## EVENTS AND CALLBACKS` only |

A single `WinExist` query needs only `Module_WindowManagement.md`. Descend into a `## TIER` section
when the task needs a runnable example.

## Critical Rules

### GUI
- Convention: use a class when GUI state, lifecycle, or multiple related events justify it; simple stateless GUI code may use functions.
- Match the layout technique to the task: automatic positioning (`xm`, `x+n`, `Section`) for simple forms; the GuiForm/`currentY` pattern (a repository convention) when explicit coordinates are needed.
- A method callback's hidden `this` parameter is otherwise filled by the event's first argument, so bind it (`.Bind(this)` / `ObjBindMethod`).
- Re-enable an owner window before hiding or destroying its owned dialog.

### Window & Control
- HWNDs are Integers (never strings); test with `if !hwnd`.
- Check each Win*/Control* function's contract: most throw `TargetError` when the target is missing, while `WinExist`/`WinActive`/`WinWait*`/`WinGetList` do not. Use `try/catch TargetError` or a precondition guard accordingly.
- Identify windows with `ahk_id`, a pure HWND, `ahk_class`, `ahk_exe`, or `ahk_group`.
- `SetTitleMatchMode`, `DetectHiddenWindows`, `CoordMode`, `SendMode` are per-thread settings.

### Input & Hotkeys
- Multi-line hotkey/hotstring actions use braces `{}`.
- `#HotIf` is the only context directive (`#If` and `#IfWin` are v1).
- `Hotkey()`/`HotIf()`/`OnEvent` callbacks are function objects that accept their parameters (or end with `*`), never label strings.
- `Send()` defaults to SendInput, which ignores `SetKeyDelay`; use `SendEvent` when delays are required.
- Key names in `GetKeyState()` and `KeyWait()` are quoted strings.

### Graphics & Screen
- `ImageSearch` and `PixelSearch` return 1/0; read the result as a Boolean, not `ErrorLevel`.
- Set `CoordMode("Pixel"/"Mouse", "Screen")` in the thread (startup or the callback) before screen-absolute coordinate operations (default is client-relative).
- Use `MonitorGet` bounds, not `A_ScreenWidth`/`A_ScreenHeight`, for non-primary monitors.
- Overlay Guis drawn at screen pixels use `-DPIScale`.
