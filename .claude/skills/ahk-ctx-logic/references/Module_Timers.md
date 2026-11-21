# Module_Timers.md
<!-- DOMAIN: Timers — SetTimer API, one-shot and repeating timers, bound callbacks, timer lifecycle in classes, debounce/throttle, timer-driven state machines and chunked work -->
<!-- SCOPE: Thread interruption, Critical, Sleep, Sleep -1, priorities and re-entrancy are in Module_ThreadsAndCritical.md. Exception classes and OnError are in Module_ExceptionHandling.md. True multithreading, COM async and IPC are not covered — see Module_COMAutomation.md. -->
<!-- TRIGGERS: SetTimer, "timer", "delay", "interval", "period", "one-shot", "run once", "run every N seconds", "background task", "debounce", "throttle", "polling", "async", "state machine", "chunked processing", ".Bind", ObjBindMethod, "class timer fails", "timer won't stop", "cancel timer", A_TickCount -->
<!-- CONSTRAINTS: SetTimer needs a function object (not a name string); positive Period repeats, negative runs once then deletes the timer, 0 deletes it; the timer is identified by the function object, so cancel with the SAME object (store the BoundFunc); the timer list keeps a reference to that object, so an object whose bound method is an active timer is not freed and its __Delete does not run until the timer is deleted; omitting Function inside a timer thread targets the timer that launched the thread; Period is rounded up to the OS tick (typically 10 or 15.6 ms); errors in a timer callback do not reach the code that called SetTimer. -->
<!-- CROSS-REF: Module_ThreadsAndCritical.md, Module_ExceptionHandling.md, Module_ClassLifecycle.md, Module_GuiBasics.md, Module_COMAutomation.md, Module_FatArrowFunctions.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `SetTimer, MyLabel, 1000` | `SetTimer MyFunc, 1000` | No commands and no labels as callbacks; pass a function object |
| `SetTimer("MyFunc", 1000)` | `SetTimer(MyFunc, 1000)` | `Function` is a function object; pass the function itself, not its name |
| `SetTimer(this.Method, 1000)` | `SetTimer(this.Method.Bind(this), 1000)` | The unbound method needs its hidden `this` parameter → `SetTimer` itself throws `ValueError` ("Invalid callback function") |
| `SetTimer, MyLabel, Off` | `SetTimer MyFunc, 0` | Period `0` deletes the timer |
| `SetTimer(Func, "1000")` | `SetTimer(Func, 1000)` | `Period` is documented as an Integer |

## API QUICK-REFERENCE

### SetTimer

| Call | Effect |
|------|--------|
| `SetTimer(Function, Period?, Priority?)` | Create or update the timer for `Function` (a function object) |
| `Period > 0` | Repeat until disabled |
| `Period < 0` | Run once after `Abs(Period)` ms, then delete the timer |
| `Period = 0` | Delete the timer. If its thread is still running, deletion happens after the thread finishes |
| `Period` omitted | New timer: 250 ms. Existing timer: reset at its former period (unless only `Priority` is given) |
| `Priority` | Integer thread priority, default 0 (see Module_ThreadsAndCritical.md). Omit `Period` to change only the priority |
| `SetTimer , 0` / `SetTimer , 1000` | `Function` omitted: act on the timer that launched the current thread |

Facts from `lib/SetTimer.htm`:

- Passing an empty value as `Function` is an error. Give a non-empty value or omit the parameter entirely.
- Calling `SetTimer` on an existing timer resets it — the full period must pass again before the next run.
- A new or updated timer does not run immediately. To run it now as well, call the function directly.
- `Abs(Period)` may be at most 4294967295 ms (49.7 days).
- `Period` is typically rounded up to a multiple of 10 or 15.6 ms.
- If a timer is disabled while its function is running, the function runs to completion.
- Each timer thread starts with default settings (`SendMode` and others).
- `KeyHistory` shows how many timers exist and how many are enabled.

### Binding Utilities

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `.Bind()` | `FuncObj.Bind(Args*)` | BoundFunc | Fixes leading arguments. Each call creates a **new** object |
| `ObjBindMethod()` | `ObjBindMethod(Obj, Method, Params*)` | BoundFunc | Binds a method by name. Each call creates a new object |

### Time and Measurement

| Item | Notes |
|------|-------|
| `A_TickCount` | ms since the system started, up to 49.7 days; about 10 ms precision |
| `FormatTime(YYYYMMDDHH24MISS?, Format?)` | Formats a timestamp; omit the first parameter for the current time. An invalid date/time portion is omitted from the result |
| `A_Now` | Current local time as `YYYYMMDDHH24MISS` |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Pass a function object, not a name string, and bind methods. See V1 → V2 BREAKING CHANGES for the wrong forms.
- A timer is keyed by its function object. `SetTimer(obj.M.Bind(obj), 0)` creates a new BoundFunc, so it does not cancel the timer started with an earlier `.Bind()`. Store the BoundFunc and reuse it.
  ✗ `SetTimer(this.Tick.Bind(this), 0)` → ✓ `SetTimer(this.TickFn, 0)`
