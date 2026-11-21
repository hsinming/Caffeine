# Module_RuntimePrototyping.md
<!-- DOMAIN: Runtime prototyping (opt-in, advanced) — attaching call/get/set descriptors to existing objects and prototypes, existence guards before DefineProp, inspecting and copying own descriptors, ObjSetBase/Base changes, and extending built-in prototypes in AHK v2 -->
<!-- SCOPE: Basic DefineProp usage and validated properties are in Module_PropertyDescriptors.md. Static class definitions and inheritance are in Module_ClassBasics.md. Closure factories, method decorators and runtime class generation are in Module_RuntimeClassFactory.md. Normal class/object tasks do not need this module. -->
<!-- TRIGGERS: "add method at runtime", "add property to instance", "change method at runtime", "modify prototype", "extend built-in type", "String.Prototype", "Array.Prototype", ObjSetBase, ObjGetBase, Base, GetMethod, GetOwnPropDesc, "copy descriptors", mixin, "safe DefineProp", "descriptor object", prototyping -->
<!-- CONSTRAINTS: Get/Set/Call functions receive the target object as their first parameter. DefineProp replaces an existing own property of the same name without error (a dynamic descriptor keeps accessors it does not name). GetOwnPropDesc throws PropertyError for names the object does not own. Changing Base (or ObjSetBase) throws if it would change the object's native type (e.g. an Array must keep Array.Prototype in its chain). Primitive prototypes lack DefineProp; call it indirectly. Changes to shared prototypes affect every value of that type. -->
<!-- CROSS-REF: Module_PropertyDescriptors.md, Module_RuntimeClassFactory.md, Module_ClassBasics.md, Module_ObjectBasics.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `obj.Method := Func("Name")` | `obj.DefineProp("Method", {Call: Name})` | `Func("Name")` lookup is v1 style; a value property holding a function is still callable but differs from a method |
| `obj.base := proto` on a different native type | Keep the native type; use composition | Throws if the native type would change |
| Getter/setter without a leading object parameter | `GetFn(this)` / `SetFn(this, value)` | Parameter-count error or wrong binding |
| `(this) => { ... }` multi-line descriptor | Named function | `=> {` is not a block body in v2.0 |
| Assuming `DefineProp` refuses duplicate names | Guard with `HasOwnProp`/`HasMethod` first | `DefineProp` silently replaces |

## API QUICK-REFERENCE

### Descriptor and Prototype Functions

| Method / Function | Signature | Returns | Throws | Notes |
|-------------------|-----------|---------|--------|-------|
| `.DefineProp()` | `obj.DefineProp(Name, Desc)` | Target object | — | Value descriptor replaces value and accessors; dynamic descriptor keeps unspecified accessors |
| `.GetOwnPropDesc()` | `obj.GetOwnPropDesc(Name)` | New descriptor object | PropertyError | Only accessors defined on `obj` itself appear |
| `.HasOwnProp()` | `obj.HasOwnProp(Name)` | 1 or 0 | — | Own only; also `ObjHasOwnProp(obj, Name)` (cannot be overridden) |
| `.HasProp()` / `.HasMethod()` | `obj.HasMethod(Name, ParamCount?)` | 1 or 0 | — | Whole chain; `ParamCount` excludes `this` |
| `GetMethod()` | `GetMethod(Value, Name?, ParamCount?)` | Function object | MethodError | Not found, or only reachable through a getter / `__Call` |
| `.DeleteProp()` | `obj.DeleteProp(Name)` | Removed value | — | Own property only |
| `.OwnProps()` | `for name in obj.OwnProps()` | Enumerator | — | One variable: names, getters not called |
| `.Base` | `obj.Base := NewBase` | — | Exception if native type would change | Settable only on Objects |
| `ObjSetBase()` | `ObjSetBase(Obj, BaseObj)` | — | Exception for incorrect types | Bypasses meta-functions and overridden `Base` |
| `ObjGetBase()` | `ObjGetBase(Value)` | Base or `""` | — | Only `Any.Prototype` has no base |

### Descriptor Keys

| Key | Function signature | Notes |
|-----|--------------------|-------|
| `Get` | `GetFn(Obj, params*)` | Read |
| `Set` | `SetFn(Obj, Value, params*)` | Assignment; return value ignored |
| `Call` | `CallFn(Obj, args*)` | `obj.Name(args)` → `CallFn(obj, args*)` |
| `Value` | any | Value property; not combined with Get/Set/Call |

