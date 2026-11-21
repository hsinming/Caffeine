# Module_ReviewFramework.md
<!-- DOMAIN: Code Review — workflow, severity, and report format -->
<!-- SCOPE: Review process only: severity levels, the six review dimensions and their order, the pre-review declaration, finding wording, the report template, the Priority Action List, and review-depth rules. Per-dimension checklists live in Module_ReviewV2Syntax.md, Module_ReviewErrorHandling.md, Module_ReviewArchitecture.md, Module_ReviewGuiEvents.md, Module_ReviewPerformanceSecurity.md, and Module_ReviewCleanCode.md. AHK v2 language facts live in ahk-ctx-core and the domain Skills. -->
<!-- TRIGGERS: review, audit, "code review", "check my script", "quality check", "review report", "severity", "Critical vs Major", "priority action list", "how to write a finding", "fragment review", "review a long script" -->
<!-- CONSTRAINTS: Everything in this module is repo review convention, not an AutoHotkey language rule. Every dimension appears in the report, with an explicit pass line when it has no findings. Critical findings state a line number, a concrete consequence, and a fix. Severity follows concrete impact; style preferences are not correctness findings. -->
<!-- CROSS-REF: Module_ReviewV2Syntax.md, Module_ReviewErrorHandling.md, Module_ReviewArchitecture.md, Module_ReviewGuiEvents.md, Module_ReviewPerformanceSecurity.md, Module_ReviewCleanCode.md -->
<!-- VERSION: AHK v2.0+ -->

> **Convention, not a language limit.** The six dimensions, their order, the
> severity scale, the report layout, and all numeric thresholds in this Skill are
> this repo's review convention. Language facts (what throws, what is a syntax
> error) are cited to the official v2 docs in the per-dimension modules.

## API QUICK-REFERENCE

### Severity Classification

| Severity | Symbol | Meaning |
|----------|--------|---------|
| Critical | 🔴 | Load-time error, crash, silent data loss, wrong behavior at runtime, or a security hole |
| Major | 🟠 | Concrete maintenance or reliability risk that should be fixed in this review cycle |
| Minor | 🟡 | Readability or low-risk style concern with no correctness impact |
| Pass | ✅ | No issues found in this dimension — always write this explicitly |

### Six Review Dimensions

| # | Dimension | Primary focus | Checklist module |
|---|-----------|---------------|------------------|
| 1 | Modern Syntax & v2 Compliance | `=` vs `:=`, `#Requires`, quoting, `%Expr%`, hotkey bodies, v1 command syntax | `Module_ReviewV2Syntax.md` |
| 2 | Error Handling & Type Safety | try/catch on operations that throw, catch bodies that do not hide failures, type guards | `Module_ReviewErrorHandling.md` |
| 3 | Variable Scope, Architecture & SE Design | globals, data structures, responsibilities, parameter shape, nesting | `Module_ReviewArchitecture.md` |
| 4 | GUI & Event Binding | callback receivers, `OnEvent()`, fat-arrow callbacks, `SetTimer`, GUI lifetime | `Module_ReviewGuiEvents.md` |
| 5 | Performance, Security & Resource Management | loop invariants, COM lifetime, CoordMode scope, untrusted input in DllCall/RegWrite/RegEx | `Module_ReviewPerformanceSecurity.md` |
| 6 | Clean Code, Over-Engineering & Composite | comments, naming, magic values, YAGNI, over-defensive guards, duplicate hotkeys, dead code | `Module_ReviewCleanCode.md` |

Dimension 4 is `✅ Not applicable (no GUI)` when no `Gui()`, `OnEvent()`, or `SetTimer()` is present.

## AHK V2 CONSTRAINTS

These are review-process rules (convention), not language rules.

- Evaluate dimensions in order 1 → 6. A syntax error found in Dimension 1 can make
  Dimension 2–5 observations invalid; say so in the report.
- Every dimension appears in the report. Silence makes the reader assume the
  dimension was not evaluated.
  - ✗ (Dimension 4 section absent)
  - ✓ `✅ Not applicable — no GUI or SetTimer present in this script.`
- Review only what is present. Never flag absent features that were not requested.
- For a fragment, say "Fragment" in the declaration; apply Dimension 1 to all
  visible code and Dimensions 2–6 only to constructs in the fragment.
- Run the Dimension 6 over-engineering checks before writing Dimension 3
  refactoring advice when the script shows a single-use class or factory, a
  neutral-verb name on a mutating function, or a pattern whose cost is not
  justified. If Dimension 6 flags a class as YAGNI, do not also produce
  Dimension 3 refactoring advice for it.
- Each finding has one owning dimension: assign it to the most specific one and do
  not repeat it under others.

Triage order when time is short:
1. Dimension 1 — syntax errors invalidate everything else
2. Dimension 2 — correctness before architecture
3. Dimension 4 — callback receiver and runtime context
4. Dimension 6 over-engineering — may remove code that Dimension 3 would otherwise refactor
5. Dimensions 3 and 5

## PRE-REVIEW DECLARATION

Write this block before analysing any line. Omitting it is 🟠 Major (convention):
the reader cannot interpret severities without it.

```
Review scope:    [Complete script | Fragment — Dim 2–6 limited to visible constructs]
AHK version:     [v2.0 confirmed via #Requires | v2.0 assumed — no directive found]
Script length:   [< 50 lines | 50–200 lines | 200–500 lines | 500+ lines]
Declared intent: [stated goal] | [Not declared — reviewing for general quality only]
```

