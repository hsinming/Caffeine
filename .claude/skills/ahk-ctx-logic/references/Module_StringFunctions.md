# Module_StringFunctions.md
<!-- DOMAIN: Strings — built-in string functions, quoting, backtick escape sequences, concatenation and joining, Format(), case conversion, comparison, splitting and searching -->
<!-- SCOPE: Regular expressions (RegExMatch, RegExReplace, options, match objects) are in Module_RegEx.md. File encoding and reading files are in Module_FileIO.md. GUI control text is in Module_GuiBasics.md. Hotstring definitions are in Module_HotkeysAndHotstrings.md. -->
<!-- TRIGGERS: StrLen, SubStr, InStr, StrReplace, StrSplit, StrCompare, StrUpper, StrLower, StrTitle, Trim, LTrim, RTrim, Format, String(), "string", "text", "escape", "backtick", "newline", "tab", "quote", "join array", "replace text", "split string", "substring", "concatenate", "continuation section", "case-insensitive compare", "pad number" -->
<!-- CONSTRAINTS: The escape character is backtick (`) — backslash has no special meaning, so "\n" is two characters; single and double quotes behave the same; strings are immutable — StrReplace/Trim/StrUpper return a new string; there is no Array.Join() method; strings have no Length property in v2.0 — use StrLen(); Trim's default OmitChars is space and tab; positions are 1-based and negative positions count from the end. -->
<!-- CROSS-REF: Module_RegEx.md, Module_FileIO.md, Module_GuiBasics.md, Module_HotkeysAndHotstrings.md, Module_ArrayBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `"\n"` or `"\t"` | `` "`n" `` or `` "`t" `` | Backslash is a normal character; `"\n"` is the two characters `\` and `n` (true in v1 too) |
| `StringReplace, out, str, old, new` | `out := StrReplace(str, old, new)` | v1 string commands were removed |
| `StringLower, out, in` / `StringUpper, out, in` | `StrLower(in)` / `StrUpper(in)` | v1 commands removed |
| `IfInString, var, needle` | `if InStr(var, needle)` | Legacy `If` commands removed |
| `StringTrimLeft, out, in, n` | `SubStr(in, n + 1)` | `LTrim()` removes characters, not a count |
| `StringLen, out, str` | `StrLen(str)` | Strings have no `Length` property in v2.0 |
| `StringSplit, arr, str, ","` | `arr := StrSplit(str, ",")` | Returns an Array |
| `"Value: %Var%"` | `"Value: " Var` or `Format("Value: {1}", Var)` | `%` inside quotes is literal |

## API QUICK-REFERENCE

### String Functions

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `StrLen()` | `StrLen(String)` | Integer | Number of characters |
| `SubStr()` | `SubStr(String, StartingPos, Length?)` | String | 1-based. `-1` = last char. Negative `Length` omits that many chars from the end |
| `InStr()` | `InStr(Haystack, Needle, CaseSense?, StartingPos?, Occurrence?)` | Integer (0 = not found) | Negative `StartingPos` searches right to left when `Occurrence` is omitted; negative `Occurrence` always searches right to left |
| `StrReplace()` | `StrReplace(Haystack, Needle, ReplaceText?, CaseSense?, &OutputVarCount?, Limit?)` | String | `ReplaceText` omitted = delete `Needle` |
| `StrSplit()` | `StrSplit(String, Delimiters?, OmitChars?, MaxParts?)` | Array | `Delimiters` may be a string or an Array of strings; blank = one element per character. `OmitChars` trims each element |
| `StrCompare()` | `StrCompare(String1, String2, CaseSense?)` | Integer (<0, 0, >0) | `CaseSense`: `Off`/0 (default), `On`/1, `"Locale"`, `"Logical"` (digits compared as numbers: `"A2"` < `"A10"`) |
| `StrUpper()` / `StrLower()` / `StrTitle()` | `StrUpper(String)` | String | Return a converted copy |
| `Trim()` / `LTrim()` / `RTrim()` | `Trim(String, OmitChars?)` | String | Default `OmitChars` is space and tab. Numbers are not supported as `String` |
| `Format()` | `Format(FormatStr, Values*)` | String | `{1}` positional, `{}` next value, `{1:05d}` zero pad, `{1:.2f}` 2 decimals, `{1:U}`/`{1:L}`/`{1:T}` case |
| `String()` | `String(Value)` | String | Numbers use default formatting; objects call `Value.ToString()` — `MethodError` if not defined (not built in) |
| `Ord()` / `Chr()` | `Ord(String)` / `Chr(Number)` | Integer / String | Code point of first char / char from code point |
| `IsDigit()`, `IsXDigit()`, `IsAlpha()`, `IsAlnum()`, `IsSpace()`, `IsUpper()`, `IsLower()` | `IsAlpha(Value, Mode?)` | Boolean | String-pattern checks; docs: `Value` must be a string, otherwise `TypeError`, and a pure number such as `5` counts as a non-string. `Mode` `"Locale"` only for `IsAlpha`, `IsAlnum`, `IsUpper`, `IsLower` |

### Escape Sequences

Source: `misc/EscapeChar.htm`.

| Sequence | Result | Sequence | Result |
|----------|--------|----------|--------|
| ` `` ` | literal backtick | `` `n `` | linefeed (LF) |
| `` `" `` / `` `' `` | literal quote | `` `r `` | carriage return (CR) |
| `` `; `` | literal `;` (needed only after a space/tab) | `` `t `` | tab |
| `` `: `` | literal `:` (only in a hotstring abbreviation) | `` `s `` | space |
| `` `{ `` | `{` (only when remapping a key to `{`) | `` `b `` | backspace |
| `` `a `` | bell (7) | `` `v `` / `` `f `` | vertical tab (11) / form feed (12) |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Backtick is the only escape character: newlines and tabs are `` `n `` / `` `t ``. Backslash is literal, including inside regex patterns (where PCRE then reads it — see Module_RegEx.md). The `"\n"` wrong form is in V1 → V2 BREAKING CHANGES.
  ✗ `"C:\\Temp"` → ✓ `"C:\Temp"`
- Single and double quotes work the same. Use the other quote type to avoid escaping: `'He said "Hi"'`.
- Concatenate with a space (auto-concat) or `.`. The space before a variable or dot is mandatory: `"a" b` and `"a" . b`.
- Strings are immutable values. `StrReplace`, `Trim`, `StrUpper`, `SubStr` and others return a new string; assign the result.
  ✗ `StrReplace(s, a, b)` → ✓ `s := StrReplace(s, a, b)`
- Strings have no `Length` property and Arrays have no `Join()` method in v2.0. Use `StrLen()` and a loop (or the `JoinArray` recipe). No v1 string commands remain; their v2 forms, and `StrLen` for `str.Length`, are in V1 → V2 BREAKING CHANGES.
  ✗ `arr.Join(", ")` → ✓ loop or `JoinArray`
  ✗ `LTrim(s, 3)` to drop a count of characters → ✓ `SubStr(s, 4)`
- `InStr()` returns a position (1-based) or 0. Using it directly in `if` is valid because 0 is false.
- `StrCompare()` returns a signed integer. Compare the result with 0, not with `true`.
  ✗ `if StrCompare(a, b) = true` → ✓ `if StrCompare(a, b) = 0`
- `=` and `!=` compare case-insensitively; `==` and `!==` compare case-sensitively.
- A comment needs a space or tab before `;`. A `;` with another character to its left is not a comment and needs no escape.
- Convention, not a language limit: build long text with `.=` in a loop, or collect parts in an Array and join once.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `MethodError` | `arr.Join(", ")` | Message names `Join` | Loop join (TIER 1) or `JoinArray` recipe |
| `PropertyError` | `str.Length` on a string | Message names `Length` | `StrLen(str)` |
| `MethodError` | `String(obj)` where `obj` has no `ToString` method | Message names `ToString` | Define `ToString()` or format the fields yourself |
| `TypeError` | `IsAlpha(obj)` or another string-pattern `Is` function on a non-string value | Message about the type | Pass a string, or check the type first |
| `IndexError` | `StrSplit(...)[0]` | Message about the index | Arrays are 1-based |

## TIER 1 — Building, Quoting and Joining
> METHODS COVERED: `.=` · `RTrim()` · `Format()`

```ahk
#Requires AutoHotkey v2.0

; ✓ Auto-concat (space) and explicit concat (.)
first := "Ada", last := "Lovelace"
full := first " " last
full2 := first . " " . last

; ✓ .= appends
report := ""
report .= "Line 1`n"
report .= "Line 2`n"

; ✓ Join with a separator only between items
items := ["apple", "banana", "cherry"]
joined := ""
for i, item in items
    joined .= (i > 1 ? ", " : "") item

; ✓ Or append then strip the trailing separator
joined2 := ""
for item in items
    joined2 .= item ", "
joined2 := RTrim(joined2, ", ")

; ✓ Choose quotes to avoid escaping
q1 := 'He said "Hello"'
q2 := "It's working"
q3 := "He said `"Hello`""          ; escaped form, same result as q1

; ✓ Format for templates and padding
line := Format("{1:-10}|{2:05d}|{3:.2f}", "Name", 42, 3.14159)   ; "Name      |00042|3.14"

; ✓ Continuation section: lines joined with `n by default
text := "
(
First line
Second line
)"

; ✗ items.Join(", ")   ; MethodError: Array has no Join method
```

## TIER 2 — Escapes and Literal Characters
> METHODS COVERED: escape sequences

```ahk
#Requires AutoHotkey v2.0

tab   := "Name`tAge"                 ; tab
crlf  := "Line1`r`nLine2"            ; CR+LF
tick  := "A backtick: ``"            ; one literal backtick
semi  := "a `; b"                    ; `; — escape a ; that has a space or tab to its left
semi2 := "a;b"                       ; no space before ; → never a comment, no escape needed
path  := "C:\Temp\new.txt"           ; backslashes are literal — no doubling
quote := 'Path: "C:\Program Files\App\app.exe"'

; ✗ "First\nSecond"   ; shows a backslash and n, not a new line
; ✗ "C:\\Temp"        ; produces C:\\Temp with two backslashes
```

## TIER 3 — Search, Extract, Replace, Split and Compare
> METHODS COVERED: `Trim` · `StrUpper` · `StrLower` · `StrTitle` · `StrReplace` · `StrSplit` · `InStr` · `SubStr` · `StrLen` · `StrCompare`

```ahk
#Requires AutoHotkey v2.0

text := "  Hello World  "
clean := Trim(text)                       ; "Hello World"
upper := StrUpper(clean)                  ; "HELLO WORLD"
title := StrTitle("hello world")          ; "Hello World"

; ✓ Replace and count
out := StrReplace(clean, "o", "0", , &n)  ; "Hell0 W0rld", n = 2
; ✗ StrReplace(clean, "o", "0")           ; result discarded — clean unchanged

; ✓ Split; OmitChars trims each element
parts := StrSplit("a , b , c", ",", " ")  ; ["a", "b", "c"]
cells := StrSplit("x|y;z", ["|", ";"])    ; several delimiters

; ✓ Search
pos  := InStr(clean, "o")                 ; 5
last := InStr(clean, "o", , -1)           ; 8 — right-to-left from the end
if InStr(clean, "world")                  ; case-insensitive by default
    MsgBox "found"

; ✓ Extract (1-based; negative counts from the end)
word := SubStr(clean, 1, 5)               ; "Hello"
tail := SubStr(clean, -5)                 ; "World"
base := SubStr("report.txt", 1, -4)       ; "report" (negative Length drops chars)

; ✓ Compare
if StrCompare("apple", "banana") < 0
    MsgBox "apple sorts first"
if StrCompare("file2", "file10", "Logical") < 0
    MsgBox "natural order"
if ("ABC" = "abc") && !("ABC" == "abc")
    MsgBox "= ignores case, == does not"

; ✓ Length
MsgBox StrLen(clean)                      ; 11
; ✗ clean.Length                          ; strings have no Length property
```

## DROP-IN RECIPES

```ahk
#Requires AutoHotkey v2.0

; JoinArray — join any Array with a separator (Array has no Join method)
JoinArray(arr, sep := ", ") {
    if !(arr is Array)
        throw TypeError("JoinArray: arr must be an Array", -1, Type(arr))
    out := ""
    for i, item in arr
        out .= (i > 1 ? sep : "") (IsObject(item) ? Type(item) : item)
    return out
}

; NormalizeWhitespace — trim and collapse runs of whitespace to one space
NormalizeWhitespace(str) => RegExReplace(Trim(str, " `t`r`n"), "\s+", " ")

; PadLeft — fixed-width text using Format
PadLeft(value, width, padChar := " ") {
    s := String(value)
    while StrLen(s) < width
        s := padChar s
    return s
}

; StartsWith / EndsWith — case-insensitive unless caseSense is true
StartsWith(str, prefix, caseSense := false) => InStr(str, prefix, caseSense) = 1
EndsWith(str, suffix, caseSense := false) {
    if StrLen(suffix) > StrLen(str)
        return false
    return StrCompare(SubStr(str, -StrLen(suffix)), suffix, caseSense) = 0
}
```

## SEE ALSO

> This module does NOT cover: regular expressions → see Module_RegEx.md
> This module does NOT cover: reading/writing text files and encodings → see Module_FileIO.md
> This module does NOT cover: hotstring syntax and escaping in hotstrings → see Module_HotkeysAndHotstrings.md

- `Module_RegEx.md` — `RegExMatch`, `RegExReplace`, options and match objects.
- `Module_FileIO.md` — `FileRead`/`FileOpen` with encodings; line-by-line reading.
- `Module_ArrayBasics.md` — Arrays returned by `StrSplit` and used for joining.
- `Module_GuiBasics.md` — multi-line text in GUI controls.
- `Module_ExceptionHandling.md` — catching `MethodError`/`TypeError` from string code.
