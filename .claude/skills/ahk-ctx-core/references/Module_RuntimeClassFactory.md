# Module_RuntimeClassFactory.md
<!-- DOMAIN: Runtime class factories (opt-in, advanced) — closure-backed descriptors, method decorators that wrap existing methods, and generating class-like objects at run time with Class/Prototype/Call in AHK v2.0 -->
<!-- SCOPE: Descriptor basics, guards, base changes and built-in prototype extension are in Module_RuntimePrototyping.md. Ordinary class definitions are in Module_ClassBasics.md. Closures in general are in Module_FunctionObjects.md. Normal class/object tasks do not need this module. -->
<!-- TRIGGERS: "runtime class generation", "dynamic class", "class generator", "create class at runtime", metaclass, Class(), "Prototype property", "custom Call", decorator, "method decorator", "wrap method", "intercept method", "call counter", "closure factory", "context-aware property" -->
<!-- CONSTRAINTS: Prefer a static `class` definition. Class() creates a bare Class object with no Call method and no Prototype — the script must supply both before it can construct instances. The standard construction steps are: create the object, set its base to Cls.Prototype, call __Init if present, call __New(args*) if present. A decorator must keep the original function (GetMethod) and pass the object as the first argument when calling it. Each closure keeps its captured variables alive while the descriptor holding it exists. -->
<!-- CROSS-REF: Module_RuntimePrototyping.md, Module_PropertyDescriptors.md, Module_ClassBasics.md, Module_FunctionObjects.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `Class(BaseObj)` expected to produce a ready subclass | Static `class X extends Base`, or manual `Prototype` + `Call` setup | `Class()` returns a bare Class object without `Call` or `Prototype` |
| `new MyDynamicType()` | `MyDynamicType()` | `new` is not a v2 operator |
| Decorator that calls the original without the object | `Original(Obj, Args*)` | The method's hidden `this` parameter receives the wrong value |

## API QUICK-REFERENCE

### Class Construction Pieces

| Item | Signature | Notes |
|------|-----------|-------|
| `ClassObj.Call()` | `ClassObj(Params*)` | Default implementation (inherited from Object/Array/Map): allocate native object, set base to `ClassObj.Prototype`, call `__Init`, call `__New(Params*)`, return it. Can be overridden with `static Call()` |
| `ClassObj.Prototype` | `ClassObj.Prototype := Proto` | Must be an own value property for `ClassObj()` and `value is ClassObj` to work |
| `Class()` | `Class()` | New Class object based on `Class.Prototype`; no `Call` (not a subclass of Object) and no `Prototype` until assigned |
| `Proto.__Class` | `Proto.__Class := "Name"` | Name reported by `Type()` for instances; `__Delete` is never called for objects that own `__Class` |

### Helpers Used

| Function | Signature | Notes |
|----------|-----------|-------|
| `GetMethod()` | `GetMethod(Obj, Name)` | Original implementation to wrap; call it as `fn(Obj, args*)` |
| `ObjSetBase()` | `ObjSetBase(Obj, BaseObj)` | Sets the base without invoking meta-functions |
| `.Bind()` | `fn.Bind(args*)` | Pre-binds leading arguments; cheaper than one closure per object when the same function is shared |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **Use a static `class` first.** Generate types at run time only when names or members are truly data-driven.
- **`Class()` is not a factory shortcut.** Assign `Prototype`, then either set `Base` to an Object-derived class or provide a `Call` method (TIER 3 below). A generated class has an own `Prototype` value property and a working `Call`. The `Class()` wrong form is in V1 → V2 BREAKING CHANGES.
- **Set `Prototype.__Class` on a generated prototype.** Without it, `Type(inst)` shows `"Object"`.
- **Decorators keep the original.** Get it with `GetMethod(obj, name)` before redefining, call it with the object first (`Original(Obj, Args*)`) and return its result. The wrapper that drops the object is in V1 → V2 BREAKING CHANGES.
  ✗ editing the original function to add logging → ✓ `DecorateMethod(obj, name, WithCallCounter)`
- **Closures pin captured state.** A closure stored in a descriptor keeps its captured variables alive until the descriptor is replaced or deleted (`DeleteProp`). Remove closure-backed descriptors when pooled objects are recycled.
  ✗ `{Call: (this) => Prefix this.Name}` in a loop over thousands of objects → ✓ shared function + `Bind`

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Fix |
|----------------|-------------------|-----|
| `MethodError` | Calling a `Class()` object that has no `Call` | Assign `Base`/`Call` as in TIER 3 |
| `MethodError` | `GetMethod(obj, name)` on a missing method before decorating | `HasMethod` first |
| `Error` (parameter count) | Wrapper forwards arguments without the object | `Original(Obj, Args*)` |

## TIER 1 — Closure Factories: Context-Aware Properties
> METHODS COVERED: closure as `Get` accessor · `DefineProp`

