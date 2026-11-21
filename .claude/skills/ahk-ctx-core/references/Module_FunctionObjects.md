# Module_FunctionObjects.md
<!-- DOMAIN: Functions as values — nested functions, closures, Func/Closure/BoundFunc objects, dynamic calls, multi-return, and pure vs side-effect separation in AHK v2 -->
<!-- SCOPE: Declaration syntax, parameters, ByRef and scope keywords are in Module_FunctionBasics.md. Fat-arrow syntax and functional pipelines are in Module_FatArrowFunctions.md. Method binding for class callbacks is in Module_ObjectBasics.md. -->
<!-- TRIGGERS: closure, "nested function", "inner function", "function reference", Func object, Closure, BoundFunc, Bind(), Call(), MinParams, MaxParams, IsVariadic, IsByRef(), IsOptional(), HasMethod, "dynamic call", "call by name", "multi-return", "return multiple values", memoize, dispatcher, "handler map", "pure function", "side effect" -->
<!-- CONSTRAINTS: A function name is a read-only variable holding its Func; use MyFunc, not Func("MyFunc"). A nested function that refers to an outer function's local variable is a closure; captured variables are shared, not copied. Calling a value that has no Call method throws MethodError — check with HasMethod(value) for any callable, not only Func. Storing a closure in one of its own captured variables creates a reference cycle. -->
<!-- CROSS-REF: Module_FunctionBasics.md, Module_FatArrowFunctions.md, Module_ObjectBasics.md, Module_ExceptionHandling.md, Module_Maps.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Function References

| Form | Returns | Notes |
|------|---------|-------|
| `MyFunc` | Func or Closure | Each function definition creates a read-only variable holding the function object. `Func("MyFunc")` is v1 style — use `MyFunc` |
| `fn(args*)` / `fn.Call(args*)` | Any | `Call` is implied when a value is called; any object with a `Call` method is callable |
| `%name%()` | Any | Calls the function held by the variable whose name is in `name` (dynamic) |

### Func Object — Methods

| Method | Signature | Returns | Throws | Notes |
|--------|-----------|---------|--------|-------|
| `.Call()` | `FuncObj.Call(Params*)` | Defined by the function | Defined by the function | `FuncObj(Params*)` is equivalent |
| `.Bind()` | `FuncObj.Bind(Params*)` | BoundFunc | — | Binds leading parameters; caller's arguments are appended |
| `.IsByRef()` | `FuncObj.IsByRef(ParamIndex?)` | 1 or 0 | Exception if index invalid | Omit index: does the function have any ByRef parameter |
| `.IsOptional()` | `FuncObj.IsOptional(ParamIndex?)` | 1 or 0 | Exception if index invalid | Omit index: does the function have any optional parameter; supports built-ins |

### Func Object — Properties

| Property | Returns | Notes |
|----------|---------|-------|
| `.Name` | String | The function's name |
| `.MinParams` | Integer | Number of required parameters |
| `.MaxParams` | Integer | Formally declared parameters (user-defined) or maximum (built-in); for a variadic function, the count accepted before overflowing into `params*` |
| `.IsVariadic` | 1 or 0 | Use this, not `MaxParams`, to detect "no upper bound" |
| `.IsBuiltIn` | 1 or 0 | 1 for built-in functions |

`Closure` extends `Func` and adds no members. `BoundFunc` is a separate callable type.

### Callability Checks

| Function | Signature | Notes |
|----------|-----------|-------|
| `HasMethod()` | `HasMethod(Value, Name?, ParamCount?)` | `HasMethod(v)` — is `v` callable; `HasMethod(v,, n)` — can it accept `n` arguments. Same validation built-ins such as `SetTimer` use |
| `GetMethod()` | `GetMethod(Value, Name?, ParamCount?)` | Returns the function object; throws MethodError if not found, ValueError or MethodError if validation fails |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **Function references are bare names.** Write `MyFunc`, never `Func("MyFunc")` or a string.
  ✗ `fn := Func("MyFunc")` → ✓ `fn := MyFunc`
- **Closures share captured variables.** All closures created by one call of the outer function share one set of free variables; each new call of the outer function creates new closures with a new set. Changes are visible to every closure in the set. Closures that must hold independent state come from separate calls of the factory function.
  ✗ Closures in one call each "remember" a different loop value → ✓ create each closure in a separate call of a factory function
