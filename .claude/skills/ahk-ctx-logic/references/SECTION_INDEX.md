# ahk-ctx-logic Section Index

Per-heading detail for the routing table in `SKILL.md`. Find the row for the task, `grep -n "^## heading text"` the Reference module, and read that section through the next heading of the same level.

`## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` cover most routine tasks. Load a TIER section only when a complete, runnable example is needed.

### Timers (Module_Timers.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 breaking changes (timers) | `## V1 → V2 BREAKING CHANGES` |
| All timer API: SetTimer, binding, time measurement | `## API QUICK-REFERENCE` |
| `SetTimer` periods, reset, Function omitted, precision | `### SetTimer` |
| `.Bind()` / `ObjBindMethod()` | `### Binding Utilities` |
| `A_TickCount`, `FormatTime`, `A_Now` | `### Time and Measurement` |
| Constraints, QA checks and anti-patterns: cancel with stored BoundFunc, timers keep objects alive, callback errors | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — one-shot and repeating timers | `## TIER 1 — One-Shot and Repeating Timers` |
| **Working example** — timer lifecycle in classes | `## TIER 2 — Timer Lifecycle in Classes` |
| **Working example** — bound arguments, debounce, throttle | `## TIER 3 — Parameterized Callbacks, Debounce and Throttle` |
| **Working example** — state machines, chunked work | `## TIER 4 — Timer-Driven State Machines and Chunked Work` |
| Copy-paste snippets (SafeTimerCallback, WaitForWindowAsync) | `## DROP-IN RECIPES` |

---

### Threads & Critical (Module_ThreadsAndCritical.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 breaking changes (Critical, Sleep, Thread) | `## V1 → V2 BREAKING CHANGES` |
| All thread API: Critical, Sleep, Thread, directives | `## API QUICK-REFERENCE` |
| `Critical` settings and `A_IsCritical` | `### Critical` |
| `Sleep`, `Sleep 0`, `Sleep -1` | `### Sleep` |
| `Thread` sub-functions, `#MaxThreadsPerHotkey` | `### Thread and Directives` |
| Constraints, QA checks and anti-patterns: interruption, priority, buffering, Sleep does not freeze | `## AHK V2 CONSTRAINTS` |
| Symptom → cause mapping (lost events, races) | `## RUNTIME ERROR MAPPING` |
| **Working example** — thread model, Sleep, Sleep -1 | `## TIER 1 — The Thread Model: Interruption, Priority and Sleep` |
| **Working example** — Critical for atomic updates | `## TIER 2 — Critical for Atomic Shared-State Updates` |
| **Working example** — re-entrancy guards, message-check interval | `## TIER 3 — Re-Entrancy Guards and Message-Check Interval` |

---

### Exception Handling (Module_ExceptionHandling.md)

| Task | Grep for heading |
|------|-----------------|
| All error API: classes, properties, try/catch/else/finally, OnError | `## API QUICK-REFERENCE` |
| Built-in error class hierarchy and constructors | `### Built-in Error Classes` |
| Error object properties and the `What` parameter | `### Error Object Properties` |
| `try`/`catch`/`else`/`finally`/`throw`, `OnError` return values | `### Exception Control Flow` |
| Which built-ins throw vs return 0/"" | `### Throwing vs Non-Throwing Built-ins` |
| Constraints, QA checks and anti-patterns: `catch` default class, rethrow, OnError scope | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — try/catch/else/finally | `## TIER 1 — try / catch / else / finally Basics` |
| **Working example** — typed catch, custom Error subclasses, `catch Any` | `## TIER 2 — Typed Catch and Custom Error Classes` |
| **Working example** — `What`, rethrow, wrapping | `## TIER 3 — The What Parameter, Rethrow and Wrapping` |
| **Working example** — OnError global handler | `## TIER 4 — OnError Global Handler` |
| Copy-paste snippets (SafeExecute, SetupCrashLogger, TypeAssert) | `## DROP-IN RECIPES` |

---

### Error Diagnosis (Module_ErrorDiagnosis.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 mistakes and their v2 forms | `## V1 → V2 BREAKING CHANGES` |
| Symptom → cause → fix index | `### Symptom → Cause Index` |
| Built-ins used in the fixes | `### Built-ins Used in Fixes` |
| Constraints, QA checks and anti-patterns: `:=`, call statements, scope, fat arrows, 1-based arrays | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — assignment, call syntax, quoting, percent signs | `## TIER 1 — Assignment, Call Syntax, Quoting and Percent Signs` |
| **Working example** — scope, blocks, return, fat arrows | `## TIER 2 — Scope, Blocks, Return and Fat Arrows` |
| **Working example** — operators, loops, arrays, callback binding | `## TIER 3 — Operators, Loops, Arrays and Callback Binding` |
| **Working example** — `#HotIf`, GUI, Send targeting, paths | `## TIER 4 — Directives, GUI, Send Targeting, Paths and Blocking Calls` |
| **Working example** — removed features, instances, busy loops | `## TIER 5 — Version, Removed Features and Busy Loops` |

