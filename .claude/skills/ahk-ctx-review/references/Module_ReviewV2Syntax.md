# Module_ReviewV2Syntax.md
<!-- DOMAIN: Code Review — Dimension 1: Modern Syntax & v2 Compliance -->
<!-- SCOPE: Review checklist for v1 residue and v2 syntax mistakes: `=` vs `:=`, `#Requires`, quoted strings, `%Expr%` double-deref, braced hotkey bodies, v1 command syntax, g-labels, SetTimer labels, fat-arrow bodies. The full v2 syntax baseline is in Module_Instructions.md (ahk-ctx-core); error handling is in Module_ReviewErrorHandling.md. -->
<!-- TRIGGERS: "is this v2 compliant", "check syntax", "v1 to v2", "old script", "variable stays empty", "hotkey doesn't fire", `=` vs `:=`, #Requires, %Var%, "MsgBox, ", "SetTimer, ", g-label, "return at end of hotkey", "=> {" -->
<!-- CONSTRAINTS: `=` is a case-insensitive comparison in v2; it never assigns. There is no comma between a function name and its parameters: a comma written directly after the name is a load-time error, and a space before the comma marks an omitted first parameter. `%Expr%` is valid v2 double-deref, not string interpolation. Multi-line hotkey bodies need braces. A fat-arrow function evaluates one expression. Severity choices in this module are repo convention. -->
<!-- CROSS-REF: Module_ReviewFramework.md, Module_ReviewErrorHandling.md, Module_ReviewGuiEvents.md, Module_Instructions.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern | v2 form | Consequence in v2 (docs) |
|------------|---------|--------------------------|
| `counter = 0` as assignment | `counter := 0` | `=` is comparison. A line containing only `counter = 0` is not one of the expression-statement forms v2 accepts (Language.htm, Expression Statements). Inside a larger expression (`if x = 0`, `y := x = 0`, `Fn(x = 0)`) it silently compares and nothing is assigned. |
| `global counter = 0` | `global counter := 0` | A declaration initializer must use an assignment operator (Functions.htm); `=` is not one. |
| `^F1::` + lines + `return` | `^F1:: {` ... `}` or `^F1::Action()` | Hotkeys are functions in v2; a multi-line body is enclosed in braces instead of ending with `return` (v2-changes.htm, Hotkey and Hotstring Labels). |
| `MsgBox, Title, Text` | `MsgBox("Text", "Title")` | Command syntax was removed: there is no comma between the function name and its parameters (v2-changes.htm). A comma directly after the name is a load-time error. With a space before it (`MsgBox , Title, Text`) the first parameter is omitted (`WinMove , y` = `WinMove(, y)`), so `Title` and `Text` become unquoted variable references in the wrong parameter slots. |
| `SetTimer, FuncLabel, 1000` | `SetTimer(FuncRef, 1000)` | SetTimer no longer accepts label or function names; pass a function object. `SetTimer, ...` is a load-time error (comma directly after the name); with a space before the comma the Function parameter is omitted. |
| `MyGui.Add("Button", "gMyAction")` | `btn.OnEvent("Click", handler)` | g-labels were removed; register each event with `OnEvent()`. |
| `(*) => { stmt1`↵`stmt2 }` | Named function, or `(*) => (DoA(), DoB())` | A fat-arrow function evaluates one sub-expression (Variables.htm, Fat arrow). The comma operator can sequence several expressions inside one. |
| `%var%` for interpolation | `"text " var` or `Format()` | `%Expr%` is valid v2 double-deref (looks up the variable named by Expr). It is not string interpolation. |

## AHK V2 CONSTRAINTS

- `=` used where assignment was intended is **🔴 Critical** (convention severity).
  As a standalone line it is invalid syntax; inside an expression it compares and
  the intended variable is never set, so a later read can throw `UnsetError`
  (Error.htm) or use a stale value.
  - ✗ `if (count = 0) total = 0` — the body `total = 0` is a standalone `=` line, a load-time error
  - ✓ `if (count = 0)` → `total := 0`
- Missing `#Requires AutoHotkey v2.0` is **🟠 Major** (convention). The directive
  shows an error and quits when the running version does not meet the requirement,
  and lets the launcher pick the right interpreter (lib/_Requires.htm).
