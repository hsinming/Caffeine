# Module_ObjectBasics.md
<!-- DOMAIN: Object basics — the Any/Object type hierarchy, object literals, type checks, inheritance and prototype extension, and method binding for callbacks in AHK v2 -->
<!-- SCOPE: Property descriptors (DefineProp get/set/call), validated objects and descriptor recipes are in Module_PropertyDescriptors.md. Class syntax and lifecycle are in Module_ClassBasics.md / Module_ClassLifecycle.md. Meta-functions are in Module_ClassMetaFunctions.md. Runtime prototype manipulation is in Module_RuntimePrototyping.md. -->
<!-- TRIGGERS: object, "create object", "object literal", Object(), Any, HasProp, HasOwnProp, HasMethod, HasBase, GetMethod, Base, Type(), "is" operator, IsObject, "check object type", Clone, "object clone", extends, prototype, "prototype extension", ObjBindMethod, Bind(this), "method binding", "callback context", SetTimer callback, OnEvent callback -->
<!-- CONSTRAINTS: Instantiate classes with ClassName(); `new` is not a v2 operator. A method reference such as this.Tick passed to SetTimer/OnEvent is a plain function with a hidden `this` parameter — bind it with this.Tick.Bind(this) or ObjBindMethod(this, "Tick"). Plain Objects have no __Item, so obj["key"] indexing is not supported; use Map for key-value data (repository convention). HasProp checks the whole base chain; HasOwnProp checks only own properties. -->
<!-- CROSS-REF: Module_PropertyDescriptors.md, Module_ClassBasics.md, Module_Maps.md, Module_GuiBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `new ClassName()` | `ClassName()` | `new` is not a v2 operator; the line does not construct an object and fails |
| `{key: val}` used as an associative array with `obj[key]` | `Map("key", val)` | Plain Objects have no `__Item`, `Has`, `Get` or `Delete`; `obj["key"]` throws |
| `SetTimer, % this.Method, 1000` | `SetTimer(this.Method.Bind(this), 1000)` | v1 command syntax; an unbound method has no receiver for its hidden `this` parameter |
| `obj.__Set := func` / v1 meta-function signatures | `__Set(Name, Params, Value)` defined in a class, or `DefineProp` for a known property | v2 meta-functions take a `Params` Array (see Module_ClassMetaFunctions.md) |
| `(this, value) => { ...lines... }` as a descriptor | Named function reference | `{` after `=>` is not a block body in v2.0 |
| `set => { this._w := value }` in a class body | `set { this._w := value }` or `set => this._w := value` | `set =>` takes one expression, not a brace block |

## API QUICK-REFERENCE

### Any (root — every value except COM objects inherits these)

| Method / Property | Signature | Returns | Throws | Notes |
|-------------------|-----------|---------|--------|-------|
| `.GetMethod()` | `.GetMethod(Name?, ParamCount?)` | Function object | MethodError | Same as `GetMethod(Value, Name, ParamCount)` |
| `.HasBase()` | `.HasBase(BaseObj)` | 1 or 0 | — | Is `BaseObj` in the value's chain of bases |
| `.HasMethod()` | `.HasMethod(Name?, ParamCount?)` | 1 or 0 | — | Omit `Name` to test whether the value itself is callable; does not detect `__Call` |
| `.HasProp()` | `.HasProp(Name)` | 1 or 0 | — | Own or inherited; does not detect `__Get`/`__Set` |
| `.Base` | `.Base` | Base object | — | For primitives, the prototype matching `Type(Value)`; settable only on Objects |

### Object (instance methods)

| Method / Property | Signature | Returns | Throws | Notes |
|-------------------|-----------|---------|--------|-------|
| `.Clone()` | `.Clone()` | Shallow copy, same base | TypeError for unsupported built-in types | Dynamic properties are copied, not invoked |
| `.DeleteProp()` | `.DeleteProp(Name)` | Removed value (blank if none) | — | Own property only |
| `.HasOwnProp()` | `.HasOwnProp(Name)` | 1 or 0 | — | Own properties only; also `ObjHasOwnProp(Obj, Name)` |
| `.OwnProps()` | `for name, val in obj.OwnProps()` | Enumerator | Getter errors propagate | Two-variable mode skips call-only properties (methods) |
| `.DefineProp()` / `.GetOwnPropDesc()` | see Module_PropertyDescriptors.md | | | |
| `ObjOwnPropCount()` | `ObjOwnPropCount(Obj)` | Integer | — | Number of own properties |

