# Module_ClassMetaFunctions.md
<!-- DOMAIN: Class meta-functions — __Get, __Set, __Call for undefined members, __Item for indexing, __Enum for for-loops, open-ended dynamic property bags and fluent interfaces in AHK v2 -->
<!-- SCOPE: Class syntax, constructors, static members and inheritance are in Module_ClassBasics.md. Known-name properties via DefineProp are in Module_PropertyDescriptors.md. __Delete and cleanup are in Module_ClassLifecycle.md. -->
<!-- TRIGGERS: __Get, __Set, __Call, __Item, __Enum, "meta-function", "dynamic property", "undefined property", "property bag", "intercept property", "intercept method call", "bracket access", "indexer", "make class iterable", "for loop over object", enumerator, "fluent interface", "method chaining", builder -->
<!-- CONSTRAINTS: v2 signatures are __Get(Name, Params), __Set(Name, Params, Value), __Call(Name, Params); Params is an Array of the arguments between [] or (). Meta-functions run only for members that are not defined on the object or its bases. A meta-function must do the default action itself: __Get throws PropertyError, __Call throws MethodError, __Set defines the property (e.g. with DefineProp). obj[x] only invokes __Item and obj() only invokes Call — meta-functions are not used for them. -->
<!-- CROSS-REF: Module_ClassBasics.md, Module_PropertyDescriptors.md, Module_FatArrowFunctions.md, Module_Maps.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `__Get(name)` | `__Get(Name, Params)` | Wrong parameter count: the call fails or binds the wrong values |
| `__Set(name, value)` | `__Set(Name, Params, Value)` | `value` would receive the `Params` Array |
| `__Call(name, args*)` | `__Call(Name, Params)` | Arguments arrive as one Array, not spread |
| Object literal used as `obj[key]` store | Define `__Item[key]` or use a Map | Plain Objects have no `__Item` |

## API QUICK-REFERENCE

### Meta-Functions

| Meta-function | Signature | Called when | Expected default action |
|---------------|-----------|-------------|-------------------------|
| `__Get` | `__Get(Name, Params)` | Reading an undefined property (`obj.unk`, `obj.unk[x]`) | Return a value or `throw PropertyError` |
| `__Set` | `__Set(Name, Params, Value)` | Assigning an undefined property | Store or define it (e.g. `this.DefineProp(Name, {value: Value})`); throw if `Params` is not empty and unsupported |
| `__Call` | `__Call(Name, Params)` | Calling an undefined method (`obj.unk()`) | Return a result or `throw MethodError` |

`Params` holds only the arguments between `()` or `[]`, so it may be empty.

### Special Members

| Member | Signature | Notes |
|--------|-----------|-------|
| `__Item` | `__Item[key] { get => ... set => ... }` | `obj[key]` is `obj.__Item[key]`; `obj[]` is `obj.__Item`. May be `static` to index the class itself |
| `__Enum` | `__Enum(NumberOfVars)` | Called by `for`; return an enumerator. With 2 variables, the first should be a key accepted by `__Item` |
| `Call` | `Call(args*)` | Makes the object callable: `obj(args)` |

### Backing Store Methods Used in Examples

| Method | Signature | Notes |
|--------|-----------|-------|
| `Map.Has()` | `m.Has(key)` | Check before reading inside `__Get` |
| `Map.Get()` | `m.Get(key, default)` | Throws UnsetItemError only when no default and no `Map.Default` |
| `Map.__Enum()` | `m.__Enum(n)` | Delegate a wrapper's `__Enum` to an inner Map |
| `DefineProp()` | `obj.DefineProp(name, {value: v})` | Defines a property without going through `__Set` |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **Use the v2 signatures exactly.** `Params` is required even when unused.
  ✗ `__Get(name)` / `__Set(name, value)` → ✓ `__Get(name, params)` / `__Set(name, params, value)` / `__Call(name, params)`
- **Reject names you do not handle.** `__Get` throws `PropertyError` and `__Call` throws `MethodError` for unknown names.
  ✗ `return ""` for every name — hides typos → ✓ `throw PropertyError(...)` for unknown names
