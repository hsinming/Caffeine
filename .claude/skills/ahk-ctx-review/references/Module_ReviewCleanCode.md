# Module_ReviewCleanCode.md
<!-- DOMAIN: Code Review — Dimension 6: Clean Code, Over-Engineering & Composite -->
<!-- SCOPE: Review checklist for naming, comment quality, magic strings, dead code, duplicate hotkeys and #HotIf variants, and over-engineering (YAGNI factories, plugin managers, event buses, single-method wrapper classes, over-defensive internal guards). Report structure and the Priority Action List are in Module_ReviewFramework.md; architecture refactoring is in Module_ReviewArchitecture.md. -->
<!-- TRIGGERS: "clean code", "over-engineering", "YAGNI", "naming convention", "comment quality", "too abstract", "design pattern", "dead code", "magic string", "duplicate hotkey", "#HotIf", "is this guidance overbroad", "refactor review" -->
<!-- CONSTRAINTS: Naming styles (camelCase, PascalCase, UPPER_SNAKE_CASE) and prefixes such as Get/Is/Set are repo convention, not language rules; ASCII identifiers are case-insensitive. Classify clean-code and over-engineering findings by concrete maintenance impact. A hotkey may be defined more than once only with different #HotIf criteria; among eligible variants the earliest in the script fires and the global variant has the lowest precedence. -->
<!-- CROSS-REF: Module_ReviewFramework.md, Module_ReviewArchitecture.md, Module_ClassBasics.md -->
<!-- VERSION: AHK v2.0+ -->

> **Convention, not a language limit.** Everything in this module except the
> hotkey-variant rules is review convention. State the concrete cost of each finding.

## AHK V2 CONSTRAINTS

- **Hotkey variants (docs):** a hotkey can be defined more than once only if each
  definition has different `#HotIf` criteria. If several variants are eligible, the
  one closest to the top of the script fires; the global variant (no criteria)
  always has the lowest precedence. Modifier order does not matter (`^!c` = `!^c`),
  but key names must match (`Esc` ≠ `Escape`), and `*F1` is separate from `F1`
  (lib/_HotIf.htm, Variants). Two definitions with the same criteria are not
  variants → **🔴 Critical** (convention severity).
- **Naming is case-insensitive:** `myDataManager` and `MyDataManager` are the same
  name, so a case style is readability only.
- **Names and side effects:** `Get*`/`Is*`/`Set*` are conventions, not contracts.
  Report a name only when it materially misleads callers (for example a getter that
  writes a file).
- **Comments** should explain intent, constraints, or trade-offs. One restating
  comment → 🟡 Minor; a stale or wrong comment → 🟠 Major; pervasive noise → one
  aggregated Major finding.
- **Over-engineering:** before recommending deletion, check whether the abstraction
  gives testability, an extension boundary, or clear ownership. A design pattern in
  a small script deserves scrutiny, not an automatic finding.
- **Documentation:** a short header comment on public functions (purpose,
  parameters, return shape, what it throws) is the repo convention; a missing
  header is 🟡 Minor.
- **Guards:** validate at the public boundary; redundant guards inside an internal
  helper are 🟡 Minor (🟠 Major when several pile up), but keep them when the helper
  is reused or failures would be hard to diagnose.

## TIER 6 — Clean Code, Over-Engineering & Composite Review
> METHODS COVERED: `#HotIf` · `WinActive()` · `OutputDebug()` · `A_Clipboard` · `Type()`

```ahk
; ================= CLEAN CODE =================
; CHECK 1: Naming (convention)
; ✗ x := 0, tmp2 := GetData()      ; 🟡 non-descriptive outside a tiny loop
retryCount := 0                    ; camelCase variables
class DataManager {                ; PascalCase classes
}
MAX_RETRY_COUNT := 100             ; UPPER_SNAKE_CASE constants

; ----------------------------------------------------------------
; CHECK 2: Comments explain why, not what
counter := 0
counter += 1        ; ✗ "add 1 to counter" restates the code
counter += 1        ; ✓ debounce: first event always accepted, later ones throttled

; ----------------------------------------------------------------
; CHECK 3: Names that hide side effects
users := Map()
; ✗ GetUser(id) { FileAppend(id "`n", "access.log"), ... }   ; read + write
GetUser(id) => users.Get(id, "")               ; ✓ pure read
LogAccess(id) => FileAppend(id "`n", "access.log")

; ----------------------------------------------------------------
; CHECK 4: Affirmative booleans (🟡 Minor)
; ✗ if !isNotReady
isReady := true
if isReady
    OutputDebug("ready")

; ----------------------------------------------------------------
; CHECK 5: Repeated magic strings → one constant
; ✗ "HKCU\Software\MyApp" written inline in 3+ places   ; 🟠 Major
APP_REGISTRY_KEY := "HKCU\Software\MyApp"
NOTEPAD_CLASS    := "ahk_class Notepad"

