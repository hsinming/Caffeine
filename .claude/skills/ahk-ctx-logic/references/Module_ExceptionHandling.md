# Module_ExceptionHandling.md
<!-- DOMAIN: Exception Handling — built-in Error classes, Error object properties, try/catch/else/finally, throw and rethrow, custom Error subclasses, OnError global handlers -->
<!-- SCOPE: v1→v2 syntax mistakes and syntax/runtime error diagnosis are in Module_ErrorDiagnosis.md. Input guards and TypeError/ValueError selection for parameters are in Module_GuardClauses.md. COM HRESULT propagation and deep GUI event-binding diagnostics are not covered — see Module_COMAutomation.md and Module_GuiBasics.md. -->
<!-- TRIGGERS: try, catch, finally, throw, rethrow, "catch Any", OnError, exception, Error class, TypeError, ValueError, OSError, TargetError, TimeoutError, IndexError, ZeroDivisionError, MemoryError, UnsetError, UnsetItemError, MemberError, PropertyError, MethodError, "custom error", "error hierarchy", "crash log", "global error handler", err.Message, err.What, err.Extra, err.Stack -->
<!-- CONSTRAINTS: `catch` with no class catches only `Error` instances — use `catch Any` to catch any thrown value; `try` alone (no catch/finally) behaves like `catch Error` with an empty block; `throw` with no value re-throws only while a `catch` is executing (also from a function it calls or a nested `try`-`finally`, but not inside a nested `try`-`catch`); catch class names must be literal class names resolved at load time; OnError callbacks receive (thrown, mode) and return 0/""/nothing, 1, or -1 (-1 continues only when mode is "Return"); OnError cannot see load-time errors. -->
<!-- CROSS-REF: Module_ErrorDiagnosis.md, Module_GuardClauses.md, Module_ClassBasics.md, Module_COMAutomation.md, Module_FileIO.md, Module_GuiBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Built-in Error Classes

All classes below are predefined subclasses of `Error` (docs: `lib/Error.htm`). Constructor: `ErrClass(Message?, What?, Extra?)` unless noted.

| Class | Parent | Thrown when (official wording, shortened) |
|-------|--------|-------------------------------------------|
| `Error` | `Object` | Base class; also thrown directly by built-in code |
| `MemoryError` | `Error` | A memory allocation failed |
| `OSError` | `Error` | A Win32 call failed. `OSError(Code?)`: numeric `Code` sets `.Number` and `.Message`; `Code` defaults to `A_LastError`. Example: `OSError(5).Message` = `"(5) Access is denied."` |
| `TargetError` | `Error` | Target (window, control, menu, status bar) not found |
| `TimeoutError` | `Error` | `SendMessage` timed out |
| `TypeError` | `Error` | Unexpected **type** of value; `.Extra` usually holds the errant value |
| `UnsetError` | `Error` | Read of a variable, property or item that has no value |
| `MemberError` | `UnsetError` | Missing member (covers both subclasses below) |
| `PropertyError` | `MemberError` | Missing property |
| `MethodError` | `MemberError` | Missing method, or the value cannot be called |
| `UnsetItemError` | `UnsetError` | Missing item, e.g. `map[key]` when the Map has no such key and no `Default` |
| `ValueError` | `Error` | Correct type but unexpected **value** |
| `IndexError` | `ValueError` | `__Item` index invalid or out of range (e.g. `arr[0]`) |
| `ZeroDivisionError` | `Error` | Division by zero in an expression or `Mod()` |

There is no `KeyError`, `NameError`, `SyntaxError` or `NetworkError` built-in class.

### Error Object Properties

All are get/set value properties (docs: `lib/Error.htm`).

| Property | Content |
|----------|---------|
| `.Message` | Error message (shown by the default error dialog) |
| `.What` | Source of the error — usually a function name; blank for expression errors such as math on a non-number |
| `.Extra` | Extra string; shown after "Specifically:" in the dialog |
| `.File` / `.Line` | Script file and line where the error occurred or the object was constructed |
| `.Stack` | Call stack text at construction time (max 2047 chars) |
| `.Number` | `OSError` only — the OS error code |

`What` parameter: a negative integer selects a stack frame. `-1` = the current function, `-2` = its caller, and so on. Then `.What` is that function's name and `.File`/`.Line` point at the line that **called** it. A non-numeric `What` is just stored as text.

### Exception Control Flow

