# Module_ValidationRules.md
<!-- DOMAIN: Validation Rules — format and business-rule checks (e-mail, password, filename, port, slug), collect-all error reporting, environment pre-flight checks (file, folder, window, process), fluent ValidationBuilder and FormValidator for GUI forms -->
<!-- SCOPE: Type checks, IsSet/unset parameters, TypeError vs ValueError selection and duck typing are in Module_GuardClauses.md. Regex syntax is in Module_RegEx.md. try/catch and Error classes are in Module_ExceptionHandling.md. GUI form construction is in Module_GuiBasics.md. -->
<!-- TRIGGERS: "validate input", "validate form", "form validation", "email validation", "password strength", "filename validation", "port number", slug, "business rule", "collect all errors", "show all errors", ValidationBuilder, FormValidator, "fluent validator", "pre-flight", "file exists check", FileExist, DirExist, WinExist, ProcessExist, "sanitize input" -->
<!-- CONSTRAINTS: FileExist/DirExist return an attribute string or "" (they never throw); WinExist and ProcessExist return 0 when nothing matches; FileExist matches folders too — test for "D" in the result when only files are allowed; a pre-flight check does not guarantee success, so file and window operations can still throw OSError/TargetError; ValidationBuilder and FormValidator are user-defined classes in this module, not built-ins. -->
<!-- CROSS-REF: Module_GuardClauses.md, Module_RegEx.md, Module_ExceptionHandling.md, Module_GuiBasics.md, Module_FileIO.md, Module_ClassBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `IfExist, path` | `if FileExist(path)` | Legacy `If` commands removed |
| `IfWinExist, title` | `if WinExist(title)` | Same |
| `Process, Exist, name` then `ErrorLevel` | `pid := ProcessExist(name)` | Result is the return value |
| `if ErrorLevel` after `FileCopy` | `try FileCopy(...)` / `catch OSError` | Failures throw |

## API QUICK-REFERENCE

### Environment Pre-Flight Functions

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `FileExist()` | `FileExist(FilePattern)` | Attribute letters of the first match (e.g. `"A"`, `"D"`, `"N"`), or `""` | Matches files **and** folders; wildcards allowed |
| `DirExist()` | `DirExist(FilePattern)` | Attribute letters, or `""` | Folders only |
| `DirCreate()` | `DirCreate(DirName)` | — | Creates parent folders too; throws `OSError` on failure |
| `WinExist()` | `WinExist(WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)` | HWND, or 0 | Also sets the Last Found Window |
| `ProcessExist()` | `ProcessExist(PIDOrName?)` | PID, or 0 | Name or PID |
| `SplitPath()` | `SplitPath(Path, &OutFileName?, &OutDir?, &OutExtension?, &OutNameNoExt?, &OutDrive?)` | — | Output parameters need `&` |

### ValidationBuilder (user-defined, TIER 3)

| Method | Returns | Behavior |
|--------|---------|----------|
| `ValidationBuilder.For(value, field?)` | builder | Static factory |
| `.Required()` | `this` | Error if a string is blank after `Trim` |
| `.IsInteger()` / `.IsString()` | `this` | Error if `value is Integer` / `value is String` is false |
| `.InRange(min, max)` | `this` | Checked only for Integer values |
| `.MinLength(n)` / `.MaxLength(n)` | `this` | Checked only for strings |
| `.Matches(pattern, desc?)` | `this` | Checked only for strings |
| `.Satisfies(fn, desc?)` | `this` | Throws `TypeError` at once if `fn` is not callable |
| `.Errors` | Array | Collected messages (read-only use) |
| `.HasErrors()` | Boolean | Non-throwing status |
| `.Validate()` | `true` | Throws one `ValueError` listing every message |

### FormValidator (user-defined, TIER 3)

| Method | Returns | Behavior |
|--------|---------|----------|
| `.Add(builder)` | `this` | Register a builder |
| `.AllErrors()` | Array | Messages from every builder |
| `.IsValid()` | Boolean | No builder has errors |
| `.Validate()` | `true` | Throws one `ValueError` for the whole form |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- `FileExist`, `DirExist`, `WinExist` and `ProcessExist` report by return value and do not throw. Use them directly in `if`.
- `FileExist(path)` is true for a folder too. When the path must be a file, also check `!InStr(FileExist(path), "D")`.
  ✗ `if FileExist(path)` before `FileRead` → ✓ also reject `"D"` in the attributes
