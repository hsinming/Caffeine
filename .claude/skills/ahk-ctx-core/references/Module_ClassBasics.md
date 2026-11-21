# Module_ClassBasics.md
<!-- DOMAIN: Class basics — class definitions, __New constructors, instance and static members, properties, inheritance with super, nested classes and factory methods in AHK v2 -->
<!-- SCOPE: Meta-functions (__Get/__Set/__Call/__Item/__Enum) and fluent interfaces are in Module_ClassMetaFunctions.md. __Delete, dispose patterns, reference cycles and observers are in Module_ClassLifecycle.md. Runtime prototype manipulation is in Module_RuntimePrototyping.md. GUI classes are in Module_GuiBasics.md. -->
<!-- TRIGGERS: class, "create a class", "define class", __New, constructor, instantiate, "instance variable", static, "static method", "class variable", property, get, set, extends, inheritance, super, polymorphism, "abstract method", "nested class", "factory method", "factory pattern", __Init, "class initialization" -->
<!-- CONSTRAINTS: Instantiate with ClassName(); `new` is not a v2 operator. A class name is a read-only global, so `box := Box()` fails. Derived constructors call super.__New(args*); super() means super.Call(), not the base constructor. Static members belong to the class object: use ClassName.Member (or this.Member inside a static method); an instance does not inherit static members. Instance variable declarations run before __New. -->
<!-- CROSS-REF: Module_ClassMetaFunctions.md, Module_ClassLifecycle.md, Module_ObjectBasics.md, Module_PropertyDescriptors.md, Module_RuntimePrototyping.md, Module_GuiBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `new ClassName()` | `ClassName()` | `new` is not a v2 operator; no object is constructed |
| `super()` in a derived `__New` | `super.__New(args*)` | `super()` is `super.Call()` — it does not initialize the current object |
| `this.StaticProp` inside an instance method | `ClassName.StaticProp` | Instances inherit from `ClassName.Prototype`, not from the class object; reading fails, writing creates an instance property |
| `instance := ClassName()` where the variable has the class's name | `obj := ClassName()` | Assigning to a top-level class name is a load-time error |
| `(x) => { return x * 2 }` callback | Named function or `(x) => x * 2` | `=> {` is not a block body in v2.0 |
| `{key: val}` for component specs read with `.Has()` | `Map("key", val)` | Plain Objects have no `Has`/`Get` |

## API QUICK-REFERENCE

### Class Members

| Member | Syntax | Notes |
|--------|--------|-------|
| Instance variable | `name := expr` in class body | Evaluated for each new instance (in an auto-generated `__Init`) after base-class declarations, before `__New` |
| Static variable | `static name := expr` | Evaluated once when the class is initialized; subclasses can read it unless they own the name |
| Method | `Name(params) { ... }` | Defined on `ClassName.Prototype`; hidden first parameter `this` |
| Static method | `static Name(params) { ... }` | Defined on the class object; `this` is the class (or subclass) |
| Fat-arrow method | `Name(params) => expr` | Single expression |
| Property | `Name { get { ... } set { ... } }` | `set` has hidden `value`; `get`/`set` do not share locals |
| Short property | `Name => expr` | Getter only |
| Parameterized property | `Name[key] { get ... set ... }` | `obj.Name[key]` |
| Nested class | `class Inner { ... }` inside a class | Stored as `Outer.Inner`; no link to Outer instances |

### Construction

| Item | Signature | Notes |
|------|-----------|-------|
| `ClassName()` | `ClassName(args*)` | Default `Call`: creates the object, sets its base to `ClassName.Prototype`, calls `__Init`, then `__New(args*)` |
| `__New()` | `__New(params*)` | Constructor. Construction fails if `__New` exists but cannot be called with the given arguments, or if arguments are passed and there is no `__New` |
| `super.__New()` | `super.__New(args*)` | Runs the base-class constructor on `this` |
| `super.Method()` | `super.Method(args*)` | Base version of an overridden method or property; throws if not defined in a superclass |
| `static __New()` | `static __New()` | Runs when the class is initialized — once for the class and once for each subclass that does not define its own |
| `.__Class` | `obj.__Class` | Class name (stored on the Prototype) |

