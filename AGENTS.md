# AGENTS.md

## Project

Single-file AutoHotkey v2 tray app (`caffeine.ahk`) that prevents Windows sleep/display-off via `SetThreadExecutionState`. MIT licensed.

## Build & Run

- **Run script**: `AutoHotkey.exe caffeine.ahk` (requires AutoHotkey v2 on Windows)
- **Compile**: `.\build.ps1` — locates `Ahk2Exe.exe` from standard install paths and produces `Caffeine.exe`
- Ahk2Exe compiler directives are embedded as comments at the top of `caffeine.ahk` (`;@Ahk2Exe-SetMainIcon`, etc.)
- `app.ico` is embedded into `Caffeine.exe` at compile time (via `;@Ahk2Exe-SetMainIcon`).

### Known Rendering Quirks
- **The `.\build.ps1` False Typo**: The Windows path separator and the file name `build.ps1` form the literal sequence `\b`. Some terminal outputs, log viewers, or markdown engines interpret `\b` as a backspace escape sequence, causing it to render visually as `.uild.ps1`. **Do not attempt to "fix" this** — the raw file bytes are perfectly correct (`.` `\` `b`).

## Tool & File Guidelines

### AHK File Editing (Critical Rule)
The `edit` tool has escape, CRLF, and Unicode bugs on `.ahk` files.
* **Targeted edits**: Use PowerShell via `bash` (preserving UTF-8 BOM):
  ```powershell
  $p = "caffeine.ahk"
  $enc = New-Object System.Text.UTF8Encoding $true
  $c = [System.IO.File]::ReadAllText($p, $enc)
  $c = $c.Replace('old text', 'new text')
  [System.IO.File]::WriteAllText($p, $c, $enc)
  ```
* **Full rewrite**: Use the `write` tool.

### File Encoding Rules
| File Type | Encoding | PowerShell Command to Write |
| :--- | :--- | :--- |
| `*.ahk` | UTF-8 **with BOM** | `[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding $true))` |
| `*.md` | UTF-8 (no BOM) | Standard UTF-8 |
| `*.ini` | UTF-16 LE | `[System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UnicodeEncoding($false, $true)))` |

### Verifying AHK Files
1. **LSP Diagnostics**: Use `lsp_diagnostics` (skip or expect warnings for non-standard compiler directives like `;@Ahk2Exe-`).
2. **Ground Truth Interpreter check**: Run the AHK v2 compiler or interpreter with `/ErrorStdOut` (exit code 0 = compile OK, 2 = compile error). For Caffeine, executing `.\build.ps1` compiles the script and serves as an excellent verification step.

## AHK v2 Conventions & Coding Gotchas

- **No `new` keyword**: Instantiation is `ClassName()`, not `new ClassName()`.
- **Map for Key-Value Lookups**: Use `Map()` instead of `{key: value}` for dynamic runtime key-value lookups.
- **A_Clipboard**: Use `A_Clipboard` instead of the deprecated `Clipboard`.
- **Stored-Callable Invocation Trap**: `obj.prop(args)` treats `prop` as a method and injects `obj` as the first parameter. To call a stored function/closure without injection, extract it: `local fn := obj.prop; fn(args)` or use `obj.prop.Call(args)`.
- **Tray Icon Update (`TraySetIcon`)**: To dynamically change the tray icon, use `TraySetIcon(path)`. Never assign to `A_Icon := ...` which is not a built-in variable and has no effect. Always guard `TraySetIcon` with `if FileExist(path)` to prevent runtime crashes if icon files are missing.
- **4-space indentation, CRLF line endings, K&R braces**
- **Fat-arrow closures** for one-shot callbacks: `(*) => ExitApp()`
- **Explicit `DllCall` type strings** (`"UInt"`, `"Ptr"`, etc.)
- **No `"RAW"` encoding in `FileOpen`**: It throws a `ValueError`. Omit the parameter for raw binary read; use `"UTF-8-RAW"` for BOM-free writes.
- **OnExit with fat-arrow cleanup** to restore system power state.

## Key Files

| File | Purpose |
|------|---------|
| `caffeine.ahk` | Entire application (contains tray menu & sleep prevention logic) |
| `app.ico` | App main icon (embedded at compile-time) |
| `on.ico` | Active tray icon (displayed when sleep prevention is active) |
| `off.ico` | Inactive tray icon (displayed when sleep prevention is inactive/disabled) |
| `build.ps1` | Compile script |
| `README.md` | User-facing docs |

## Skills

This repo has `.claude/skills/` with AHK v2 reference modules. The skill system is configured in `opencode.json` with AHK-specific agents (`ahk-orchestrator`, `ahk-architect`, `ahk-code`, `ahk-debug`, `ahk-ask`). Load the relevant skill before writing or reviewing AHK code.