`{Get: fn}` object literals are the documented descriptor form. Building a descriptor with `d := Object(), d.Call := fn` is an optional readability convention.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **Object parameter first.** `GetFn(Obj)`, `SetFn(Obj, Value)`, `CallFn(Obj, Args*)`. The getter/setter wrong form is in V1 → V2 BREAKING CHANGES.
  ✗ `CallFn(x)` — `x` receives the object, the caller's argument shifts → ✓ `CallFn(Obj, x)`
- **Multi-statement accessors are named functions.** The `=> { ... }` descriptor wrong form is in V1 → V2 BREAKING CHANGES.
- **Guard before replacing.** `DefineProp` overwrites an existing own property with no error. When replacing is not intended, check `HasOwnProp`/`HasMethod` first: `if !obj.HasOwnProp(name) { obj.DefineProp(name, desc) }`. The unguarded wrong form is in V1 → V2 BREAKING CHANGES.
- **`GetOwnPropDesc` needs an own property.** Check `HasOwnProp` first; inherited methods live on the class Prototype, not on the instance.
  ✗ `inst.GetOwnPropDesc("Method")` → ✓ inspect `ClassName.Prototype` or check `HasOwnProp`
- **Native type is fixed.** An Array must keep `Array.Prototype` in its base chain, a Map `Map.Prototype`, and so on. `Base`/`ObjSetBase` changes keep the native type (V1 → V2 BREAKING CHANGES).
  ✗ `arr.Base := {}` → ✓ subclass `Array`
- **Primitive prototypes** (`String.Prototype`, `Integer.Prototype`, …) do not derive from `Object.Prototype`; use `DefProp := {}.DefineProp` then `DefProp(String.Prototype, ...)`. Value properties cannot be assigned on primitive values.
- **Shared-prototype edits are global** (advice): a method added to `Array.Prototype` appears on every Array in the script, including in libraries. Change a built-in prototype only when explicitly required. Prefer a subclass (`class MyArray extends Array`) or a helper function; undo with `DeleteProp` if needed.
  ✗ `Array.Prototype.DefineProp("Sum", d)` → ✓ subclass or helper function
- **`GetMethod` limits.** It cannot retrieve methods that exist only through a getter returning a function or through `__Call`, even though calling them works.

Safe-access priority order:
1. `HasOwnProp(name)` — own vs inherited; required before `GetOwnPropDesc`
2. `HasMethod(name)` — before `GetMethod` or decorating
3. `HasProp(name)` — chain-level existence
4. `IsObject(target)` — before `DefineProp`/`Base` changes
5. `try`/`catch` — around `Base`/`ObjSetBase` when the base may be incompatible

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `MethodError` | `GetMethod(obj, "Name")` when the method is missing or only reachable via a getter/`__Call` | `HasMethod` first; `try` for getter-provided methods |
| `PropertyError` | `GetOwnPropDesc("Name")` for an inherited or missing property | `HasOwnProp` first |
| Exception on `Base`/`ObjSetBase` | New base would change the native type, or wrong argument types | Keep the same built-in prototype in the chain |
| Exception on assignment | Setting a value property on a primitive (`"".test := 2`) | Define a setter or do not store state on primitives |

## TIER 1 — Descriptor Fundamentals: Call, Get and Set on One Object
> METHODS COVERED: `DefineProp` · `Call`/`Get`/`Set` descriptor keys · `Type()`

```ahk
CustomMethod(Obj, Prefix) => Prefix ": " Obj.Name

MyObj := {Name: "Alpha"}
MyObj.DefineProp("Greet", {Call: CustomMethod})
MsgBox(MyObj.Greet("Status"))          ; Status: Alpha — CustomMethod(MyObj, "Status")

GetterFunc(Obj) => Obj._HiddenValue * 2
SetterFunc(Obj, AssignedValue) {
    if !IsInteger(AssignedValue)
        throw TypeError("Only integers allowed.", -1)
    Obj._HiddenValue := Integer(AssignedValue)
}
MyData := {_HiddenValue: 10}
MyData.DefineProp("Doubled", {Get: GetterFunc, Set: SetterFunc})
MsgBox(MyData.Doubled)                 ; 20
MyData.Doubled := 50                   ; SetterFunc(MyData, 50)
; MyData.Doubled := "x"                ; ✗ TypeError from SetterFunc

; ✓ Optional readability convention: build the descriptor step by step
desc := Object()
desc.Call := CustomMethod
MyObj.DefineProp("Greet2", desc)
```

## TIER 2 — Existence Guards and Descriptor Inspection
> METHODS COVERED: `HasMethod` · `HasOwnProp` · `GetOwnPropDesc` · `GetMethod` · `IsObject`

