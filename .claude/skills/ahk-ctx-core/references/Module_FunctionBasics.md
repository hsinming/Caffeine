# Module_FunctionBasics.md
<!-- DOMAIN: Function basics — named function declaration, calling syntax, parameters (default, unset, variadic, ByRef), variable scope (local, global, static) in AHK v2 -->
<!-- SCOPE: Nested functions, closures, Func object API, multi-return and dispatch recipes are in Module_FunctionObjects.md. Fat-arrow syntax is in Module_FatArrowFunctions.md. Class methods are in Module_ClassBasics.md. DLL/COM callbacks are in Module_CallbacksAndMessages.md. -->
<!-- TRIGGERS: function, "define function", "declare function", parameter, "optional param", "default value", unset, "?", IsSet(), IsSetRef(), ByRef, "&", VarRef, "by reference", "output param", variadic, "*", "spread args", global, local, static, "variable scope", "return value" -->
<!-- CONSTRAINTS: No space between a function name and "(" in a call expression. Functions are assume-local: a variable that is assigned inside the function is local unless declared global; globals that are only read need no declaration. A ByRef parameter (&p) requires the caller to pass a VarRef (&var). Reading an unset parameter (p?) throws; guard it with IsSet(). All parameters to the right of the first optional parameter must also be optional; the variadic parameter (*) must be last. -->
<!-- CROSS-REF: Module_FunctionObjects.md, Module_FatArrowFunctions.md, Module_ClassBasics.md, Module_ExceptionHandling.md, Module_ArrayBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `ByRef varName` keyword in parameter definition | `&varName` prefix on parameter | Load-time error — the `ByRef` keyword does not exist in v2 |
| `MyFunc(x)` for a ByRef parameter | `MyFunc(&x)` — caller passes a VarRef | Passing something other than a VarRef to a ByRef parameter is an error |
| `FuncName (args)` with space before `(` in an expression | `FuncName(args)` — name and `(` adjacent | Not a call: in an expression the space makes it auto-concatenation of `FuncName` and `(args)` |
| `if param == ""` to detect an absent argument | `param?` (or `param := unset`) in the signature + `IsSet(param)` | Without `?`/`:=`, the parameter is required; an omitted `?` parameter has no value and reading it throws |
| `Func("MyFunc")` to get a function reference | `MyFunc` (the function name is a read-only variable holding the Func) | `Func("Name")` lookup by name is not v2 code |
| `%varName%` deref inside expressions | Use the variable directly | Percent-deref of plain variables is v1 syntax; in v2 `%expr%` is for dynamic names and for dereferencing a VarRef |

## API QUICK-REFERENCE

### Parameter Modifier Syntax

| Modifier | Form | Notes |
|----------|------|-------|
| Default value | `param := expr` | Default may be a literal or an expression evaluated each time the default is needed (e.g. `X := []` creates a new Array per call) |
| Unset / optional | `param?` or `param := unset` | Caller may omit; the parameter then has no value — check with `IsSet(param)` before reading |
| Variadic collector | `params*` | Collects surplus arguments into an Array (1-based); only the final parameter may be variadic; a bare `*` accepts surplus arguments without storing them |
| ByRef | `&param` | Caller passes a VarRef (`&var`); the parameter is an alias for the caller's variable |
| Optional ByRef | `&param := default` | When the caller omits it, the function uses a local variable holding the default |

### Parameter Order Rule

All parameters to the right of the first optional parameter must also be optional; the variadic parameter must be last. `:=` and `?` parameters may be interleaved. Optional parameters can be omitted from the middle of a call: `MyFunc(1,, 3)`.

| Position | Modifier | Example |
|----------|----------|---------|
| First | Required | `req` |
| After first optional | Optional only (`:=` or `?`) | `opt := 0`, `maybe?` |
| Last | Variadic | `rest*` |

### Scope Declaration Keywords

