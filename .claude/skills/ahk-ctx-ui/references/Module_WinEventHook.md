# Module_WinEventHook.md
<!-- DOMAIN: Event-driven window monitoring -->
<!-- SCOPE: SetWinEventHook/UnhookWinEvent through DllCall, CallbackCreate/CallbackFree lifetime, binding a method as the WINEVENTPROC, explicit start/stop lifecycle, choosing WinWait vs a hook. Not covered: Win* functions (Module_WindowManagement.md), general DllCall/struct rules (Module_CallbacksAndMessages.md in ahk-ctx-system), OnMessage window-message handling (ahk-ctx-system). -->
<!-- TRIGGERS: SetWinEventHook, UnhookWinEvent, CallbackCreate, CallbackFree, ObjBindMethod, EVENT_SYSTEM_FOREGROUND, EVENT_OBJECT_CREATE, EVENT_OBJECT_DESTROY, WINEVENT_OUTOFCONTEXT, "detect when window opens", "react to focus change", "passive window monitoring", "without polling" -->
<!-- CONSTRAINTS: CallbackCreate keeps a reference to the function object until CallbackFree — a callback bound to `this` keeps the object alive, so __Delete alone cannot stop the hook; provide an explicit Stop(). Do not use the "Fast" option for out-of-context WinEvent callbacks (they arrive via the message queue, so the calling thread varies). Unhook before CallbackFree. -->
<!-- CROSS-REF: Module_WindowManagement.md, Module_CallbacksAndMessages.md, Module_ClassLifecycle.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

| Call | Signature | Notes |
|------|-----------|-------|
| `CallbackCreate()` | `CallbackCreate(Function, Options?, ParamCount?)` | Returns a machine-code address. Retains a reference to `Function` until `CallbackFree`. Default (no `"Fast"`) starts a new thread per call. |
| `CallbackFree()` | `CallbackFree(Address)` | Deletes the callback and releases the function reference |
| `ObjBindMethod()` | `ObjBindMethod(Obj, Method, Params*)` | BoundFunc that calls `Obj.Method(Params*, …)`; `this.Method.Bind(this)` is equivalent |
| `SetWinEventHook` | `DllCall("SetWinEventHook", "UInt", eventMin, "UInt", eventMax, "Ptr", 0, "Ptr", callback, "UInt", pid, "UInt", tid, "UInt", flags, "Ptr")` | Win32; returns the hook handle or 0 on failure |
| `UnhookWinEvent` | `DllCall("UnhookWinEvent", "Ptr", hHook)` | Win32; call before `CallbackFree` |

Common constants (Win32): `EVENT_SYSTEM_FOREGROUND := 0x0003`, `EVENT_OBJECT_CREATE := 0x8000`, `EVENT_OBJECT_DESTROY := 0x8001`, `EVENT_OBJECT_SHOW := 0x8002`, `WINEVENT_OUTOFCONTEXT := 0`, `OBJID_WINDOW := 0`. The WINEVENTPROC has 7 parameters: `(hHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime)`.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- A method has a hidden `this` parameter; pass a bound function (`ObjBindMethod(this, "Dispatch")` or `this.Dispatch.Bind(this)`), with `ParamCount` 7.
  ✗ `CallbackCreate(this.Dispatch, …)` → ✓ `CallbackCreate(ObjBindMethod(this, "Dispatch"), , 7)`
- `CallbackCreate` holds the bound function, which holds `this`. While the callback exists, the object's reference count never reaches zero, so `__Delete` will not run. Release the hook with an explicit `Stop()` (then `__Delete` can act as a safety net), called by `OnExit` or the owner.
  ✗ `monitor := ""` expected to unhook → ✓ `monitor.Stop()`
- The "Fast" option must be avoided when the thread that calls the address varies (e.g. callbacks triggered by incoming messages, as with out-of-context WinEvents). Use the default mode.
  ✗ `CallbackCreate(fn, "Fast", 7)` → ✓ `CallbackCreate(fn, , 7)`
- Check the hook handle for 0; free the callback when hooking fails.
- Cleanup order: `UnhookWinEvent` first, then `CallbackFree`. Hooks and callbacks are released by the OS when the script process exits.
  ✗ `CallbackFree(cb)` then `UnhookWinEvent` → ✓ unhook first
- The callback filters out non-window objects (`idObject != 0`) and `hwnd = 0`.
- Prefer `WinWait`/`WinWaitClose` for a single "wait until it appears/closes"; use a hook for continuous or many-window monitoring.
  ✗ `Loop { if WinExist(…) … Sleep 100 }` → ✓ `WinWait` or a hook

## RUNTIME ERROR MAPPING

| Symptom | Cause | Fix |
|---------|-------|-----|
| Hook never stops; `__Delete` never runs | Callback holds a reference to the object | Call `Stop()` explicitly |
| Parameter-count error in the callback | Unbound method or wrong `ParamCount` | Bind `this`; `ParamCount` 7 |
| `SetWinEventHook` returns 0 | Invalid range/flags | Check constants; free the callback |
| Odd settings / last-found window inside handler | `"Fast"` mode with message-driven callbacks | Remove `"Fast"` |

## TIER 1 — WinEventMonitor Class

```ahk
#Requires AutoHotkey v2.0
Persistent

class WinEventMonitor {
    hHook := 0
    cb := 0

    ; handler receives (event, hwnd)
    __New(eventMin, eventMax, handler, pid := 0) {
        this.handler := handler
        this.cb := CallbackCreate(ObjBindMethod(this, "Dispatch"), , 7)   ; default mode, 7 params
        this.hHook := DllCall("SetWinEventHook"
            , "UInt", eventMin, "UInt", eventMax
            , "Ptr", 0, "Ptr", this.cb
            , "UInt", pid, "UInt", 0
            , "UInt", 0                         ; WINEVENT_OUTOFCONTEXT
            , "Ptr")
        if !this.hHook {
            CallbackFree(this.cb), this.cb := 0
            throw OSError(, -1, "SetWinEventHook")
        }
    }

    Dispatch(hHook, event, hwnd, idObject, idChild, thread, time) {
        if idObject != 0 || !hwnd               ; only whole windows
            return
        this.handler.Call(event, hwnd)
    }

    Stop() {                                    ; breaks the callback → object reference
        if this.hHook
            DllCall("UnhookWinEvent", "Ptr", this.hHook), this.hHook := 0
        if this.cb
            CallbackFree(this.cb), this.cb := 0
    }

    __Delete() => this.Stop()                   ; safety net only
}

OnWinEvent(event, hwnd) {
    title := ""
    try title := WinGetTitle(hwnd)
    switch event {
        case 0x0003: ToolTip("Focus: " title)
        case 0x8000: OutputDebug("Created " hwnd " " title)
        case 0x8001: OutputDebug("Destroyed " hwnd)
    }
}

monitor := WinEventMonitor(0x0003, 0x8001, OnWinEvent)   ; foreground … object destroy
OnExit((*) => monitor.Stop())
```

## SEE ALSO

- `Module_WindowManagement.md` — WinWait/WinWaitClose for single waits.
- `Module_CallbacksAndMessages.md` (ahk-ctx-system) — DllCall types and CallbackCreate details.
- `Module_ClassLifecycle.md` (ahk-ctx-core) — `__Delete` and reference counting.
