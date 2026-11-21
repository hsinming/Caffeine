# Module_ReviewErrorHandling.md
<!-- DOMAIN: Code Review — Dimension 2: Error Handling & Type Safety -->
<!-- SCOPE: Review checklist for try/catch coverage, empty catch bodies, type guards on external data, and the throwing-vs-non-throwing operations table used during review, plus OnError and safe-wrapper recipes. The error class hierarchy and catch-clause semantics are in Module_ExceptionHandling.md (ahk-ctx-logic). -->
<!-- TRIGGERS: "is my error handling correct", "why does my script crash", "does X throw", "do I need try/catch", "empty catch", try, catch, OnError, FileRead(), FileOpen(), RegRead(), ComObject(), DllCall(), Download(), WinGetTitle(), SendMessage(), Integer(), Type(), IsInteger() -->
<!-- CONSTRAINTS: Wrap only operations whose docs say they throw. An empty catch that hides a failure is Critical (convention in Module_ExceptionHandling.md (ahk-ctx-logic)). OnError callbacks return 0/""/nothing to keep default handling, 1 to suppress the error dialog, -1 to also let a continuable thread continue. RegRead takes an optional Default that replaces the OSError for a missing key or value. There is no NameError class in v2. -->
<!-- CROSS-REF: Module_ReviewFramework.md, Module_ReviewPerformanceSecurity.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Throwing Operations Reference

Each row is from the function's "Error Handling" section in the v2 docs.

| Category | Throws (wrap when failure is possible) | Docs |
|----------|----------------------------------------|------|
| File I/O | `FileRead()` — OSError on open/read failure; `FileOpen()` — OSError if the file cannot be opened; `FileAppend()` — OSError; `FileDelete()` — Error if any file could not be deleted (`Extra` = failure count) | lib/FileRead.htm, lib/FileOpen.htm, lib/FileAppend.htm, lib/FileDelete.htm |
| Registry | `RegRead()` — OSError for a missing key/value **only when Default is omitted**, or on permission errors; `RegWrite()`, `RegDelete()` — OSError | lib/RegRead.htm |
| Regex | `RegExMatch()` / `RegExReplace()` — Error on a pattern syntax error ("Compile error N at offset M") or a PCRE execution error | lib/RegExMatch.htm |
| Process | `ProcessGetPath()` / `ProcessGetName()` — TargetError if the process is not found, OSError if the name/path cannot be read | lib/ProcessGetName.htm |
| Network | `Download()` — exception on failure (a server error page can still "succeed") | lib/Download.htm |
| DLL | `DllCall()` — Error (DLL or function not found), TypeError/ValueError (bad arg types), OSError (HRESULT failure) | lib/DllCall.htm |
| COM | `ComObject()`, `ComObjQuery()` — exception on failure (e.g. unsupported interface) | lib/ComObject.htm, lib/ComObjQuery.htm |
| Windows | `WinGetTitle()`, `WinGetPID()`, `WinGetClass()`, `WinActivate()` — TargetError if the window is not found | lib/WinGetTitle.htm, lib/WinActivate.htm |
| Messaging | `SendMessage()` — TargetError (no window/control), TimeoutError (timed out), OSError (could not send) | lib/SendMessage.htm |
| Conversion | `Integer()` — TypeError if the value cannot be converted | lib/Integer.htm |
| Dialogs | `MsgBox()` — Error only for invalid options, more than 7 nested calls, or if the box cannot be shown | lib/MsgBox.htm |

Do **not** require try/catch for ordinary `MsgBox()`, `ToolTip()`, `Sleep()`,
`Send()`, `OutputDebug()`, `StrLen()`, `StrReplace()`, or `WinActive()`
(returns the HWND or 0; no TargetError). Wrapping them fabricates a risk. `InStr()`
is not on this list: it throws ValueError for an empty Needle, an invalid
CaseSense, or an Occurrence/StartingPos of 0 (lib/InStr.htm), so validate the arguments.

### Functions Referenced in Dimension 2

- **`FileRead(Filename, Options?)`** — returns a String, or a Buffer with the `RAW` option | OSError
- **`FileOpen(Filename, Flags, Encoding?)`** — returns a File object | OSError | The file closes when the object is freed, but the docs recommend closing it as soon as possible
- **`RegRead(KeyName?, ValueName?, Default?)`** — returns String or Integer | OSError unless Default is given
- **`ComObject(CLSID, IID?)`** — returns a COM wrapper object | exception on failure
- **`Type(Value)`** — exact type name (`"Map"`, `"Array"`, `"Integer"`, `"String"`, ...)
- **`IsObject(Value)`** — true for any object
- **`IsInteger(Value)`** — true for an integer or a purely numeric string without a decimal point
- **`Integer(Value)`** — TypeError if not convertible; `IsNumber()` tells whether conversion will succeed
- **`InputBox(Prompt?, Title?, Options?, Default?)`** — returns an object with `.Value` and `.Result` (`"OK"`, `"Cancel"`, `"Timeout"`)
- **`OnError(Callback, AddRemove?)`** — callback `(Thrown, Mode)`; returns 0/"" (default handling), 1 (suppress dialog and remaining callbacks), or -1 (as 1, and continue the thread when Mode is `Return`). Not called while `try` is active

## AHK V2 CONSTRAINTS