- **Nested functions are private.** A nested function is not accessible by name outside the function that encloses it. A nested function that captures nothing is automatically static (one shared Func for every call).
- **Avoid storing a closure in one of its own captured variables.** That creates a reference cycle that must be broken (e.g. by clearing the variable) before the closure can be freed. Referring to a closure through its original nested-function name is safe.
  ✗ `self := Inner` inside the outer function, `Inner` refers to `self` → ✓ refer to the closure by its nested function name
- **Calling a non-callable value throws MethodError.** Guard dynamic calls with `HasMethod(fn)` (or `HasMethod(fn,, n)`), which also accepts BoundFuncs and user objects with a `Call` method. `fn is Func` rejects BoundFunc and custom callables.
  ✗ `if fn is Func` as the only callable check → ✓ `if HasMethod(fn)`
- **Dynamic calls are checked at run time.** Some error checks that are done at load time for a direct call (such as `MyFunc()`) are done only at run time when the call target is a variable or expression.
- **Names match side effects** (convention). `Check*`/`Is*` functions do not mutate, and functions that mutate use mutation verbs.
  ✗ `CheckThreshold()` resets a counter → ✓ `IsThresholdExceeded()` + `ResetSession()`
  ✗ `ProcessData()` writes a global and a file → ✓ `UpdateDataCache()` + `WriteDataLog()`

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `MethodError` | Calling a value with no `Call` method (string, number, plain object) | `if HasMethod(fn)` before calling |
| `Error` (parameter count / VarRef) | Dynamic call with too few/too many arguments or a non-VarRef for a ByRef parameter | Check `MinParams`/`MaxParams`/`IsVariadic`, `IsByRef(n)`, or `HasMethod(fn,, n)` |
| `UnsetItemError` | `handlers[key]()` when `key` is not in the Map | `handlers.Has(key)` first |

## TIER 1 — Nested Functions, Closures, and Func Objects
> METHODS COVERED: nested function · closure factory · shared captured variables · `.Bind()` · `.IsByRef()` · `.Name` · `.MinParams` · `.IsVariadic`

```ahk
; ---- NESTED HELPER: private to the outer function ----
ProcessPositive(data) {
    IsPositive(item) {                 ; captures nothing → static nested function
        return (item is Number) && (item > 0)
    }
    result := []
    for item in data
        if IsPositive(item)
            result.Push(item)
    return result
}
clean := ProcessPositive([3, -1, 0, 7, 2])
MsgBox(clean.Length)                   ; 3
; IsPositive(5)                        ; ✗ not accessible outside ProcessPositive

; ---- CLOSURE FACTORY: each outer call creates new closures ----
MakeAdder(n) {
    Add(x) {
        return x + n                   ; n is captured
    }
    return Add
}
Add5  := MakeAdder(5)
Add10 := MakeAdder(10)
MsgBox(Add5(3) " " Add10(3))           ; 8 13

; ---- SHARED STATE: closures from one call share variables ----
BuildAccumulator() {
    total := 0
    Accumulate(n) {
        total += n                     ; writes the shared 'total'
    }
    GetTotal() {
        return total
    }
    return Map("add", Accumulate, "get", GetTotal)
}
acc := BuildAccumulator()
addFn := acc["add"], getFn := acc["get"]
addFn(10), addFn(25)
MsgBox(getFn())                        ; 35

; ---- FUNC OBJECT introspection ----
SumAll(nums*) {
    total := 0
    for n in nums
        total += n
    return total
}
fn := SumAll
MsgBox(fn.Name " variadic=" fn.IsVariadic " min=" fn.MinParams)   ; SumAll variadic=1 min=0

AddTen := fn.Bind(10)                  ; BoundFunc: 10 is always the first argument
MsgBox(AddTen(1, 2))                   ; 13

; ---- Validate a callback's signature before storing it ----
CheckSwapSig(f) {
    if !f.IsByRef(1) || !f.IsByRef(2)
        throw ValueError("handler must declare (&a, &b)", -1)
}
SwapForSig(&a, &b) {
    t := a, a := b, b := t
}
CheckSwapSig(SwapForSig)               ; passes
```

### Performance Notes

- **Static memoization:** `static cache := Map()` inside a pure function avoids recomputation; never memoize functions with side effects.
- **Static lookup tables:** `static days := Map(...)` is built once, the first time the line is reached.
- **Built-ins over script loops:** `StrSplit()`, `RegExMatch()`, `InStr()` and `Sort()` do the work in native code; prefer them to character-by-character loops.
- **Objects are references:** passing a Map or Array shares it without copying; ByRef is only needed to rebind the caller's variable.