| Keyword | Form | Notes |
|---------|------|-------|
| `global` | `global VarName` or `global VarName := init` | Needed to **assign** a global (or use `&` on it) inside a function; a global that is only read needs no declaration |
| `static` | `static VarName := init` | Value persists between calls; the initializer runs only the first time execution reaches it |
| `local` | `local VarName` | Forces a local; required for locals inside an assume-global function |
| Assume-global | first line of body is `global` | All undeclared variables are global (except parameters) |
| Assume-static | first line of body is `static` | All undeclared locals are static (except parameters) |

Declarations take effect for the whole function even inside an `if` block (initializers stay conditional).

### IsSet / IsSetRef

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `IsSet()` | `IsSet(Var)` | 1 or 0 | Takes a variable directly (not a property or expression). Use for `?` parameters and lazy init of globals/statics |
| `IsSetRef()` | `IsSetRef(&Ref)` | 1 or 0 | Checks the variable a VarRef points to, typically a non-ByRef parameter holding a VarRef. Inside a ByRef (`&p`) function use `IsSet(p)` |

### Built-in Functions Referenced in Examples

| Function | Signature | Returns | Throws | Notes |
|----------|-----------|---------|--------|-------|
| `StrSplit()` | `StrSplit(String, Delimiters?, OmitChars?, MaxParts?)` | Array | — | 1-based Array of substrings |
| `Integer()` | `Integer(Value)` | Integer | TypeError | Thrown if the value cannot be converted |
| `Float()` | `Float(Value)` | Float | TypeError | Thrown if the value cannot be converted |
| `Trim()` | `Trim(String, OmitChars?)` | String | — | Default removes spaces and tabs |
| `FileAppend()` | `FileAppend(Text, Filename?, Options?)` | — | OSError | Options can name the encoding, e.g. `"UTF-8"` |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **No space between the function name and `(` in a call expression.** `Square (7)` inside an expression is auto-concatenation, not a call. At the start of a line, a function call statement may omit the parentheses: `MsgBox "Hi"` — then the rest of the line is the parameter list.
  ✗ `result := Square (7)` — not a function call → ✓ `result := Square(7)`

- **Functions are assume-local.** A variable that is assigned (or used with `&`) inside a function is local unless declared `global`. A global that is only read resolves to the global without a declaration.
  ✗ `Inc() { gCount += 1 }` — `gCount` is a new local with no value; reading it throws UnsetError → ✓ `Inc() { global gCount; gCount += 1 }`
  - `#Warn LocalSameAsGlobal` reports undeclared locals that share a global's name; it is the only `#Warn` check that is off by default.

- **ByRef needs a VarRef from the caller.** `Swap(&a, &b)` must be called as `Swap(&x, &y)`. Passing a plain value to a ByRef parameter is an error. Properties (`obj.prop`) and built-in variables cannot be passed ByRef.

- **Unset parameters must be checked before reading.** Reading a `p?` parameter that was omitted throws an UnsetError, like any uninitialized variable. Use `IsSet(p)`, or pass it through with the maybe operator: `MsgBox("Hi", title?)`.
  ✗ `return name " " age` with `age?` unchecked → ✓ `if !IsSet(age) ...` first

- **`return` without a value returns an empty string.** A function that reaches its closing brace without `return` also returns `""`. `return` and its value belong on the same line.

- **`static` initializers run once.** After a static initializer is successfully evaluated it is removed from the flow of control; do not use `static` for values that must reset each call.
  ✗ `static result := ""` for a value that must reset → ✓ `result := ""` (plain local)

- **Parameter order:** required parameters come before the first optional one, and the variadic parameter is last. See `### Parameter Order Rule`.
  ✗ `F(a := 1, b)` → ✓ `F(b, a := 1)`, or make `b` optional

- **Variadic calls need parentheses.** `fn(arr*)` spreads an Array (or any enumerable). Only the right-most argument can be spread, and function call statements (without parentheses) cannot be variadic.

Safe-access priority order for optional parameters:
  1. `:=` default value — no guard needed in the body
  2. `param?` + `IsSet(param)` — when absent vs present needs different logic
  3. `param?` passed on with `param?` — forward "maybe absent" to another function
  4. `&param := default` — optional ByRef output parameter