- A pre-flight check can pass and the real operation can still fail (file locked, window closed in between). Keep `try`/`catch OSError` or `TargetError` around the operation when failure matters.
- `ProcessClose` returns the PID, or 0 if no matching process was found or it could not be closed.
  ✗ `ProcessClose(n)` then assume the process is gone → ✓ check the returned PID
- Anchor regex patterns used for validation with `^...$`; an unanchored pattern matches anywhere in the string.
  ✗ `RegExMatch(s, "\d+")` → ✓ `RegExMatch(s, "^\d+$")`
- Convention, not a language limit: order checks from cheap to expensive — type and length first, then `RegExMatch`, then file/window/process queries.
- Convention, not a language limit: for user-facing forms, collect every error and report them together in one message; for function arguments, fail on the first error (see Module_GuardClauses.md).
  ✗ throw on the first bad field of a form → ✓ collect and report all fields
- Convention, not a language limit: validators throw `ValueError` / `TypeError` with `-1` and the value, not a bare `Error`.
  ✗ `throw Error("bad")` in validators → ✓ `ValueError` / `TypeError` with `-1` and the value

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `OSError` | `FileRead`/`FileCopy`/`DirCreate` fails although a pre-check passed | `.Number` holds the OS error code | `try`/`catch OSError` around the operation |
| `TargetError` | Window closed between `WinExist` and `WinActivate`/`ControlSend` | Message names the target type | `try`/`catch TargetError` |
| `ValueError` | `ValidationBuilder.Validate()` / `FormValidator.Validate()` found problems | `.Message` lists every rule | Show `e.Message` to the user |
| `TypeError` | `.Satisfies()` given a non-callable rule | Thrown immediately | Pass a function or closure |
| Validation passes but should fail | Unanchored pattern like `"\d+"` accepts `"abc123"` | Tests with mixed input | Use `"^\d+$"` |

## TIER 1 — Format and Business Rules
> METHODS COVERED: `RegExMatch()` · `StrLen()` · `Trim()` · `.Push()`

Single-rule checks throw at once. Multi-rule checks on one field collect every failure and throw once.

```ahk
#Requires AutoHotkey v2.0

ValidateEmail(email) {
    if !(email is String) || Trim(email) = ""
        throw ValueError("email must be a non-empty string", -1, email)
    ; simplified pattern — tighten as needed
    if !RegExMatch(email, "i)^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$")
        throw ValueError("email format invalid", -1, email)
    return true
}

; ✓ Collect all failures for one field
ValidatePassword(pw, minLength := 8) {
    if !(pw is String)
        throw TypeError("password must be a string", -1, Type(pw))
    errors := []
    if StrLen(pw) < minLength
        errors.Push("at least " minLength " characters")
    if !RegExMatch(pw, "[A-Z]")
        errors.Push("an uppercase letter")
    if !RegExMatch(pw, "[a-z]")
        errors.Push("a lowercase letter")
    if !RegExMatch(pw, "\d")
        errors.Push("a digit")
    if !RegExMatch(pw, "[^a-zA-Z0-9]")
        errors.Push("a special character")
    if errors.Length {
        msg := "Password needs:"
        for e in errors
            msg .= "`n- " e
        throw ValueError(msg, -1)
    }
    return true
}