### Binding Methods for Callbacks

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `.Bind()` | `this.Method.Bind(this, args*)` | BoundFunc | Binds the method's function object to `this`; the method is resolved when `Bind` runs |
| `ObjBindMethod()` | `ObjBindMethod(Obj, Method?, Params*)` | BoundFunc | Calls `Obj.Method(...)` by name when invoked, so it also works for methods without a retrievable function object (e.g. COM) |

### Type Introspection

| Function / Operator | Signature | Returns | Notes |
|---------------------|-----------|---------|-------|
| `Type()` | `Type(Value)` | String | Class name: `"Integer"`, `"Float"`, `"String"`, `"Object"`, `"Array"`, `"Map"`, a user class name, or `"Prototype"` for prototype objects |
| `is` | `Value is Class` | 1 or 0 | Base-chain check; works for primitives (`x is Integer`). `"12" is Number` is false — use `IsNumber()` for numeric strings |
| `IsObject()` | `IsObject(Value)` | 1 or 0 | Any object |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **`ClassName()` constructs; `new` does not exist.** A class name is a read-only variable holding the class object, so the same name cannot also hold an instance: `box := Box()` fails (identifiers are case-insensitive). The `new` wrong form is in V1 → V2 BREAKING CHANGES.
- **Bind methods passed as callbacks** to `SetTimer`, `OnEvent`, `Hotkey` or `OnMessage` (`.Bind(this)` / `ObjBindMethod`), and keep the BoundFunc when it must be removed later. `this.Tick` evaluates to the method's function object, whose first (hidden) parameter is `this`. Passed alone, it is called without the object: `SetTimer` rejects it because it needs one parameter, and `OnEvent` would pass the control as `this`.
  ✗ `SetTimer(this.Tick, 1000)` → ✓ `SetTimer(this.boundTick := this.Tick.Bind(this), 1000)`, then delete the timer later with `SetTimer(this.boundTick, 0)`
  ✗ `SetTimer(this.Tick.Bind(this), 0)` to stop — each `Bind` creates a new object, so the timer is not found → ✓ keep the first BoundFunc and pass it again
- **Object literals define value properties.** `{a: 1}` is equivalent to `obj := Object(), obj.a := 1`, except each pair defines a value property directly; setters and `__Set` are not used for the literal's own pairs (except `Base`).
- **Key-value data belongs in a Map** (repository convention backed by API differences): plain Objects have no `Has`, `Get`, `Delete`, `Count` or `__Enum`, so `for k, v in obj` and `obj["k"]` do not work. Object literals stay correct for descriptors, option objects and fixed-shape records. The dictionary wrong form is in V1 → V2 BREAKING CHANGES.
- **`HasProp` vs `HasOwnProp`.** `HasProp` returns 1 for inherited properties and methods too; use `HasOwnProp` when "defined on this instance" matters.
- **`Type()` is the exact type**, not "can be used as a number". Check numeric input with `IsInteger(x)` / `IsNumber(x)`.
  ✗ `Type(x) = "Integer"` rejects `"42"` from an Edit control → ✓ `IsInteger(x)` / `IsNumber(x)`
- **Prototype extension is global.** Defining a property on `String.Prototype`, `Array.Prototype` etc. affects every value of that type. Primitive prototypes do not derive from `Object.Prototype`, so call `DefineProp` indirectly: `({}.DefineProp)(String.Prototype, "Name", desc)`.
  ✗ `Object().DefineProp(String.Prototype, ...)` → ✓ `({}.DefineProp)(String.Prototype, ...)`

Safe-access priority order for properties:
1. `obj.HasOwnProp(name)` / `obj.HasProp(name)` before reading a property that may be absent
2. `Map.Get(key, default)` for key-value data
3. `try`/`catch PropertyError` — only when the error itself is useful

Lifetime (official behavior): objects are reference-counted and freed when the last reference is released; reference cycles keep objects alive until broken. See Module_ClassLifecycle.md.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `PropertyError` | Reading `obj.name` when no own/inherited property exists and no `__Get` handles it | `HasProp()` first, or set a default |
| `MethodError` | Calling a missing method, or `GetMethod()` on a name that is not a method | `HasMethod()` first |
| `Error` / `ValueError` | `SetTimer(this.Method, ...)` with an unbound method (parameter-count validation) | Bind the method |
| Error on `obj["key"]` | Indexing a plain Object (no `__Item`) | Use a Map, or define `__Item` |

## TIER 1 — Object Fundamentals, Creation, and the Any Root
> METHODS COVERED: `Type()` · `HasProp()` · `HasMethod()` · class instantiation · object literal · `Map()`