- **Naming (convention, not a language rule):** prefixes like `Get*`, `Is*`, `Set*` should tell the reader whether a function reads, tests, or mutates; keep side effects (logging, file writes) out of `Get*`/`Is*` functions.
  ✗ `GetUser()` that also writes a log → ✓ `GetUser()` + `LogAccess()`

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `UnsetError` | Reading an omitted `?` parameter, or reading a local that was never assigned (e.g. `x += 1` on an undeclared global name) | Guard with `IsSet()`; declare `global` for globals that are assigned |
| `Error` (parameter mismatch) | Passing a non-VarRef to a ByRef parameter, or too few/too many arguments in a dynamic call | Pass `&var`; check `fn.IsByRef(n)`, `MinParams`/`MaxParams`/`IsVariadic`, or `HasMethod(fn,, n)` |
| `TypeError` | `Integer("abc")` / `Float("abc")` | Validate with `IsNumber()` / `IsInteger()` first |

## TIER 1 — Basic Declaration and Calling
> METHODS COVERED: named function definition · `return` · call statement · `StrSplit()`

A function definition is a name immediately followed by `(`, a parameter list, and a braced body. Functions are defined when the script loads, so they can be called before the line that defines them. A function without `return`, or with a bare `return`, returns `""`.

```ahk
; ✓ Template showing every parameter form in a legal order
FunctionName(requiredParam, optionalParam := "default", unsetParam?, extras*) {
    if !IsSet(unsetParam)          ; ✓ check before reading a ? parameter
        unsetParam := ""
    static callCount := 0          ; ✓ initializer runs only the first time it is reached
    callCount += 1
    return requiredParam           ; ✓ return and value on one line
}

Square(n) {
    return n * n
}
result := Square(7)                ; ✓ 49
MsgBox(result)
MsgBox "Statement call: " result   ; ✓ parentheses may be omitted at the start of a line

; ✗ result2 := Square (7)          ; → auto-concatenation, not a call

Clamp(value, lo, hi) {
    if value < lo
        return lo
    if value > hi
        return hi
    return value
}
MsgBox(Clamp(15, 0, 10))           ; 10

NoReturn() {
    x := 1 + 1
}
MsgBox(NoReturn() == "" ? "empty" : "value")   ; empty

MsgBox(Double(5))                  ; 10 — defined below, still callable
Double(x) {
    return x * 2
}
```

## TIER 2 — Variable Scope: Local, Global, Static
> METHODS COVERED: `global` · `static` · `local` · assume-local reads

```ahk
; ---- LOCAL (default) ----
LocalDemo() {
    x := 99                        ; assignment makes x local
    return x
}
x := 0
LocalDemo()
MsgBox(x)                          ; 0 — global x untouched

; ---- READING a global needs no declaration ----
gPrefix := "LOG"
ReadOnlyUse(msg) {
    return gPrefix ": " msg        ; ✓ only read, so it resolves to the global
}
MsgBox(ReadOnlyUse("start"))       ; LOG: start

; ---- ASSIGNING a global needs a declaration ----
gCounter := 0
IncrementGlobal() {
    global gCounter                ; ✓ required because gCounter is assigned below
    gCounter += 1
}
IncrementGlobal()
MsgBox(gCounter)                   ; 1

; ✗ Without the declaration gCounter is a new, unset local
; IncrementShadow() {
;     gCounter += 1                ; → UnsetError: the local has no value yet
; }

; ---- STATIC ----
CountCalls() {
    static n := 0                  ; runs only the first time
    n += 1
    return n
}
CountCalls(), CountCalls()
MsgBox(CountCalls())               ; 3

; ---- Explicit LOCAL ----
Explicit() {
    local result := "defined locally"
    return result
}
```

## TIER 3 — Parameter Modifiers: Default, Unset, Variadic
> METHODS COVERED: `:=` default · `?` unset · `*` variadic · `arr*` spread · maybe operator `var?` · `IsSet()`