- The script's timer list keeps a reference to the function object until the timer is deleted. A BoundFunc holds its bound arguments. So while `this.Method.Bind(this)` is an active timer, the object stays alive and `__Delete` does not run. Give every class that owns a timer an explicit `Stop()`/`Close()` method that deletes it; `__Delete` cannot be the trigger for that.
  ✗ timer cancelled only in `__Delete` → ✓ explicit `Stop()`
- One-shot timers (negative `Period`) delete themselves after running; no cancel is needed afterwards. Use one for delayed work.
  ✗ `Sleep 5000` then work, inside an event handler (see Module_ThreadsAndCritical.md) → ✓ `SetTimer Work, -5000` and return
- Errors thrown inside a timer callback do not reach the code that called `SetTimer`. Catch them inside the callback when you need logging or recovery.
- Timing facts are in `### SetTimer`. Common wrong forms:
  ✗ `SetTimer Fn, 1000` expecting `Fn` to run now → ✓ call `Fn()` once, then `SetTimer`
  ✗ `SetTimer Fn, 1` for a 1 ms cadence → ✓ accept ~10–16 ms granularity
- `SetTimer , 0` (Function omitted) works only inside a thread launched by a timer.
- A timer may not run on time if its function is still running when the period expires again (`lib/SetTimer.htm`, "Reliability"). Timers also do not run while the script is uninterruptible (`Critical`), during `Thread "NoTimers"`, while any thread is paused, or while one of the script's menus is shown. An overdue timer runs once when possible, then resumes its schedule.
- Closures capture variables, not values. A nested function created in a loop sees the variable's final value. Use `.Bind(value)` to fix a value at scheduling time.
- Convention, not a language limit: keep timer callbacks short; move long work into chunks (TIER 4).

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `ValueError` ("Invalid callback function") | `SetTimer(this.Method, 1000)` without binding | Thrown by the `SetTimer` call, not when the timer fires | `this.Tick := this.Method.Bind(this)`, then `SetTimer(this.Tick, 1000)` |
| `PropertyError` / `UnsetError` | `SetTimer(this.TickFn, 0)` before `this.TickFn` was assigned, or a misspelt variable | Message names the property/variable | Create the BoundFunc in `__New` |
| `TypeError` when Function is empty | `SetTimer(cb, 1000)` where `cb` is `""` | Thrown by `SetTimer` | Pass a function object or omit the parameter |
| No error, timer keeps firing | Cancel used a fresh `.Bind()` | Timer still active (`KeyHistory`) | Cancel with the stored BoundFunc |
| Error not seen by caller | Exception inside the timer callback | `try` around `SetTimer` never catches it | `try`/`catch` inside the callback (DROP-IN RECIPES) |

## TIER 1 — One-Shot and Repeating Timers
> METHODS COVERED: `SetTimer()` · `FormatTime()` · `ToolTip()`

```ahk
#Requires AutoHotkey v2.0

; ✓ Repeating timer
ShowTime() {
    ToolTip "Time: " FormatTime(, "HH:mm:ss")
}
SetTimer ShowTime, 1000

; ✓ One-shot: runs once after 5 s, then the timer is deleted
StopClock() {
    SetTimer ShowTime, 0
    ToolTip
}
SetTimer StopClock, -5000

; ✓ A timer can delete itself: omit Function inside its own thread
Countdown() {
    static n := 3
    ToolTip "T-" n--
    if n < 0 {
        SetTimer , 0
        ToolTip
    }
}
SetTimer Countdown, 1000

; ✓ Pass arguments with Bind; the BoundFunc is also the timer's identity
timedOut := MsgBox.Bind("Timed out.")
SetTimer timedOut, -10000
; SetTimer timedOut, 0      ; cancels it, because it is the same object
```

## TIER 2 — Timer Lifecycle in Classes
> METHODS COVERED: `SetTimer()` · `.Bind()`

Store the BoundFunc once, use it to start and stop, and give the owner an explicit `Stop()`.

```ahk
#Requires AutoHotkey v2.0

class Poller {
    __New(intervalMs := 1000) {
        this.Interval := intervalMs
        this.Running  := false
        this.TickFn   := this.Tick.Bind(this)   ; ✓ one stored object
    }

    Start() {
        if this.Running
            return
        this.Running := true
        SetTimer this.TickFn, this.Interval
    }

    Stop() {
        if !this.Running
            return
        this.Running := false
        SetTimer this.TickFn, 0                 ; ✓ same object → timer deleted
    }

    SetInterval(ms) {
        this.Interval := ms
        if this.Running
            SetTimer this.TickFn, ms            ; ✓ updates and resets the period
    }

    Tick() {
        ; poll something
    }
}

p := Poller(500)
p.Start()
; ... later:
p.Stop()     ; ✓ explicit stop; after this the object can be freed normally
p := ""

; ✗ SetTimer this.Tick.Bind(this), 0   ; new BoundFunc — the running timer is not cancelled
; ✗ Relying on __Delete to stop the timer: the active timer keeps the BoundFunc,
;   which keeps `this` alive, so __Delete is never reached while the timer exists.
```