| Statement | Syntax | Notes |
|-----------|--------|-------|
| `try` | `try { ... }` or `try Statement` | Without `catch`/`finally` it behaves like `catch Error` with an empty block |
| `catch` | `catch [Class1, Class2] [as OutVar] { ... }` | No class = `Error`. `catch Any` catches every thrown value. Class names must be literal full names (resolved at load time) |
| `else` | `} else { ... }` after the last `catch` | Runs only if the `try` block finished without an exception. Errors thrown inside `else` are not handled by the same `try` |
| `finally` | `finally { ... }` | Always runs last; must come after `else` if both exist |
| `throw` | `throw Value` | Any value can be thrown. Inside a `catch` (or a function it calls, or a nested `try`-`finally`), `throw` with no value re-throws the caught value. Not supported inside a nested `try`-`catch` |
| `OnError()` | `OnError(Callback, AddRemove?)` | `AddRemove`: `1` (default) call after existing callbacks, `-1` call before them, `0` remove |

OnError callback: `Callback(Thrown, Mode)`. `Mode` is `"Return"` (continuable runtime error), `"Exit"` (non-continuable error or a script `throw`), or `"ExitApp"` (critical error — the program exits). Return value:

| Return | Effect |
|--------|--------|
| `0`, `""` or no `return` | Normal handling continues (other callbacks, then the default dialog) |
| `1` | Suppress the default dialog and any remaining callbacks |
| `-1` | Same as `1`, and if `Mode` is `"Return"` the current thread continues |

### Throwing vs Non-Throwing Built-ins

| Call | On failure |
|------|-----------|
| `FileRead`, `FileAppend`, `DirCreate` | Throw `OSError` |
| `Run`/`RunWait` | Throw an error if the target cannot be launched |
| `WinActivate`, `ControlSend`, `ControlClick` and most `Win*`/`Control*` actions | Throw `TargetError` when the target is not found |
| `WinExist`, `WinWaitActive` | Return `0` (no throw) |
| `FileExist`, `DirExist` | Return `""` (no throw) |
| `ProcessExist`, `ProcessClose` | Return `0` (no throw) |
| `RegExMatch`, `RegExReplace` | Throw `Error` for a bad pattern (`"Compile error N at offset M: ..."`) |
| `arr[i]` out of range / `map[k]` missing | `IndexError` / `UnsetItemError` |
| Call a value with no `Call` method | `MethodError` |
| Too few/too many arguments to a dynamic call | `Error` |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- `catch` without a class catches only `Error` instances. A script that throws a string or a non-`Error` object needs `catch Any` (or the right class). Each `catch` lists the classes it really expects.
  ✗ `catch as e` expecting to catch `throw "text"` → ✓ `catch Any as e`
- Put a subclass `catch` before its base class. Example: `catch TargetError` before `catch Error`. If `catch Error` comes first, it matches every built-in error.
  ✗ `catch Error` above `catch TargetError` → ✓ subclass first, `catch Error` last
- `catch` class names are resolved at load time. An unknown class name is a load-time error. A local variable with the same name as the class also causes an error.
  ✗ `catch KeyError` / `catch NameError` → ✓ `UnsetItemError`, or no such class
- Load-time (syntax) errors cannot be caught by `try` and are never passed to `OnError`.
- A bare `throw` re-throws only while a `catch` is executing. It also works in a function that the `catch` calls, and inside a nested `try`-`finally`, but not inside a nested `try`-`catch` (docs: `lib/Throw.htm`). Elsewhere, write the value to throw.
  ✗ bare `throw` in normal code to "raise" → ✓ `throw Error("msg", -1)`
- Use `finally` for cleanup that must run (file handles, `Critical`, flags).
- `OnError` callbacks run on the thread that failed, before the call stack unwinds. They run only for errors that would show the error dialog, so an error caught by `try` never reaches them.
- An `OnError` callback accepts `(thrown, mode)` and returns `1` or `-1` only when suppression is intended (return values: `### Exception Control Flow`).
- `-1` from an `OnError` callback continues the thread only when `Mode` is `"Return"`. In `"ExitApp"` mode the program still exits.
- An `OnError` callback that ignores some parameters must end its parameter list with `*`, e.g. `LogErr(err, *)`.
- A method passed to `OnError` must be bound.
  ✗ `OnError(Logger.Handle)` → ✓ `OnError(ObjBindMethod(Logger, "Handle"))`
- Convention, not a language limit: throw the most specific built-in class (`TypeError`, `ValueError`, `OSError`, `TargetError`) or a custom subclass, rather than base `Error`, so callers can filter with `catch`.
  ✗ `throw Error("bad type")` → ✓ `throw TypeError("expected Integer", -1, x)`