```ahk
; ---- DEFAULT VALUE ----
Repeat(str, times := 1) {
    result := ""
    loop times
        result .= str
    return result
}
MsgBox(Repeat("ha", 3))            ; hahaha

; ---- UNSET PARAMETER ----
Describe(name, age?) {
    if !IsSet(age)
        return name " (age unknown)"
    return name " age " age
}
MsgBox(Describe("Alice"))          ; Alice (age unknown)

; ✓ Forward a maybe-absent parameter with the maybe operator
Greet(title?) {
    MsgBox("Hello!", title?)       ; omitted title → MsgBox uses its own default
}
Greet()

; ---- VARIADIC ----
Sum(nums*) {
    total := 0
    for n in nums
        total += n
    return total
}
MsgBox(Sum(1, 2, 3))               ; 6
MsgBox(Sum())                      ; 0 — nums is an empty Array

args := [7, 8, 9]
MsgBox(Sum(args*))                 ; 24 — spread at the call site

; ---- ORDER: required → optional (interleaved) → variadic ----
Combined(req, opt := 0, maybe?, rest*) {
    result := req + opt
    if IsSet(maybe)
        result += maybe
    for v in rest
        result += v
    return result
}
MsgBox(Combined(10, 5, 3, 1, 2))   ; 21
MsgBox(Combined(10,, 3))           ; 13 — middle optional omitted
```

## TIER 4 — ByRef Parameters: Output Params and In-Place Mutation
> METHODS COVERED: `&` ByRef definition · `&` VarRef at call site · optional ByRef · `IsSetRef()`

A ByRef parameter is an alias for the caller's variable. Use it for output parameters (status + data) or to reassign the caller's variable. Objects are already passed as references; ByRef on an object parameter is only needed to rebind the caller's variable.

```ahk
Swap(&a, &b) {
    temp := a, a := b, b := temp
}
x := 10, y := 20
Swap(&x, &y)                       ; ✓ & at the call site
MsgBox(x " / " y)                  ; 20 / 10
; Swap(x, y)                       ; ✗ → error: not a VarRef

; ---- OUTPUT PARAMETER ----
TryParseInt(str, &out) {
    if str ~= "^\d+$" {
        out := Integer(str)
        return true
    }
    out := 0
    return false
}
if TryParseInt("42", &parsed)
    MsgBox("Parsed: " parsed)      ; Parsed: 42

; ---- REBIND the caller's variable ----
DoubleAll(&arr) {
    newArr := []
    for v in arr
        newArr.Push(v * 2)
    arr := newArr                  ; caller's variable now points to newArr
}
data := [1, 2, 3]
DoubleAll(&data)
MsgBox(data[3])                    ; 6

; ---- OPTIONAL ByRef ----
GetBounds(arr, &outMin := 0, &outMax := 0) {
    outMin := arr[1], outMax := arr[1]
    for v in arr {
        if v < outMin
            outMin := v
        if v > outMax
            outMax := v
    }
}
GetBounds([3, 1, 4, 1, 5, 9], &mn, &mx)
MsgBox(mn " to " mx)               ; 1 to 9

; ---- IsSetRef: a non-ByRef parameter that receives a VarRef ----
DescribeRef(ref) {
    return IsSetRef(ref) ? "set: " %ref% : "unset"
}
MsgBox(DescribeRef(&neverAssigned))  ; unset
```

## SEE ALSO

- `Module_FunctionObjects.md` — nested functions, closures, Func object API (`Bind`, `MinParams`, `IsByRef`), multi-return, memoize and dispatch recipes.
- `Module_FatArrowFunctions.md` — `=>` syntax, named fat arrows, fat-arrow properties, functional patterns.
- `Module_ClassBasics.md` — methods, properties and `this`.
- `Module_ExceptionHandling.md` — try/catch patterns inside function bodies.
- `Module_ArrayBasics.md` — consuming Arrays returned by variadic and multi-return functions.