## TIER 3 — Parameterized Callbacks, Debounce and Throttle
> METHODS COVERED: `SetTimer()` · `.Bind()` · closures · `A_TickCount`

```ahk
#Requires AutoHotkey v2.0

; ✓ Bind fixes argument values at scheduling time
Notify(msg) => ToolTip(msg)
messages := ["one", "two", "three"]
for i, msg in messages
    SetTimer Notify.Bind(msg), -1000 * i

; ✗ In a function, a closure created in the loop captures the variable msg,
;   so every callback would see its final value.

; ✓ Debounce: each call resets the same one-shot timer
CreateDebounce(callback, waitMs) {
    fire := () => callback()      ; one function object per debouncer
    Debounced(*) {
        SetTimer fire, -waitMs    ; same object → existing timer is reset
    }
    return Debounced
}
SaveDraft() => OutputDebug("saved")
debouncedSave := CreateDebounce(SaveDraft, 1000)
debouncedSave(), debouncedSave(), debouncedSave()   ; SaveDraft runs once, 1 s after the last call

; ✓ Throttle: run at most once per interval (no timer needed)
CreateThrottle(callback, minIntervalMs) {
    last := 0
    Throttled(*) {
        now := A_TickCount
        ; A_TickCount covers up to 49.7 days; treat a smaller value as elapsed
        if (now - last >= minIntervalMs || now < last) {
            last := now
            callback()
        }
    }
    return Throttled
}
```

## TIER 4 — Timer-Driven State Machines and Chunked Work
> METHODS COVERED: `SetTimer()` · `.Bind()` · `Min()`

Split long work into steps. Each step schedules the next one with a one-shot timer, so the current thread ends between steps.

```ahk
#Requires AutoHotkey v2.0

class Sequence {
    __New() {
        this.State  := 0
        this.StepFn := this.Step.Bind(this)
    }
    Start() {
        this.State := 1
        SetTimer this.StepFn, -1
    }
    Step() {
        switch this.State {
            case 1:
                ; phase 1 work
                this.State := 2
                SetTimer this.StepFn, -500
            case 2:
                ; phase 2 work
                this.State := 3
                SetTimer this.StepFn, -1000
            case 3:
                this.State := 0          ; done; no new timer
        }
    }
}

class ChunkProcessor {
    __New(items, chunkSize := 100) {
        this.Items := items
        this.Index := 1
        this.Size  := chunkSize
        this.Fn    := this.ProcessChunk.Bind(this)
    }
    Start() => SetTimer(this.Fn, 10)
    ProcessChunk() {
        last := Min(this.Index + this.Size - 1, this.Items.Length)
        while this.Index <= last {
            ; process this.Items[this.Index]
            this.Index++
        }
        if this.Index > this.Items.Length
            SetTimer this.Fn, 0        ; all chunks done
    }
}
```

## DROP-IN RECIPES

```ahk
#Requires AutoHotkey v2.0

; SafeTimerCallback — keeps errors inside the timer thread and reports them
; ✓ try/catch around SetTimer would never see errors from later timer runs
SafeTimerCallback(fn, errHandler?) {
    if !HasMethod(fn)
        throw TypeError("SafeTimerCallback: fn must be callable", -1)
    Wrapper(*) {
        try {
            fn()
        } catch as e {
            if IsSet(errHandler)
                errHandler(e)
            else
                OutputDebug("Timer error: " e.Message " @ " e.File ":" e.Line)
        }
    }
    return Wrapper
}
; SetTimer SafeTimerCallback(MyTask), 1000
; SetTimer SafeTimerCallback(MyTask, (e) => MsgBox(e.Message)), -5000

; WaitForWindowAsync — poll for a window without holding the current thread
WaitForWindowAsync(winTitle, onFound, timeoutMs := 10000) {
    start := A_TickCount
    Check() {
        if hwnd := WinExist(winTitle) {
            SetTimer Check, 0
            onFound(hwnd)
        } else if A_TickCount - start > timeoutMs {
            SetTimer Check, 0
        }
    }
    SetTimer Check, 250
}
```

## SEE ALSO

> This module does NOT cover: thread interruption, Critical, Sleep and re-entrancy → see Module_ThreadsAndCritical.md
> This module does NOT cover: Error classes and global handlers → see Module_ExceptionHandling.md
> This module does NOT cover: true parallelism or COM-based async → see Module_COMAutomation.md

- `Module_ThreadsAndCritical.md` — how timer threads interrupt other threads, `Critical`, `Sleep -1`, priorities.
- `Module_ExceptionHandling.md` — `try`/`catch` inside callbacks, `OnError`.
- `Module_ClassLifecycle.md` — `__New`/`__Delete` lifecycle behind class-based timers.
- `Module_GuiBasics.md` — updating GUI controls from timer callbacks.
- `Module_FatArrowFunctions.md` — closures and fat-arrow semantics.
