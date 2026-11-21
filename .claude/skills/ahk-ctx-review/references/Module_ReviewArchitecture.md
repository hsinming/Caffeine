# Module_ReviewArchitecture.md
<!-- DOMAIN: Code Review — Dimension 3: Variable Scope, Architecture & SE Design Principles -->
<!-- SCOPE: Review checklist for implicit global coupling, data-structure choice (Array/Map vs pseudo-arrays and parallel variables), single responsibility, named constants, function length, parameter count, and nesting depth. Class semantics are in Module_ClassBasics.md and function/scope rules in Module_FunctionBasics.md (ahk-ctx-core). Over-engineering (YAGNI) is in Module_ReviewCleanCode.md. -->
<!-- TRIGGERS: "refactor", "too complex", "too many globals", "function too long", "too many parameters", "deep nesting", "pseudo-array", "should I use a class", "single responsibility", "architecture review", global, Map(), Array(), static -->
<!-- CONSTRAINTS: All thresholds here (parameter counts, nesting depth, function length) are repo heuristics, not language limits; classify by concrete impact. `{}` in v2 creates an Object (properties), `Map()` holds arbitrary keys — prefer Map for runtime-keyed data (convention). Do not refactor code that Dimension 6 flags for deletion. -->
<!-- CROSS-REF: Module_ReviewFramework.md, Module_ReviewCleanCode.md, Module_ClassBasics.md, Module_FunctionBasics.md -->
<!-- VERSION: AHK v2.0+ -->

> **Convention, not a language limit.** AHK v2 imposes none of the thresholds
> below. They are review heuristics; state the concrete cost when you raise one.

## AHK V2 CONSTRAINTS

- Functions are assume-local in v2: a function reads a global variable without a
  declaration, but must declare `global x` to assign it (Functions.htm). Many
  functions that assign shared globals → 🟠 Major coupling finding (convention).
- `{}` is an object literal that creates an `Object` with properties
  (Objects.htm, Object Literal). `Map()` stores arbitrary keys and is the repo
  convention for runtime-keyed data. Neither is "v1 only".
- Variable names that differ only in case are the same variable (ASCII names are
  case-insensitive), so naming cannot distinguish two values.
- Do not produce Dimension 3 refactoring advice for a class Dimension 6 marks
  YAGNI; recommend deletion once.

## TIER 3 — Variable Scope, Architecture & SE Design Principles
> METHODS COVERED: `Map()` · `Array()` · `class static` · `FileAppend()` · `for` · `StrSplit()` · `RegExMatch()`

```ahk
; CHECK 1: Implicit global coupling
; ✗ Shared mutable globals assigned from many functions (🟠 Major, convention)
global hitCount := 0
IncrementHitGlobal() {
    global hitCount
    hitCount += 1
}

; ✓ Encapsulate shared state in a class (convention)
class Session {
    static hitCount := 0
    static Increment(delta := 1) => Session.hitCount += delta
    static Reset() => Session.hitCount := 0
}
Session.Increment()

; ----------------------------------------------------------------
; CHECK 2: Collections instead of numbered variables
; ✗ item1 := "apple", item2 := "banana"   — cannot loop or count them
; ✓ Ordered data → Array; keyed data → Map
items := ["apple", "banana", "cherry"]
for i, item in items
    OutputDebug(i ": " item)

config := Map("host", "localhost", "port", 5432)
OutputDebug(config["host"])

; ----------------------------------------------------------------
; CHECK 3: Single responsibility
; ✗ One function updates state, shows UI, and writes a log
UpdateAndNotify(val) {                  ; 🟠 Major: mixed concerns, vague name
    Session.Increment(val)
    if (Session.hitCount > 10)
        MsgBox("Threshold reached!")
    FileAppend(Session.hitCount "`n", "log.txt")
}

; ✓ Focused functions
HIT_THRESHOLD := 10
IsThresholdReached() => Session.hitCount > HIT_THRESHOLD
AppendHitLog(path) {
    try FileAppend(Session.hitCount "`n", path)
    catch as e
        OutputDebug("AppendHitLog: " e.Message)
}

; ----------------------------------------------------------------
; CHECK 4: Named constants for magic values (convention)
; ✗ if (retryCount > 3) Sleep(5000)      ; what are 3 and 5000?
MAX_RETRIES := 3
RETRY_DELAY_MS := 5000
retryCount := 0
if (retryCount > MAX_RETRIES)
    Sleep(RETRY_DELAY_MS)

; ----------------------------------------------------------------
; CHECK 5: Separate I/O, parsing, and UI
ReadConfig(path) => FileRead(path, "UTF-8")      ; I/O only; caller handles OSError

ParseConfigLines(raw) {                          ; pure parsing, no I/O
    result := Map()
    for line in StrSplit(raw, "`n", "`r") {
        if RegExMatch(line, "^(\w+)=(.+)$", &m)
            result[m[1]] := m[2]
    }
    return result
}

; ----------------------------------------------------------------
; CHECK 6: Long positional parameter lists
; ✗ Callers must remember the order of six positional arguments
SendNotificationPositional(to, from, subject, body, cc, bcc) {
}
; ✓ One options object with defaults (convention; a Map or an Object both work)
SendNotification(opts) {
    to      := opts.Get("to", "")
    subject := opts.Get("subject", "(no subject)")
}
SendNotification(Map("to", "a@b.c", "subject", "Hi"))

; ----------------------------------------------------------------
; CHECK 7: Deep nesting → guard clauses or extraction
; ✗
ProcessItemsNested(items) {
    for item in items {
        if (item.type = "A") {
            if (item.active) {
                Loop item.count {
                    if (A_Index > 5)
                        HandleItem(item)
                }
            }
        }
    }
}
; ✓
ProcessItems(items) {
    for item in items
        ProcessSingleItem(item)
}
ProcessSingleItem(item) {
    if (item.type != "A" || !item.active)
        return
    Loop item.count {
        if (A_Index > 5)
            HandleItem(item)
    }
}
HandleItem(item) {
}
```

### Heuristic thresholds (convention)

| Signal | Default classification | Escalate when |
|--------|------------------------|---------------|
| More than 4 positional parameters | 🟡 Minor / 🟠 Major | Callers pass many blanks or confuse argument order |
| Nesting depth ≥ 4 | 🟠 Major | Conditions interact and control flow is hard to verify |
| Function mixes I/O, logic, and UI | 🟠 Major | Parts cannot be tested or reused separately |
| Many functions assign shared globals | 🟠 Major | Order-dependent bugs or re-entrancy (timers, hotkeys) |
| Numbered variables used as a list | 🟠 Major | Code loops or counts them by building names |

Pure data tables and lookup Maps are exempt from length heuristics.

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| Long mixed-responsibility function | I/O, parsing, and UI in one body | Split when it improves clarity or testing | End-to-end generation |
| Long positional parameter list | `Fn(a, b, c, d, e, f)` | `Fn(opts)` with defaults via `.Get()` | Positional signatures are the default habit |
| Pseudo-arrays | `item1`, `item2`, `item3` | `items := [...]` | v1 pseudo-array idiom |
| Treating thresholds as rules | "7 params → Critical" with no impact | State the concrete cost, then classify | Checklist over judgement |

## SEE ALSO

- `Module_ReviewCleanCode.md` — YAGNI and over-abstraction (run before this module when classes look unnecessary)
- `Module_ClassBasics.md` (ahk-ctx-core) — class semantics and static members
- `Module_FunctionBasics.md` (ahk-ctx-core) — scope, parameters, and callbacks
