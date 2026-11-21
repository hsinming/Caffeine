---
name: ahk-ctx-agent-protocol
description: >
  Platform-neutral operating protocol for AutoHotkey v2 agent ecosystems. Use
  before reading, editing, writing, or
  verifying `.ahk` files; before running AHK v2 `/ErrorStdOut` interpreter
  checks; when a running script shows an error popup that stdout cannot capture; before using current documentation connectors for AHK API verification; or before
  running shell commands that could delete, reset, or overwrite files. Covers
  capability discovery, safe `.ahk` edit patterns, ground-truth verification,
  documentation lookup fallback behavior, and
  destructive command safety. This is process/tooling guidance, not AHK language
  content; for AHK syntax, debugging, and API rules use ahk-ctx-script-debugging,
  ahk-ctx-core, ahk-ctx-logic, ahk-ctx-system,
  ahk-ctx-ui, ahk-ctx-uia, or ahk-ctx-review.
metadata:
  version: "2026.10.16"
---

# AHK Agent Protocol

This skill defines portable operating rules, not a tool API. The host agent or
platform-specific prompt supplies the actual file, shell, approval, browser,
documentation, and task-management capabilities. Never assume a tool exists
because it is named in an example or in another platform's adapter.

## Trigger Phrase Routing

| User phrase or task signal | Inject first | Then load only if needed |
|---|---|---|
| `.ahk`, edit, write, BOM, CRLF, encoding | `## 4. Editing `.ahk` Files Safely` | `ahk-ctx-core` (always), plus the domain skill for the area |
| `/ErrorStdOut`, compile, syntax-check, timeout, persistent script | `## 5. AHK v2 Ground-Truth Verification` | `ahk-ctx-script-debugging` |
| error popup, dialog appeared, hotkey/timer/GUI error, OnError, can't see error | `### 5.1 Capturing Runtime Error Popups` | `ahk-ctx-script-debugging` Step 2 |
| tool unavailable, connector, MCP, platform capability | `## 1. Discover Available Capabilities` | host-provided adapter or fallback |
| current docs, API uncertain | `## 6. Current Documentation Lookup` | domain reference module |
| delete, reset, restore, overwrite, `Remove-Item`, `git checkout` | `## 7. Destructive Shell Commands` | approval flow |

Use the exact section title as the routing anchor; do not inject this whole protocol when only AHK syntax is requested.

Use this shared protocol for every `ahk-*` custom agent and for ordinary work on AutoHotkey v2 files. Platform-specific agent prompts may implement the capability contract below, but the protocol remains usable when those adapters are absent.

## 1. Discover Available Capabilities

Before using any non-core capability, inspect the tools and instructions actually
available in the current session. Record the capabilities that matter to the
task rather than trying to identify a platform by name.

The useful capability categories are:

- read/search files
- edit files safely
- run shell commands or tests
- request approval/escalation
- query current documentation
- track progress or dispatch subagents

If the host agent provides a platform adapter, follow that adapter for the
category involved. If it does not, use an available equivalent or state the
limitation.

## 2. Capability Contract

Tool and MCP availability varies by app, CLI, IDE, WSL, SSH, container, and cloud environment.

Before relying on a non-core capability:

- Prefer the capabilities currently surfaced in the session.
- Verify optional tools or connectors through the host's discovery mechanism when one exists.
- For file discovery, prefer a fast repository search such as `rg` / `rg --files`; fall back only when unavailable.
- If a capability is absent, use direct file reads, available shell commands, local documentation, or clearly state the remaining uncertainty.

## 3. Host Adapter Boundary

A host adapter may map the capability contract to concrete tools, commands, or
connectors. Keep that mapping outside this skill so the same protocol can be
used by different agents and execution environments.

### Adapter Requirements for Host Agents

A platform adapter should define only how the host implements these operations:

| Capability | Required adapter information |
|---|---|
| Read/search | preferred read and search tools |
| Edit | safe edit mechanism and encoding rules |
| Execute | shell/test command mechanism and approval behavior |
| Documentation | current-doc lookup mechanism and fallback |
| Progress | plan, todo, or progress-report mechanism |
| Delegation | subagent/task dispatch mechanism, if available |

Do not put those platform-specific names into this shared protocol unless they
are explicitly marked as examples.

## 4. Editing `.ahk` Files Safely

