# Module_CallbacksAndMessages.md
<!-- DOMAIN: DLL Calls — native callbacks and window messages -->
<!-- SCOPE: CallbackCreate/CallbackFree (Fast, CDecl, & options, ParamCount, binding methods), EnumWindows/EnumChildWindows, low-level hooks (SetWindowsHookExW/CallNextHookEx), OnMessage (MaxThreads, return values, registration order), SendMessage/PostMessage (errors, timeout), WM_COPYDATA inter-script messaging. DllCall types are in Module_DllCallBasics.md; Buffer/NumGet/struct layouts are in Module_BufferAndMemory.md. Control-level SendMessage usage for GUI controls is in Module_ControlInteraction.md. -->
<!-- TRIGGERS: CallbackCreate, CallbackFree, "callback function pointer", EnumWindows, EnumChildWindows, SetWindowsHookEx, CallNextHookEx, WH_KEYBOARD_LL, "low-level hook", OnMessage, SendMessage, PostMessage, WM_COPYDATA, WM_DEVICECHANGE, WM_POWERBROADCAST, "inter-script communication", IPC, "window message", MaxThreads, TimeoutError -->
<!-- CONSTRAINTS: CallbackCreate keeps a reference to the function until CallbackFree; free each address when no longer needed. "Fast" must be avoided when the calling thread can vary (e.g. callbacks triggered by incoming messages). ParamCount defaults to Function.MinParams — a method's Func has a hidden `this` parameter, so bind methods (Bind/ObjBindMethod) before passing them. SendMessage throws TargetError (no target), TimeoutError (default 5000 ms) and OSError (could not send); PostMessage throws TargetError/OSError. OnMessage and CallbackCreate do not make a script persistent — call Persistent(). -->
<!-- CROSS-REF: Module_DllCallBasics.md, Module_BufferAndMemory.md, Module_ControlInteraction.md, Module_ScriptLifecycle.md, Module_ClassLifecycle.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `RegisterCallback("FuncName", ...)` | `CallbackCreate(FuncObj, Options?, ParamCount?)` | Renamed; takes a function object, not a name |
| (no free in v1) | `CallbackFree(addr)` | Each callback keeps its function referenced until freed |
| `OnMessage(0x200, "FuncName")` | `OnMessage(0x200, FuncObj)` | Callbacks are function objects |
| `SendMessage, Msg, w, l, Ctrl, Win` + `ErrorLevel` | `result := SendMessage(Msg, w, l, Ctrl?, WinTitle?)` | Returns the reply; failures throw |
| `(n, w, l) => { stmt1; stmt2 }` callback | Named function | Fat-arrow functions take a single expression (`=> expr`); there is no block body |

## API QUICK-REFERENCE

### Callbacks

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `CallbackCreate()` | `CallbackCreate(Function, Options?, ParamCount?)` | Machine-code address | Options: `Fast`/`F` (no new thread per call), `CDecl`/`C` (ignored on 64-bit), `&` (pass the parameter-list address). ParamCount defaults to `Function.MinParams`. Throws if Function is not callable or ParamCount is invalid |
| `CallbackFree()` | `CallbackFree(Address)` | — | Deletes the callback and releases the function reference |

- Without `Fast`, each call starts a new AHK thread. `Fast` performs better but lets the callback change thread settings (`A_LastError`, last found window…) of whichever thread is running — avoid it when the calling thread varies, e.g. callbacks triggered by incoming messages.
- Return values: blank or no `Return` → 0 to the caller; otherwise return an integer (32-bit builds truncate to 32 bits).
- Parameters are integers: unsigned 32-bit on AHK 32-bit (recover a signed value with `x := x << 32 >> 32`), signed 64-bit on AHK 64-bit. Mask 8/16-bit (and 32-bit on x64) parameters, e.g. `x &= 0xFFFF`, because upper bits may hold garbage.

### Window Messages

| Function | Signature | Returns | Throws |
|----------|-----------|---------|--------|
| `OnMessage()` | `OnMessage(MsgNumber, Callback, MaxThreads := 1)` | — | — |
| `SendMessage()` | `SendMessage(Msg, wParam?, lParam?, Control?, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?, Timeout := 5000)` | Reply (integer) | `TargetError`, `TimeoutError`, `OSError` |
| `PostMessage()` | `PostMessage(Msg, wParam?, lParam?, Control?, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)` | — | `TargetError`, `OSError` |

