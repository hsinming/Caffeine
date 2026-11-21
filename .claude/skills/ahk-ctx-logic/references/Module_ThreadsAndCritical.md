# Module_ThreadsAndCritical.md
<!-- DOMAIN: Pseudo-Threads and Interruption — AHK thread model, interruption and priority, Critical, A_IsCritical, Sleep and Sleep -1, Thread settings, re-entrancy and shared-state races -->
<!-- SCOPE: SetTimer API, timer lifecycle, debounce/throttle and state machines are in Module_Timers.md. Exception handling is in Module_ExceptionHandling.md. True multithreading and COM async are not covered — see Module_COMAutomation.md. -->
<!-- TRIGGERS: Critical, "Critical Off", A_IsCritical, Sleep, "Sleep -1", "Sleep 0", Thread, "Thread NoTimers", "Thread Interrupt", "thread priority", "interrupt", "uninterruptible", "re-entrancy", "reentrant", "race condition", "shared state corruption", "#MaxThreadsPerHotkey", "hotkey runs twice", "GUI freezes", "message queue", "pseudo-thread", OnMessage callback timing -->
<!-- CONSTRAINTS: AutoHotkey runs one thread at a time; a new thread (hotkey, timer, GUI event, menu item, OnMessage) interrupts the current one, which resumes when the new one ends; Critical makes the current thread uninterruptible and buffers events instead of discarding them; Critical "Off" lets an interruption happen about 5 ms later, not immediately; Sleep pauses only the current thread — new threads can start during it; Sleep -1 does not sleep, it checks the message queue so pending interruptions happen at that point; a thread with lower priority than the current thread cannot interrupt it and its events are not buffered; Critical is per-thread and is off again when the thread ends. -->
<!-- CROSS-REF: Module_Timers.md, Module_ExceptionHandling.md, Module_GuiBasics.md, Module_HotkeysAndHotstrings.md, Module_COMAutomation.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `Critical, On` / `Critical, Off` | `Critical` / `Critical "Off"` | No commands; `Critical` is a function returning the previous setting |
| `Sleep, 500` | `Sleep 500` or `Sleep(500)` | No comma after the function name |
| `Thread, NoTimers` | `Thread "NoTimers"` | Sub-command is a quoted string |
| `Sleep -1` read as "1 ms pause" (any version) | Treat it as "check messages now" | It does not sleep; pending interruptions run at that point |

## API QUICK-REFERENCE

### Critical

| Call | Returns | Notes |
|------|---------|-------|
| `Critical` or `Critical "On"` | Previous setting (Integer) | Current thread cannot be interrupted; events are buffered |
| `Critical "Off"` / `Critical 0` | Previous setting | Thread becomes interruptible; a buffered interruption happens after about 5 ms on average |
| `Critical N` (N > 0) | Previous setting | On, with a message-check interval of N ms (default 16 ms while on, 5 ms while off) |
| `Critical -1` | Previous setting | On, and preemptive message checks are disabled (waits such as `Sleep` still check messages) |
| `A_IsCritical` | 0 or the current interval | Save with `prev := A_IsCritical`, restore with `Critical prev` |

### Sleep

| Call | Behavior |
|------|----------|
| `Sleep N` (0–2147483647) | Pauses the current thread about N ms (rounded up to 10 or 15.6 ms). New threads can start meanwhile |
| `Sleep 0` | Gives up the rest of the time slice; actual delay 0–20 ms or more |
| `Sleep -1` | No delay; checks the message queue immediately so pending interruptions happen here |

### Thread and Directives