AHK v2 source is unusually sensitive to backslashes, backticks, CRLF, UTF-8 BOM, and non-ASCII comments or string literals. Avoid fragile ad hoc text replacement for `.ahk` files when the change involves any of these characters.

Write new `.ahk` files as UTF-8 with BOM, especially when comments or strings hold non-ASCII text, and keep an existing file's BOM state. This is the AHK/Windows tooling compatibility rule, not a project preference.

Use the host's deterministic literal-replacement or full-file write path when
escaping or encoding is the hard part. The exact tool is supplied by the host
adapter; do not assume a particular editor or patch command.

For Windows hosts, a PowerShell literal replacement is one valid implementation:

```powershell
$p = "path/to/File.ahk"
$enc = New-Object System.Text.UTF8Encoding $true   # $true = emit BOM
$c = [System.IO.File]::ReadAllText($p, $enc)
$c = $c.Replace('exact old text', 'new text')      # literal, no regex escapes
[System.IO.File]::WriteAllText($p, $c, $enc)
```

For full-file replacement, rewrite the complete file only when safer than a targeted edit and only after reading the current file carefully.

Verified status varies by host — do not assume a fix or a bug carries over between platforms, and do not assume a single positive test clears a host for an entire session. As of 2026-07-23, Claude Code's built-in edit tool was empirically tested (byte-level check, not just re-reading the file) against a Windows path adjacent to a backtick escape, CRLF line endings, a UTF-8 BOM, and Chinese-text matching, and reproduced none of the corruption failure modes described above for **content** — backslashes, backtick sequences, CJK text, and BOM presence all survive a Claude Code edit intact. That single-file test was too narrow, though: a later multi-edit session (2026-08-13, then reconfirmed 2026-08-15 across a 6-file batch of same-shaped edits) found that Claude Code's edit tool **does** silently rewrite `.ahk` files from CRLF to LF line endings, intermittently — some edited files in the same batch flipped to LF while others in the identical batch stayed CRLF, so a clean check on one file is not evidence the next one is safe. This is nearly invisible: a repo with `core.autocrlf=true` and no `.gitattributes` shows an empty `git diff` for a pure EOL change, so diffing alone will not catch it — use the byte-level check in `### EOL verification and recovery` below instead. For any other or unverified host, default to those alternatives until the host's own edit tool has been tested the same way — and even a tested host still needs the EOL check below on every touched file, every session.

### EOL verification and recovery (Claude Code and any host with a similar edit tool)

After using an in-place edit tool (not a full-file rewrite) on `.ahk` files on a host where CRLF corruption is confirmed possible, verify line endings on **every** touched file before treating the edit as done — do not rely on one file's result to clear the rest of the batch:

- Ground truth is a byte-level count of `\r\n` vs. bare `\n` in the live working-tree file — not a visual read-back, and not `grep -c $'\r'` through an MSYS/Git-Bash shell, which has been observed to report false CRLF matches in this environment. A reliable check on Windows:
  ```powershell
  $text = [System.IO.File]::ReadAllText($path)
  ([regex]::Matches($text, "`r`n")).Count   # CRLF count
  ([regex]::Matches($text, "(?<!`r)`n")).Count  # bare-LF count — should be 0 if the file is pure CRLF
  ```
- To compare against the last-committed version, use `git cat-file -p <rev>:<path>` for raw bytes. (Tested 2026-08-24 on Windows/Git Bash, git 2.45.1: `git show <rev>:<path>` returned byte-identical output to `git cat-file -p` across autocrlf-true, explicit-LF, and `.gitattributes eol=crlf` cases — no EOL conversion was observed on this host/version. Prefer `git cat-file -p` anyway for a guaranteed-raw read, but do not treat `git show` as untrustworthy without re-testing on the current host/git version.)

Recovery depends on whether the corrupted state has been committed yet:

- **Not yet committed** (the common case — caught right after editing): rewrite the file in place, converting bare `\n` to `\r\n`, while preserving that specific file's original BOM state exactly (check the first 3 bytes for `EF BB BF`; do not add or remove a BOM as a side effect of an EOL fix — some repos are inconsistent about BOM per-file, and that inconsistency is not this fix's job to resolve). A safe pattern:
  ```powershell
  $enc = New-Object System.Text.UTF8Encoding $hasBom   # match the file's existing BOM state
  $text = [System.IO.File]::ReadAllText($path, $enc)
  $normalized = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
  [System.IO.File]::WriteAllText($path, $normalized, $enc)
  ```
  Re-run the AHK v2 ground-truth check (`## 5`) and the project's test suite afterward — this only touches line endings, but verify anyway.
