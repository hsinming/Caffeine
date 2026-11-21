# Module_ErrorDiagnosis.md
<!-- DOMAIN: Error Diagnosis — v1→v2 migration mistakes, load-time (syntax) errors, common runtime errors and their v2 fixes -->
<!-- SCOPE: try/catch/finally, throw, Error classes, custom exceptions and OnError are in Module_ExceptionHandling.md. Timer-specific failures are in Module_Timers.md. COM HRESULT errors and deep GUI event-binding diagnostics are not covered — see Module_COMAutomation.md and Module_GuiBasics.md. -->
<!-- TRIGGERS: debug, crash, "syntax error", "load-time error", "runtime error", "not working", "script won't run", "unknown command", "variable not assigned", "has not been assigned a value", ErrorLevel, UnsetError, "v1 to v2 migration", "old script broken", "unexpected behavior", "new keyword", "#If", "Loop Parse", "percent signs", "this is unset", "too few parameters", "missing operator" -->
<!-- CONSTRAINTS: `x = value` as a statement is not an assignment in v2 (legacy assignment was removed) — use `:=`; inside an expression `=` is a case-insensitive comparison; there are no commands, only function call statements, so text arguments must be quoted and no comma follows the function name; `ErrorLevel` is not set by v2 built-ins; `new ClassName()` is not v2 syntax — call `ClassName()`; there must be no space between a function name and `(` in an expression call; functions are assume-local, so a global that is assigned inside a function needs a `global` declaration. -->
<!-- CROSS-REF: Module_ExceptionHandling.md, Module_Timers.md, Module_Instructions.md, Module_ClassBasics.md, Module_GuiBasics.md, Module_ContainerChoice.md, Module_HotkeysAndHotstrings.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `x = 5 + 2` (legacy assignment) | `x := 5 + 2` | Legacy `var = value` was removed. Inside an expression, `=` is a case-insensitive comparison, so `y := x = 5` stores 0/1 |
| `MsgBox Hello, World!` / `Run notepad.exe` | `MsgBox "Hello, World!"` / `Run "notepad.exe"` | All parameters are expressions — unquoted words are read as variable names |
| `SetTimer, MyFunc, 2000` | `SetTimer MyFunc, 2000` or `SetTimer(MyFunc, 2000)` | No comma is allowed between a function name and its parameters |
| `MsgBox % "Value: " Var` / `"Value: %Var%"` | `MsgBox "Value: " Var` | No `%` expression prefix; `%` inside quotes is literal text. `%Expr%` outside quotes is a dynamic (double-deref) reference |
| `#If WinActive("Title")` | `#HotIf WinActive("Title")` | `#If` does not exist in v2 |
| `if ErrorLevel` after a call | `try`/`catch`, or test the return value | v2 built-ins do not set `ErrorLevel`; failures throw or are reported by return value |
| `obj := new MyClass()` | `obj := MyClass()` | v2 creates instances by calling the class; `new` is not an operator |
| `Gui, Add, Edit, vMyEdit` | `g := Gui()`, `g.Add("Edit", "vMyEdit")`, `g.Show()` | GUI is object-based in v2 |
| `Loop, Parse, Str, CSV` | `Loop Parse Str, "CSV"` or `for part in StrSplit(Str, ",")` | Loop Parse still exists, but with v2 parameter syntax |
| `Func("MyFunc")` | `MyFunc` | Use the function name directly as a function object |
| `if var is integer` (content check) | `IsInteger(var)` | v2 `is` checks the class (`"5" is Integer` is false); `IsInteger` checks if a string looks like an integer |

## API QUICK-REFERENCE

### Symptom → Cause Index

| Symptom | Probable cause | Fix (see TIER) |
|---------|----------------|----------------|
| Load-time error on a line like `x = 5` | Legacy assignment | `x := 5` (TIER 1) |
| `UnsetError` "has not been assigned a value" for a word you meant as text | Unquoted text argument | Quote it (TIER 1) |
| `UnsetError` for a global inside a function | The function assigns the name, so it is local | `global name` (TIER 2) |
| Value from `return` is empty | Value is on the next line after `return` | Same line: `return total` (TIER 2) |
| Second statement runs even when `if` is false | Missing braces around a multi-line body | Add `{ }` (TIER 2) |
| `ValueError` "Invalid callback function" from the `SetTimer`/`OnError` call | Unbound method passed as callback | `.Bind(obj)` / `ObjBindMethod` (TIER 3) |
| Method sees the wrong object as `this` in a GUI event | Unbound method — `this` receives the GuiControl | Bind the method (TIER 3) |
| `IndexError` on `arr[0]` | Arrays are 1-based | Start at 1 (TIER 3) |
| Keys go to the wrong window | Plain `Send` with no target | `WinActivate` + `WinWaitActive`, or `ControlSend` (TIER 4) |
| `OSError` on another user's machine | Hard-coded path | `A_ScriptDir`, `A_MyDocuments`, `FileSelect` (TIER 4) |

