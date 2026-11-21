---
name: ahk-ctx-review
description: >
  AHK v2 code review workflow. Use when the user asks to review, audit, or critique an AutoHotkey v2
  script, find bugs, check v2 compliance, assess security, naming, over-engineering or refactoring needs, or review a Module_*.md. Produces
  a six-dimension report with severity levels and a Priority Action List.
metadata:
  version: "2026.10.16"
---

# AHK v2 Code Review — Orchestration Protocol

This skill owns the review workflow, finding classification, and report format.
It does not own AHK v2 syntax, API semantics, or domain-specific best practices;
load those from `ahk-ctx-core` and the relevant domain skill. Steps 1–3 below are this
Skill's flow. Severity levels, thresholds, and naming styles are repo convention; language facts
are cited to the official v2 docs inside each Reference module.

## Step 1 — Load Modules (before reading the submitted code)

Always load: `references/Module_ReviewFramework.md`, `references/Module_ReviewV2Syntax.md`, and
`../ahk-ctx-core/references/Module_Instructions.md` (full file, the v2 syntax baseline for Dimension 1).
Then scan the submitted code and load the rows it matches. Read the listed heading through the next
heading of the same level; `references/SECTION_INDEX.md` lists every heading per Module.

| Signal | Module | Heading |
|---|---|---|
| review, audit, critique, report format, severity | `Module_ReviewFramework.md` | `## REPORT OUTPUT FORMAT`, `### Severity Classification` |
| v2 compliance, check syntax, v1 residue, `=` vs `:=`, hotkey doesn't fire, variable stays empty | `Module_ReviewV2Syntax.md` | `## V1 → V2 BREAKING CHANGES` |
| `try`, `catch`, `OnError`, `FileRead`, `RegRead`, `ComObject`, `DllCall`, `Download`, `WinGet*`, does X throw, crash | `Module_ReviewErrorHandling.md` + `../ahk-ctx-logic/references/Module_ExceptionHandling.md` | `### Throwing Operations Reference` |
| globals, many functions, long parameter lists, deep nesting, refactor | `Module_ReviewArchitecture.md` | `## TIER 3 — Variable Scope, Architecture & SE Design Principles` |
| `Gui()`, `.Add()`, `.OnEvent()`, `SetTimer`, `.Bind()`, g-label | `Module_ReviewGuiEvents.md` + `../ahk-ctx-ui/references/Module_GuiBasics.md` | `## AHK V2 CONSTRAINTS` |
| loops over I/O, COM, `ObjRelease`, `CoordMode`, user input reaching `DllCall`/`RegWrite`/regex, performance, security | `Module_ReviewPerformanceSecurity.md` | `## AHK V2 CONSTRAINTS` |
| `DllCall`, `Buffer`, `ComObjQuery` | `../ahk-ctx-system/references/Module_DllCallBasics.md` | DllCall signature rules for Dimension 5 security checks |
| `class`, `extends`, `__New`, `static`, OOP patterns | `../ahk-ctx-core/references/Module_ClassBasics.md` | class semantics, lifecycle, callback context |
| function definitions, parameters, scope, callbacks | `../ahk-ctx-core/references/Module_FunctionBasics.md` | function semantics and parameter rules |
| any script (Dimension 6 always runs): naming, comments, YAGNI, over-engineering, duplicate hotkeys | `Module_ReviewCleanCode.md` | `## AHK V2 CONSTRAINTS` |
| correctness, runtime bug, error class semantics | `ahk-ctx-logic` | error mapping and validation constraints |
| file/COM/DLL/HTTP behavior | `ahk-ctx-system` | named system module API + constraints |
| GUI/window/input behavior | `ahk-ctx-ui` | named UI module API + constraints |
| UIA/browser behavior | `ahk-ctx-uia` | discovery or interaction router, then browser router |

## Step 2 — Review

Follow `Module_ReviewFramework.md` for the pre-review declaration, the six dimensions in order, finding wording, the report format, and the Priority Action List. Complete the declaration before analysing any line. The Dimension 1 to 6 checklists are the Modules the router loaded.

## Step 3 — Severity baselines

Repo convention, not language rules. Confirm the concrete consequence and the relevant source module before assigning a severity; style preferences are not automatically correctness findings. A dimension with no findings still appears as `✅ No issues found.` or `✅ Not applicable ([reason]).`

**Critical 🔴**
- `=` used as assignment (`counter = 0` alone on a line is invalid v2; inside an expression it compares)
- Empty `catch {}` that hides a failure
- Bare instance-method callback such as `OnEvent("Click", this.OnClick)` (the control arrives as `this`, parameters shift by one)
- Same hotkey defined twice with the same `#HotIf` criteria
- Multi-statement fat-arrow body `=> { }` (a fat arrow evaluates one expression)
- User input reaching a `DllCall` path or `RegWrite` key without validation
- Dynamic `RegExMatch(data, userPattern)` outside try/catch
- Complexity or nesting that makes behavior materially unsafe or unreviewable, with the concrete impact stated

**Major 🟠**
- Read/predicate name that hides a material side effect (`GetUser()` that also writes an audit file)
- Abstraction with zero current callers, or a design pattern whose cost current variants do not justify
- Long function or long parameter list that mixes responsibilities; deep nesting that obscures control flow
- Loop-invariant I/O or COM creation inside a loop or hot hotkey
- `ObjRelease()` on a `ComObject()`/`ComObjQuery()` wrapper (it takes an Integer pointer; wrappers release themselves)
- Magic string in 3+ locations
- Clean Code issue that materially obscures behavior or raises maintenance risk; classify by impact

**Minor 🟡**
- Single comment that restates code, non-descriptive name (`x`, `tmp2`) outside a loop, magic literal in 1–2 locations, single defensive guard in an internal helper, single-method class that could be a function

Operations that throw, with docs pages: `Module_ReviewErrorHandling.md` → `### Throwing Operations Reference`.