```ahk
Fibonacci(n) {
    static cache := Map()
    if cache.Has(n)
        return cache[n]
    result := n <= 1 ? n : Fibonacci(n - 1) + Fibonacci(n - 2)
    cache[n] := result
    return result
}
MsgBox(Fibonacci(30))

GetDayName(n) {
    static days := Map(1, "Mon", 2, "Tue", 3, "Wed", 4, "Thu", 5, "Fri", 6, "Sat", 7, "Sun")
    return days.Get(n, "Unknown")
}
MsgBox(GetDayName(3))                  ; Wed
```

## TIER 2 — Multi-Return and Pure vs Side-Effect Separation
> METHODS COVERED: Map multi-return · Array multi-return · ByRef + return · pure core / side-effect wrapper

Return several values with a Map (named fields, good for 3+ values), an Array (positional, good for 2–3 values) or ByRef output parameters. Keep pure computation separate from functions that touch files, globals or the UI (convention): the pure part is easy to test and safe to memoize.

```ahk
; ---- Map: named fields ----
AnalyzeList(arr) {
    if arr.Length == 0
        return Map("count", 0, "sum", 0, "mean", 0)
    total := 0
    for v in arr
        total += v
    return Map("count", arr.Length, "sum", total, "mean", total / arr.Length)
}
stats := AnalyzeList([4, 7, 2, 9, 1])
MsgBox("count=" stats["count"] " mean=" stats["mean"])   ; count=5 mean=4.6

; ---- Array: positional ----
SplitFullName(fullName) {
    parts := StrSplit(fullName, " ", , 2)
    return [parts[1], parts.Length > 1 ? parts[2] : ""]
}
name := SplitFullName("Grace Hopper")
MsgBox(name[1] " / " name[2])          ; Grace / Hopper

; ---- Pure core + thin side-effect wrapper ----
FormatLogLine(level, msg, stamp) {     ; pure: same input → same output
    return "[" stamp "] " level ": " msg
}
WriteLog(level, msg, logPath) {        ; side effect isolated here
    FileAppend(FormatLogLine(level, msg, A_Now) "`n", logPath, "UTF-8")
}

; ---- Pure filter with a predicate ----
PureFilter(arr, predFn) {
    result := []
    for v in arr
        if predFn(v)
            result.Push(v)
    return result
}
evens := PureFilter([1, 2, 3, 4, 5, 6], (n) => Mod(n, 2) == 0)
MsgBox(evens.Length)                   ; 3
```

## DROP-IN RECIPES

```ahk
; Memoize — wraps a pure function; one cache per Memoize call
Memoize(fn) {
    if !HasMethod(fn)
        throw TypeError("Memoize: fn must be callable, got " Type(fn), -1)
    cache := Map()
    Cached(args*) {
        key := ""
        for a in args
            key .= "|" a               ; assumes primitive arguments
        if cache.Has(key)
            return cache[key]
        return cache[key] := fn(args*)
    }
    return Cached
}
; Call site: fastFib := Memoize(SlowFib), MsgBox(fastFib(25))

; TrySafeCall — calls fn; returns true/false and puts the result or error message in outResult
TrySafeCall(fn, &outResult, params*) {
    if !HasMethod(fn)
        throw TypeError("TrySafeCall: fn must be callable, got " Type(fn), -1)
    try {
        outResult := fn(params*)
        return true
    } catch Error as e {
        outResult := e.Message
        return false
    }
}
; Call site: if TrySafeCall(myHandler, &result, arg1)  MsgBox(result)

; DispatchFn — calls a handler from a Map; fails loudly on misconfiguration
DispatchFn(handlers, key, params*) {
    if !(handlers is Map)
        throw TypeError("DispatchFn: handlers must be a Map, got " Type(handlers), -1)
    if !handlers.Has(key)
        throw ValueError("DispatchFn: no handler registered for '" key "'", -1)
    fn := handlers[key]
    if !HasMethod(fn, , params.Length)
        throw TypeError("DispatchFn: handler for '" key "' cannot take " params.Length " args", -1)
    return fn(params*)
}
; Call site: DispatchFn(Map("save", SaveFn, "load", LoadFn), "save", "data.txt")
```

## SEE ALSO

- `Module_FunctionBasics.md` — declaration, parameters, ByRef, scope keywords.
- `Module_FatArrowFunctions.md` — `=>` lambdas, named fat arrows, currying and composition.
- `Module_ObjectBasics.md` — `ObjBindMethod()` and `.Bind(this)` for method callbacks.
- `Module_Maps.md` — Map API used for handler tables and multi-return.
- `Module_ExceptionHandling.md` — try/catch around dynamic calls.
