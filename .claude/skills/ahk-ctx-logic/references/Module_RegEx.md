# Module_RegEx.md
<!-- DOMAIN: Regular Expressions — RegExMatch, RegExReplace, AHK pattern options, RegExMatchInfo match objects, capture groups and backreferences, errors from bad patterns -->
<!-- SCOPE: Non-regex string functions, escapes and joining are in Module_StringFunctions.md. Regex-based input validation frameworks are in Module_ValidationRules.md. Regex callouts (C option) are not covered. -->
<!-- TRIGGERS: RegExMatch, RegExReplace, regex, "regular expression", pattern, "match object", "capture group", "named group", backreference, "$1", "i)", "m)", "s)", "x)", PCRE, "extract with regex", "replace with regex", "case-insensitive regex", "multiline regex", "compile error" -->
<!-- CONSTRAINTS: Options go at the very start of the pattern followed by ")" (e.g. "i)abc") — not "/abc/i"; the output variable must be passed with & (a VarRef); when there is no match RegExMatch returns 0 and makes the output variable blank; a bad pattern throws an Error ("Compile error N at offset M: ..."); in a replacement only "$" needs escaping ("$$"); backslash is a PCRE escape inside the pattern, while backtick sequences such as `n are converted by AHK before PCRE sees the pattern. -->
<!-- CROSS-REF: Module_StringFunctions.md, Module_ValidationRules.md, Module_ExceptionHandling.md, Module_FileIO.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `RegExMatch(str, pat, match)` | `RegExMatch(str, pat, &match)` | The output parameter needs a VarRef (`&`) |
| `RegExMatch(str, "O)pat", m)` / `"P)pat"` | `RegExMatch(str, "pat", &m)` | Options `O` and `P` were removed; v2 always stores a match object |
| `match1`, `match2` pseudo-array variables | `m[1]`, `m[2]` or `m.1` | Captures are read from the match object |
| `"/pattern/i"` (JS/Perl) | `"i)pattern"` | Slashes are literal pattern characters in AHK |

## API QUICK-REFERENCE

### Regex Functions

| Function | Signature | Returns | Throws |
|----------|-----------|---------|--------|
| `RegExMatch()` | `RegExMatch(Haystack, NeedleRegEx, &OutputVar?, StartingPos?)` | Position of the match (1-based), or 0 | `Error` for a pattern syntax error or a PCRE execution error |
| `RegExReplace()` | `RegExReplace(Haystack, NeedleRegEx, Replacement?, &OutputVarCount?, Limit?, StartingPos?)` | New string | Same as above |

`StartingPos`: negative counts from the right (`-1` = last character); `0` starts at the end of `Haystack`. The returned position is always relative to the first character.

### Match Object (RegExMatchInfo)

`N` may be `0` (whole match), a group number, or a group name.

| Member | Returns |
|--------|---------|
| `m[]`, `m[N]`, `m.N` (e.g. `m.1`, `m.Year`) | Whole match or captured group text |
| `m.Pos[N]` / `m.Len[N]` | Position / length of the match or group |
| `m.Name[N]` | Name of group N, if it has one |
| `m.Count` | Number of capturing groups (maximum N) |
| `m.Mark` | Name from the last `(*MARK:NAME)` |
| `for` / `Loop m.Count` | Match objects can be enumerated |

### Options (start of pattern, case-sensitive)

| Option | Effect |
|--------|--------|
| `i` | Case-insensitive (A–Z) |
| `m` | Multiline: `^`/`$` match at internal line breaks |
| `s` | DotAll: `.` also matches newlines (a CRLF still needs two characters) |
| `x` | Ignore unescaped whitespace in the pattern (literal `` `n``/`` `t`` included) |
| `U` | Ungreedy quantifiers |
| `A` / `D` | Anchor at start / `$` only at very end (`D` ignored with `m`) |
| `J` | Allow duplicate group names |
| `S` | Study the pattern for repeated use |
| `` `n `` / `` `r `` / `` `a `` | Which newline markers `^`, `$` and `.` recognize (default: `` `r`n ``, `` `n ``, `` `r ``) |