---

### Strings (Module_StringFunctions.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 breaking changes (strings) | `## V1 → V2 BREAKING CHANGES` |
| All string API: StrLen, SubStr, InStr, StrReplace, StrSplit, Format, … | `## API QUICK-REFERENCE` |
| String built-in functions | `### String Functions` |
| Backtick escape sequences | `### Escape Sequences` |
| Constraints, QA checks and anti-patterns: backtick escapes, immutability, no `.Length`/`.Join()` | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — building, quoting, joining, Format, continuation | `## TIER 1 — Building, Quoting and Joining` |
| **Working example** — escapes and literal characters | `## TIER 2 — Escapes and Literal Characters` |
| **Working example** — search, extract, replace, split, compare | `## TIER 3 — Search, Extract, Replace, Split and Compare` |
| Copy-paste snippets (JoinArray, NormalizeWhitespace, StartsWith/EndsWith) | `## DROP-IN RECIPES` |

---

### Regular Expressions (Module_RegEx.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 breaking changes (regex) | `## V1 → V2 BREAKING CHANGES` |
| All regex API | `## API QUICK-REFERENCE` |
| `RegExMatch` / `RegExReplace` signatures and errors | `### Regex Functions` |
| Match object (`Pos`, `Len`, `Name`, `Count`, `Mark`) | `### Match Object (RegExMatchInfo)` |
| Pattern options (`i`, `m`, `s`, `x`, `U`, …) | `### Options (start of pattern, case-sensitive)` |
| Replacement backreferences (`$1`, `${name}`, `$U1`, `$$`) | `### Replacement Backreferences` |
| Constraints, QA checks and anti-patterns: option prefix, `&OutputVar`, blank on no match | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — RegExMatch basics and options | `## TIER 1 — RegExMatch Basics and Options` |
| **Working example** — groups, named groups, find all | `## TIER 2 — Capture Groups, Named Groups and Iteration` |
| **Working example** — RegExReplace and backreferences | `## TIER 3 — RegExReplace and Backreferences` |
| Copy-paste snippets (SafeRegExExtract, RegExMatchAll, RegExEscape) | `## DROP-IN RECIPES` |

---

### Guard Clauses (Module_GuardClauses.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 breaking changes (`is`, unset, `IsFunc`) | `## V1 → V2 BREAKING CHANGES` |
| All guard API | `## API QUICK-REFERENCE` |
| `is`, `Type()`, `IsInteger()`, `IsNumber()`, `IsObject()`, `IsSet()` | `### Type Checks` |
| `p?`, `:= unset`, `??`, passing `p?` on | `### Unset Parameters and Defaults` |
| `HasMethod()`, `HasProp()`, `HasBase()` | `### Capability Probes` |
| `TypeError`/`ValueError`/`TargetError` and the `What` parameter | `### Error Classes for Guards` |
| Constraints, QA checks and anti-patterns: class test vs content test, IsSet on variables only | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — type detection and unset parameters | `## TIER 1 — Type Detection and Unset Parameters` |
| **Working example** — guards for functions and constructors | `## TIER 2 — Guard Clauses for Functions and Constructors` |
| **Working example** — duck typing and interface checks | `## TIER 3 — Duck Typing and Interface Checks` |

---

### Validation Rules (Module_ValidationRules.md)

| Task | Grep for heading |
|------|-----------------|
| v1 → v2 breaking changes (pre-flight checks) | `## V1 → V2 BREAKING CHANGES` |
| All validation-rule API | `## API QUICK-REFERENCE` |
| `FileExist()`, `DirExist()`, `WinExist()`, `ProcessExist()`, `SplitPath()` | `### Environment Pre-Flight Functions` |
| `ValidationBuilder` methods | `### ValidationBuilder (user-defined, TIER 3)` |
| `FormValidator` methods | `### FormValidator (user-defined, TIER 3)` |
| Constraints, QA checks and anti-patterns: FileExist matches folders, pre-checks are not guarantees | `## AHK V2 CONSTRAINTS` |
| Runtime error → probable cause mapping | `## RUNTIME ERROR MAPPING` |
| **Working example** — e-mail, password, filename, port, slug rules | `## TIER 1 — Format and Business Rules` |
| **Working example** — file/folder/window/process pre-flight | `## TIER 2 — Environment Pre-Flight Checks` |
| **Working example** — fluent ValidationBuilder + FormValidator | `## TIER 3 — Fluent ValidationBuilder and FormValidator` |
| Copy-paste snippet (AssertParams) | `## DROP-IN RECIPES` |