```ahk
SafeDefineMethod(TargetObj, MethodName, FuncRef) {
    if !IsObject(TargetObj)
        throw TypeError("Target must be an object.", -1)
    if TargetObj.HasMethod(MethodName)
        return false                   ; do not replace
    TargetObj.DefineProp(MethodName, {Call: FuncRef})
    return true
}

DescribeOwnProp(Obj, PropName) {
    if !Obj.HasOwnProp(PropName)
        return "not an own property"
    d := Obj.GetOwnPropDesc(PropName)
    if d.HasProp("Value")
        return "value property"
    kinds := ""
    for k in ["Get", "Set", "Call"]
        if d.HasProp(k)
            kinds .= k " "
    return "dynamic: " Trim(kinds)
}

RetrieveMethodFunc(Obj, MethodName) {
    if !Obj.HasMethod(MethodName)
        return ""
    try return GetMethod(Obj, MethodName)
    catch MethodError
        return ""                      ; e.g. method supplied by a getter
}

SayHello(Obj) => "Hello from " (Obj.HasProp("Name") ? Obj.Name : "unknown")
TestObj := {Name: "Beta"}
MsgBox(SafeDefineMethod(TestObj, "Speak", SayHello))   ; 1
MsgBox(SafeDefineMethod(TestObj, "Speak", SayHello))   ; 0 — already defined
MsgBox(DescribeOwnProp(TestObj, "Name"))               ; value property
MsgBox(DescribeOwnProp(TestObj, "Speak"))              ; dynamic: Call
fn := RetrieveMethodFunc(TestObj, "Speak")
MsgBox(fn(TestObj))                                    ; Hello from Beta — pass 'this' explicitly
```

## TIER 3 — Changing Bases and Extending Built-in Prototypes
> METHODS COVERED: `Base` · Array subclass · indirect `DefineProp` on `String.Prototype`

```ahk
; ✓ Mixin-style base swap on a plain Object
Walker := {Walk: (this) => this.name " walks"}
pet := {name: "Rex"}
pet.Base := Walker                     ; Object → Object: same native type
MsgBox(pet.Walk())                     ; Rex walks

; ✗ Changing the native type
arr := [1, 2]
try arr.Base := Walker                 ; Walker is not derived from Array.Prototype
catch as e
    MsgBox("Refused: " Type(e))

; ✓ Array subclass instead of editing Array.Prototype
class NumList extends Array {
    Sum() {
        total := 0
        for v in this
            total += v
        return total
    }
}
MsgBox(NumList(1, 2, 3).Sum())         ; 6

; ✓ Extending a primitive prototype (global effect — use sparingly)
DefProp := {}.DefineProp
DefProp(String.Prototype, "Length", {get: StrLen})
MsgBox("hello".Length)                 ; 5
; "abc".tag := 1                       ; ✗ cannot assign value properties on primitives
```

## DROP-IN RECIPES

```ahk
; SafeDefineProp — validates the descriptor and refuses to overwrite unless Force is true
SafeDefineProp(Obj, PropName, DescObj, Force := false) {
    if Type(PropName) != "String" || PropName = ""
        throw TypeError("SafeDefineProp: PropName must be a non-empty string", -1)
    if !IsObject(Obj) || !IsObject(DescObj)
        throw TypeError("SafeDefineProp: Obj and DescObj must be objects", -1)
    if !DescObj.HasProp("Get") && !DescObj.HasProp("Set")
        && !DescObj.HasProp("Call") && !DescObj.HasProp("Value")
        throw ValueError("SafeDefineProp: descriptor needs Get, Set, Call or Value", -1)
    if !Force && Obj.HasOwnProp(PropName)
        throw Error("SafeDefineProp: '" PropName "' already exists; pass Force := true", -1)
    return Obj.DefineProp(PropName, DescObj)
}
; Call site: SafeDefineProp(MyObj, "Status", {Get: StatusGetter})

; CopyOwnDescriptors — copies own properties (descriptor level) from one object to another
CopyOwnDescriptors(FromObj, ToObj, ExcludeList := []) {
    excluded := Map()
    for name in ExcludeList
        excluded[name] := true
    for PropName in FromObj.OwnProps() {   ; one variable: getters are not invoked
        if excluded.Has(PropName)
            continue
        ToObj.DefineProp(PropName, FromObj.GetOwnPropDesc(PropName))
    }
    return ToObj
}
; Call site: CopyOwnDescriptors(MixinProto, Target.Prototype, ["__Class"])
```

## SEE ALSO

- `Module_PropertyDescriptors.md` — everyday `DefineProp`, get/set/call, validated properties.
- `Module_RuntimeClassFactory.md` — closure factories, method decorators, runtime class generation.
- `Module_ClassBasics.md` — static class definitions and `extends`.
- `Module_ObjectBasics.md` — `Any`/`Object` API.
- `Module_ExceptionHandling.md` — error classes thrown here.