| Item | Notes |
|------|-------|
| `Thread "NoTimers"[, false]` | Prevents only timers from interrupting the current thread |
| `Thread "Priority", N` | Sets the current thread's priority (default 0) |
| `Thread "Interrupt", Duration?, LineCount?` | Sets how long a new thread stays uninterruptible; `Thread "Interrupt", 0` makes all threads always interruptible |
| `#MaxThreadsPerHotkey N` | By default a hotkey or hotstring does not start again while its previous thread is still running |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Only one thread runs at a time. A new thread interrupts the current thread. The interrupted thread resumes, with its own settings restored, when the new thread finishes (`misc/Threads.htm`).
- A thread with lower priority than the current thread cannot interrupt it. Its timers do not run, and hotkey/GUI events during that time are **not** buffered — they are lost.
  ✗ `Thread "Priority", 10` to avoid interruption → ✓ `Critical` (buffers events instead of dropping them)
- An uninterruptible thread (`Critical`, a menu shown, `Send`/`WinActivate` delays, the start-up period set by `Thread "Interrupt"`) **buffers** events and launches them later.
- `Critical` delays interruptions; it does not discard them. An overdue timer runs once when the script becomes interruptible again.
  ✗ expecting `Critical` to drop overdue work → ✓ a guard flag (`Busy`) released in `finally`
- A critical thread becomes interruptible while a `MsgBox` or other dialog is shown, and critical again after the dialog closes.
- `Critical` is per thread. When a critical thread ends, the resumed thread is non-critical by definition, so `Critical "Off"` right before a thread ends is not needed. A helper that may run inside a critical caller saves and restores the setting instead of always turning it off.
  ✗ `Critical "Off"` inside a helper → ✓ `prev := Critical()` … `Critical prev`
- If the auto-execute section turns on `Critical` and never turns it off, every new thread starts critical.
- `Sleep` pauses only the current thread. Hotkeys, timers, menu items and GUI events can start new threads while it sleeps — the script does not "freeze". (`RunWait` and the `Win*Wait` functions behave the same way.)
- `Sleep -1` forces pending interruptions to run; it is never a short delay. That wrong reading is in V1 → V2 BREAKING CHANGES.
  ✗ `Sleep -1` expecting ~1 ms → ✓ `Sleep 10`, or a timer
- Emergencies can interrupt any thread, even a critical one: `OnExit`, an `OnMessage` callback for a message that is not buffered, and callbacks the thread itself triggers (e.g. via `SendMessage` or `DllCall`).
- Shared state that a hotkey, timer and GUI event all touch is protected by `Critical` or by a single owner. A re-entrancy flag is released in `finally`.
- Convention, not a language limit: keep `Critical` sections short — only the statements that must not be interleaved (the read-modify-write that must stay together). Do not hold it across `Sleep`, file I/O or network calls.
- Convention, not a language limit: in an event handler, schedule follow-up work with `SetTimer fn, -ms` and return, instead of `Sleep` followed by more work.

## RUNTIME ERROR MAPPING

| Symptom | Trigger Condition | Detection | Fix |
|---------|-------------------|-----------|-----|
| Lost increments / corrupt shared data | Two threads interleave a read-modify-write | Counters lower than expected | Wrap the read-modify-write in `Critical` (TIER 2) |
| Hotkey presses or GUI clicks ignored | Current thread has higher priority than the event's thread | Events lost, not delayed | Use `Critical` instead of raised priority (TIER 1) |
| OnMessage/GUI events lost with "thread already running" | Message checks happen while a handler is still busy | Missing events under load | Raise the message-check interval, e.g. `Critical 30` (TIER 3) |
| Outer critical section unexpectedly ends | A helper calls `Critical "Off"` unconditionally | Interruptions inside the caller's critical block | Save/restore `A_IsCritical` (TIER 2) |
| Handler re-enters itself | A function is called by a timer and a hotkey | Nested runs | Guard flag released in `finally` (TIER 3) |

## TIER 1 — The Thread Model: Interruption, Priority and Sleep
> METHODS COVERED: `Sleep()` · `Thread()` · `SetTimer()`

