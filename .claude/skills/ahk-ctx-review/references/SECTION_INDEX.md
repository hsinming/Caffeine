# ahk-ctx-review Section Index

Per-heading detail for the router in `SKILL.md`. Find the row for the task, open the Reference module, and `grep -n "^## heading"` (or `^### heading`) to jump to the section. Read through the next heading of the same level.

| Task | Module | Heading |
|------|--------|---------|
| Severity classification table | `Module_ReviewFramework.md` | `### Severity Classification` |
| Six-dimension overview and module map | `Module_ReviewFramework.md` | `### Six Review Dimensions` |
| Review order, triage, fragment rules | `Module_ReviewFramework.md` | `## AHK V2 CONSTRAINTS` |
| Pre-review declaration | `Module_ReviewFramework.md` | `## PRE-REVIEW DECLARATION` |
| Report output template | `Module_ReviewFramework.md` | `## REPORT OUTPUT FORMAT` |
| Finding wording and aggregation | `Module_ReviewFramework.md` | `## FINDING WORDING RULES` |
| Priority Action List rules | `Module_ReviewFramework.md` | `## PRIORITY ACTION LIST` |
| Review depth vs script size | `Module_ReviewFramework.md` | `## REVIEW DEPTH` |
| QA checklist before submitting | `Module_ReviewFramework.md` | `## AGENT QA CHECKLIST` |
| v1 → v2 breaking changes | `Module_ReviewV2Syntax.md` | `## V1 → V2 BREAKING CHANGES` |
| **Dimension 1** — Modern Syntax & v2 Compliance | `Module_ReviewV2Syntax.md` | `## TIER 1 — Modern Syntax & v2 Compliance` |
| Which operations throw (vs return a value) | `Module_ReviewErrorHandling.md` | `### Throwing Operations Reference` |
| **Dimension 2** — Error Handling & Type Safety | `Module_ReviewErrorHandling.md` | `## TIER 2 — Error Handling & Type Safety` |
| Exception → probable cause | `Module_ReviewErrorHandling.md` | `## RUNTIME ERROR MAPPING` |
| OnError bootstrap and safe wrappers | `Module_ReviewErrorHandling.md` | `## DROP-IN RECIPES` |
| **Dimension 3** — Variable Scope, Architecture & SE Design | `Module_ReviewArchitecture.md` | `## TIER 3 — Variable Scope, Architecture & SE Design Principles` |
| Parameter/nesting/length heuristics | `Module_ReviewArchitecture.md` | `### Heuristic thresholds (convention)` |
| **Dimension 4** — GUI & Event Binding | `Module_ReviewGuiEvents.md` | `## TIER 4 — GUI & Event Binding` |
| Class-based GUI controller template | `Module_ReviewGuiEvents.md` | `## DROP-IN RECIPES` |
| **Dimension 5** — Performance, Security & Resource Management | `Module_ReviewPerformanceSecurity.md` | `## TIER 5 — Performance, Security & Resource Management` |
| **Dimension 6** — Clean Code, Over-Engineering & Composite | `Module_ReviewCleanCode.md` | `## TIER 6 — Clean Code, Over-Engineering & Composite Review` |
| Clean-code / OE severity baselines | `Module_ReviewCleanCode.md` | `### Classification baselines (convention)` |
| Anti-patterns per dimension | each module | `## ANTI-PATTERNS` |