- **Already committed and unnoticed**: do not hand-restore CRLF on top of a commit. Commit as-is (autocrlf normalizes the stored blob), then run `git checkout -- <file>` to re-apply the canonical checked-out form, and confirm with an empty `git diff` — this is the documented recovery path and is simpler than reconstructing the original bytes by hand.

When working through a path-converting shell, use that shell's documented way to
preserve Windows paths and `/ErrorStdOut` arguments.

## 5. AHK v2 Ground-Truth Verification

The AHK v2 interpreter is the ground truth for syntax and runtime behaviour; lint guesses and visual inspection are not. After every `.ahk` write or edit, validate the file with `ahk-ctx-script-debugging` Step 1 (`/Validate` through its bundled runner, `scripts/Invoke-AhkProbe.ps1`, plus its name-case check, `scripts/Test-AhkNameCase.ps1`, for names that differ only by case), and run it with Step 2 when runtime behaviour matters. Use the AutoHotkey v2 executable configured for the machine; a common install path is `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`.

If the current environment cannot run Windows AHK, state that verification was not available and which static checks you performed instead.

### 5.1 Capturing Runtime Error Popups

An unhandled error thrown after startup by a hotkey, timer, or GUI callback shows an **Error popup** (a `#32770` dialog) and writes nothing to stdout. `ahk-ctx-script-debugging` Step 2 injects a probe with `/include`, leaving the script unchanged: such errors arrive as structured stdout lines (type, message, file, line, stack) and the popup never appears. Its `-Hotkey` option fires hotkeys by posting `WM_HOTKEY` to the main window of the spawned PID only, so it does not touch the user's windows.

**Popup scan (fallback).** When a popup is already on screen, for example from a copy the user started, find visible `#32770` windows owned by that PID and read their text. `GetWindowText` returns an empty body for another process's Edit control; send `WM_GETTEXT` (`0xD`) to each child found with `EnumChildWindows` to get the message, line number, and call stack. Read-only: leave the dialog's buttons alone, and end a process you spawned by its PID, never by image name.

**Other input.** Simulating clicks or keystrokes (`Send`, `ControlClick`, `PostMessage` to GUI controls) can reach the user's real windows. Ask for confirmation first, or ask the user to exercise the action and report back.

## 6. Current Documentation Lookup

Use current documentation when an AHK v2 API detail is unfamiliar, version-sensitive, or easy to misuse, such as `DllCall`, COM methods, GUI option strings, UIA behavior, `Buffer`, WinHTTP, or directive syntax.

Use whatever current-documentation connector the host adapter exposes. Context7
is one possible provider, not a requirement of this protocol. If no current-doc
connector is available or it is blocked, proceed from loaded AHK skills and
local references, and explicitly flag unverified API assumptions.

Some networks block outbound HTTPS to documentation providers even when other
hosts work. Do not spend more than one attempt per session proving this. Treat
it as a possible network condition, not necessarily a missing-tool condition.

Do not install or invoke an undocumented command-line client as a substitute
unless the current environment explicitly supports it.

## 7. Destructive Shell Commands

Never run destructive commands unilaterally. Ask for user confirmation or use the platform's approval/escalation flow before commands that delete, reset, discard, or overwrite work, including:

```text
rm
rm -rf
rmdir
del
Remove-Item
git reset
git clean
git checkout -- *
git restore
git branch -D
```

For non-destructive commands, still respect the current sandbox and approval policy. If an important command fails due to sandboxing, network restrictions, or missing permissions, retry only through the platform's scoped approval/escalation mechanism when available.

## 8. What This Skill Does Not Cover

This skill does not teach AHK v2 syntax, architecture, UIA, GUI, async logic, or repository-specific conventions. Load the relevant AHK language or project skills for those rules:

- `ahk-ctx-script-debugging` for broken scripts, compile/runtime errors, persistent-script timeout-safe `/ErrorStdOut` checks, and silent hotkey/debugging workflows
- `ahk-ctx-core`
- `ahk-ctx-logic`
- `ahk-ctx-system`
- `ahk-ctx-ui`
- `ahk-ctx-uia`
- `ahk-ctx-review`