- **Meta-functions only see undefined members.** Anything defined on the object or a base (class property, method, value property, inherited `Base`) bypasses them. To route every property through a meta-function, avoid defining properties with those names.
- **Create backing storage with `DefineProp` or in `__New` carefully.** Instance variable declarations behave like normal assignments; if the backing property does not exist yet and the class defines `__Set`, an assignment can be routed to `__Set`. Defining the store with `this.DefineProp("_props", {value: Map()})` avoids that.
  ✗ `_props := Map()` in the class body of a class with `__Set` → ✓ `this.DefineProp("_props", {value: Map()})` in `__New`
- **Indexing and calling the object itself are separate.** `obj[x]` uses only `__Item`; `obj()` (including calls made by `SetTimer`, `Hotkey`) uses only `Call`.
  ✗ handling bracket access in `__Get` → ✓ define `__Item`
- **`HasProp`/`HasMethod` cannot see dynamic members.** They return 0 for names handled only by `__Get`/`__Call`; provide your own `Has(name)` method if callers need one.
  ✗ `obj.HasProp("color")` on a `__Get` bag → ✓ a custom `Has(name)` method
- **Object literals do not use `__Set`.** Each `{name: value}` pair defines a value property directly.
- **`__Enum` returns an enumerator**, for example an inner Map's `__Enum(n)`.
- **Fluent methods `return this`.**

Safe-access priority order for dynamic properties:
1. `this._store.Has(name)` inside `__Get` before reading the store
2. A custom `Has(name)` method for callers
3. `DefineProp` for names known when the object is built
4. `__Get`/`__Set` only for genuinely open-ended names

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `PropertyError` | `__Get` (or the default behavior) for an unknown property | Expected; or add the key to the store |
| `MethodError` | Calling an undefined method when no `__Call` handles it | Define the method or handle it in `__Call` |
| `Error` (parameter count) | v1-style `__Get(name)` / `__Set(name, value)` | Use the v2 signatures |
| `UnsetItemError` | `this._store[name]` inside `__Get` for a missing key | Check `Has()` first and throw `PropertyError` |
| Error in `for` | Object without `__Enum` (or enumerator-compatible `Call`) passed to `for` | Define `__Enum` |

## TIER 1 — Dynamic Property Bags with __Get and __Set
> METHODS COVERED: `__Get` · `__Set` · `DefineProp` backing store · custom `Has()` · per-key validators

```ahk
class DynamicObject {
    __New() {
        this.DefineProp("_props", {value: Map()})   ; ✓ not routed through __Set
    }
    __Get(name, params) {
        if this._props.Has(name)
            return this._props[name]
        throw PropertyError("Property '" name "' not found", -1)
    }
    __Set(name, params, value) {
        if params.Length
            throw ValueError("Property '" name "' takes no parameters", -1)
        this._props[name] := value
    }
    Has(name) => this._props.Has(name)
}

obj := DynamicObject()
obj.color := "blue"                    ; __Set
MsgBox(obj.color)                      ; __Get → blue
MsgBox(obj.Has("size"))                ; 0

; ✗ v1-style signatures
; __Get(name) { ... }                  ; → parameter-count error
; __Set(name, value) { ... }           ; → value receives the Params Array

class ValidatedConfig {
    __New() {
        this.DefineProp("_config", {value: Map()})
        this.DefineProp("_validators", {value: Map()})
    }
    SetValidator(key, fn) => this._validators[key] := fn
    __Get(key, params) {
        if !this._config.Has(key)
            throw PropertyError("Configuration key '" key "' not found", -1)
        return this._config[key]
    }
    __Set(key, params, value) {
        if this._validators.Has(key) && !this._validators[key](value)
            throw ValueError("Invalid value for '" key "'", -1)
        this._config[key] := value
    }
}
cfg := ValidatedConfig()
cfg.SetValidator("port", (v) => IsInteger(v) && v > 0 && v <= 65535)
cfg.port := 8080
; cfg.port := -1                       ; ✗ ValueError
```

## TIER 2 — __Call, __Item and __Enum
> METHODS COVERED: `__Call` · `__Item` · `__Enum` delegating to a Map