### Utility Functions Used Here

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `HasProp()` / `HasMethod()` | `obj.HasProp(name)` | 1 or 0 | Own or inherited |
| `Map()` | `Map(k, v, ...)` | Map | Key-value state (convention for dynamic data) |
| `Type()` | `Type(value)` | String | Class name |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Instantiate with `ClassName(args*)` and store the instance in a variable whose name differs from the class name (case-insensitive). The `new` and same-name wrong forms are in V1 → V2 BREAKING CHANGES.
- A derived `__New` calls `super.__New(args*)` before using fields the base constructor sets. `super()` is `super.Call()`; that wrong form is in V1 → V2 BREAKING CHANGES.
- Access static members through the class name: `ClassName.StaticProp`. Inside a static method `this.StaticProp` is fine because `this` is the class. The instance-method wrong form is in V1 → V2 BREAKING CHANGES.
- Instance variable declarations behave like assignments run before `__New`. A class must not define both an `__Init` method and instance variable declarations.
- A class is initialized the first time it is referenced (or when execution reaches its definition at startup). Static initializers that refer to each other across classes can see a value that is not set yet.
- Callbacks: bind instance methods passed to `SetTimer`, `OnEvent`, `Hotkey`, `OnMessage` (`this.Method.Bind(this)` or `ObjBindMethod(this, "Method")`) and keep the BoundFunc if you must remove it later. Multi-statement callbacks use named functions or methods; the `=> { }` wrong form is in V1 → V2 BREAKING CHANGES.
- `{}` object literals are fine for descriptors and options; use `Map()` for state that needs `Has`/`Delete`/enumeration (repository convention). The `.Has()` on an object literal wrong form is in V1 → V2 BREAKING CHANGES.
- Naming guidance (convention): `Get*`, `Is*`, `Set*` prefixes should match what a method does; keep logging/cache updates out of pure reads.
  ✗ `GetStatus()` sets `this.lastChecked` → ✓ `GetStatus()` + `RecordCheckTime()`

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| Load-time error | Assigning to a top-level class name (`Box := Box()`) | Use a different variable name |
| `Error` (parameter count) | `ClassName(args)` where `__New` takes a different number of parameters, or args passed with no `__New` | Match `__New`'s signature |
| `PropertyError` | `this.StaticProp` read from an instance; base field read before `super.__New()` ran | Use `ClassName.StaticProp`; call `super.__New()` first |
| `Error` (super) | `super.Method()` where no superclass defines `Method` | Define it in the base class or drop the `super` call |

## TIER 1 — Class Fundamentals: Constructors, Properties, and Static Members
> METHODS COVERED: `__New` · instance/static variables · `get`/`set` property · fat-arrow property · parameterized property · bound timer callback

```ahk
class Animal {
    name := ""                         ; instance variable — runs before __New
    age  := 0
    __New(name, age) {
        this.name := name
        this.age  := age
    }
    GetInfo() => this.name " is " this.age " years old"
}

class MathUtils {
    static PI := 3.14159
    static CalculateArea(radius) => this.PI * radius * radius   ; this = MathUtils here
}

pet := Animal("Buddy", 5)
MsgBox(pet.GetInfo())
MsgBox(MathUtils.CalculateArea(10))

class Person {
    _name := ""
    _age  := 0
    phoneNumbers := Map()

    name {
        get => this._name
        set {
            if Type(value) != "String" || value = ""
                throw ValueError("Name must be a non-empty string")
            this._name := value
        }
    }
    age {
        get => this._age
        set => this._age := Max(0, Integer(value))
    }
    displayName => this._name " (" this._age ")"
    phoneNumber[kind] {
        get => this.phoneNumbers.Get(kind, "")
        set => this.phoneNumbers[kind] := value
    }
    __New(name, age) {
        this.name := name              ; runs the setter
        this.age  := age
    }
}
p := Person("John", 25)
p.phoneNumber["mobile"] := "555-1234"
MsgBox(p.displayName " " p.phoneNumber["mobile"])

class TooltipTimer {
    static Interval := 1000
    __New() {
        this.seconds := 0
        this.timerCallback := this.UpdateDisplay.Bind(this)   ; keep it to stop the timer
        SetTimer(this.timerCallback, TooltipTimer.Interval)
    }
    UpdateDisplay() {
        this.seconds++
        ToolTip("Elapsed: " this.seconds " s")
    }
    Stop() {
        SetTimer(this.timerCallback, 0)
        ToolTip()
    }
}
tt := TooltipTimer()
; tt.Stop() later — the timer holds a reference, so __Delete alone would never run (see Module_ClassLifecycle.md)
```