### Built-ins Used in Fixes

| Function | Signature | Notes |
|----------|-----------|-------|
| `IsSet()` | `IsSet(Var)` | 1 if the variable has a value; works on variables only, not properties |
| `StrSplit()` | `StrSplit(String, Delimiters?, OmitChars?, MaxParts?)` | Returns an Array |
| `WinWaitActive()` | `WinWaitActive(WinTitle?, WinText?, Timeout?, ...)` | Returns the HWND, or 0 on timeout (no throw) |
| `ControlSend()` | `ControlSend(Keys, Control?, WinTitle?, ...)` | Throws `TargetError` if the window/control is not found |
| `FileSelect()` | `FileSelect(Options?, RootDir?, Title?, Filter?)` | Returns `""` if cancelled |
| `ProcessExist()` | `ProcessExist(PIDOrName?)` | PID or 0 |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 form from V1 → V2 BREAKING CHANGES remains: `%Var%` inside quoted strings, a comma after a function name, `new`, `#If`, `ErrorLevel`, `Func("name")`, `is` as a content test, or v1 command syntax.
- `:=` assigns. A line `x = 5` is not an assignment in v2. Inside an expression, `=` compares case-insensitively and `==` compares case-sensitively.
- There are no commands, only function call statements. Parentheses may be omitted when the return value is not needed (`MsgBox "Hi"`). All parameters are expressions, so text must be quoted.
- In an expression call there must be no space between the function name and `(`. As a statement, `MsgBox ("Hi")` is a call statement whose single argument is the parenthesized expression `("Hi")`.
  ✗ `x := StrLen ("abc")` → ✓ `x := StrLen("abc")`
- Functions are assume-local. A function can read a global without declaring it, but if it assigns the name anywhere, the name is local throughout the function unless declared `global`. Declare every global a function assigns.
- Reading a variable that has no value throws `UnsetError`. Use `IsSet(Var)` to test first.
- `return` takes its value on the same line. A value on the next line is a separate statement.
- A fat-arrow function `=>` has exactly one expression as its body. `() => { a(); b() }` is not a block; braces there would start an object literal. Use a named (or nested) function for several statements.
- Method definitions have a hidden first parameter `this`. Passing `obj.Method` without binding means the first argument the caller passes becomes `this`. Bind every method passed as a callback (`.Bind(obj)` or `ObjBindMethod`).
  ✗ `SetTimer this.Tick, 1000` → ✓ `SetTimer this.Tick.Bind(this), 1000`
- Arrays are 1-based. Index 0, or an index whose absolute value is greater than `Length`, throws `IndexError`. Negative indexes count from the end.
  ✗ `arr[0]` → ✓ `arr[1]`
- Convention, not a language limit: start every script with `#Requires AutoHotkey v2.0`.
- Convention, not a language limit: this repo uses `Map()` for key/value data; object literals are valid v2 syntax for fixed property sets.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `UnsetError` | Reading an unassigned variable (often a misspelt name, an unquoted word, or `ErrorLevel`) | Message: variable "has not been assigned a value" | Assign it, quote the text, or test with `IsSet()` |
| `TypeError` / `UnsetError` | A non-VarRef passed to an output parameter, e.g. `MouseGetPos(x, y)` (`UnsetError` first if `x` has no value) | Message mentions the parameter or variable | Use `&`: `MouseGetPos(&x, &y)` |
| `ValueError` ("Invalid callback function") | Unbound method (hidden `this`) passed to `SetTimer`/`OnError`/`OnMessage`/`OnEvent` when its parameters cannot take the arguments the caller supplies | Thrown by the registering call, not when the callback fires | Bind: `this.Tick.Bind(this)` |
| `MethodError` | Calling a value that has no `Call` method, or a method that does not exist | Message names the method | `HasMethod(obj, "Name")` or fix the name |
| `IndexError` | `arr[0]` or index beyond `Length` | Message mentions the index | Use `1..Length`, or check `arr.Length` |

## TIER 1 — Assignment, Call Syntax, Quoting and Percent Signs
> METHODS COVERED: `MsgBox()` · `Run()` · `A_Clipboard` · `A_ScreenWidth`