Combine options: `"im)^abc$"`. PCRE inline options such as `(?i)` are also valid inside the pattern for part of it.

### Replacement Backreferences

| Syntax | Meaning |
|--------|---------|
| `$0` … `$9` | Whole match / group 1–9 |
| `${10}`, `${name}` | Group above 9, or a named group |
| `$U1`, `$L1`, `$T1` (also `$U{1}`) | Group converted to upper / lower / title case |
| `$$` | Literal `$` — the only character that needs escaping |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Options must be at the very beginning of the pattern followed by `)`. The slash-flag wrong form is in V1 → V2 BREAKING CHANGES.
- Pass the output variable as `&m`. When the function returns 0, `m` is made blank, so read groups only after a successful match. The missing-`&` and pseudo-array wrong forms are in V1 → V2 BREAKING CHANGES.
  ✗ `RegExMatch(s, p, &m)` then `m[1]` → ✓ `if RegExMatch(s, p, &m)` first
- A dot does not match `` `r `` or `` `n `` unless `s` (or a newline option) is used.
- By default a pattern matches anywhere in the string. Use `^` and `$` (or the `A` option) to anchor it.
- The pattern is an AHK string first: `` `n `` becomes a real newline before PCRE sees it; `\n` is passed to PCRE, which reads it as a newline escape. Both work inside patterns, but only the backtick form works in ordinary strings.
- PCRE metacharacters `\.*?+[{|()^$` need a backslash to be literal inside the pattern.
  ✗ `RegExMatch(s, userText)` → ✓ `RegExMatch(s, RegExEscape(userText))`
- A literal `$` in a replacement is written `$$` (see `### Replacement Backreferences`).
  ✗ `"\$1.00"` in a replacement → ✓ `"$$1.00"`
- The 100 most recently used patterns are cached in compiled form. For a plain substring search, `InStr` is faster than `RegExMatch` (official performance note).
  ✗ `RegExMatch(s, "abc")` → ✓ `InStr(s, "abc")`
- Nonexistent or non-participating groups in a replacement become empty strings.
- Convention, not a language limit: wrap `RegExMatch`/`RegExReplace` in `try`/`catch Error` only when the pattern comes from the user or from data.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `Error` | Invalid pattern (unclosed group, bad quantifier) | Message `"Compile error N at offset M: ..."` | Fix the pattern; `try` for user patterns |
| `Error` | Catastrophic backtracking or recursion | `.Extra` holds the PCRE error number (e.g. -8 match limit, -21 recursion) | Make quantifiers more restrictive |
| `TypeError` / `UnsetError` | Output parameter passed without `&` | Message about the parameter or an unset variable | `RegExMatch(s, p, &m)` |
| Error reading `m[1]` | No match, so `m` is blank (not an object) | Function returned 0 | `if RegExMatch(s, p, &m)` before reading groups |

## TIER 1 — RegExMatch Basics and Options
> METHODS COVERED: `RegExMatch()` · options `i` `m` `s` `x`

```ahk
#Requires AutoHotkey v2.0

; ✓ Case-insensitive, anchored
if RegExMatch("USER@EXAMPLE.COM", "i)^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$")
    MsgBox "looks like an e-mail address"

; ✓ Multiline: ^ and $ work per line
logText := "INFO start`nERROR disk full`nINFO end"
if RegExMatch(logText, "m)^ERROR (.*)$", &m)
    MsgBox "First error: " m[1]           ; "disk full"

; ✓ DotAll: . also crosses newlines
RegExMatch("<b>`nbold`n</b>", "s)<b>(.*?)</b>", &m)

; ✓ Extended: whitespace in the pattern is ignored
RegExMatch("2024-05-17", "x) (\d{4}) - (\d{2}) - (\d{2})", &d)
MsgBox d[1] "/" d[2] "/" d[3]

; ✓ Position and length
pos := RegExMatch("abc123", "\d+", &num)  ; pos = 4
MsgBox num[0] " at " num.Pos " len " num.Len   ; "123 at 4 len 3"

; ✗ RegExMatch(str, "/abc/i")   ; slashes and i are literal pattern text
; ✗ RegExMatch(str, pat, m)     ; m is not a VarRef
```

## TIER 2 — Capture Groups, Named Groups and Iteration
> METHODS COVERED: `RegExMatch()` · `m.Count` · `m.Name[N]` · `StartingPos`

```ahk
#Requires AutoHotkey v2.0

; ✓ Named groups: (?<name>...) or (?P<name>...)
if RegExMatch("Price: $25.99", "\$(?<dollars>\d+)\.(?<cents>\d{2})", &p) {
    MsgBox p["dollars"] " dollars, " p.cents " cents"
    MsgBox "Groups: " p.Count ", group 1 name: " p.Name[1]
}

; ✓ Find all matches: continue after the previous match
text := "a1 b22 c333"
pos := 1
while pos := RegExMatch(text, "\d+", &m, pos) {
    OutputDebug m[0] " at " pos
    pos += m.Len                  ; move past this match
}

; ✓ Walk the groups of one match
RegExMatch("John Smith 42", "(\w+) (\w+) (\d+)", &r)
Loop r.Count
    OutputDebug A_Index ": " r[A_Index]
```

## TIER 3 — RegExReplace and Backreferences
> METHODS COVERED: `RegExReplace()` · `$1` · `${name}` · `$U1` · `$$`

```ahk
#Requires AutoHotkey v2.0

text := "Hello 123 World 456"

; ✓ Replace runs of non-digits with one space
digits := RegExReplace(text, "\D+", " ")          ; " 123 456"

; ✓ Swap with backreferences
swapped := RegExReplace(text, "(\w+) (\d+)", "$2 $1")   ; "123 Hello 456 World"

; ✓ Count replacements and limit them
once := RegExReplace(text, "\d", "#", &count, 1)       ; "Hello #23 World 456", count = 1

; ✓ Case conversion and named groups in the replacement
shout := RegExReplace("hello world", "(\w+)", "$U1")    ; "HELLO WORLD"
iso   := RegExReplace("17/05/2024", "(?<d>\d\d)/(?<m>\d\d)/(?<y>\d{4})", "${y}-${m}-${d}")

; ✓ Literal dollar sign in a replacement
price := RegExReplace("cost: 5", "\d+", "$$$0")         ; "cost: $5"

; ✗ RegExReplace(text, "\d", "\$")   ; backslash does not escape $ — use $$
```

## DROP-IN RECIPES

```ahk
#Requires AutoHotkey v2.0

; SafeRegExExtract — group text or a default; bad patterns become ValueError
SafeRegExExtract(haystack, pattern, group := 0, fallback := "") {
    try {
        found := RegExMatch(haystack, pattern, &m)
    } catch Error as e {
        throw ValueError("Invalid regex pattern", -1, e.Message)
    }
    if !found
        return fallback
    return m[group]
}

; RegExMatchAll — Array of match objects
RegExMatchAll(haystack, pattern) {
    results := []
    pos := 1
    while pos := RegExMatch(haystack, pattern, &m, pos) {
        results.Push(m)
        pos += m.Len ? m.Len : 1       ; step past an empty match
        if pos > StrLen(haystack) + 1  ; an empty match at the very end would repeat forever
            break
    }
    return results
}

; RegExEscape — make user text safe to embed as a literal in a pattern
RegExEscape(str) => "\Q" StrReplace(str, "\E", "\E\\E\Q") "\E"
```

## SEE ALSO

> This module does NOT cover: non-regex string functions and escapes → see Module_StringFunctions.md
> This module does NOT cover: building validators on top of regex → see Module_ValidationRules.md

- `Module_StringFunctions.md` — `InStr`, `StrReplace`, `StrSplit` and backtick escapes.
- `Module_ValidationRules.md` — format checks (e-mail, slug, filename) built on `RegExMatch`.
- `Module_ExceptionHandling.md` — catching `Error` from bad patterns.
- `Module_FileIO.md` — reading file text before matching.