## TIER 2 — Inheritance and Polymorphism
> METHODS COVERED: `extends` · `super.__New()` · `super.Method()` · abstract-method pattern

AHK does not chain constructors automatically: a derived `__New` must call `super.__New(...)`. A base method that always throws acts as an "abstract" method (convention).

```ahk
class Vehicle {
    __New(make, model, year) {
        this.make := make, this.model := model, this.year := year
    }
    GetDescription() => this.year " " this.make " " this.model
    Start() => MsgBox("Starting " this.GetDescription())
    GetMaxSpeed() {
        throw Error("GetMaxSpeed must be implemented by " this.__Class)
    }
}

class Car extends Vehicle {
    __New(make, model, year, doors) {
        super.__New(make, model, year)
        this.doors := doors
    }
    Start() {
        super.Start()
        MsgBox("Car engine started")
    }
    GetMaxSpeed() => 120
}

class Motorcycle extends Vehicle {
    GetMaxSpeed() => 180               ; inherits Vehicle.__New
}

for v in [Car("Toyota", "Camry", 2023, 4), Motorcycle("Harley", "Sportster", 2023)]
    MsgBox(v.GetDescription() " - max " v.GetMaxSpeed())

; ✗ super()   ; equivalent to super.Call(), not the base constructor
```

## TIER 3 — Nested Classes and Factory Patterns
> METHODS COVERED: nested class `Outer.Inner()` · static factory methods · Map specs with `.Get()` defaults

A nested class is stored as a static property of the outer class (`Outer.Inner`). It has no automatic link to the outer class or its instances; reach shared state through `Outer.StaticProp`.

```ahk
class UIComponentFactory {
    static theme := "default"

    class Button {
        __New(text, x, y, width := 100, height := 30) {
            this.text := text, this.x := x, this.y := y
            this.width := width, this.height := height
        }
        Render(g) => g.AddButton("x" this.x " y" this.y " w" this.width " h" this.height, this.text)
        ThemedColor() => UIComponentFactory.theme = "dark" ? 0x333333 : 0xF0F0F0
    }

    class TextInput {
        __New(placeholder, x, y, width := 200, height := 25) {
            this.placeholder := placeholder, this.x := x, this.y := y
            this.width := width, this.height := height
        }
        Render(g) => g.AddEdit("x" this.x " y" this.y " w" this.width " h" this.height, this.placeholder)
    }

    ; ✓ Specs are Maps so optional keys can use .Get(key, default)
    static CreateForm(specs) {
        result := []
        for spec in specs {
            switch spec["type"] {
                case "button":
                    result.Push(UIComponentFactory.Button(spec["text"], spec["x"], spec["y"]
                        , spec.Get("width", 100), spec.Get("height", 30)))
                case "input":
                    result.Push(UIComponentFactory.TextInput(spec["placeholder"], spec["x"], spec["y"]
                        , spec.Get("width", 200), spec.Get("height", 25)))
            }
        }
        return result
    }
}

UIComponentFactory.theme := "dark"
components := UIComponentFactory.CreateForm([
    Map("type", "input",  "placeholder", "Enter name", "x", 10, "y", 10),
    Map("type", "button", "text", "Submit", "x", 10, "y", 40, "width", 80)
])
g := Gui()
for c in components
    c.Render(g)
g.Show()
```

## SEE ALSO

- `Module_ClassMetaFunctions.md` — `__Get`, `__Set`, `__Call`, `__Item`, `__Enum`, fluent builders.
- `Module_ClassLifecycle.md` — `__Delete`, dispose patterns, reference cycles, observers, pooling.
- `Module_ObjectBasics.md` — `Any`/`Object` API, method binding for callbacks.
- `Module_PropertyDescriptors.md` — `DefineProp` equivalents of property definitions.
- `Module_RuntimePrototyping.md` — changing prototypes and bases at run time.
- `Module_GuiBasics.md` — GUI classes and event wiring.
- `Module_ExceptionHandling.md` — custom `Error` subclasses.
