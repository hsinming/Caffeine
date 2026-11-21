# Module_FatArrowFunctions.md
<!-- DOMAIN: Fat arrow functions — `=>` lambdas, named fat arrows, closure capture, fat-arrow properties and methods, functional patterns (compose, curry, partial) in AHK v2 -->
<!-- SCOPE: Full function declaration syntax and parameters are in Module_FunctionBasics.md. Func object API and closure lifetime rules are in Module_FunctionObjects.md. __Get/__Set/__Call meta-functions are in Module_ClassMetaFunctions.md. Timer/OnMessage scheduling is in Module_Timers.md. -->
<!-- TRIGGERS: =>, "fat arrow", "arrow function", lambda, "inline callback", "short function syntax", "computed property", "property that calculates", closure, "function remembers variables", curry, currying, compose, composition, "partial application", "functional programming", "higher-order function" -->
<!-- CONSTRAINTS: In AHK v2.0 a fat arrow evaluates one expression; `=> { ... }` is not a block body. Use a named (nested) function for multi-statement logic. A lambda stored in an object property and called as obj.prop() receives obj as its first argument. A fat-arrow property `Prop => expr` defines only a getter; assigning to it throws. Inside a function, a fat arrow that refers to outer locals creates a new closure each time it is evaluated. -->
<!-- CROSS-REF: Module_FunctionBasics.md, Module_FunctionObjects.md, Module_ClassBasics.md, Module_ClassMetaFunctions.md, Module_ArrayAlgorithms.md, Module_Timers.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| No lambda syntax — every callback is a named function | `param => expr` for single-expression callbacks | Not an error; fat arrows are simply available in v2 |
| `Func("FuncName")` to obtain a reference | Bare name `FuncName` or `FuncName.Bind(args*)` | `Func("Name")` lookup by name is not v2 code |
| `(x) => { return x * 2 }` (JavaScript block body) | `(x) => x * 2`, or a named function for several statements | Not valid v2.0 syntax — `{` after `=>` starts an object literal, not a block |

## API QUICK-REFERENCE

### Fat Arrow Syntax Forms

| Form | Example | Notes |
|------|---------|-------|
| One parameter | `x => x * 2` | Parentheses optional only when the name is omitted and there is exactly one parameter |
| Several parameters | `(a, b) => a + b` | Parentheses required |
| No parameters | `() => "hi"` | Empty parentheses required |
| Variadic | `(args*) => args.Length` | Same parameter syntax as normal functions |
| Named | `Fact(n) => n <= 1 ? 1 : n * Fact(n - 1)` | Name is visible inside the expression (recursion) and in `Func.Name`; avoids a self-referencing closure |
| Method | `Method() => expr` in a class body | Single-line method returning `expr` |
| Getter property | `Prop => expr` in a class body | Getter only; re-evaluated on each read |
| Parameterized getter | `Prop[key] => expr` | `key` is the bracket argument |
| Getter + setter | `Prop { get => expr` / `set => expr }` | `set` receives the hidden `value` parameter |

The fat-arrow function is always assume-local (declarations cannot be used). A named fat arrow is defined when the script starts; the reference is stored in a variable only when the assignment runs.

### Functional Helpers Used in Examples

| Method/Function | Signature | Returns | Notes |
|-----------------|-----------|---------|-------|
| `Func.Bind()` | `fn.Bind(args*)` | BoundFunc | Binds leading arguments |
| `Func.Call()` | `fn.Call(args*)` | Any | Same as `fn(args*)` |
| `IsSet()` | `IsSet(var)` | 1 or 0 | Optional-parameter detection |
| `FormatTime()` | `FormatTime(YYYYMMDDHH24MISS?, Format?)` | String | Omit the time for "now" |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **One expression only.** A fat arrow evaluates a single expression. Ternaries, `&&`/`||`, assignments and function calls are fine; statements (`if`, `loop`, `return`) are not. For several statements, define a named (nested) function and use its name as the value. The `=> { }` block-body wrong form is in V1 → V2 BREAKING CHANGES.
- **Stored lambdas called as methods get the object first.** `obj.prop(args)` passes `obj` as the first argument when `prop` holds a function. Declare a leading parameter (e.g. `this`) or call it as `obj.prop.Call(args)` / `fn := obj.prop, fn(args)`.
  ✗ `{increment: () => ++count}` then `c.increment()` throws (too many arguments) → ✓ `{increment: (this) => ++count}`
