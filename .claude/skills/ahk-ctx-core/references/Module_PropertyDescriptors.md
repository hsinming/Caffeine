# Module_PropertyDescriptors.md
<!-- DOMAIN: Property descriptors — DefineProp with get/set/call/value, GetOwnPropDesc, OwnProps enumeration, class get/set blocks, computed, read-only and validated properties in AHK v2 -->
<!-- SCOPE: Type hierarchy, object literals, inheritance and callback binding are in Module_ObjectBasics.md. Open-ended dynamic properties via __Get/__Set are in Module_ClassMetaFunctions.md. Descriptor guards, decorators and runtime class generation are in Module_RuntimePrototyping.md / Module_RuntimeClassFactory.md. -->
<!-- TRIGGERS: DefineProp, GetOwnPropDesc, OwnProps, DeleteProp, "property descriptor", getter, setter, "get/set", "computed property", "read-only property", "validated property", "property validation", "call descriptor", "value property", "dynamic property", "config object" -->
<!-- CONSTRAINTS: A descriptor is an object with Get, Set and/or Call (dynamic property) or Value (value property). Get/Set/Call functions receive the target object as their first parameter; Set receives the assigned value second. A `=>` descriptor function is one expression; use a named function for several statements. Defining a dynamic property keeps accessor functions not named in the new descriptor; defining a value property replaces everything. If no Set (or value) is defined or inherited, assigning to the property throws. -->
<!-- CROSS-REF: Module_ObjectBasics.md, Module_ClassBasics.md, Module_ClassMetaFunctions.md, Module_RuntimePrototyping.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Descriptor Methods (Object)

| Method | Signature | Returns | Throws | Notes |
|--------|-----------|---------|--------|-------|
| `.DefineProp()` | `obj.DefineProp(Name, Descriptor)` | The target object | — | Defines or modifies an own property |
| `.GetOwnPropDesc()` | `obj.GetOwnPropDesc(Name)` | New descriptor object | PropertyError if not an own property | Contains only the accessors defined on `obj` itself, or `Value` |
| `.DeleteProp()` | `obj.DeleteProp(Name)` | Removed value (blank if none) | — | Own property only |
| `.OwnProps()` | `for name [, value] in obj.OwnProps()` | Enumerator | Getter errors propagate | One variable: names only, getters not called. Two variables: getters called; call-only properties and getters needing parameters are skipped |

### Descriptor Keys

| Key | Function signature | Notes |
|-----|--------------------|-------|
| `Get` | `GetFn(this, params*)` | Called on read |
| `Set` | `SetFn(this, value, params*)` | Called on assignment; return value is ignored |
| `Call` | `CallFn(this, args*)` | Called when the property is called as a method |
| `Value` | any value | Defines a value property; replaces any accessors |

If `Get` has `MaxParams` 1 (or `Set` has 2) and is not variadic, the property takes no parameters; `obj.prop[x]` is forwarded to the `__Item` of the value returned by `Get`. If there is no `Get` but there is a `Call`, the function itself becomes the (read-only) property value.

### Class-Body Equivalents

| Class body | Equivalent descriptor |
|------------|-----------------------|
| `Prop { get { ... } set { ... } }` | `{Get: fn, Set: fn}` on the Prototype |
| `Prop => expr` | `{Get: fn}` (read-only) |
| `Method() { ... }` | `{Call: fn}` on the Prototype |

A property definition with both `get` and `set` creates two separate functions; they do not share local or static variables.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **First parameter is the target object.** Normal functions used as accessors must declare it explicitly: `GetFn(this)`, `SetFn(this, value)`, `CallFn(this, args*)`. Class property/method definitions add these hidden parameters automatically.
  ✗ `GetFn() => 42` used as `Get` → ✓ `GetFn(this) => 42`