- Convention, not a language limit: never leave a `catch` block empty without a comment saying why the error is ignored.
  ✗ `try { X() } catch { }` → ✓ log, or comment why it is safe to ignore
- Convention, not a language limit: use `try`/`catch` for real failures (I/O, missing windows, user-supplied regex). Check predictable conditions such as `FileExist()` with `if`.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `PropertyError` | Reading a custom property (`.Code`, `.URL`) on an error caught by a broad `catch` that also catches built-in errors | Message names the missing property | Catch the custom class first, or test with `err is MyError` / `HasProp(err, "Code")` |
| `ValueError` (too few parameters) | Unbound method passed as an `OnError` callback, e.g. `OnError(Logger.Handle)` — the thrown value would fill the hidden `this`, so one parameter is missing | `ValueError` ("Invalid callback function") thrown by the `OnError` call itself | `OnError(ObjBindMethod(Logger, "Handle"))` or `OnError(Logger.Handle.Bind(Logger))` |
| Uncaught non-`Error` value | `throw "text"` or `throw {code: 1}` with only `catch as e` | Default dialog shows the thrown value | Throw an `Error` subclass, or use `catch Any as e` |
| Load-time error | `catch SomeUndefinedClass` | Script will not start | Define the class or fix the name |

## TIER 1 — try / catch / else / finally Basics
> METHODS COVERED: `try` · `catch` · `else` · `finally` · `FileRead()` · `FileOpen()`

`try` guards a block. The first matching `catch` handles the error. `else` runs only when nothing was thrown. `finally` always runs, so put cleanup there.

```ahk
#Requires AutoHotkey v2.0

; ✓ Catch an OSError from FileRead and fall back to defaults
try {
    content := FileRead(A_ScriptDir "\config.txt")
} catch OSError as err {
    MsgBox("Could not read config: " err.Message)
    content := ""
} else {
    MsgBox("Config loaded (" StrLen(content) " chars)")
}

; ✓ finally releases the handle whether or not Read() throws
fh := FileOpen(A_ScriptDir "\data.txt", "w", "UTF-8")
try {
    fh.Write("hello")
} finally {
    fh.Close()
}

; ✓ One-line try: errors (Error instances only) are silently ignored
try FileDelete(A_Temp "\maybe-missing.tmp")

; ✗ Empty catch hides the cause — add at least a comment or a log line
; try {
;     RiskyOperation()
; } catch {
; }
```

## TIER 2 — Typed Catch and Custom Error Classes
> METHODS COVERED: `class ... extends Error` · `catch Class1, Class2` · `catch Any` · `Type()` · `is`

A custom class can extend any built-in error class. If the subclass does not define `__New`, it takes the normal `(Message, What, Extra)` arguments. Callers then filter by class.

```ahk
#Requires AutoHotkey v2.0

; ✓ Custom classes without __New keep the standard (Message, What, Extra) arguments
class AppError extends Error {
}
class ConfigError extends AppError {
}

; ✓ Custom class with extra data: call super.__New() first
class HttpError extends AppError {
    __New(message, statusCode, url := "") {
        super.__New(message, , url)   ; sets Message, Extra, File, Line, Stack
        this.StatusCode := statusCode
    }
}

LoadSettings(path) {
    if !FileExist(path)
        throw ConfigError("Settings file missing", -1, path)
    return FileRead(path)
}

try {
    LoadSettings(A_ScriptDir "\settings.ini")
} catch HttpError as err {          ; ✓ most specific first
    MsgBox("HTTP " err.StatusCode ": " err.Message)
} catch ConfigError, OSError as err {   ; ✓ several classes in one clause
    MsgBox(Type(err) ": " err.Message "`n" err.Extra)
} catch Error as err {              ; ✓ broad fallback last
    MsgBox("Unexpected: " err.Message)
}

; ✓ catch Any is the only form that also catches non-Error values
try {
    throw "plain string"
} catch Any as thrown {
    MsgBox("Caught: " (thrown is Error ? thrown.Message : thrown))
}
```

## TIER 3 — The What Parameter, Rethrow and Wrapping
> METHODS COVERED: `Error(Message, What, Extra)` · `throw` (no value) · `.Stack`

Use a negative `What` so the error points at the caller instead of an internal helper. Use bare `throw` to pass a caught error on unchanged, with its original `.File`, `.Line` and `.Stack`.

```ahk
#Requires AutoHotkey v2.0