- The empty `catch` convention is in `Module_ExceptionHandling.md` (ahk-ctx-logic).
  Review severity: an empty `catch` body that hides a failure is **🔴 Critical**.
  Surface `e.Message` (and `e.Extra` when useful), rethrow, or apply a stated fallback.
  - ✗ `catch { }` — failure is invisible
  - ✓ `catch as e { OutputDebug(e.Message) }`
  - An empty catch with a comment that states an intentional fallback is a
    judgement call, not automatically Critical.
- Never flag the non-throwing calls listed above as needing try/catch.
- A thrown value that no `try` catches and no `OnError` callback handles shows the
  default error dialog and ends the thread (lib/OnError.htm, Error Modes).
- There is no `NameError` in v2. Reading a variable with no value throws
  `UnsetError`; reading a missing property throws `PropertyError` (lib/Error.htm).

## TIER 2 — Error Handling & Type Safety
> METHODS COVERED: `FileRead()` · `ComObject()` · `RegRead()` · `InputBox()` · `Type()` · `IsObject()` · `IsInteger()` · `Integer()`

```ahk
; CHECK 1: try/catch around operations that throw
; ✗ FileRead throws OSError if the file is missing; the thread ends with an error dialog
ReadFileUnguarded(path) {
    return FileRead(path)               ; 🔴 Critical when the file may be absent
}

; ✓
ReadFileGuarded(path) {
    try {
        return FileRead(path)
    } catch as e {
        OutputDebug("ReadFileGuarded: " e.Message)
        return ""
    }
}

; ----------------------------------------------------------------
; CHECK 2: catch must not swallow the failure
; ✗
; try {
;     xl := ComObject("Excel.Application")
; } catch {
; }
; ✓
try {
    xl := ComObject("Excel.Application")
} catch as e {
    MsgBox("COM init failed: " e.Message, "Error", 0x10)
}

; ----------------------------------------------------------------
; CHECK 3: Validate external data before arithmetic
; ✓ RegRead's Default replaces the OSError for a missing value
timeout := RegRead("HKCU\Software\MyApp", "Timeout", "30")
timeoutMs := IsInteger(timeout) ? Integer(timeout) * 1000 : 30000

; ----------------------------------------------------------------
; CHECK 4: Guard empty or cancelled input
answer := InputBox("Enter pattern:", "Search")
if (answer.Result != "OK" || answer.Value = "")
    ExitApp()
pos := InStr(answer.Value, "target")

; ----------------------------------------------------------------
; CHECK 5: Runtime type checks
; ✗ typeof() is not a v2 built-in
; ✓
obj := Map()
if (Type(obj) = "Map")
    OutputDebug("is a Map")
if IsObject(obj)
    OutputDebug("is some object")
```

## RUNTIME ERROR MAPPING

| Exception | Trigger | Review signal | Fix |
|-----------|---------|---------------|-----|
| `OSError` | `FileRead`/`FileOpen`/`RegRead` (no Default) on a missing target | Call not in `try` | try/catch, or `RegRead(..., Default)` |
| `TargetError` | `WinGetTitle`/`WinGetPID`/`WinGetClass`/`WinActivate` with no matching window | Call not in `try`, window may be absent | Wrap, or test `WinExist()` first |
| `TimeoutError` | `SendMessage` not processed in time (default 5000 ms) | Call to a possibly hung window | Wrap; pass an explicit Timeout |
| `TypeError` | `Integer("abc")`; wrong DllCall arg type | Converting external text | Check `IsNumber()`/`IsInteger()` first |
| `UnsetError` | Reading a variable that was never assigned | Often an earlier `=` that compared | See Module_ReviewV2Syntax.md |

## DROP-IN RECIPES

```ahk
; Recipe 1: CompliantScriptBootstrap — header for fixing Dim 1/2 findings
#Requires AutoHotkey v2.0
#SingleInstance Force

OnError(GlobalErrHandler)

GlobalErrHandler(err, mode) {
    MsgBox("Unhandled error: " err.Message "`nLine: " err.Line "`nFile: " err.File
        , "Script Error", 0x10)
    ; 1 = suppress the default dialog; -1 = same, and continue if the error is continuable
    return InStr(mode, "Return") ? -1 : 1
}
```

```ahk
; Recipe 2: SafeThrowingOp — surface the failure, keep the call site simple
SafeFileRead(path, encoding := "UTF-8") {
    try
        return FileRead(path, encoding)
    catch OSError as e
        throw Error("SafeFileRead failed: " e.Message " | path: " path, -1)
}

; RegRead with a fallback needs no try: Default replaces the OSError for a
; missing key/value (permission errors still throw)
timeout := RegRead("HKCU\Software\MyApp", "Timeout", "30")
```

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| Fabricated throw | try/catch around `ToolTip`, `Sleep`, `WinActive` | No wrapper | Defensive-programming habit |
| Silent catch | `catch { }` | `catch as e { OutputDebug(e.Message) }` | Hiding noise during development |
| try around RegRead just for a default | `try v := RegRead(k, n) catch v := "30"` | `v := RegRead(k, n, "30")` | Unaware of the Default parameter |
| Inventing error classes | "throws NameError" | `UnsetError`, `PropertyError`, `MethodError` | Python vocabulary |

## SEE ALSO

- `Module_ReviewFramework.md` — severity scale and report format
- `Module_ReviewPerformanceSecurity.md` — dynamic regex and untrusted input
- `Module_ExceptionHandling.md` (ahk-ctx-logic) — error class hierarchy and catch semantics