These are load-time or first-run failures caused by v1 habits.

```ahk
#Requires AutoHotkey v2.0

; ✓ := is assignment
x := 5 + 2

; ✗ x = 5 + 2          ; v1 legacy assignment — not valid as a v2 assignment
; ✗ y := x = 7         ; valid v2, but stores the comparison result (1 or 0)

; ✓ Text arguments are quoted; parentheses optional for a call statement
MsgBox "Hello, World!"
MsgBox("Hello, World!")
Run 'notepad.exe "' A_ScriptDir '\readme.txt"'

; ✗ MsgBox Hello, World!   ; unquoted words are variable references
; ✗ SetTimer, MyFunc, 2000 ; comma after the function name is not allowed

; ✓ Expression call: no space before (
result := StrLen("abc")
; ✗ result := StrLen ("abc")  ; space before ( — not parsed as a function call

; ✓ Variables are used directly; concatenate with a space or .
name := "Ann"
MsgBox "Hi " name
MsgBox "Progress: 50%"        ; % inside quotes is literal

; ✗ MsgBox "Hi %name%"      ; shows the literal text %name%

; ✓ Two quoted strings next to each other are auto-concatenated into ONE argument
MsgBox "Hello" " World"       ; one argument: "Hello World"
MsgBox "Hello", "Title"       ; two arguments: text and title

; ✓ Built-in variables keep the A_ prefix
A_Clipboard := "copied"
width := A_ScreenWidth
; ✗ Clipboard := "copied"   ; just creates a normal variable named Clipboard
```

## TIER 2 — Scope, Blocks, Return and Fat Arrows
> METHODS COVERED: `global` · `IsSet()` · `=>`

```ahk
#Requires AutoHotkey v2.0

; ✓ A function or hotkey that ASSIGNS a global must declare it
counter := 0
F1:: {
    global counter
    counter += 1
}
; ✗ Without "global counter", counter is local here and += reads an unset local → UnsetError

; ✓ Reading only (no assignment anywhere in the function) resolves to the global
ShowCounter() => MsgBox(counter)

; ✓ IsSet() tests a variable before reading it
GetCache() {
    static cache
    if !IsSet(cache)
        cache := Map()
    return cache
}

; ✓ Braces for multi-line bodies
if (counter > 10) {
    MsgBox "High"
    MsgBox "Done"
}
; ✗ Without braces only the first line belongs to the if

; ✓ return and its value on the same line
Total(a, b) {
    return a + b
}
; ✗ return
;   a + b           ; separate statement — the function returns ""

; ✓ Fat arrow: one expression only
double := (n) => n * 2
logBoth := (msg) => (OutputDebug(msg), MsgBox(msg))   ; comma operator: still one expression

; ✓ Several statements: use a function with a block body
HandleClick(*) {
    MsgBox "Hi"
    OutputDebug "clicked"
}
; ✗ onClick := () => { MsgBox("Hi"); DoMore() }   ; not a block body in v2.0
```

## TIER 3 — Operators, Loops, Arrays and Callback Binding
> METHODS COVERED: `StrSplit()` · `Loop Parse` · `Loop Read` · `.Bind()` · `ObjBindMethod()`

```ahk
#Requires AutoHotkey v2.0

text := "a,b,c"

; ✓ == is case-sensitive, = is case-insensitive
if (text == "A,B,C")
    MsgBox "never shown"
if (text = "A,B,C")
    MsgBox "shown"

; ✓ Two v2 ways to split
for i, part in StrSplit(text, ",")
    OutputDebug i ": " part
Loop Parse text, ","
    OutputDebug A_Index ": " A_LoopField

; ✓ Line-by-line file reading (v2 parameter syntax, no comma after Read)
Loop Read A_ScriptDir "\data.txt"
    OutputDebug A_LoopReadLine
; ✗ for line in FileOpen("data.txt")   ; File objects cannot be enumerated by for

; ✓ Arrays are 1-based; -1 is the last element
parts := StrSplit(text, ",")
first := parts[1]
last  := parts[-1]
; ✗ parts[0]   ; IndexError

; ✓ Bind the receiver when passing a method as a callback
class Clock {
    __New() {
        this.Ticks := 0
        this.TickFn := this.Tick.Bind(this)       ; store it so it can be cancelled later
        SetTimer this.TickFn, 1000
    }
    Tick() => this.Ticks++
}
; ✗ SetTimer this.Tick, 1000
;   ; the timer calls Tick with no arguments, but Tick needs its hidden this → SetTimer throws ValueError at once

; ✓ ObjBindMethod binds by name
; myButton.OnEvent("Click", ObjBindMethod(app, "OnClick"))
; ✗ myButton.OnEvent("Click", app.OnClick)   ; this receives the GuiControl, not app
```

