# Module_ClassLifecycle.md
<!-- DOMAIN: Object lifetime in classes — reference counting, __Delete, the Dispose pattern, try/finally cleanup, reference cycles from timers/callbacks/observers, object pointers and pooling in AHK v2 -->
<!-- SCOPE: Class syntax and constructors are in Module_ClassBasics.md. Meta-functions are in Module_ClassMetaFunctions.md. GUI Destroy and event-handler cycles are detailed in Module_GuiBasics.md. Raw DllCall memory is in Module_DllCallBasics.md. -->
<!-- TRIGGERS: __Delete, destructor, dispose, Dispose, cleanup, "resource cleanup", "release resources", "try/finally", RAII, "reference count", "reference cycle", "circular reference", "memory leak", "object not freed", "weak reference", ObjPtr, ObjPtrAddRef, ObjFromPtr, ObjFromPtrAddRef, ObjAddRef, ObjRelease, "observer pattern", "event emitter", subscribe, unsubscribe, "object pool" -->
<!-- CONSTRAINTS: Objects are reference-counted: __Delete runs exactly when the last reference is released, so it never runs while a cycle (including one through a bound timer or event callback) keeps the object alive. __Delete is not called for objects referenced only by locals of functions that had not returned when the script was terminated directly (e.g. ExitApp), and at exit globals are released in an arbitrary order. Prefer an explicit, idempotent Dispose method, called from finally, with __Delete calling it only as a safeguard. A pointer from ObjPtr is not a reference; using it after the object is freed is invalid. -->
<!-- CROSS-REF: Module_ClassBasics.md, Module_ObjectBasics.md, Module_GuiBasics.md, Module_Timers.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

### Lifecycle Members

| Member | Signature | Notes |
|--------|-----------|-------|
| `__Delete()` | `__Delete()` | Called when the last reference is released. Not called for objects that own a `__Class` property (prototypes). An unhandled error inside it shows an error dialog as if from a new thread, then `__Delete` returns |
| `Dispose()` (convention) | `Dispose()` | Frees resources and breaks cycles; must do nothing on a second call; may also be called from `__Delete` as a safeguard (pattern described in the official docs) |
| `try`/`finally` | `try { ... } finally { obj.Dispose() }` | Cleanup runs on success and on error |

### Object Pointer Functions

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `ObjPtr()` | `ObjPtr(Obj)` | Integer address | Does not add a reference; the address is valid only until the object is deleted |
| `ObjPtrAddRef()` | `ObjPtrAddRef(Obj)` | Integer address | Same as `ObjAddRef(address := ObjPtr(Obj))` — the address now counts as a reference |
| `ObjFromPtr()` | `ObjFromPtr(Ptr)` | Object | Takes ownership of a counted reference; the address must then be treated as invalid |
| `ObjFromPtrAddRef()` | `ObjFromPtrAddRef(Ptr)` | Object | Makes a new counted reference from an address |
| `ObjAddRef()` / `ObjRelease()` | `ObjAddRef(Ptr)` | New ref count (debug use only) | Increment/decrement manually |

### Collections Used Here

| Method | Signature | Notes |
|--------|-----------|-------|
| `Map.Clear()` | `m.Clear()` | Remove all items |
| `Map.Delete()` | `m.Delete(key)` | Returns the removed value; throws UnsetItemError if the key is absent |
| `Array.Clone()` | `arr.Clone()` | Shallow copy — iterate a copy when handlers may unsubscribe during the loop |
| `Array.RemoveAt()` | `arr.RemoveAt(i)` | Shifts later items left; remove from the end backwards |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- **Reference counting is deterministic, cycles are not collected.** An object is deleted (and `__Delete` called) at the moment its last reference is released. Two objects that refer to each other, or an object whose bound method is held by `SetTimer`/`OnMessage`/a GUI event, are never deleted until the cycle is broken.
  ✗ Relying on `obj := ""` to stop a timer whose callback is `obj.Tick.Bind(obj)` — the timer still holds `obj` → ✓ `obj.Dispose()` deletes the timer (`SetTimer(this.boundTick, 0)`) and breaks the cycle
  ✗ `__Delete() { SetTimer(this.cb, 0) }` with `this.cb` bound to `this` → ✓ explicit `Dispose()`, or bind an uncounted pointer as in TIER 3
- **Direct termination skips some `__Delete` calls.** After `ExitApp` or tray-menu exit, objects held only by locals of unfinished functions are not released. At exit, global and static variables are released in an arbitrary order, so `__Delete` should not rely on other globals.
- **`Dispose` is idempotent and called explicitly** (official pattern, labeled convention in this repository). Every resource-owning class has one. Call it from `finally` or from the owner; let `__Delete` call it only as a fallback. `Dispose()` stops timers/monitors with the same BoundFunc that registered them and clears properties that form cycles.
  ✗ `SetTimer(this.Tick.Bind(this), 0)` — each `Bind` makes a new object → ✓ `SetTimer(this.boundTick, 0)` with the stored BoundFunc