```ahk
class Settings {
    __New() {
        this.DefineProp("_s", {value: Map("theme", "dark", "language", "en")})
    }
    ; getTheme() / setTheme(v) handled dynamically
    __Call(name, params) {
        if RegExMatch(name, "i)^get(\w+)$", &m)
            return this._s.Get(StrLower(m[1]), "")
        if RegExMatch(name, "i)^set(\w+)$", &m) && params.Length = 1 {
            this._s[StrLower(m[1])] := params[1]
            return this
        }
        throw MethodError("Unknown method: " name, -1)
    }
    __Item[key] {
        get => this._s[key]            ; UnsetItemError for unknown keys
        set => this._s[key] := value
    }
    __Enum(numberOfVars) => this._s.__Enum(numberOfVars)
}

s := Settings()
s.setTheme("light")                    ; __Call
MsgBox(s.getTheme())                   ; light
s["debug"] := true                     ; __Item set
for key, value in s                    ; __Enum
    OutputDebug(key " = " value)

class Env {
    static __Item[name] {              ; static: index the class itself
        get => EnvGet(name)
        set => EnvSet(name, value)
    }
}
MsgBox(Env["PATH"])
```

## TIER 3 — Fluent Interfaces
> METHODS COVERED: methods that `return this` · method-call continuation lines

Every builder method returns `this`, so calls chain left to right. A line that starts with `.` continues the previous expression.

```ahk
class QueryBuilder {
    _table := "", _columns := [], _conditions := [], _limit := 0

    From(table) {
        this._table := table
        return this
    }
    Select(columns*) {
        for c in columns
            this._columns.Push(c)
        return this
    }
    Where(condition) {
        this._conditions.Push(condition)
        return this
    }
    Limit(count) {
        this._limit := count
        return this
    }
    Build() {
        if this._table = ""
            throw ValueError("Table name is required", -1)
        q := "SELECT " (this._columns.Length ? QueryBuilder.Join(this._columns, ", ") : "*")
        q .= " FROM " this._table
        if this._conditions.Length
            q .= " WHERE " QueryBuilder.Join(this._conditions, " AND ")
        if this._limit > 0
            q .= " LIMIT " this._limit
        return q
    }
    static Join(arr, sep) {
        out := ""
        for i, item in arr
            out .= (i > 1 ? sep : "") item
        return out
    }
}

query := QueryBuilder()
    .From("users")
    .Select("id", "name")
    .Where("active = 1")
    .Limit(10)
    .Build()
MsgBox(query)   ; SELECT id, name FROM users WHERE active = 1 LIMIT 10
```

### Performance Notes

- Every access to an undefined member goes through a meta-function call; in hot loops, read the backing Map directly or define real properties.
- If all names are known when the object is created, `DefineProp` per name avoids the per-access dispatch logic.

## DROP-IN RECIPES

```ahk
; TypedStore — property bag with optional per-key validators
class TypedStore {
    __New(validators?) {
        if IsSet(validators) && !(validators is Map)
            throw TypeError("TypedStore: validators must be a Map of key → callable", -1)
        this.DefineProp("_props", {value: Map()})
        this.DefineProp("_validators", {value: validators ?? Map()})
    }
    __Get(name, params) {
        if !this._props.Has(name)
            throw PropertyError("TypedStore: key '" name "' not found", -1)
        return this._props[name]
    }
    __Set(name, params, value) {
        if this._validators.Has(name) && !this._validators[name](value)
            throw ValueError("TypedStore: value for '" name "' failed validation", -1)
        this._props[name] := value
    }
    Has(name) => this._props.Has(name)
    Keys() {
        keys := []
        for key in this._props
            keys.Push(key)
        return keys
    }
}
; Call site:
; store := TypedStore(Map("port", v => IsInteger(v) && v > 0 && v <= 65535))
; store.port := 8080
```

## SEE ALSO

- `Module_ClassBasics.md` — class definitions, constructors, inheritance.
- `Module_PropertyDescriptors.md` — `DefineProp` for properties with known names.
- `Module_FatArrowFunctions.md` — fat-arrow properties and methods.
- `Module_Maps.md` — Map API used as the backing store.
- `Module_ExceptionHandling.md` — `PropertyError`, `MethodError`, custom errors.