```ahk
CreateConstantGetter(value) {
    ConstantGetter(Obj) => value       ; closure over 'value'; Obj is required first param
    return ConstantGetter
}

ApplyVersion(TargetObj, VersionStr) {
    TargetObj.DefineProp("Version", {Get: CreateConstantGetter(VersionStr)})
}

app := {}
ApplyVersion(app, "1.0.4")
MsgBox(app.Version)                    ; 1.0.4 — no visible backing field
; app.Version := "2"                   ; ✗ throws — no setter

; ✓ Shared function + Bind instead of a new closure per object
StaticReader(Prefix, this) => Prefix this.Name
AttachReader(Obj, Prefix) => Obj.DefineProp("Read", {Call: StaticReader.Bind(Prefix)})
item := {Name: "Widget"}
AttachReader(item, "Item: ")
MsgBox(item.Read())                    ; Item: Widget
```

## TIER 2 — Method Decorators: Non-Destructive Interception
> METHODS COVERED: `GetMethod` · `HasMethod` · `DefineProp` · `.Bind()` · variadic forwarding

```ahk
; Decorator: takes the original function, returns a wrapper with the same calling convention
WithCallCounter(Original, Obj, Args*) {
    if !Obj.HasOwnProp("CallCount")
        Obj.CallCount := 0
    Obj.CallCount++
    return Original(Obj, Args*)
}

DecorateMethod(Obj, MethodName, Decorator) {
    if !Obj.HasMethod(MethodName)
        throw MethodError("DecorateMethod: '" MethodName "' not found", -1)
    Original := GetMethod(Obj, MethodName)
    Obj.DefineProp(MethodName, {Call: Decorator.Bind(Original)})
}

class Worker {
    Process(val) => val * 10
}
w := Worker()
DecorateMethod(w, "Process", WithCallCounter)   ; only this instance is decorated
w.Process(5), w.Process(10)
MsgBox(w.CallCount " " w.Process(1))            ; 2 10

; Timing decorator built the same way
WithTiming(Original, Obj, Args*) {
    start := A_TickCount
    try return Original(Obj, Args*)
    finally OutputDebug(Type(Obj) " call took " (A_TickCount - start) " ms")
}
DecorateMethod(w, "Process", WithTiming)        ; stacks on top of WithCallCounter
```

## TIER 3 — Runtime Class Generation (v2.0-compatible)
> METHODS COVERED: `Class()` · `Prototype` · custom `Call` · `ObjSetBase` · `__Init`/`__New` · `OwnProps` · `DeleteProp`

```ahk
CreateDynamicClass(ClassName, BaseClass := Object) {
    cls := Class()
    cls.Base := BaseClass                         ; inherits static members and Call from BaseClass
    proto := {}
    proto.Base := BaseClass.Prototype             ; instances inherit from BaseClass.Prototype
    proto.__Class := ClassName
    cls.Prototype := proto                        ; own value property: required by cls() and 'is'
    return cls
}

Entity := CreateDynamicClass("RuntimeEntity")
IdentifyFn(this) => "I am a " this.__Class
Entity.Prototype.DefineProp("Identify", {Call: IdentifyFn})
InitFn(this, name := "unnamed") {
    this.name := name
}
Entity.Prototype.DefineProp("__New", {Call: InitFn})

e := Entity("probe")                   ; inherited Object.Call: base, __Init, __New
MsgBox(Type(e) " " e.Identify() " " e.name " " (e is Entity))   ; RuntimeEntity I am a RuntimeEntity probe 1

for name in Entity.Prototype.OwnProps()
    OutputDebug(name)                  ; __Class, Identify, __New (order not guaranteed)
Entity.Prototype.DeleteProp("Identify")

; Manual alternative when a custom construction step is needed
ManualCall(cls, args*) {
    inst := {}
    ObjSetBase(inst, cls.Prototype)
    if inst.HasMethod("__New")
        inst.__New(args*)
    return inst
}
Gadget := Class()
Gadget.Prototype := {__Class: "Gadget"}
Gadget.DefineProp("Call", {Call: ManualCall})
g := Gadget()
MsgBox(Type(g))                        ; Gadget
```

### Performance Notes

- `DefineProp` costs a little each time it runs; lookups afterwards cost the same as for class-defined members, plus the accessor call.
- A closure per object allocates captured state per object; when many objects share the same logic, bind a shared function (`StaticReader.Bind(Prefix)`).
- Keep generated hierarchies shallow; lookups walk the base chain.
- Remove closure-backed descriptors (`DeleteProp`) before reusing pooled objects so captured state is released.

## SEE ALSO

- `Module_RuntimePrototyping.md` — descriptor guards, `Base` changes, built-in prototype extension.
- `Module_PropertyDescriptors.md` — get/set/call descriptors.
- `Module_ClassBasics.md` — static `class` definitions (preferred).
- `Module_FunctionObjects.md` — closures and `Bind`.
- `Module_ExceptionHandling.md` — error classes.