- **`__Delete` must not throw.** Catch and log cleanup errors inside it.
- **Pointers are not weak references.** An `ObjPtr` value does not keep the object alive and must never be used after the object is deleted; there is no way to test whether it is still valid. Use explicit unsubscribe/dispose ownership instead of "liveness probes".
  ✗ `if ObjFromPtrAddRef(p)` as a liveness check → ✓ explicit unsubscribe / dispose
- **Observer subscriptions are removed** (token `Dispose()`) before the subscriber is dropped. When handlers may unsubscribe during dispatch, iterate a copy.
  ✗ `for cb in this.listeners[event]` → ✓ iterate `this.listeners[event].Clone()`
- **Empty `catch` blocks** follow the convention in `Module_ExceptionHandling.md` (ahk-ctx-logic). In cleanup loops a comment alone is not enough: log the error (e.g. `OutputDebug`).
  ✗ `catch {}` → ✓ `catch as err` + `OutputDebug`

Resource lifecycle checklist: file handles, COM objects, timers, message monitors, GUI windows and hooks each need an owner that releases them in `Dispose`/`finally`.

## RUNTIME ERROR MAPPING

| Symptom / Exception | Trigger Condition | Fix |
|---------------------|-------------------|-----|
| `__Delete` never runs; timer keeps firing | Timer/OnMessage/event holds a BoundFunc with the object bound | Call `Dispose()` to remove the callback, or bind an uncounted pointer (see TIER 3) |
| Error dialog from `__Delete` | Unhandled error during cleanup | Wrap cleanup steps in `try`/`catch` and log |
| `UnsetItemError` | `Map.Delete(key)` for a key already removed | Check `Has(key)` first |
| Crash / undefined behavior | Using an `ObjPtr` address after the object was freed | Keep a real reference or unsubscribe explicitly |

## TIER 1 — Resource Management with Dispose and try/finally
> METHODS COVERED: `Dispose()` · `__Delete()` · `try`/`finally` · `Map.Clear()` · `FileDelete()`

```ahk
class TempFileSet {
    __New(prefix) {
        this.prefix := prefix
        this.files := []
        this.disposed := false
    }
    Create(text) {
        if this.disposed
            throw Error("TempFileSet: already disposed", -1)
        path := A_Temp "\" this.prefix "_" A_TickCount "_" this.files.Length ".tmp"
        FileAppend(text, path, "UTF-8")
        this.files.Push(path)
        return path
    }
    Dispose() {
        if this.disposed                  ; ✓ idempotent
            return
        this.disposed := true
        for path in this.files {
            try FileDelete(path)
            catch as err
                OutputDebug("TempFileSet cleanup: " err.Message)
        }
        this.files := []
    }
    __Delete() => this.Dispose()          ; safeguard only
}

tmp := TempFileSet("job")
try {
    tmp.Create("step 1")
    tmp.Create("step 2")
} finally {
    tmp.Dispose()                         ; ✓ runs even if Create throws
}

; ✓ Reusable "using" helper
Using(resource, callback) {
    try {
        return callback(resource)
    } finally {
        if HasMethod(resource, "Dispose")
            resource.Dispose()
    }
}
Using(TempFileSet("once"), (t) => t.Create("data"))
```

## TIER 2 — Observer Pattern with Explicit Subscriptions
> METHODS COVERED: subscription token · `Array.Clone()` before iterating · backwards `RemoveAt` · `OutputDebug`

A Model that holds a callback bound to a View, while the View holds the Model, is a cycle. Return a subscription object from `On()`; the subscriber disposes it before it is released.

