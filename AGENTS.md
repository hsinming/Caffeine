# AGENTS.md

## Project

AutoHotkey v2 tray app that prevents Windows sleep/display-off via `SetThreadExecutionState`. MIT licensed. `caffeine.ahk` holds the tray UI and side effects, `core.ahk` the pure logic, and `tests\` the headless tests.

## Build & Run

`.\build.ps1` compiles `caffeine.ahk` to `dist\Caffeine.exe` (or `-Output <path>`) and doubles as the compile check. Run the script with `AutoHotkey.exe caffeine.ahk` (AutoHotkey v2). Ahk2Exe directives are comments at the top of `caffeine.ahk`.

`.\test.ps1` runs the smoke test (`tests\smoke.ahk` against `caffeine.ahk`) and every `tests\*_test.ahk` headless, writes `test-result.json`, and exits non-zero on any failure. Tests use `Test(name, fn)` and `AssertEqual` from `tests\Assert.ahk`; pure logic lives in `core.ahk` and takes `now` as a parameter.

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

### AHK reference

The project skills `.claude/skills/ahk-ctx-*` are the AHK v2 reference: `ahk-ctx-core`, `ahk-ctx-logic`, `ahk-ctx-system`, `ahk-ctx-ui` for language and API rules, `ahk-ctx-script-debugging` for a failing script, `ahk-ctx-review` for review.

## Closed Loop

Every `ready-for-agent` issue runs this loop. Terms (Test Run, Test Result, Quality Gate, Escalation) are defined in `GLOSSARY.md`; the reasons are in `docs/adr/0001-closed-loop.md`.

1. **Plan.** Read the issue (`gh issue view <n>`) and its parent spec. Plan in plan mode.
2. **Red.** For a bug, first write a test in `tests\*_test.ahk` that reproduces it, and run `.\test.ps1` until that test fails.
3. **Develop.** Change the code.
4. **Test Run.** Run `.\test.ps1`. Fix only from `test-result.json` (`syntaxError`, then each `failures[]` entry: `test`, `expected`, `actual`, `file`, `line`, `stack`); use `ahk-ctx-script-debugging` to debug. Repeat until `passed` is `true`. Each Test Run that fails counts as one round.
5. **Review.** Call the `reviewer` subagent with `git diff` and the issue number. `CHANGES` counts as one round: fix the listed problems and go back to step 4. Continue only on `APPROVE`.
6. **Commit.** Commit on `main` with `Fixes #<n>` in the message. The pre-commit hook (`.githooks/pre-commit`) re-runs `test.ps1` and `build.ps1`; when it rejects the commit, go back to step 4. Every commit goes through the hook: `--no-verify` and `-n` are banned and denied in `.claude/settings.json`. Push only when the maintainer approves.

**Stop rules.** Escalate when the same test fails 3 rounds in a row, or after 5 rounds in total. To escalate: stop, comment the last `test-result.json` on the issue (`gh issue comment <n>`), and add the `ready-for-human` label.

**Processing the queue.** On "process ready-for-agent issues": list them with `gh issue list --label ready-for-agent --state open`, skip any with an open blocker, and run the loop on each in ascending issue number, one issue at a time. Bug reports from the tray "Report a Bug" item arrive through `.github/ISSUE_TEMPLATE/bug.yml` labelled `bug` and `needs-triage`; they enter the loop only after triage marks them `ready-for-agent`.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`hsinming/Caffeine`), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root, if they exist.