; ✓ -1: .What = "ParsePort", .Line = the line that called ParsePort
ParsePort(text) {
    if !IsInteger(text)
        throw ValueError("Port must be an integer", -1, text)
    port := Integer(text)
    if port < 1 || port > 65535
        throw ValueError("Port out of range", -1, port)
    return port
}

; ✓ Bare throw inside catch re-throws the same value (stack info preserved)
ReadRequired(path) {
    try {
        return FileRead(path)
    } catch OSError as err {
        OutputDebug("ReadRequired failed: " err.Message)
        throw
    }
}

; ✓ Wrap a low-level error in a domain error; keep the original in Extra
LoadProfile(path) {
    try {
        return FileRead(path)
    } catch OSError as err {
        throw Error("Profile could not be loaded", -1, err.Message)
    }
}
```

## TIER 4 — OnError Global Handler
> METHODS COVERED: `OnError()` · `FormatTime()` · `FileAppend()` · `Type()` · `.Bind()`

`OnError` is the last line of defense for errors that nothing caught. Register it before the code it should cover. It is not called while a `try` is handling the error.

```ahk
#Requires AutoHotkey v2.0

OnError(LogUncaught)   ; ✓ register early; handlers run in registration order

LogUncaught(thrown, mode) {
    line := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    if thrown is Error
        line .= " [" Type(thrown) "] " thrown.Message " @ " thrown.File ":" thrown.Line
    else
        line .= " [thrown value] " String(thrown)
    try FileAppend(line "`n", A_ScriptDir "\crash.log", "UTF-8")
    if mode = "Return"
        return -1      ; continuable runtime error: keep the thread running
    return 1           ; suppress the default dialog; the thread still exits
}

; ✓ Remove when no longer needed
; OnError(LogUncaught, 0)

; ✓ Callback that needs only the error: end the parameter list with *
; OnError(ShowOnly)
; ShowOnly(err, *) => (MsgBox(err.Message), 1)
```

## DROP-IN RECIPES

```ahk
#Requires AutoHotkey v2.0

; RECIPE 1: SafeExecute — run a callable; return a result Map or re-throw
; ✓ Returns Map("ok", true, "value", result) on success
; ✓ With a fallback supplied, returns Map("ok", false, "value", fallback, "error", err)
SafeExecute(fn, fallback := unset) {
    if !HasMethod(fn)
        throw TypeError("SafeExecute: fn must be callable", -1, Type(fn))
    try {
        return Map("ok", true, "value", fn())
    } catch Error as err {
        if !IsSet(fallback)
            throw      ; re-throw: original File/Line/Stack kept
        return Map("ok", false, "value", fallback, "error", err)
    }
}
; outcome := SafeExecute(FileRead.Bind("config.txt"), "")

; RECIPE 2: SetupCrashLogger — dated log file, folder created on demand
SetupCrashLogger(logDir := A_ScriptDir "\logs") {
    if !DirExist(logDir)
        DirCreate(logDir)
    logPath := logDir "\crash_" FormatTime(, "yyyyMMdd") ".log"
    OnError(_CrashLogWrite.Bind(logPath))
    return logPath
}

_CrashLogWrite(logPath, err, mode) {
    msg := err is Error ? Type(err) ": " err.Message " @ " err.File ":" err.Line : String(err)
    try FileAppend(FormatTime(, "HH:mm:ss") " " msg "`n", logPath, "UTF-8")
    return 1   ; suppress the default dialog
}

; RECIPE 3: TypeAssert — exact Type() check reported at the caller's caller
; ✓ -2: the error points at the line that called the function using TypeAssert
TypeAssert(value, typeName, paramName := "param") {
    if Type(value) != typeName
        throw TypeError(paramName " must be " typeName "; got " Type(value), -2)
}
```

## SEE ALSO

> This module does NOT cover: v1→v2 syntax mistakes and syntax/runtime error diagnosis → see Module_ErrorDiagnosis.md
> This module does NOT cover: parameter guards and choosing TypeError vs ValueError for input → see Module_GuardClauses.md
> This module does NOT cover: COM exception propagation and HRESULT codes → see Module_COMAutomation.md

- `Module_ErrorDiagnosis.md` — common v1→v2 and syntax/runtime mistakes with their v2 fixes.
- `Module_GuardClauses.md` — type checks, `IsSet()`, duck typing and fail-early guards that throw the classes listed here.
- `Module_ClassBasics.md` — `extends`, `super.__New()` and class lifecycle, needed for custom error hierarchies.
- `Module_FileIO.md` — `OSError` handling for file I/O and file-handle cleanup.
- `Module_COMAutomation.md` — COM errors and `ComCall` failures.