; ----------------------------------------------------------------
; CHECK 6: Dead code and debug output
; ✗ large commented-out blocks; MsgBox("DEBUG: ...") left in      ; 🟡 Minor
DEBUG_MODE := false
DebugLog(msg) {
    if DEBUG_MODE
        OutputDebug("[DEBUG] " msg)
}

; ----------------------------------------------------------------
; CHECK 7: Duplicate hotkeys
; ✗ Same hotkey, same (no) criteria, defined twice:
; ^F1::MsgBox("Action A")
; ^F1::MsgBox("Action B")
; ✓ One definition that dispatches ...
^F1:: {
    if WinActive(NOTEPAD_CLASS)
        OutputDebug("Notepad F1")
    else
        OutputDebug("default F1")
}
; ✓ ... or real variants with different #HotIf criteria
#HotIf WinActive("ahk_class Notepad")
^F3::OutputDebug("Notepad F3")
#HotIf
^F3::OutputDebug("global F3 — lowest precedence")

; ============= OVER-ENGINEERING =============
; CHECK 8: YAGNI — factory with one product and one caller (🟠 Major)
; ✗ content := FileReaderFactory.Create("text").Read("data.txt")
; ✓ content := FileRead("data.txt", "UTF-8")

; CHECK 9: Plugin manager / event bus for a small script (🟠 Major)
; ✗ class EventBus { static Subscribe(...) ... static Publish(...) ... }  used twice
; ✓ Direct calls, or a Map of function objects if dispatch is truly needed
OpenHandler() => OutputDebug("open")
SaveHandler() => OutputDebug("save")
handlers := Map("open", OpenHandler, "save", SaveHandler)
handlers["open"]()

; CHECK 10: Single-method class wrapping a built-in (🟠 Major)
; ✗ class ClipboardHelper { static Get() => A_Clipboard }
; ✓ use A_Clipboard directly
current := A_Clipboard

; CHECK 11: Over-defensive internal guards
; ✓ Validate at the public boundary; trust internal callers
ProcessUserCommand(rawInput) {
    if (Type(rawInput) != "String" || rawInput = "")
        throw ValueError("rawInput must be a non-empty String", -1)
    return BuildSummary(StrSplit(rawInput, " "))
}
BuildSummary(items) {           ; internal: no repeated IsObject/Type checks
    result := ""
    for item in items
        result .= item "`n"
    return result
}
```

### Classification baselines (convention)

| Signal | Baseline | Notes |
|--------|----------|-------|
| Same hotkey, same criteria, twice | 🔴 Critical | Not a valid variant |
| Getter/predicate that hides a material side effect | 🟠 Major | Rename or split |
| Abstraction with one product or one caller | 🟠 Major | Unless it buys testability or a real extension point |
| Pattern cost not justified by variants, lifetime, or expected change | 🟠 Major | Count actual uses |
| Magic string in 3+ places | 🟠 Major | 1–2 places → 🟡 Minor |
| Stale or misleading comment | 🟠 Major | Restating comment → 🟡 Minor |
| Negative boolean name, non-descriptive name, case-style mismatch | 🟡 Minor | Case style is readability only |
| Single defensive guard in an internal helper | 🟡 Minor | 3+ redundant guards → 🟠 Major |
| Single-method class that adds nothing | 🟡 Minor / 🟠 Major | Keep when it serves lifecycle or interface needs |

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| Comment restates code | `; add 1 to counter` | `; debounce: first event always accepted` | Explanatory-comment habit |
| Misleading getter | `GetUser()` also calls `FileAppend()` | Split read and log | Names not updated as behavior grows |
| Negative boolean | `isNotReady`, `!isDisabled` | `isReady`, `isEnabled` | Double negation is common in examples |
| Repeated magic string | `"HKCU\Software\MyApp"` inline 4 times | `APP_REGISTRY_KEY` constant | Magic-number rule applied, magic-string rule forgotten |
| YAGNI factory | `FileReaderFactory.Create("text").Read(path)` | `FileRead(path, "UTF-8")` | "Extensible" by default |
| Wrapper class for a built-in | `ClipboardHelper.Get()` | `A_Clipboard` | Enterprise OOP habits |
| Treating case style as a bug | `🟠 class myDataManager must be PascalCase` | `🟡` readability note at most | Case-sensitive languages |
| Calling #HotIf variants duplicates | Flag `^F3` under two different `#HotIf` blocks | Valid variants; check precedence instead | Not reading the criteria |

## SEE ALSO

- `Module_ReviewFramework.md` — report structure and Priority Action List
- `Module_ReviewArchitecture.md` — refactoring after over-engineering is removed
- `Module_ClassBasics.md` (ahk-ctx-core) — class semantics