- **One expression per `=>`.** `{set: (this, v) => { ... }}` is not valid; pass a named function for multi-statement logic.
  ✗ `obj.DefineProp("age", {set: (this, v) => { if v < 0 ... }})` → ✓ `SetAge(this, v) { ... }` then `obj.DefineProp("age", {set: SetAge})`
  ✗ `Width { set => { this._w := value } }` in a class body → ✓ `Width { set { this._w := value } }`
- **Partial redefinition keeps old accessors.** `DefineProp(name, {Get: g})` on a property that already has `Set` keeps that `Set`. To remove an accessor, `DeleteProp` and define again.
  ✗ Redefine with only `Get` to make it read-only → ✓ `DeleteProp` then `DefineProp` with only `Get`
- **Read-only means "no setter anywhere".** If no `Set` or value is defined or inherited, assignment throws. An inherited value property counts as a setter: assignment then creates an own value property.
- **`GetOwnPropDesc` reads own properties only.** Call it after `HasOwnProp` (or inside `try`); it throws for an inherited or missing name (see `.GetOwnPropDesc()` in API QUICK-REFERENCE).
  ✗ `obj.GetOwnPropDesc("InheritedMethod")` → ✓ `if obj.HasOwnProp(name) ...`
- **Object literals as descriptors are fine.** `{get: fn}` is the documented form. Using `Object()` with `d.Get := fn` is a readability convention only.
- **Descriptors cost a call per access.** Cache expensive computed values in a backing property.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `PropertyError` | `GetOwnPropDesc(name)` on an inherited or missing property | `HasOwnProp(name)` first |
| `Error` (parameter count) | Accessor function missing the leading `this` parameter | Add `this` as the first parameter |
| Exception on assignment | Assigning to a property with no Set and no value | Add a `Set` accessor or accept the read-only design |
| `ValueError` / `TypeError` (script-thrown) | Validation inside a `Set` accessor rejects a value | Catch at the call site or fix the value |

## TIER 1 — Property Descriptors: get, set, call, and DefineProp
> METHODS COVERED: `DefineProp` · `GetOwnPropDesc` · `HasOwnProp` · class `get`/`set` blocks

```ahk
obj := {}

; ✓ Computed getter — one expression
obj.DefineProp("currentTime", {get: (*) => FormatTime(, "yyyy-MM-dd HH:mm:ss")})
MsgBox(obj.currentTime)

; ✓ Multi-statement setter as a named function
SetAge(this, value) {
    if value < 0 || value > 150
        throw ValueError("Invalid age: " value)
    this._age := value
}
obj.DefineProp("age", {
    get: (this) => this.HasOwnProp("_age") ? this._age : 0,
    set: SetAge
})
obj.age := 25
MsgBox(obj.age)                        ; 25

; ✓ Call descriptor — a method on one object
CalculateOp(this, operation, a, b) {
    switch operation {
        case "add":      return a + b
        case "multiply": return a * b
        default:         throw ValueError("Unknown operation: " operation)
    }
}
obj.DefineProp("calculate", {call: CalculateOp})
MsgBox(obj.calculate("add", 5, 3))     ; 8

; ✓ Inspect a descriptor
desc := obj.GetOwnPropDesc("age")
MsgBox(desc.HasProp("Value") ? "value property" : "dynamic property")   ; dynamic property

; ✓ Class-body form
class Rectangle {
    __New(width, height) {
        this._width := width, this._height := height
    }
    Width {
        get => this._width
        set {
            if value <= 0
                throw ValueError("Width must be positive")
            this._width := value
        }
    }
    Area => this._width * this._height     ; read-only
}
rect := Rectangle(10, 5)
MsgBox(rect.Area)                      ; 50
; rect.Area := 1                       ; ✗ throws — no setter
```

## TIER 2 — Runtime Properties from a Backing Map
> METHODS COVERED: `DefineProp` in a loop · closures over a name · `Map.Get` / `Map.Set`

