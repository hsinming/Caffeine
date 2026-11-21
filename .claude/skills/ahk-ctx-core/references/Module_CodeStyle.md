# AHK File Formatting Specification

## Overview

Formatting rules for this repository's AHK v2 files: 4 spaces per indentation
level, no tabs, CRLF line endings. The sections below cover indentation, line
endings, comments, delimiter balancing, structural layout, and name case.

Except where a rule is marked as an AHK language rule (comment syntax, `/* */`
placement, no space before `(` in calls, case-insensitive names), everything here is a repository
convention, not a language limit: AHK v2 accepts tabs, LF line endings and
other brace styles.

## 1. Indentation

### Criteria

- **Standard**: Use 4 spaces per indentation level, in multiples of 4. Tabs are
  not allowed in this repository's AHK files. Continuation lines may be
  indented for readability but must still use spaces only.

### Common Issues and Resolution

- **Wrong indentation (tabs or off-multiple spacing)**: Normalize to 4 spaces per level.
- **Auto-fix**: Only normalize leading whitespace. Do not rewrite strings, comments, or continuation sections with broad regex rules.

## 2. Line Endings

### Criteria

- **Consistency**: All lines in a file must use the same line ending type.
- **Standard**: Use CRLF for this repository's AHK files, as AHK primarily runs on Windows.

### Common Issues and Resolution

- **Mixed or LF-only endings**: Convert to CRLF using text editor tools.
- **Auto-fix**: Use `unix2dos` or editor end-of-line settings to convert LF to CRLF. `dos2unix` performs the opposite conversion.

## 3. Comment Formatting

### Single-Line Comments

- **Syntax**: Use `;` for single-line comments.
- **Placement**: Comments can start at the beginning of a line or after code. An inline `;` must have at least one space or tab to its left (AHK language rule).
- **Spacing**: One space after `;` is recommended for readability.
- **Examples**:
```ahk
; This is a comment
MsgBox("Hello") ; This is an inline comment
```

### Multi-Line Comments

* **Syntax**: Use `/* */` for multi-line comments.
* **Formatting** (AHK language rules):
  * `/*` must appear at the start of the line (excluding leading whitespace).
  * `*/` can appear only at the start or end of a line. If `*/` is omitted, the rest of the file is commented out.
  * Indenting comment content to match surrounding code is recommended for readability, but is not enforced by the language.
* **Examples**:
```ahk
functionName(param) {
    /* Multi-line
       comment */
}
```

### Common Issues and Resolution

* **Missing space before inline `;`**: Add one space before `;`.
* **`/*` not at line start**: Move `/*` to the beginning of the line.
* **`*/` in the middle of a line**: Move `*/` to either the start or end of the line.
* **Unbalanced multi-line**: Fix by adding missing `*/` or `/*`.
* **Auto-fix**: Only insert missing comment spacing when the `;` token is outside strings and continuation sections. Do not attempt to balance block comments with regex alone.

## 4. Balanced Delimiters

* **Braces `{}`**: Must be balanced. Each opening `{` must have a corresponding closing `}`.
* **Parentheses `()`**: Balanced pairs required.
* **Brackets `[]`**: Balanced for Array literals, indexing, and property access.
* **Interpreter validation is authoritative**: a naive scan for matching delimiters can be fooled by strings, comments, escaped quotes, and continuation sections — verify changed `.ahk` files with `AutoHotkey.exe /ErrorStdOut` when a Windows AHK v2 runtime is available.

### Common Issues and Resolution

* **Unmatched brace**: Add missing `}` or `{`.
* **Extra parenthesis**: Remove or add to balance.
* **Auto-fix**: Use an AHK-aware parser or the AHK v2 interpreter to identify and suggest fixes. Do not auto-insert delimiters from a regex-only check.

## 5. Structural Elements

### Function Definitions

* **Syntax**: `functionName(parameters) {` — no space between the name and `(` (AHK language rule).
* **Formatting**:
  * Function name in camelCase or PascalCase (recommended convention).
  * Parameters separated by commas, spaces after commas.
  * Opening brace on same line as function header (OTB style — convention; AHK also accepts the brace on the next line).
  * Body indented by 4 spaces.
  * Closing brace on new line, aligned with function start.
* **Examples**:
```ahk
myFunction(param1, param2) {
    ; body
}
```

### Class Declarations

* **Syntax**: `class ClassName {`
* **Formatting**:
  * Class name in PascalCase (recommended convention).
  * Opening brace on same line.
  * Methods indented inside class.
  * Properties and methods follow function formatting.
* **Examples**:
```ahk
class MyClass {
    __New() {
        ; constructor
    }

    methodName() {
        ; method
    }
}
```

### Common Issues and Resolution

* **Misaligned braces**: Align closing brace with class/function start.

## 6. Name Case

Identifiers are case-insensitive: `_Tick` and `_tick` are one name. This is an AHK
language rule, and the interpreter reports no load error when code treats two such
names as different.

* **Spell each name once.** Give two names a different spelling, never a different
  capitalization: a method `_Tick` and a field for the timer callback become `_Tick`
  and `_timerFn`.
* **Do not reuse a function or class name as a variable.** `map := Map()` makes
  `Map()` call the empty local `map`; use `items := Map()`.
* **Verify after every write or edit.** Run `ahk-ctx-script-debugging`
  `scripts/Test-AhkNameCase.ps1` on the file and fix every error it reports
  (`class-member-collision`, `shadowed-name`); a warning means one name is spelled two
  ways, so make the spelling consistent.

### Common Issues and Resolution

* **`Property is read-only` at run time with a clean `/Validate`**: a method or property
  and `this.X :=` differ only by case. Rename one of them.
