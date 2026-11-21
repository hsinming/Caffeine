# Module_GuardClauses.md
<!-- DOMAIN: Guard Clauses and Type Checks — is/Type()/Is* functions, IsSet and unset optional parameters, ?? and var?, fail-early guards with TypeError/ValueError, constructor guards, duck typing with HasMethod/HasProp -->
<!-- SCOPE: Business-rule validation (formats, passwords, filenames), environment pre-flight checks and the ValidationBuilder/FormValidator framework are in Module_ValidationRules.md. try/catch structure and custom Error classes are in Module_ExceptionHandling.md. Validator base-class design is in Module_ClassBasics.md. -->
<!-- TRIGGERS: validate, guard clause, type check, IsSet, "is Integer", "is Number", IsInteger, IsNumber, IsFloat, Type(), TypeError, ValueError, HasMethod, HasProp, HasBase, "duck typing", "fail early", "input validation", assert, precondition, "defensive programming", "parameter guard", "interface validation", "constructor guard", "__New validation", "unset parameter", "optional parameter default", "??", "coalescing" -->
<!-- CONSTRAINTS: `x is Integer` checks the class (a numeric string is NOT an Integer); IsInteger/IsNumber/IsFloat check whether a value is or looks like a number; `p?` equals `p := unset` and leaves the parameter without a value when omitted — reading it throws UnsetError, so test with IsSet(p) or use `p ?? fallback`; IsSet takes a variable, not a property; a negative What (e.g. -1) makes the error point at the line that called the current function; duck-type external objects with HasMethod/HasProp instead of exact Type() names. -->
<!-- CROSS-REF: Module_ValidationRules.md, Module_ExceptionHandling.md, Module_ClassBasics.md, Module_Instructions.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `if var is integer` (content check) | `IsInteger(var)` | v2 `is` checks the class: `"42" is Integer` is false. `IsInteger("42")` is true |
| `if var is number` | `IsNumber(var)` (content) or `var is Number` (pure number type) | Same split between content and type |
| `if (param = "")` to detect an omitted parameter | `if !IsSet(param)` with `param?` | v2 has real "unset"; `""` is a value |
| `IsFunc("Name")` | `HasMethod(value)` or `value is Func` | `IsFunc` was removed |

## API QUICK-REFERENCE

### Type Checks

| Check | Signature | True when |
|-------|-----------|-----------|
| `is` | `Value is Class` | `Value` is an instance of `Class` (any depth), same as `HasBase(Value, Class.Prototype)`. Works for `Integer`, `Float`, `Number`, `String`, `Object`, `Array`, `Map`, `Func` and user classes |
| `Type()` | `Type(Value)` | Returns the class name: `"Integer"`, `"Float"`, `"String"`, `"Array"`, `"Map"`, `"Func"`, `"BoundFunc"`, user class name, `"Object"`, `"Prototype"`, COM class |
| `IsInteger()` | `IsInteger(Value)` | Integer, or a purely numeric string (decimal or hex) without a decimal point; spaces/tabs around and a sign allowed; not empty |
| `IsFloat()` | `IsFloat(Value)` | Float, or a numeric string with a decimal point |
| `IsNumber()` | `IsNumber(Value)` | `IsInteger` or `IsFloat` is true |
| `IsObject()` | `IsObject(Value)` | Value is an object (including prototypes and COM objects), not a number or string |
| `IsSet()` | `IsSet(Var)` | The **variable** has a value. Not usable on properties or expressions |
| `IsSetRef()` | `IsSetRef(&Ref)` | The variable behind a VarRef has a value |
| `IsDigit()`, `IsAlpha()`, `IsSpace()`, `IsTime()` … | `IsAlpha(Value, Mode?)` | String pattern checks (see Module_StringFunctions.md) |

### Unset Parameters and Defaults

| Syntax | Meaning |
|--------|---------|
| `F(p?)` / `F(p := unset)` | `p` has no value when omitted |
| `F(p := 10)` | Default value when omitted |
| `p ?? fallback` | `p` if it has a value, otherwise `fallback` (left side must be a variable); no error for unset `p` |
| `p?` placement | The `?` must be followed by `)`, `]`, `}`, `,` or `:` (ignoring whitespace), so `MsgBox "x", title?` on its own line is invalid; write `MsgBox("x", title?)` |
| `G(p?)` inside `F` | Pass `p` on, still unset if it was omitted ("maybe" operator; valid for optional parameters, array elements, object literals, right side of `:=`) |

### Capability Probes

| Function | Signature | Notes |
|----------|-----------|-------|
| `HasMethod()` | `HasMethod(Value, Name?, ParamCount?)` | `Name` omitted = `"Call"` (is it callable?). `ParamCount` also checks `MinParams`/`MaxParams`/`IsVariadic` when present |
| `HasProp()` | `HasProp(Value, Name)` | Own or inherited property |
| `HasBase()` | `HasBase(Value, BaseObj)` | `BaseObj` is in the base chain |