`DefineProp` can create properties whose names are known only at run time. Each accessor below is a closure over `name`; the values live in a Map.

```ahk
class DynamicObject {
    __New() {
        this.properties := Map()
    }
    AddProperty(name, initialValue := "", validator?) {
        props := this.properties
        Getter(this) {
            return props.Get(name, "")
        }
        Setter(this, value) {
            if IsSet(validator) && !validator(value)
                throw ValueError("Invalid value for " name ": " value)
            props[name] := value
        }
        this.DefineProp(name, {get: Getter, set: Setter})
        props[name] := initialValue
    }
}

d := DynamicObject()
d.AddProperty("age", 0, (v) => IsInteger(v) && v >= 0 && v <= 150)
d.age := 25
MsgBox("Age: " d.age)
; d.age := -1                          ; ✗ ValueError
```

## TIER 3 — Validated Objects and Config Patterns
> METHODS COVERED: validating `set` accessors · `Map.Get` with defaults · single try/catch at the boundary

Put validation in the setter so every assignment is checked in one place.

```ahk
class ValidatedConfig {
    __New() {
        this._settings := Map()
    }
    DatabaseHost {
        get => this._settings.Get("DatabaseHost", "localhost")
        set {
            if value == ""
                throw ValueError("Database host cannot be empty")
            this._settings["DatabaseHost"] := value
        }
    }
    DatabasePort {
        get => this._settings.Get("DatabasePort", 5432)
        set {
            if !IsInteger(value) || value < 1 || value > 65535
                throw ValueError("Port must be between 1 and 65535")
            this._settings["DatabasePort"] := Integer(value)
        }
    }
}

try {
    config := ValidatedConfig()
    config.DatabaseHost := "production.db.company.com"
    config.DatabasePort := 5432
    MsgBox("Host: " config.DatabaseHost)
} catch ValueError as e {
    MsgBox("Configuration error: " e.Message)
}
```

### Performance Notes

- Each read of a `Get` property calls a function; cache values used in tight loops.
- `OwnProps()` with two variables calls every getter; use one variable when only names are needed.
- `Clone()` is shallow and copies dynamic properties without invoking them.

## DROP-IN RECIPES

```ahk
; SafeGetProp — read a property or return a default when it does not exist
SafeGetProp(obj, name, default := "") {
    if Type(name) != "String" || name = ""
        throw TypeError("SafeGetProp: name must be a non-empty string", -1)
    return HasProp(obj, name) ? obj.%name% : default
}
; Call site: theme := SafeGetProp(config, "theme", "light")

; BindAll — store a BoundFunc for each named method as obj.bound_<Name>
BindAll(obj, methodNames*) {
    for name in methodNames {
        if !obj.HasMethod(name)
            throw MethodError("BindAll: method '" name "' not found", -1)
        obj.DefineProp("bound_" name, {value: ObjBindMethod(obj, name)})
    }
    return obj
}
; Call site: BindAll(this, "OnClick"), btn.OnEvent("Click", this.bound_OnClick)

; MakeReadOnly — replace an own value property with a getter; later assignment throws
MakeReadOnly(obj, propName) {
    if !obj.HasOwnProp(propName)
        throw PropertyError("MakeReadOnly: '" propName "' is not an own property", -1)
    currentVal := obj.%propName%
    obj.DeleteProp(propName)
    obj.DefineProp(propName, {get: (this) => currentVal})
    return obj
}
; Call site: MakeReadOnly(config, "ApiKey")
```

## SEE ALSO

- `Module_ObjectBasics.md` — `Any`/`Object` API, object literals, inheritance, method binding.
- `Module_ClassBasics.md` — class property syntax in context.
- `Module_ClassMetaFunctions.md` — `__Get`/`__Set` for property names not known in advance.
- `Module_RuntimePrototyping.md` — existence guards, copying descriptors, safe `DefineProp`.
- `Module_ExceptionHandling.md` — custom error types thrown from setters.