```ahk
class EventSubscription {
    __New(emitter, event, callback) {
        this.emitter := emitter, this.event := event, this.callback := callback
        this.active := true
    }
    Dispose() {
        if !this.active
            return
        this.active := false
        this.emitter.Off(this.event, this.callback)
        this.emitter := "", this.callback := ""     ; break references
    }
}

class EventEmitter {
    __New() {
        this.listeners := Map()
    }
    On(event, callback) {
        if !this.listeners.Has(event)
            this.listeners[event] := []
        this.listeners[event].Push(callback)
        return EventSubscription(this, event, callback)
    }
    Off(event, callback) {
        if !this.listeners.Has(event)
            return
        list := this.listeners[event]
        Loop list.Length {
            i := list.Length - A_Index + 1         ; backwards: removal does not skip items
            if list[i] = callback                  ; objects compare by reference
                list.RemoveAt(i)
        }
    }
    Emit(event, args*) {
        if !this.listeners.Has(event)
            return
        for cb in this.listeners[event].Clone() {  ; ✓ handlers may unsubscribe during Emit
            try cb(args*)
            catch as err
                OutputDebug("listener error: " err.Message)
        }
    }
}

class Model extends EventEmitter {
    __New() {
        super.__New()
        this.data := Map()
    }
    Set(key, value) {
        this.data[key] := value
        this.Emit("change", key, value)
    }
}

class View {
    __New(model) {
        this.model := model
        this.subscription := model.On("change", this.OnModelChange.Bind(this))
    }
    OnModelChange(key, value) => ToolTip("View: " key " = " value)
    Dispose() {
        if this.subscription {
            this.subscription.Dispose()
            this.subscription := ""
        }
        this.model := ""
    }
}

m := Model()
v := View(m)
m.Set("name", "John")
v.Dispose()                               ; ✓ breaks Model → callback → View → Model
v := ""
```

## TIER 3 — Timers Without Keeping the Object Alive
> METHODS COVERED: `ObjPtr()` · `ObjFromPtrAddRef()` · `SetTimer` · `__Delete()`

From the official "Problems with Reference Counting" section: bind the object's *address* instead of the object, and rebuild a counted reference each time the timer fires. The object can then be freed normally, and `__Delete` deletes the timer. The address must never be used after the object is deleted.

```ahk
class Ticker {
    count := 0
    __New() {
        ; BoundFunc holding the address — the timer does not count as a reference to 'this'
        this.Timer := (p => ObjFromPtrAddRef(p).Update()).Bind(ObjPtr(this))
        SetTimer(this.Timer, 1000)
    }
    __Delete() {
        SetTimer(this.Timer, 0)           ; stop before the address becomes invalid
    }
    Update() => ToolTip(++this.count)
}
t := Ticker()
Sleep(3500)
t := ""                                   ; last reference → __Delete → timer deleted
ToolTip()
```

### Performance Notes

- **Object pooling** (reuse instances instead of creating new ones) only helps when allocation is measurably hot; pooled objects need a `Reset()` method and explicit release, not `__New`/`__Delete`.
- **Lazy initialization:** compute an expensive property on first read, cache it in a backing field, and clear the cache when inputs change.
- **Bind once:** keep BoundFuncs created in `__New`; each `Bind` call allocates a new object and a different object cannot delete an existing timer.
- **Static tables:** initialize lookup Maps as `static` class variables, not per instance.

## DROP-IN RECIPES

```ahk
; MakeTimerSubscription — owns a timer callback and stops it deterministically
MakeTimerSubscription(target, methodName, period) {
    if !target.HasMethod(methodName)
        throw MethodError("MakeTimerSubscription: method '" methodName "' not found", -1)
    callback := ObjBindMethod(target, methodName)
    SetTimer(callback, period)
    return {Callback: callback, Dispose: (this) => SetTimer(callback, 0)}
}
; Call site: sub := MakeTimerSubscription(this, "Refresh", 1000) ... sub.Dispose()

; Disposable — base class with an idempotent Dispose and a template method
class Disposable {
    _disposed := false
    Dispose() {
        if this._disposed
            return
        this._disposed := true
        try this._OnDispose()
        catch as err
            OutputDebug(this.__Class "._OnDispose error: " err.Message)
    }
    _OnDispose() {
        ; subclasses release resources here
    }
    __Delete() => this.Dispose()
    static Use(resource, callback) {
        if !(resource is Disposable)
            throw TypeError("Disposable.Use: resource must extend Disposable", -1)
        try {
            return callback(resource)
        } finally {
            resource.Dispose()
        }
    }
}

class TempFileWriter extends Disposable {
    __New(path) {
        this._path := path
        FileAppend("", path, "UTF-8")
    }
    Write(text) {
        if this._disposed
            throw Error("TempFileWriter: already disposed", -1)
        FileAppend(text, this._path, "UTF-8")
    }
    _OnDispose() {
        if FileExist(this._path)
            FileDelete(this._path)
    }
}
; Call site: Disposable.Use(TempFileWriter(A_Temp "\work.tmp"), (w) => w.Write("data"))
```

## SEE ALSO

- `Module_ClassBasics.md` — class syntax, constructors, binding callbacks.
- `Module_ObjectBasics.md` — `.Bind(this)` vs `ObjBindMethod`.
- `Module_Timers.md` — `SetTimer` and thread behavior.
- `Module_GuiBasics.md` — `Gui.Destroy()` and GUI event cycles.
- `Module_ExceptionHandling.md` — try/catch/finally details.