- **Captured variables are shared.** A fat arrow inside a function that refers to outer locals is a closure; it sees the variable's current value at call time. Closures created in one call (for example inside a loop) share the same variables.
  ✗ Lambdas created in one loop each "remember" a different `i` → ✓ create each lambda in a separate factory call
- **Getter-only fat-arrow properties are read-only.** If no setter is defined or inherited, assigning to the property throws. Use `Prop { get => ... set => ... }` or `set { ... }` for write access.
  ✗ `obj.version := "3.0"` with `version => expr` → ✓ `version { get => ... set => ... }`
- **Self-reference.** Inside a function, `f := (n) => ... f(n - 1)` captures `f` and creates a reference cycle (closure → `f` → closure). Use the named form `f := F(n) => ... F(n - 1)`.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| Load-time error | `=> {` used as a block body | Use a single expression or a named function |
| `Error` (too many parameters) | Lambda in an object property called as `obj.prop()` without a leading `this` parameter | Add `(this, ...)` or use `obj.prop.Call()` |
| `PropertyError` / `Error` | Assigning to a getter-only property | Add a setter |

## TIER 1 — Basic Arrow Function Syntax
> METHODS COVERED: `=>` one-parameter · several-parameter · no-parameter forms

```ahk
multiply := (x, y) => x * y
square   := x => x * x
greet    := () => "Hello World"
MsgBox(multiply(4, 5) " " square(3) " " greet())   ; 20 9 Hello World

; ✗ Block body — not valid in v2.0
; add := (a, b) => {
;     return a + b
; }

; ✓ Several statements: named function, referenced by name
AddAndLog(a, b) {
    sum := a + b
    OutputDebug("sum=" sum)
    return sum
}
add := AddAndLog
MsgBox(add(5, 3))                  ; 8
```

## TIER 2 — Named Arrow Functions and Recursion
> METHODS COVERED: named fat arrow · recursion without a self-referencing closure

```ahk
; ✓ The name is visible inside the expression
factorial := Fact(n) => n <= 1 ? 1 : n * Fact(n - 1)
MsgBox(factorial(5))               ; 120

MakeCountdown() {
    ; ✗ Inside a function this captures 'down' itself → reference cycle
    ; down := (n) => n <= 0 ? "done" : down(n - 1)
    ; ✓ Named form — no captured self-reference
    return Down(n) => n <= 0 ? "done" : Down(n - 1)
}
MsgBox(MakeCountdown()(3))         ; done
```

## TIER 3 — Closures and Variable Capture
> METHODS COVERED: lexical capture · lambdas in object literals · closure factory

```ahk
CreateCounter() {
    count := 0
    return {
        increment: (this) => ++count,   ; (this) receives the object
        getValue:  (this) => count,
        reset:     (this) => count := 0
    }
}
counter := CreateCounter()
counter.increment(), counter.increment()
MsgBox(counter.getValue())         ; 2 — all three lambdas share 'count'

; ✓ Each factory call captures its own minLength/maxLength
CreateValidator(minLength, maxLength) {
    return (text) => StrLen(text) >= minLength && StrLen(text) <= maxLength
}
isEmail := CreateValidator(5, 100)
isPassword := CreateValidator(8, 50)
MsgBox(isEmail("user@domain.com") " " isPassword("abc"))   ; 1 0
```

## TIER 4 — Fat Arrow Properties
> METHODS COVERED: getter fat-arrow property · parameterized property · `get =>` / `set =>` · fat-arrow method