```ahk
#Requires AutoHotkey v2.0

; A hotkey thread can be interrupted by a timer thread.
SetTimer () => ToolTip("tick " A_TickCount), 200

F1:: {
    ; ✓ Sleep pauses only this thread; the timer above keeps updating the ToolTip.
    Sleep 2000
    MsgBox "F1 finished"
}

; ✓ Schedule follow-up work and return instead of Sleep + work
F2:: {
    ToolTip "Working..."
    SetTimer () => ToolTip(), -2000     ; hide after 2 s; the F2 thread ends now
}

; ✓ Sleep -1: let pending interruptions run at a chosen point
F3:: {
    Critical
    ; ... atomic work ...
    Critical "Off"
    Sleep -1      ; buffered events run here, not ~5 ms later at a random line
    ; ... continue ...
}

; ✗ Raising priority to "protect" a thread discards lower-priority events
; Thread "Priority", 10   ; hotkeys pressed now are ignored, not queued
```

## TIER 2 — Critical for Atomic Shared-State Updates
> METHODS COVERED: `Critical()` · `A_IsCritical`

Two threads can interleave inside a read-modify-write. `Critical` keeps the statements together.

```ahk
#Requires AutoHotkey v2.0

global g_Count := 0

; ✗ A timer can interrupt between the read and the write; one increment is lost
UnsafeIncrement() {
    global g_Count
    snapshot := g_Count
    ; <-- another thread increments g_Count here
    g_Count := snapshot + 1
}

; ✓ Critical makes the read-modify-write uninterruptible
SafeIncrement() {
    global g_Count
    prev := Critical()          ; turn on, remember previous setting
    g_Count += 1
    Critical prev               ; restore (does not end an outer critical block)
    FileAppend g_Count "`n", A_Temp "\count.log"   ; I/O outside Critical
}

; ✓ Group several control updates so no other thread sees a half-updated state
UpdatePair(ctrlA, ctrlB, a, b) {
    prev := A_IsCritical
    Critical
    ctrlA.Value := a
    ctrlB.Value := b
    Critical prev
}

; ✗ Holding Critical over slow work delays every hotkey, timer and GUI event
; Bad() {
;     Critical
;     Sleep 500
;     data := FileRead("huge.txt")
;     Critical "Off"
; }
```

## TIER 3 — Re-Entrancy Guards and Message-Check Interval
> METHODS COVERED: `Critical N` · `try`/`finally` · `#MaxThreadsPerHotkey`

A function that can be started from more than one place (hotkey, timer, GUI event) can be entered again while it is still running. A guard flag makes the skip policy explicit.

```ahk
#Requires AutoHotkey v2.0

class Syncer {
    __New() {
        this.Busy := false
    }
    Run(*) {
        if this.Busy
            return               ; ✓ skip: a previous run is still active
        this.Busy := true
        try {
            ; slow work that may be interrupted by other threads
        } finally {
            this.Busy := false   ; ✓ always released, even on error
        }
    }
}

sync := Syncer()
runFn := ObjBindMethod(sync, "Run")
SetTimer runFn, 5000
F5::runFn()                      ; ✓ manual trigger shares the same guard

; ✓ OnMessage handler that must not lose messages while busy:
; a larger message-check interval gives the handler time to finish.
WM_COPYDATA(wParam, lParam, msg, hwnd) {
    Critical 30
    ; ... read the data quickly ...
    return true
}
OnMessage 0x004A, WM_COPYDATA

; ✓ Allow a hotkey to start again while it is still running (default is 1 thread)
; #MaxThreadsPerHotkey 2
```

## SEE ALSO

> This module does NOT cover: SetTimer API, timer lifecycle, debounce/throttle → see Module_Timers.md
> This module does NOT cover: Error classes and try/catch → see Module_ExceptionHandling.md
> This module does NOT cover: real parallelism, background processes and COM async → see Module_COMAutomation.md

- `Module_Timers.md` — timers are the most common source of interrupting threads.
- `Module_ExceptionHandling.md` — `finally` for releasing guards and restoring `Critical`.
- `Module_GuiBasics.md` — GUI events as threads; updating controls safely.
- `Module_HotkeysAndHotstrings.md` — hotkey threads, `#MaxThreadsPerHotkey`, `#MaxThreadsBuffer`.