### Error Classes for Guards

| Class | Use for | Constructor |
|-------|---------|-------------|
| `TypeError` | Wrong type | `TypeError(Message, What?, Extra?)` |
| `ValueError` | Right type, invalid value or range | `ValueError(Message, What?, Extra?)` |
| `TargetError` | Window/control not found | `TargetError(Message, What?, Extra?)` |
| `UnsetError` | (thrown automatically when reading a value that is not there) | — |

`What = -1` sets `.What` to the current function and `.Line` to the line that **called** it; `-2` goes one level higher. `Extra` should hold the bad value. Full list in Module_ExceptionHandling.md.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- `is` is a class test. `"5" is Integer` and `"5" is Number` are false; use `IsInteger`/`IsNumber` for text from GUIs, files, `InputBox` or `A_Args`.
  ✗ `if input is Integer` for GUI/file text → ✓ `IsInteger(input)`
- `x is String` is true only for real strings. `Type(x) = "String"` gives the same answer for primitives; either is fine.
- Reading a parameter declared `p?` when it was omitted throws `UnsetError`. Check `IsSet(p)` first, or use `p ?? fallback`. The `p = ""` wrong form is in V1 → V2 BREAKING CHANGES.
- `IsSet` accepts only a variable (`IsSet(p)`), not `IsSet(obj.Prop)`. For properties use `HasProp(obj, "Prop")`.
  ✗ `IsSet(this.Cache)` → ✓ `HasProp(this, "Cache")`
- Wrong types throw `TypeError`; wrong values throw `ValueError`; both pass `-1` as `What` and the bad value as `Extra` (see `### Error Classes for Guards`).
  ✗ `throw Error("bad type")` → ✓ `throw TypeError("expected Integer", -1, Type(x))` (convention)
  ✗ `throw ValueError("bad")` → ✓ `throw ValueError("bad", -1, value)`
- `HasMethod(v)` with no name tests whether `v` can be called (has a `Call` method). Prefer it over `v is Func` when any callable (BoundFunc, Closure, object with `Call`) should be accepted.
- A property implemented by `__Get` is not reported by `HasProp`; dynamic objects may need their own checks.
- Convention, not a language limit: validate at public or external boundaries (function APIs, user input, file data). Internal helpers may trust their callers' documented contract.
- Convention, not a language limit: in `__New`, finish all guards before the first `this.Prop :=` assignment so a failed guard leaves no half-built state behind (for example, state that `__Delete` or a registered callback could see).
- Convention, not a language limit: probe external objects with `HasMethod`/`HasProp` (duck typing) before use, rather than `Type(obj) = "ClassName"`, which rejects subclasses, or a `try`/`catch` probe.
  ✗ `Type(obj) = "MyClass"` → ✓ `HasMethod(obj, "Run")` or `obj is MyClass`
  ✗ `try obj.Run()` / `catch MethodError` → ✓ `HasMethod(obj, "Run")` first

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `UnsetError` | Reading an omitted `p?` parameter | Message names the variable | `IsSet(p)` or `p ?? fallback` |
| `MethodError` | Calling a method the object does not have | Message names the method | `HasMethod(obj, "Name")` guard → `TypeError` |
| `PropertyError` | Reading a property the object does not have | Message names the property | `HasProp(obj, "Name")` guard |
| `TypeError` (from a math operator) | Arithmetic on a non-numeric string from user input | `.What` is blank for expression errors | `IsNumber(text)` then `Number(text)` |
| Load-time error | `IsSet(obj.Prop)` | Script will not start | `HasProp(obj, "Prop")` |

## TIER 1 — Type Detection and Unset Parameters
> METHODS COVERED: `is` · `Type()` · `IsInteger()` · `IsNumber()` · `IsObject()` · `IsSet()` · `??` · `p?`

```ahk
#Requires AutoHotkey v2.0

; ✓ Class test vs content test
MsgBox (42 is Integer)          ; 1
MsgBox ("42" is Integer)        ; 0 — a string, even if it looks numeric
MsgBox IsInteger("42")          ; 1 — content test
MsgBox IsNumber(" 3.5 ")        ; 1 — spaces/tabs around are allowed

; ✓ Convert after checking text input
ParseCount(text) {
    if !IsInteger(text)
        throw ValueError("count must be a whole number", -1, text)
    return Integer(text)
}

; ✓ Class membership follows inheritance
class Shape {
}
class Circle extends Shape {
}
c := Circle()
MsgBox((c is Shape) " " Type(c))  ; "1 Circle"

; ✓ Optional parameters: IsSet, ?? and passing on with ?
Greet(name?, title?) {
    who := name ?? "friend"
    MsgBox("Hello, " who, title?)    ; title stays unset if omitted → MsgBox uses its default
}
Greet()
Greet("Ann", "Welcome")

ApplyDefaults(timeout?) {
    if IsSet(timeout) && !(timeout is Integer)
        throw TypeError("timeout must be Integer when given", -1, Type(timeout))
    return timeout ?? 3000
}

; ✗ if (timeout = "")   ; reading an unset parameter throws UnsetError
```