Every value except COM objects belongs to the `Any` hierarchy. Primitive values (strings, numbers) are not Objects but delegate property and method lookups to their prototype (`String.Prototype`, `Integer.Prototype`, …), so `HasProp()` and `HasMethod()` work on them.

```ahk
MsgBox(Type("Hello") " " Type(42) " " Type(1.5))   ; String Integer Float
MsgBox(HasMethod(0, "HasMethod"))                  ; 1 — primitives inherit Any methods

obj := {}
MsgBox(obj.HasProp("SomeProperty"))                ; 0

class Person {
    __New(name, age) {
        this.name := name
        this.age  := age
    }
    Greet() => MsgBox("Hello, I'm " this.name)
}
john := Person("John", 30)                         ; ✓ no 'new'
john.Greet()

; ✓ Object literal for a fixed-shape record
personData := {name: "John", age: 30}
MsgBox(personData.name)

; ✓ Map for dynamic key-value data
settings := Map("theme", "dark", "volume", 80)
MsgBox(settings.Get("missing", "default"))

; ✗ person := Person() then Person := ...   ; class names are read-only
; ✗ MsgBox(personData["name"])             ; plain Objects have no __Item
```

## TIER 2 — Class Inheritance and Prototype Extension
> METHODS COVERED: `extends` · `super.__New` · `is` · `HasBase()` · `Clone()` · prototype extension on `String.Prototype`

```ahk
class Animal {
    __New(name, species) {
        this.name := name, this.species := species
    }
    Speak() => MsgBox(this.name " makes a sound")
}

class Dog extends Animal {
    __New(name, breed) {
        super.__New(name, "Dog")       ; ✓ run the base constructor on this object
        this.breed := breed
    }
    Speak() => MsgBox(this.name " barks")
}

buddy := Dog("Buddy", "Golden Retriever")
buddy.Speak()
MsgBox((buddy is Animal) " " buddy.HasBase(Animal.Prototype))   ; 1 1

clone := buddy.Clone()                 ; shallow copy, same base
MsgBox(clone.name " " (clone is Dog))  ; Buddy 1

; ✓ Prototype extension — affects every string in the script
ReverseStr(this) {
    out := ""
    Loop Parse this
        out := A_LoopField out
    return out
}
DefProp := {}.DefineProp               ; primitive prototypes lack DefineProp
DefProp(String.Prototype, "Reverse", {call: ReverseStr})
MsgBox("Hello".Reverse())              ; olleH

; ✗ Object().DefineProp(String.Prototype, "x", d)   ; defines on the new Object, not on String.Prototype
```

## TIER 3 — BoundFunc and Callback Context Management
> METHODS COVERED: `.Bind(this)` · `ObjBindMethod()` · `SetTimer` · `Gui.OnEvent`

Bind once and keep the BoundFunc when the callback must be removed later (`SetTimer(fn, 0)`, `OnMessage(msg, fn, 0)`). A timer or message callback holding a bound `this` keeps the object alive — see Module_ClassLifecycle.md for breaking that cycle.

```ahk
class TimerExample {
    __New(name) {
        this.name := name, this.count := 0
        this.boundTick := this.Tick.Bind(this)     ; bind once
    }
    Start() => SetTimer(this.boundTick, 1000)
    Stop()  => SetTimer(this.boundTick, 0)         ; same object deletes the timer
    Tick() {
        this.count++
        ToolTip(this.name " tick #" this.count)
        if this.count >= 3
            this.Stop(), ToolTip()
    }
}
t := TimerExample("MyTimer")
t.Start()

; ✗ SetTimer(this.Tick, 1000)   ; hidden 'this' parameter has no argument

class SimpleGUI {
    __New() {
        this.gui := Gui("+Resize", "My Application")
        this.nameEdit := this.gui.AddEdit("w200")
        btn := this.gui.AddButton("w100", "Submit")
        btn.OnEvent("Click", this.OnSubmit.Bind(this))
        this.gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))
        this.gui.Show("w300 h150")
    }
    OnSubmit(ctrl, *) {
        if this.nameEdit.Value != ""
            MsgBox("Hello, " this.nameEdit.Value "!")
    }
    OnClose(*) => ExitApp()
}
app := SimpleGUI()
```

## SEE ALSO

- `Module_PropertyDescriptors.md` — `DefineProp`, get/set/call descriptors, validated config objects, descriptor recipes.
- `Module_ClassBasics.md` — class syntax, properties, static members, nested classes.
- `Module_ClassLifecycle.md` — `__Delete`, dispose patterns, reference cycles from bound callbacks.
- `Module_Maps.md` — Map as the key-value container.
- `Module_GuiBasics.md` — GUI events and control callbacks.
