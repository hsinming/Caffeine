# AGENTS.md

## Project

Single-file AutoHotkey v2 tray app (`caffeine.ahk`) that prevents Windows sleep/display-off via `SetThreadExecutionState`. MIT licensed.

## Build & Run

`.\build.ps1` compiles `caffeine.ahk` to `Caffeine.exe` and doubles as the compile check. Run the script with `AutoHotkey.exe caffeine.ahk` (AutoHotkey v2). Ahk2Exe directives are comments at the top of `caffeine.ahk`.

### Rendering quirk
`.\build.ps1` can render as `.uild.ps1`, because `\b` looks like a backspace escape. The file bytes are correct; keep the name as written.

## File Editing

- **`.ahk` files**: the `edit` tool has escape, CRLF and Unicode bugs on them. Use PowerShell and keep the UTF-8 BOM:
  ```powershell
  $p = "caffeine.ahk"
  $enc = New-Object System.Text.UTF8Encoding $true
  $c = [System.IO.File]::ReadAllText($p, $enc)
  $c = $c.Replace('old text', 'new text')
  [System.IO.File]::WriteAllText($p, $c, $enc)
  ```
  For a full rewrite, use the `write` tool.
- **Encodings**: `*.ahk` UTF-8 **with BOM**; `*.md` UTF-8 no BOM; `*.ini` UTF-16 LE.

## AHK v2 Conventions & Gotchas

- **No `new` keyword**: instantiate with `ClassName()`.
- **Map for key-value lookups**: use `Map()`, not `{key: value}`, for dynamic keys.
- **A_Clipboard**: use it, not the deprecated `Clipboard`.
- **Stored-callable trap**: `obj.prop(args)` treats `prop` as a method and injects `obj` as the first parameter. Use `obj.prop.Call(args)` or extract it first: `fn := obj.prop; fn(args)`.
- **Tray icon**: use `TraySetIcon(path)`, never `A_Icon := ...` (no effect). Guard it with `if FileExist(path)`.
- **`FileOpen`**: no `"RAW"` encoding (throws `ValueError`). Omit it for binary read; use `"UTF-8-RAW"` for BOM-free writes.
- **Style**: 4-space indent, CRLF, K&R braces, fat-arrow closures for one-shot callbacks (`(*) => ExitApp()`), explicit `DllCall` type strings (`"UInt"`, `"Ptr"`), `OnExit` cleanup to restore power state.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`hsinming/Caffeine`), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root, if they exist.