; ✓ Windows file name rules
ValidateFilename(name) {
    if !(name is String) || Trim(name) = ""
        throw ValueError("filename must be a non-empty string", -1, name)
    if RegExMatch(name, '[\\/:*?"<>|]')
        throw ValueError("filename contains \ / : * ? `" < > or |", -1, name)
    if StrLen(name) > 255
        throw ValueError("filename longer than 255 characters", -1, StrLen(name))
    return true
}

ValidatePort(port) {
    if !IsInteger(port)
        throw TypeError("port must be an integer", -1, port)
    if port < 1 || port > 65535
        throw ValueError("port must be 1-65535", -1, port)
    return Integer(port)
}

ValidateSlug(slug) {
    if !(slug is String) || !RegExMatch(slug, "^[a-z0-9](?:[a-z0-9-]{0,58}[a-z0-9])?$")
        throw ValueError("slug: 1-60 chars, lowercase letters, digits and inner hyphens", -1, slug)
    return true
}

try {
    ValidatePassword("weak")
} catch ValueError as e {
    MsgBox e.Message
}
```

## TIER 2 — Environment Pre-Flight Checks
> METHODS COVERED: `FileExist()` · `DirExist()` · `DirCreate()` · `WinExist()` · `WinActivate()` · `ProcessExist()` · `ProcessClose()` · `FileOpen()` · `FileCopy()` · `SplitPath()`

```ahk
#Requires AutoHotkey v2.0

; ✓ File must exist and must not be a folder
ReadTextFile(path) {
    attrs := FileExist(path)
    if attrs = "" || InStr(attrs, "D")
        throw ValueError("not an existing file", -1, path)
    f := FileOpen(path, "r", "UTF-8")      ; can still throw OSError
    try {
        return f.Read()
    } finally {
        f.Close()
    }
}

; ✓ Create the folder if needed (DirCreate creates parents and throws on failure)
WriteToDir(dir, name, text) {
    if !DirExist(dir)
        DirCreate(dir)
    FileAppend(text, dir "\" name, "UTF-8")
}

; ✓ Window pre-flight, with the real call still guarded
SendToWindow(winTitle, keys) {
    if !WinExist(winTitle)
        throw TargetError("window not found", -1, winTitle)
    try {
        WinActivate(winTitle)
        if !WinWaitActive(winTitle, , 2)
            throw TargetError("window did not activate", -1, winTitle)
        SendInput(keys)
    } catch TargetError as e {
        throw TargetError("window lost during send", -1, e.Message)
    }
}

; ✓ Process pre-flight; ProcessClose returns 0 if nothing was closed
CloseProcess(name) {
    if !ProcessExist(name)
        throw TargetError("process not running", -1, name)
    if !ProcessClose(name)
        throw Error("process could not be closed", -1, name)
}

; ✓ Batch work: cache folder checks per directory
BatchWrite(paths, text) {
    seen := Map()
    for path in paths {
        SplitPath(path, , &dir)
        if !seen.Has(dir)
            seen[dir] := DirExist(dir) != ""
        if !seen[dir]
            throw ValueError("folder missing", -1, dir)
        FileAppend(text, path, "UTF-8")
    }
}
```

## TIER 3 — Fluent ValidationBuilder and FormValidator
> METHODS COVERED: `ValidationBuilder` · `FormValidator` (user-defined) · `HasMethod()` · `RegExMatch()`

Each builder collects errors for one field without throwing. `FormValidator` gathers all builders and throws one `ValueError` for the whole form.

```ahk
#Requires AutoHotkey v2.0

class ValidationBuilder {
    static For(value, field := "value") {
        vb := ValidationBuilder()
        vb.Value := value
        vb.Field := field
        return vb
    }
    __New() {
        this.Errors := []
    }
    _Add(msg) {
        this.Errors.Push(this.Field ": " msg)
        return this
    }
    Required() => (this.Value is String && Trim(this.Value) = "") ? this._Add("is required") : this
    IsInteger() => (this.Value is Integer) ? this : this._Add("must be Integer (got " Type(this.Value) ")")
    IsString()  => (this.Value is String)  ? this : this._Add("must be String (got " Type(this.Value) ")")
    InRange(lo, hi) {
        if this.Value is Integer && (this.Value < lo || this.Value > hi)
            this._Add("must be " lo "-" hi " (got " this.Value ")")
        return this
    }
    MinLength(n) => (this.Value is String && StrLen(this.Value) < n) ? this._Add("needs at least " n " chars") : this
    MaxLength(n) => (this.Value is String && StrLen(this.Value) > n) ? this._Add("allows at most " n " chars") : this
    Matches(pattern, desc := "valid format") {
        if this.Value is String && !RegExMatch(this.Value, pattern)
            this._Add("must be " desc)
        return this
    }
    Satisfies(fn, desc := "custom rule") {
        if !HasMethod(fn, , 1)
            throw TypeError("Satisfies: fn must accept 1 argument", -1, Type(fn))
        if !fn(this.Value)
            this._Add("must satisfy " desc)
        return this
    }
    HasErrors() => this.Errors.Length > 0
    Validate() {
        if !this.HasErrors()
            return true
        throw ValueError(_JoinLines(this.Errors), -1)
    }
}

class FormValidator {
    __New() {
        this.Builders := []
    }
    Add(builder) {
        this.Builders.Push(builder)
        return this
    }
    AllErrors() {
        all := []
        for b in this.Builders
            all.Push(b.Errors*)
        return all
    }
    IsValid() => this.AllErrors().Length = 0
    Validate() {
        errs := this.AllErrors()
        if errs.Length = 0
            return true
        throw ValueError("Form validation failed:`n" _JoinLines(errs), -1)
    }
}

_JoinLines(arr) {
    out := ""
    for i, line in arr
        out .= (i > 1 ? "`n" : "") "- " line
    return out
}

; Usage — every field is checked, all problems shown together
SubmitRegistration(username, email, age) {
    form := FormValidator()
    form.Add(ValidationBuilder.For(username, "username")
        .IsString().Required().MinLength(3).MaxLength(20)
        .Matches("^\w+$", "letters, digits or underscore"))
    form.Add(ValidationBuilder.For(email, "email")
        .IsString().Required()
        .Matches("i)^[^@\s]+@[^@\s]+\.[a-z]{2,}$", "a valid e-mail address"))
    form.Add(ValidationBuilder.For(age, "age").IsInteger().InRange(13, 120))
    try {
        form.Validate()
        MsgBox "Registered " username
    } catch ValueError as e {
        MsgBox "Please fix:`n" e.Message
    }
}

SubmitRegistration("AB", "not-an-email", 200)
```

## DROP-IN RECIPES

```ahk
#Requires AutoHotkey v2.0

; AssertParams — check several parameters at once, report all problems
; specs: Array of Maps with "name", "value", "type" ("String" | "Integer" | "Float" | "Number" | "Object")
; and optional "nonblank" (true = reject blank strings)
AssertParams(specs) {
    errors := []
    for spec in specs {
        name := spec["name"], val := spec["value"], want := spec["type"]
        switch want {
            case "String":  ok := val is String
            case "Integer": ok := val is Integer
            case "Float":   ok := val is Float
            case "Number":  ok := val is Number
            case "Object":  ok := IsObject(val)
            default:        throw ValueError("AssertParams: unknown type", -1, want)
        }
        if !ok
            errors.Push(name ": must be " want ", got " Type(val))
        else if want = "String" && spec.Has("nonblank") && spec["nonblank"] && Trim(val) = ""
            errors.Push(name ": must not be blank")
    }
    if errors.Length
        throw ValueError("Parameter validation failed:`n" _JoinErrors(errors), -2)
    return true
}

_JoinErrors(arr) {
    out := ""
    for i, e in arr
        out .= (i > 1 ? "`n" : "") "- " e
    return out
}

; AssertParams([
;     Map("name", "userId", "value", 42, "type", "Integer"),
;     Map("name", "label", "value", "Hi", "type", "String", "nonblank", true)
; ])
```

## SEE ALSO

> This module does NOT cover: type checks, IsSet and duck typing → see Module_GuardClauses.md
> This module does NOT cover: regex syntax and options → see Module_RegEx.md
> This module does NOT cover: building the GUI form itself → see Module_GuiBasics.md

- `Module_GuardClauses.md` — fail-early guards, `is` vs `IsInteger`, `HasMethod`/`HasProp`.
- `Module_RegEx.md` — patterns, anchors and options used by the rules here.
- `Module_ExceptionHandling.md` — `ValueError`, `TargetError`, `OSError` and catching them.
- `Module_FileIO.md` — file reading/writing behind the pre-flight checks.
- `Module_GuiBasics.md` — showing validation errors in GUI forms.
- `Module_ClassBasics.md` — designing reusable validator classes.