If a declaration is uncertain, make the most conservative assumption and note it.

## REPORT OUTPUT FORMAT

```
AHK v2 Code Review Report
[Pre-review declaration block]

Dimension 1 — Modern Syntax & v2 Compliance
- 🔴 / 🟠 / 🟡 Line N — [concrete consequence]. Fix: [inline code, ≤ 5 lines]
  OR ✅ No issues found.

Dimension 2 — Error Handling & Type Safety
...
Dimension 3 — Variable Scope, Architecture & SE Design Principles
...
Dimension 4 — GUI & Event Binding
✅ Not applicable (no GUI constructs present).
Dimension 5 — Performance, Security & Resource Management
...
Dimension 6 — Clean Code, Over-Engineering & Composite
...

Summary
2–3 sentences of overall quality assessment.

Priority Action List
1. [Top Critical finding] — one-line rationale. (🔴 Critical)
2. ...up to 5 items, ordered by severity then impact
```

## FINDING WORDING RULES

**Critical findings must** name the line, state the concrete consequence, and give
a fix (inline code if ≤ 5 lines). They must not use "might", "could", "consider",
or "perhaps".

```
✓  🔴 Line 7 — `counter = 0` is a comparison, not an assignment; as a standalone
      line it is invalid v2 syntax. Fix: `counter := 0`
✗  🔴 Line 7 — counter might not be assigned correctly. Consider using :=.
```

**Major findings must** state what the problem costs and the recommended action.

```
✓  🟠 Line 23 — GetUser() also appends to access.log, so callers that only read
      also write. Move the FileAppend into LogAccess() and call it explicitly.
✗  🟠 Line 23 — GetUser() is not that clean.
```

**Minor findings** may be brief but must name the line and pattern:
`🟡 Line 45 — isNotReady is a negative name; rename to isReady`.

**Aggregation:** when the same pattern appears in 5+ places, report one finding with
representative line numbers instead of one per occurrence.

## PRIORITY ACTION LIST

- At most 5 items.
- Order: Critical first, then Major by impact. No Minor items unless no Critical or
  Major findings remain.
- A class flagged YAGNI in Dimension 6 appears once ("delete class X"), without
  separate Dimension 3 refactoring items.

```
Priority Action List
1. Replace `=` with `:=` on lines 3, 7, 12 — `=` compares; nothing is assigned. (🔴 Critical)
2. Wrap FileRead() on line 24 in try/catch — a missing file throws OSError and ends the thread. (🔴 Critical)
3. Move FileRead() on line 24 above the Loop — it re-reads the same file 100 times per press. (🟠 Major)
4. Give the ^F1 hotkey a braced body — v1 label-and-return bodies are not v2 syntax. (🔴 Critical)
5. Move the `counter` global into a class static property. (🟠 Major)
```

## REVIEW DEPTH

- **Script size:** under 50 lines, run the full six-dimension pass. Over 200 lines,
  triage Critical and Major first. Over 500 lines, check every hotkey definition
  and loop body, focus Dimension 3 on decomposition and global count, and suggest
  splitting into files when the function count is high. (Convention.)
- **Comment noise:** more than 5 comment-restates-code cases → one Major finding
  with representative lines, not 20 Minor findings.
- **Over-engineering first:** YAGNI findings in Dimension 6 shrink the Dimension 3
  scope; do not refactor code that should be deleted.

## AGENT QA CHECKLIST

- [ ] Did I write the pre-review declaration first?
- [ ] Did I evaluate all 6 dimensions in order and include each in the report?
- [ ] Did I avoid flagging non-throwing calls (`ToolTip`, `Sleep`, `Send`, `OutputDebug`, `WinActive`, ordinary `MsgBox`) as needing try/catch?
- [ ] Did I rate every `=` used for assignment as Critical, with line number and `:=` fix?
- [ ] Did I flag every empty `catch` that hides a failure, with a fix that surfaces `e.Message`?
- [ ] Are naming and design findings based on concrete impact, not on prefix or line-count rules alone?

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| Fabricated throwing operation | `🔴 MsgBox can throw — wrap in try/catch` | No finding; ordinary MsgBox calls need no try/catch | "Wrap everything" habits from other languages |
| Omitted pass line | Dimension section missing | `✅ No issues found.` or `✅ Not applicable (no GUI present).` | Generators skip sections with nothing to say |
| Flagging absent features | `🟠 Missing .Destroy() call` in a script with no GUI | `✅ Not applicable — no GUI present` | Matching a checklist without checking the code |
| Vague Critical wording | `🔴 counter might not be assigned` | `🔴 Line 7 — counter = 0 compares; nothing is assigned. Fix: counter := 0` | Hedging instead of stating the consequence |
| Double-counting | Same line reported in Dims 3, 5, and 6 | One finding in the most specific dimension | No line-ownership rule |

## SEE ALSO

- `Module_ReviewV2Syntax.md` — Dimension 1 checklist
- `Module_ReviewErrorHandling.md` — Dimension 2 checklist and throwing-operations table
- `Module_ReviewArchitecture.md` — Dimension 3 checklist
- `Module_ReviewGuiEvents.md` — Dimension 4 checklist
- `Module_ReviewPerformanceSecurity.md` — Dimension 5 checklist
- `Module_ReviewCleanCode.md` — Dimension 6 checklist