OnMessage details:
- Callback `(wParam, lParam, msg, hwnd)`. Returning an integer replies immediately and stops further processing of the message; returning nothing lets normal processing continue.
- `MaxThreads` `0` unregisters; a negative value registers the callback **before** earlier callbacks for the same message.
- `SendMessage` `Timeout`: `0` waits forever, negative times out immediately. Higher-integrity (admin) windows may block messages from a non-admin script (OSError).

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 callback form from V1 → V2 BREAKING CHANGES remains: `RegisterCallback`, function names as strings, `ErrorLevel`, block-bodied fat arrows.
- Free every `CallbackCreate` address with `CallbackFree` when it is no longer needed (for example in the owner's cleanup method). Create callbacks once, not inside loops.
- `Fast` only when the callback is invoked synchronously from the thread that made the DllCall (e.g. `EnumWindows`); never for hooks, subclassing or message-driven callbacks.
  ✗ `CallbackCreate(fn, "Fast", 3)` for a hook → ✓ omit `Fast`
- Pass bound methods to `CallbackCreate`/`OnMessage`: `CallbackCreate(this.Proc.Bind(this), , 3)` or `ObjBindMethod(obj, "Proc")`. A plain method reference has a hidden `this` parameter, so arguments shift. ParamCount matches the native signature.
  ✗ `CallbackCreate(obj.Proc, ...)` → ✓ `obj.Proc.Bind(obj)` / `ObjBindMethod`
- Hook procedures should call `CallNextHookEx` so other hooks still receive the event (Win32 rule, outside AHK docs); `EnumWindows` callbacks return non-zero to continue.
  ✗ `return 0` from `EnumWindowsProc` to continue → ✓ `return 1`
- Scripts that only wait for messages or callbacks are not persistent automatically — call `Persistent()`.
- `SendMessage` waits up to 5 s by default and throws `TimeoutError`; use `PostMessage` when no reply is needed. Handle `TargetError`/`TimeoutError` where the target may be missing or hung.

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| `TargetError` | `SendMessage`/`PostMessage` window or control not found | `e is TargetError` | Check `WinExist` / correct WinTitle |
| `TimeoutError` | Target did not process the message within `Timeout` | `e is TimeoutError` | Larger timeout, `PostMessage`, or handle the hang |
| `OSError` | Message blocked (e.g. UIPI integrity level) | `e.Number` | Run at matching integrity or use another IPC method |
| Exception from `CallbackCreate` | Function not callable, bad ParamCount | `e.Message` | Pass a function object; set ParamCount |
| Too-few-parameters error inside a callback | Unbound method or wrong ParamCount | Error on first callback | Bind; match ParamCount to the C signature |
| Script exits at once | Only OnMessage/callbacks registered | Exit with no error | `Persistent()` |

## TIER 1 — Enumeration Callbacks
> METHODS COVERED: CallbackCreate (Fast) · CallbackFree · EnumWindows · EnumChildWindows · ObjBindMethod

```ahk
#Requires AutoHotkey v2.0
titles := []
EnumWindowsProc(hwnd, lParam) {
    if (t := WinGetTitle(hwnd)) != ""
        titles.Push(t)
    return 1                                    ; non-zero = continue enumeration
}
cb := CallbackCreate(EnumWindowsProc, "Fast", 2)   ; ✓ Fast: called synchronously from this thread
DllCall("EnumWindows", "Ptr", cb, "Ptr", 0, "Int")
CallbackFree(cb)
MsgBox(titles.Length " titled windows")

class WindowCounter {
    count := 0
    Proc(hwnd, lParam) {
        this.count++
        return 1
    }
    CountChildren(parent) {
        cb := CallbackCreate(ObjBindMethod(this, "Proc"), "Fast", 2)   ; ✓ bound — `this` is fixed
        DllCall("EnumChildWindows", "Ptr", parent, "Ptr", cb, "Ptr", 0, "Int")
        CallbackFree(cb)
        return this.count
    }
}
if hwnd := WinExist("A")
    MsgBox(WindowCounter().CountChildren(hwnd) " child windows")

; ✗ CallbackCreate(WindowCounter.Prototype.Proc, "Fast", 2)   ; hidden `this` param → arguments shift
```

## TIER 2 — Low-Level Keyboard Hook in a Class
> METHODS COVERED: CallbackCreate (no Fast) · SetWindowsHookExW · CallNextHookEx · UnhookWindowsHookEx · Persistent

```ahk
#Requires AutoHotkey v2.0
Persistent()

class KeyboardHook {
    __New() {
        this.cb := CallbackCreate(this.Proc.Bind(this), , 3)    ; ✓ no Fast: called from message processing
        this.hHook := DllCall("SetWindowsHookExW", "Int", 13,    ; WH_KEYBOARD_LL
            "Ptr", this.cb, "Ptr", 0, "UInt", 0, "Ptr")
        if !this.hHook
            throw OSError(A_LastError, -1)
    }
    Proc(nCode, wParam, lParam) {
        if nCode >= 0 && wParam = 0x100                         ; WM_KEYDOWN
            OutputDebug("VK=0x" Format("{:X}", NumGet(lParam, 0, "UInt")))   ; KBDLLHOOKSTRUCT.vkCode
        return DllCall("CallNextHookEx", "Ptr", this.hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
    Dispose() {
        if this.hHook
            DllCall("UnhookWindowsHookEx", "Ptr", this.hHook, "Int"), this.hHook := 0
        if this.cb
            CallbackFree(this.cb), this.cb := 0                  ; also releases the bound `this`
    }
}
hook := KeyboardHook()
MsgBox("Hook installed. OK removes it.")
hook.Dispose()
; Note: the callback holds a bound reference to the object, so __Delete would not run
; while the callback exists — use an explicit Dispose().
```

## TIER 3 — OnMessage, SendMessage, PostMessage, WM_COPYDATA
> METHODS COVERED: OnMessage · SendMessage · PostMessage · NumGet · StrGet · Persistent

```ahk
#Requires AutoHotkey v2.0
Persistent()

OnMessage(0x0219, OnDeviceChange)              ; WM_DEVICECHANGE
OnDeviceChange(wParam, lParam, msg, hwnd) {
    if wParam = 0x8000                          ; DBT_DEVICEARRIVAL
        TrayTip("Device connected")
    else if wParam = 0x8004                     ; DBT_DEVICEREMOVECOMPLETE
        TrayTip("Device removed")
}                                               ; no return → normal processing continues

; Receive text from another script
OnMessage(0x004A, OnCopyData)                   ; WM_COPYDATA
OnCopyData(wParam, lParam, msg, hwnd) {
    ; COPYDATASTRUCT: dwData UPtr @0, cbData UInt @A_PtrSize, lpData Ptr @A_PtrSize*2
    cb := NumGet(lParam, A_PtrSize, "UInt")
    p  := NumGet(lParam, A_PtrSize * 2, "Ptr")
    MsgBox("Received: " StrGet(p, cb // 2, "UTF-16"))
    return 1                                    ; reply TRUE
}

; Send text to another script's main window
SendText(targetWinTitle, text) {
    data := Buffer(StrPut(text, "UTF-16"))
    StrPut(text, data, "UTF-16")
    cds := Buffer(A_PtrSize * 3, 0)
    NumPut("UPtr", 1, "UInt", data.Size, cds, 0)
    NumPut("Ptr", data.Ptr, cds, A_PtrSize * 2)
    prev := DetectHiddenWindows(true)           ; script main windows are hidden
    try return SendMessage(0x004A, 0, cds, , targetWinTitle, , , , 3000)
    catch TargetError
        return 0
    finally DetectHiddenWindows(prev)
}

; Ask a window to close without waiting for a reply
; PostMessage(0x0010, 0, 0, , "ahk_class Notepad")   ; WM_CLOSE
```

### Performance Notes

- `Fast` avoids per-call thread startup; use it for synchronous enumeration only.
- Create callbacks once and keep the address; `CallbackCreate` in a loop allocates a new stub each time.
- Keep OnMessage callbacks short; consider `Critical` instead of raising `MaxThreads` when message order matters.

## DROP-IN RECIPES

```ahk
; EnumWindowsArray — all top-level HWNDs (one callback, freed on return)
EnumWindowsArray() {
    list := []
    cb := CallbackCreate(Collect, "Fast", 2)
    try DllCall("EnumWindows", "Ptr", cb, "Ptr", 0, "Int")
    finally CallbackFree(cb)
    return list
    Collect(hwnd, lParam) {
        list.Push(hwnd)
        return 1
    }
}
```

## SEE ALSO

> This module does NOT cover: DllCall types and error classes → see Module_DllCallBasics.md
> This module does NOT cover: Buffer, struct layouts, StrGet/StrPut → see Module_BufferAndMemory.md
> This module does NOT cover: SendMessage to GUI controls, ControlSend, ControlClick → see Module_ControlInteraction.md

- `Module_DllCallBasics.md` — DllCall fundamentals used by every callback example.
- `Module_BufferAndMemory.md` — reading `lParam` structures.
- `Module_ScriptLifecycle.md` — `Persistent()` and exit cleanup.
- `Module_ClassLifecycle.md` — `Bind`, `ObjBindMethod` and reference cycles.