## TIER 2 — Guard Clauses for Functions and Constructors
> METHODS COVERED: `throw TypeError()` · `throw ValueError()` · `StrLen()` · `Trim()`

```ahk
#Requires AutoHotkey v2.0

; ✓ TypeError for the type, then ValueError for the value
SetVolume(level, channel := "master") {
    if !(level is Integer)
        throw TypeError("level must be Integer", -1, Type(level))
    if level < 0 || level > 100
        throw ValueError("level must be 0-100", -1, level)
    if !(channel is String) || Trim(channel) = ""
        throw ValueError("channel must be a non-blank string", -1, channel)
    ; inputs verified
}

; ✓ Arrays and Map-like objects
ProcessItems(items) {
    if !(items is Array)
        throw TypeError("items must be an Array", -1, Type(items))
    if items.Length = 0
        throw ValueError("items must not be empty", -1)
}

ProcessConfig(cfg) {
    if !HasMethod(cfg, "Has")
        throw TypeError("cfg must be Map-like (Has method)", -1, Type(cfg))
    if !cfg.Has("mode")
        throw ValueError("cfg needs a 'mode' key", -1)
}

; ✓ Constructor: all guards first, then assignments (convention)
class UserRecord {
    __New(name, age, email?) {
        if !(name is String) || Trim(name) = ""
            throw ValueError("name must be a non-empty string", -1, name)
        if !(age is Integer)
            throw TypeError("age must be Integer", -1, Type(age))
        if age < 0 || age > 150
            throw ValueError("age must be 0-150", -1, age)
        if IsSet(email) && !RegExMatch(email, "i)^[^@\s]+@[^@\s]+\.[a-z]{2,}$")
            throw ValueError("email format invalid", -1, email)

        this.Name  := name
        this.Age   := age
        this.Email := email ?? ""
    }
}

try {
    UserRecord("Ann", 200)
} catch ValueError as e {
    MsgBox "Rejected: " e.Message " (" e.Extra ")"
}
```

## TIER 3 — Duck Typing and Interface Checks
> METHODS COVERED: `HasMethod()` · `HasProp()` · `HasBase()` · `IsObject()`

Check what an object can do, not its class name.

```ahk
#Requires AutoHotkey v2.0

; ✓ Accept anything with a Process() method
RunProcessor(p) {
    if !HasMethod(p, "Process")
        throw TypeError("processor needs a Process() method", -1, Type(p))
    p.Process()
}

; ✓ Accept any callable (Func, BoundFunc, Closure, object with Call) that takes argCount arguments
EnsureCallable(fn, argCount := 0, name := "callback") {
    if !HasMethod(fn, , argCount)
        throw TypeError(name " must be callable with " argCount " argument(s)", -2, Type(fn))
}

; ✓ Accept objects that provide __Enum (Array, Map, custom enumerables)
EnsureIterable(x, name := "collection") {
    if !IsObject(x) || !HasMethod(x, "__Enum")
        throw TypeError(name " must be enumerable", -2, Type(x))
}

; ✓ Multi-member contract with one combined message
EnsureInterface(obj, methods, props := []) {
    if !IsObject(obj)
        throw TypeError("expected an object", -2, Type(obj))
    missing := []
    for m in methods
        if !HasMethod(obj, m)
            missing.Push("method " m)
    for p in props
        if !HasProp(obj, p)
            missing.Push("property " p)
    if missing.Length {
        list := ""
        for i, item in missing
            list .= (i > 1 ? ", " : "") item
        throw TypeError(Type(obj) " is missing: " list, -2)
    }
}

class TextRenderer {
    Name := "text"
    Process() => MsgBox("render text")
}
RunProcessor(TextRenderer())
EnsureInterface(TextRenderer(), ["Process"], ["Name"])
EnsureCallable((x) => x * 2, 1)

; ✗ if Type(obj) != "TextRenderer"   ; rejects subclasses and other valid implementations
```

## SEE ALSO

> This module does NOT cover: format rules, environment pre-flight checks and the fluent validator framework → see Module_ValidationRules.md
> This module does NOT cover: try/catch structure and custom Error classes → see Module_ExceptionHandling.md

- `Module_ValidationRules.md` — e-mail/password/filename rules, file/window/process pre-flight checks, `ValidationBuilder`.
- `Module_ExceptionHandling.md` — Error class hierarchy, `What`/`Extra`, catching guard errors.
- `Module_ClassBasics.md` — `__New` and class hierarchies used by `is` checks.
- `Module_Instructions.md` — core v2 syntax rules.