```ahk
class DataProcessor {
    _items := []
    version => "2.0.1"                                  ; getter only
    timestamp => FormatTime(, "yyyy-MM-dd HH:mm:ss")    ; recomputed on every read
    squareOf[x] => x * x                                ; parameterized getter
    count => this._items.Length
    Add(item) => this._items.Push(item)                 ; fat-arrow method
}
p := DataProcessor()
p.Add("a")
MsgBox(p.version " " p.squareOf[5] " " p.count)         ; 2.0.1 25 1
; p.version := "3.0"               ; ✗ → throws: no setter

class Counter {
    _value := 0
    value {
        get => this._value
        set {
            if value < 0
                throw ValueError("Counter cannot be negative")
            this._value := value
        }
    }
    isZero => this._value = 0
}
c := Counter()
c.value := 3
MsgBox(c.isZero)                   ; 0
```

## TIER 5 — Functional Programming Patterns
> METHODS COVERED: compose · currying · partial application · Array subclass with Map/Filter/Reduce methods

```ahk
compose := (f, g) => (x) => f(g(x))      ; apply g, then f
addOne := x => x + 1
double := x => x * 2
addThenDouble := compose(double, addOne)
MsgBox(addThenDouble(5))           ; 12

curriedAdd := (a) => (b) => (c) => a + b + c
MsgBox(curriedAdd(1)(2)(3))        ; 6

; ✓ Bind is the built-in partial application
multiply3 := (a, b, c) => a * b * c
by2 := multiply3.Bind(2)
MsgBox(by2(5, 3))                  ; 30

; ✓ Array subclass exposing a small pipeline API (method names are properties,
;   so a method called Map does not affect the global Map class)
class FunctionalArray extends Array {
    Map(fn) {
        result := FunctionalArray()
        for item in this
            result.Push(fn(item))
        return result
    }
    Filter(predicate) {
        result := FunctionalArray()
        for item in this
            if predicate(item)
                result.Push(item)
        return result
    }
    Reduce(fn, initial?) {
        acc := IsSet(initial) ? initial : this[1]
        start := IsSet(initial) ? 1 : 2
        Loop this.Length - start + 1
            acc := fn(acc, this[start + A_Index - 1])
        return acc
    }
}
nums := FunctionalArray(1, 2, 3, 4, 5)
MsgBox(nums.Map(x => x * 2).Filter(x => x > 4).Reduce((a, b) => a + b))   ; 24
```

### Performance Notes

- A fat arrow inside a function that captures outer locals allocates a new closure each time it is evaluated. Create closures once, outside hot loops.
- `Prop => expr` re-evaluates `expr` on every read; cache the value in a local when it is read many times in one block.
- The docs do not describe tail-call optimization or a recursion limit, so do not rely on deep recursion through named fat arrows — prefer loops or memoization for large inputs.
- Long `compose(compose(f, g), h)` chains add one call frame per level; for long pipelines, store the functions in an Array and loop.

## DROP-IN RECIPES

```ahk
; Pipe — applies functions left to right: Pipe(f, g, h)(x) == h(g(f(x)))
Pipe(fns*) {
    for fn in fns
        if !HasMethod(fn)
            throw TypeError("Pipe: every argument must be callable", -1)
    Run1(x) {
        for fn in fns
            x := fn(x)
        return x
    }
    return Run1
}
; Call site: slugify := Pipe(StrLower, s => Trim(s), s => StrReplace(s, " ", "-"))

; Partial — like Bind, but returns a closure (useful when a Func, not a BoundFunc, is required)
Partial(fn, leading*) {
    Apply(trailing*) {
        all := leading.Clone()
        for v in trailing
            all.Push(v)
        return fn(all*)
    }
    return Apply
}
; Call site: by2 := Partial((a, b) => a * b, 2), MsgBox(by2(21))   ; 42
```

## SEE ALSO

- `Module_FunctionBasics.md` — normal function definitions, parameters and scope.
- `Module_FunctionObjects.md` — Func/BoundFunc API, closures and reference cycles, memoize/dispatch recipes.
- `Module_ClassBasics.md` — full property syntax (`get`/`set` blocks) and methods.
- `Module_ClassMetaFunctions.md` — `__Get`/`__Set`/`__Call` for open-ended dynamic properties.
- `Module_ArrayAlgorithms.md` — `ArrayMap`, `Filter`, `Reduce` helpers on plain Arrays.
