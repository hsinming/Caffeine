# AGENTS.md

## Project

Single-file AutoHotkey v2 tray app (`caffeine.ahk`) that prevents Windows sleep/display-off via `SetThreadExecutionState`. MIT licensed.

## Build & Run

- **Run script**: `AutoHotkey.exe caffeine.ahk` (requires AutoHotkey v2 on Windows)
- **Compile**: `.\build.ps1` — locates `Ahk2Exe.exe` from standard install paths and produces `Caffeine.exe`
- Ahk2Exe compiler directives are embedded as comments at the top of `caffeine.ahk` (`;@Ahk2Exe-SetMainIcon`, etc.)
- `Coffee.ico` must be next to the script at runtime (for `A_Icon`) and at compile time (for `;@Ahk2Exe-SetMainIcon`)

## AHK v2 Conventions

- 4-space indentation, CRLF line endings, K&R braces
- No `new` keyword for instantiation
- Fat-arrow closures for one-shot callbacks: `(*) => ExitApp()`
- `DllCall` type strings are explicit (`"UInt"`, `"Ptr"`, etc.)
- Compile directives (`;@Ahk2Exe-*`) are AHK comments at runtime — only parsed by Ahk2Exe during compilation
- Tray icon set via `A_Icon` assignment; tray menu via `A_TrayMenu` object API (no v1 tray commands)
- `OnExit` with fat-arrow cleanup to restore power state

## Key Files

| File | Purpose |
|------|---------|
| `caffeine.ahk` | Entire application (37 lines) |
| `Coffee.ico` | App + tray icon |
| `build.ps1` | Compile script |
| `README.md` | User-facing docs |

## Skills

This repo has `.claude/skills/` with AHK v2 reference modules. The skill system is configured in `opencode.json` with AHK-specific agents (`ahk-orchestrator`, `ahk-architect`, `ahk-code`, `ahk-debug`, `ahk-ask`). Load the relevant skill before writing or reviewing AHK code.