- Unquoted text is a variable reference in v2. `MsgBox Hello World` is a valid
  call statement that concatenates the variables `Hello` and `World`.
- `%Expr%` is legitimate only when dynamic variable lookup is intended. Prefer a
  `Map` for data keyed by runtime strings (convention, not a language limit).
- A multi-statement `=> { ... }` body is **🔴 Critical**: the braces are not a
  function body.

## TIER 1 — Modern Syntax & v2 Compliance
> METHODS COVERED: `#Requires` · `:=` · `MsgBox()` · hotkey bodies · `%Expr%` · `SetTimer()` · fat arrow

Dimension 1 checks whether the script is v2 syntax and free of v1 habits. Run it
first: a load-time error invalidates every other dimension.

```ahk
; CHECK 1: #Requires directive
; ✗ (no directive at the top of the file) — launcher may pick the wrong interpreter
; ✓
#Requires AutoHotkey v2.0

; ----------------------------------------------------------------
; CHECK 2: Assignment operator
; ✗ v1 habit — written as a comment because the standalone line is invalid in v2:
; counter = 0
; ✗ A one-line body 'limit = 10' is still a standalone = line (load-time error):
; if (mode = "fast") limit = 10
; ✗ Inside an expression, = compares and assigns nothing:
; ready := (mode = "fast")             ; ready is 1 or 0, not a copy of mode
; ✓
counter := 0
counter := counter + 1

; ----------------------------------------------------------------
; CHECK 3: Text must be quoted
; ✗ MsgBox Hello World   ; concatenates two (unset) variables, not text
; ✓
MsgBox("Hello World")

; ----------------------------------------------------------------
; CHECK 4: %Expr% is double-deref, not interpolation
; ✗ Using double-deref where a plain variable or Map is meant:
; name := "port", value := %name%      ; reads the variable named "port"
; ✓ Data keyed by runtime strings → Map (convention)
lookup := Map("host", "localhost", "port", 5432)
result := lookup["port"]

; ----------------------------------------------------------------
; CHECK 5: Hotkey bodies
; ✗ v1 label form:
; ^F1::
;     DoSomething()
; return
; ✓ One line to the right of ::, or a braced body
^F1::DoSomething()
^F2:: {
    DoSomething()
    DoOther()
}

; ----------------------------------------------------------------
; CHECK 6: No comma after a function name
; ✗ MsgBox, Title, Text    ; load-time error: comma directly after the name
; ✗ MsgBox , Title, Text   ; loads; first parameter omitted, Title and Text are variables
; ✓
MsgBox("Text", "Title")

DoSomething() {
}
DoOther() {
}
```

## RUNTIME ERROR MAPPING

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Script fails to load on a `x = 1` line | `=` used as a standalone assignment | `x := 1` |
| `UnsetError` reading a variable "that was set" | Earlier `=` compared instead of assigning | Replace the intended assignment with `:=` |
| Hotkey body not executed as expected / load error near `return` | v1 label-and-return hotkey body | Braced body `^F1:: { ... }` |
| Load error "Function calls require a space or "("", or MsgBox shows wrong text / an unset-variable error | v1 command syntax: `MsgBox, a, b` fails to load; `MsgBox , a, b` loads and omits the first parameter | `MsgBox("b", "a")` |

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| `=` treated as a style nit | `🟡 Use := for clarity` | `🔴 = compares; nothing is assigned` | Languages where `=` assigns; v1 legacy assignment |
| Calling `%Var%` removed | "`%x%` is invalid in v2" | `%Expr%` is valid double-deref; flag it only when interpolation was intended | v1 `%var%` in command parameters |
| Block-bodied fat arrow | `(*) => { DoA()`↵`DoB() }` | Named function, or `(*) => (DoA(), DoB())` | JavaScript arrow functions allow block bodies |

## SEE ALSO

- `Module_ReviewFramework.md` — severity scale and report format
- `Module_ReviewGuiEvents.md` — g-label replacement and callback binding
- `Module_Instructions.md` (ahk-ctx-core) — full v2 syntax baseline