## TIER 4 — Directives, GUI, Send Targeting, Paths and Blocking Calls
> METHODS COVERED: `#HotIf` · `Gui()` · `Send()` · `ControlSend()` · `WinActivate()` · `WinWaitActive()` · `FileSelect()` · `Run()` · `SetTimer()`

```ahk
#Requires AutoHotkey v2.0

; ✓ Context-sensitive hotkeys use #HotIf
#HotIf WinActive("ahk_exe notepad.exe")
F2::MsgBox "Notepad is active"
#HotIf

; ✓ Object-based GUI
g := Gui(, "Title")
g.Add("Edit", "vMyEdit w200")
g.Show()

; ✓ Keys are a quoted string
Send "{Media_Play_Pause}"
; ✗ Send {Media_Play_Pause}   ; braces outside quotes are object-literal syntax

; ✓ Make sure the target is active before Send, or send to the control directly
if WinExist("ahk_exe notepad.exe") {
    WinActivate "ahk_exe notepad.exe"
    if WinWaitActive("ahk_exe notepad.exe", , 2)   ; returns 0 on timeout
        Send "Hello"
}
try ControlSend "Hello", "Edit1", "ahk_exe notepad.exe"   ; TargetError if not found

; ✓ Build paths from built-in variables or ask the user
cfg := A_ScriptDir "\settings.ini"
picked := FileSelect(1, , "Select config file")
if picked != ""
    MsgBox FileRead(picked)
; ✗ FileRead("C:\Users\Alice\config.txt")   ; OSError on any other machine

; ✓ Start a process and poll for completion so the current thread can return
Run "notepad.exe", , , &pid
SetTimer WatchProcess.Bind(pid), 500
WatchProcess(targetPid) {
    if !ProcessExist(targetPid) {
        SetTimer , 0                 ; delete the timer that launched this thread
        MsgBox "Process finished"
    }
}
; Note: RunWait pauses only the current thread. Hotkeys, timers and menu items
; can still start new threads while it waits (lib/Run.htm).
```

## TIER 5 — Version, Removed Features and Busy Loops
> METHODS COVERED: `#Requires` · `try` · `Map()` · `Sleep()`

```ahk
#Requires AutoHotkey v2.0   ; convention: first line of every v2 script

; ✓ Failures throw — no ErrorLevel
try {
    content := FileRead("missing.txt")
} catch OSError as err {
    MsgBox "Error: " err.Message
}
; ✗ FileRead("missing.txt")
;   if ErrorLevel        ; ErrorLevel is never set by v2 built-ins

; ✓ Create instances by calling the class
class Settings {
    __New() {
        this.Theme := "dark"
    }
}
s := Settings()
; ✗ s := new Settings()

; ✓ Object literal: valid v2 for fixed property sets
pt := {x: 10, y: 20}
; ✓ Map: dynamic or string keys, with Has/Get/Delete
opts := Map("theme", "dark", "volume", 80)
; ✗ bad := {x}         ; no "name:" before the value — load-time error

; ✓ Skip an optional parameter with an empty slot
MsgBox "Text", , "Iconi"      ; Title omitted

; ✓ A polling loop needs an exit condition; Sleep lets other threads run
tries := 0
while (tries < 100 && !WinExist("ahk_exe notepad.exe")) {
    tries++
    Sleep 50
}
; ✗ while true { }   ; never ends, uses a full CPU core
```

## SEE ALSO

> This module does NOT cover: try/catch/finally, Error classes, custom exceptions and OnError → see Module_ExceptionHandling.md
> This module does NOT cover: timer lifecycle and callback errors in depth → see Module_Timers.md
> This module does NOT cover: GUI event-binding diagnostics in depth → see Module_GuiBasics.md

- `Module_ExceptionHandling.md` — catching and throwing the errors diagnosed here.
- `Module_Timers.md` — SetTimer, bound callbacks and timer cleanup.
- `Module_Instructions.md` — core v2 syntax rules.
- `Module_ClassBasics.md` — class definitions, `__New`, `super`.
- `Module_ContainerChoice.md` — Map vs Object decision guide.
- `Module_HotkeysAndHotstrings.md` — `#HotIf`, hotkeys and Send modes.
