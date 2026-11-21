<priority_levels>
  MUST   — language or safety invariant; a violation is a blocking defect.
  SHOULD — engineering default; deviate when the task or a simpler design justifies it.
  MAY    — optional technique; use it when it improves the concrete solution.
</priority_levels>

<how_to_use>
  Every reference-type ahk-ctx-* Skill runs this flow; its SKILL.md adds only its own steps and
  conditional Reference modules.
  1. Route: pick Reference modules and headings from the Skill's routing table. Read each heading through the next
     `## ` heading, starting with `## API QUICK-REFERENCE` and `## AHK V2 CONSTRAINTS`; read a
     `## TIER` section when the task needs a runnable example.
  2. Load in order: this file (full); `Module_CodeStyle.md` (full) when writing or editing AHK; the
     routed sections of the Skill's own Reference modules; each cross-Skill Reference module the Skill lists, when its
     condition is present.
  3. Apply the rules below plus the Skill's critical rules. MUST rules block output; rules marked
     "repository convention" are repo style, not language limits.
  4. Write code at the lowest TIER that covers the task.
  5. Before output, run `<diagnostic_checklist>` and the Skill's self-check.
</how_to_use>

<ahk_syntax_standards>
  <required_headers>
    Entry-point scripts start with `#Requires AutoHotkey v2.0`, plus `#SingleInstance Force` when
    one active instance is intended. Library and class-only files leave startup directives to the
    entry point. `#Include` names only concrete dependencies.
  </required_headers>

  <core_rules>
    - **MUST:** Write AHK v2 expression syntax throughout: `:=` assignment, function-call commands,
      text built by concatenation (`"Hi " name`), and VarRef `&outVar` for output parameters.
    - **MUST:** ASCII identifiers are case-insensitive: `count` and `Count` in one scope are one
      variable, so a later assignment overwrites and a parameter shadows. Give every variable,
      function, class, property, and method its own word with one spelling. Prefer ASCII (an
      uppercase non-ASCII letter such as `Ä` differs from its lowercase form).
    - **MUST:** String contents and Map keys are data, not identifiers. Map string keys are
      case-sensitive by default (`CaseSense` changes this); `=` compares strings case-insensitively
      and `==` case-sensitively.
    - **MUST:** Instantiate as `myBox := Box()`; AHK v2 has no `new`. A class name is a read-only
      variable holding the class, so the instance takes another name.
    - **MUST:** A built-in function name (`max`, `round`, `sort`, `format`, `msgBox`) is a read-only
      global. Name variables, parameters, and functions descriptively (`maxValue`, `sortedItems`)
      so the built-in stays callable in every scope.
    - **MUST:** Escape with backtick: `` `n ``, `` `t ``, `` `" `` (or use the opposite quote type; a doubled `""` inside a string is an error). Backslash is a
      literal, so Windows paths keep single backslashes.
    - **MUST:** Declare `global` where a function assigns a global (or uses `&` on it) and `static` where it needs a persistent variable; a global that is only read needs no declaration.
    - **SHOULD:** Use classes for GUI, stateful automation, reusable logic, and lifecycle-driven
      workflows; keep small hotkey or one-off utility scripts as standalone functions.
  </core_rules>

  <data_structures>
    - Map() holds dynamic runtime key-value data: `Map("k1", v1)` or `map["k"] := v`. Plain Objects
      lack Has/Get/Delete/Count/__Enum (repository convention backed by API differences).
    - Object literals `{}` hold API descriptors, condition objects, and static configuration.
    - Arrays hold sequential data, indexed from 1.
  </data_structures>

  <purity_enforcement>
    - Callbacks (repository convention): a single-expression callback may be an arrow,
      `.OnEvent("Click", (*) => this.Method())`; a multi-statement callback is a named method (in
      v2.0 `=>` takes one expression). Bind with `.Bind(this)` or `ObjBindMethod()` when the
      receiving API would otherwise lose the receiver.
    - Use AHK v2's own API and operators. `const`, `let`, `===`, template literals,
      `addEventListener`, and `map.Keys()` do not exist; iterate a Map with `for key, value in map`.
  </purity_enforcement>

  <error_handling_rules>
    Repository conventions: throw `ValueError` or `TypeError` for parameter and type validation;
    a `catch` block recovers, logs, or rethrows, unless it is intentionally empty (see
    `Module_ExceptionHandling.md` (ahk-ctx-logic)); log diagnostics with OutputDebug and reserve
    MsgBox for intentional user-facing prompts.
  </error_handling_rules>

  <common_traps_and_gotchas>
    - Stored-callable `this` injection: `obj.prop(args)` calls a stored function as a method and
      passes `obj` as the first argument. Call `fn := obj.prop, fn(args)` or `obj.prop.Call(args)`.
    - `<`, `>`, `<=`, `>=` throw TypeError on non-numeric strings; compare them with StrCompare().
  </common_traps_and_gotchas>
</ahk_syntax_standards>

<diagnostic_checklist>
  Before output, check the code against every rule above, then confirm:
  - Every method named in a call, `this.Method`, or callback is defined on that class.
  - Owned resources are released through `__Delete()`, `finally`, or the API's cleanup path.
  - Before an `.ahk` edit, `ahk-ctx-agent-protocol` is loaded and its safe-edit path is followed.
</diagnostic_checklist>
