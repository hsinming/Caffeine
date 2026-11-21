---
name: ahk-ctx-logic
description: >
  AutoHotkey v2 program logic. Use when writing, modifying, or reviewing .ahk code that involves
  timers (SetTimer, debounce, polling), threads and background tasks (OnMessage, Critical, Sleep, re-entrancy), errors (try/catch,
  throw, OnError, v1 migration crashes), input validation and guard clauses (IsSet, type checks),
  string handling (escaping, Unicode), or RegEx parsing.
metadata:
  version: "2026.10.16"
---

# AHK v2 Logic Context

Read `../ahk-ctx-core/references/Module_Instructions.md` in full first; its `<how_to_use>` is the
flow for this Skill. Then load `../ahk-ctx-core/references/Module_CodeStyle.md` in full when writing
or editing AHK, and `../ahk-ctx-core/references/Module_FatArrowFunctions.md` when timer callbacks,
async patterns, or closures are present.

## Router

Read the listed heading through the next `## ` heading. `references/SECTION_INDEX.md` lists every
heading per Module, including TIER examples.

| Signal | Module | Heading |
|---|---|---|
| timer, `SetTimer`, delayed, debounce, throttle, polling, state machine | `Module_Timers.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `Critical`, `Sleep`, `Sleep -1`, interrupt, re-entrancy, race, thread priority | `Module_ThreadsAndCritical.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `try`, `catch`, `throw`, error class, `OnError`, custom error | `Module_ExceptionHandling.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| crash, "script won't run", syntax/load-time error, v1→v2 migration, `ErrorLevel`, `new` | `Module_ErrorDiagnosis.md` | `## V1 → V2 BREAKING CHANGES` + `### Symptom → Cause Index` |
| string, text, escape, backtick, join, `StrReplace`, `StrSplit`, `Format` | `Module_StringFunctions.md` | `## API QUICK-REFERENCE` + matching TIER |
| regex, `RegExMatch`, `RegExReplace`, capture group, pattern options | `Module_RegEx.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| guard, `IsSet`, `??`, type check, `is`, `IsInteger`, duck typing, `HasMethod` | `Module_GuardClauses.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| validate input/form, password/e-mail rule, pre-flight `FileExist`/`WinExist`, `ValidationBuilder` | `Module_ValidationRules.md` | `## API QUICK-REFERENCE` + matching TIER |
| `OnMessage` callback or timer exception | `Module_Timers.md` + `Module_ExceptionHandling.md` | `## AHK V2 CONSTRAINTS` in both, then `## DROP-IN RECIPES` in `Module_Timers.md` |

Load one Module for a single string or timer question; descend into a `## TIER` section when the
task needs a runnable example.

## Critical Rules

### Timers & Threads
- Bind a method passed to `SetTimer` (`.Bind(this)` or `ObjBindMethod`) and store the BoundFunc; cancel with that same object.
- An active timer keeps its BoundFunc (and the bound object) alive: stop class timers with an explicit `Stop()`, not only in `__Delete`.
- Use negative periods (e.g., `-1000`) for one-off delayed work.
- `Sleep` pauses only the current thread; new threads can still run. Convention: in event handlers, schedule follow-up work with a timer instead of `Sleep`.
- `Sleep -1` does not delay: it checks the message queue so pending interruptions run at that point.
- Keep `Critical` sections short and free of `Sleep`; save and restore `A_IsCritical` in helpers.
- Timer callback errors do not propagate to the scheduling call; catch them locally when logging or recovery is required.

### Error Handling
- `=` in an expression is a case-insensitive comparison; assign with `:=`.
- Built-ins are functions; parentheses are optional only for call statements, and text arguments are always quoted.
- `%Expr%` outside quotes is only for dynamic references.
- `catch` without a class catches only `Error` instances; use `catch Any` for any thrown value.
- Match the error class to the failure domain: `TypeError`, `ValueError`, `OSError`, `TargetError`.
- Wrap operations that can throw when the caller needs local recovery, diagnostics, or a fallback; predictable preconditions get explicit checks.

### Validation
- Validate at public/external input boundaries before dependent logic; use narrower checks for trusted internal helpers.
- `x is Integer` is a class test; use `IsInteger()`/`IsNumber()` for text that should contain a number.
- Read optional `p?` parameters only after `IsSet(p)`, or use `p ?? fallback`.
- Use `HasMethod()` and `HasProp()` for duck-type capability checks (convention).
- Fail early: throw the most specific error class available, with `-1` as `What` and the bad value as `Extra`.
- Use `ValidationBuilder` for multi-field form validation when accumulating several user-facing errors is useful; simple validation can stay direct.

### Text Processing
- Backslash is a literal in AHK strings (a PCRE escape only inside regex patterns).
- Strings have no `.Length` and Arrays have no `.Join()` in v2.0: use `StrLen()` and a join loop.
- Use `.=` for string concatenation in loops.
- Regex options go at the start of the pattern as `opts)`: `i` (case-insensitive), `m` (multiline), `s` (dot-all), `x` (extended), and others.
