# Module_HttpAsync.md
<!-- DOMAIN: Network — asynchronous and concurrent HTTP with WinHttp.WinHttpRequest.5.1 -->
<!-- SCOPE: Open(..., true) + WaitForResponse() (responsive wait), SetTimer + WaitForResponse(0) polling (non-blocking), periodic pollers, a Promise-style HttpPromise class for concurrent requests, Abort, object lifetime and BoundFunc reference cycles. Basic request construction, headers, auth and Download() are in Module_HttpRequests.md. JSON is in Module_JsonAndRestClients.md. -->
<!-- TRIGGERS: "async HTTP", "non-blocking HTTP", "concurrent requests", WaitForResponse, "WaitForResponse(0)", SetTimer polling, HttpPromise, "Promise async", then, catch, Abort, "poll API", "periodic request", "GUI freezes during request", readyState, ComObjConnect WinHttp -->
<!-- CONSTRAINTS: AutoHotkey runs one thread at a time; WinHttp performs async I/O itself. Open(..., true) + WaitForResponse() blocks the current code but keeps the script responsive (AHK Download docs). For code that must return immediately, poll WaitForResponse(0) from a SetTimer callback. WinHttp has no readyState property. A BoundFunc stored on the object it is bound to forms a reference cycle that is never freed — clear the property after stopping the timer. Methods named then/catch need AHK v2.0.3+ (reserved words as method names were fixed in v2.0.3). -->
<!-- CROSS-REF: Module_HttpRequests.md, Module_JsonAndRestClients.md, Module_ClassBasics.md, Module_ClassLifecycle.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ (HttpPromise .catch() method: v2.0.3+) -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `SetTimer, Label, 50` | `SetTimer(Callback, 50)` | Labels/command syntax are gone; callbacks are function objects |
| `ComObjCreate(...)` | `ComObject(...)` | Removed function |
| Multi-statement arrow callback `(s, b) => { ... }` | Named function, or a fat-arrow with a single expression | Fat-arrow functions take a single expression (`=> expr`); there is no block body |

## API QUICK-REFERENCE

### Waiting Modes

| Form | Current code | Script responsive? | Use when |
|------|--------------|--------------------|----------|
| `Open(m, u, false)` + `Send()` | Blocks | **No** | Console/background scripts only |
| `Open(m, u, true)` + `Send()` + `WaitForResponse()` | Blocks until done | Yes (AHK docs) | One request from a GUI script |
| `WaitForResponse(n)` | Blocks up to `n` s | Yes | Wait with a deadline; returns false on timeout and the request stays in flight |
| `WaitForResponse(0)` inside a `SetTimer` callback | Returns at once | Yes | Code must not block; multiple requests in flight |

### HttpPromise Class (defined in TIER 3)

| Member | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `HttpPromise()` | `HttpPromise(method, url, opts?)` | Instance | `opts` Map: `connectMs`, `sendMs`, `receiveMs`, `headers`, `body`, `contentType`. Sends immediately and starts a 50 ms poll timer |
| `.then()` | `.then(onFulfilled)` | `this` | Called with `Map("status", "body", "headers")` for 2xx |
| `.catch()` | `.catch(onRejected)` | `this` | Called with an `Error`; requires v2.0.3+ |
| `.abort()` | `.abort()` | — | Stops polling, aborts the request, rejects |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- AutoHotkey threads are not parallel: timers and hotkeys run in turns. Async here means WinHttp does the network I/O while the script keeps handling events.
- `Open(..., false)` freezes GUIs and hotkeys for the whole request. Prefer `Open(..., true)` + `WaitForResponse()`; GUI and hotkey code never uses the blocking form.
  ✗ `Open(..., false)` in a button handler → ✓ `Open(..., true)` + `WaitForResponse()`
- WinHttp has no `readyState`; test completion with `WaitForResponse(0)` (returns true when the response is ready).
  ✗ `while xhr.readyState != 4` (MSXML does have `readyState`) → ✓ `WaitForResponse(0)` in a timer, or `WaitForResponse()`
- Do not use `ComObjConnect` for WinHttp events in this module's patterns. Microsoft documents the WinHttp event interface as not dispatch-based, so polling is used instead (outside AHK docs — see Module_COMAutomation.md for `ComObjConnect` rules).
- Keep the request object referenced (global, static, or a property of a live object) until the response is read; a local variable in a function that returns early is released.
  ✗ local `xhr` + timer, function returns → ✓ global, static or object property
- A BoundFunc that captures `this` and is stored on `this` creates a cycle (`this → fn → this`). After `SetTimer(fn, 0)`, set the property to `0`/`""` so both can be freed.
  ✗ `this.fn := this.M.Bind(this)` kept forever → ✓ clear it after `SetTimer(this.fn, 0)`
- Assign `0` or `""` to clear a property. The docs describe `Var := unset` for variables only.
  ✗ `this.prop := unset` → ✓ `this.prop := 0`
- A method named `catch` (HttpPromise `.catch()`) needs v2.0.3+: add `#Requires AutoHotkey v2.0.3`.
- Fat-arrow callbacks take a single expression; see V1 → V2 BREAKING CHANGES.

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| COM error (unknown member) | Reading `xhr.readyState` on WinHttp | `e.Message` mentions the unknown name | Use `WaitForResponse(0)` |
| COM exception in the timer callback | Network failure surfaces in `WaitForResponse(0)` | Error dialog from the timer thread | `try` inside the poll function; reject/stop the timer |
| Memory never freed | BoundFunc stored on `this` and never cleared | Object count grows; `__Delete` never runs | Clear the property after stopping the timer |
| Syntax error at load | `catch(...)` method on v2.0.0–2.0.2 | Load-time error | `#Requires AutoHotkey v2.0.3` or rename the method |

## TIER 1 — Responsive Single Request
> METHODS COVERED: Open (async) · Send · WaitForResponse · Status · ResponseText

```ahk
#Requires AutoHotkey v2.0
AsyncGetSimple(url) {
    xhr := ComObject("WinHttp.WinHttpRequest.5.1")
    xhr.Open("GET", url, true)        ; async
    xhr.Send()
    xhr.WaitForResponse()             ; ✓ waits; script stays responsive (AHK Download docs)
    if xhr.Status = 200
        return xhr.ResponseText
    throw Error("HTTP " xhr.Status, -1, xhr.StatusText)
}

try MsgBox(SubStr(AsyncGetSimple("https://www.autohotkey.com/download/2.0/version.txt"), 1, 200))
catch as e
    MsgBox("Failed: " e.Message)
```

## TIER 2 — Non-Blocking Poll and Periodic Poller
> METHODS COVERED: SetTimer · WaitForResponse(0) · Abort · BoundFunc · class-based poller

```ahk
#Requires AutoHotkey v2.0
Persistent()
global g_xhr := "", g_pollFn := ""

AsyncGet(url, onComplete) {
    global g_xhr, g_pollFn
    g_xhr := ComObject("WinHttp.WinHttpRequest.5.1")    ; global keeps it alive
    g_xhr.Open("GET", url, true)
    g_xhr.Send()
    g_pollFn := PollReady.Bind(onComplete)
    SetTimer(g_pollFn, 50)
}

PollReady(callback) {
    global g_xhr, g_pollFn
    try {
        if !g_xhr.WaitForResponse(0)        ; false = still in flight
            return
    } catch as e {
        SetTimer(g_pollFn, 0)
        callback.Call(0, "Network error: " e.Message)
        return
    }
    SetTimer(g_pollFn, 0)
    callback.Call(g_xhr.Status, g_xhr.Status = 200 ? g_xhr.ResponseText : "")
}

AbortAsync() {
    global g_xhr, g_pollFn
    if g_pollFn
        SetTimer(g_pollFn, 0)
    if g_xhr
        g_xhr.Abort()
}

HandleResponse(status, body) => MsgBox("Status: " status "`n" SubStr(body, 1, 200))
AsyncGet("https://www.autohotkey.com/download/2.0/version.txt", HandleResponse)

; Periodic poller: a fresh synchronous request per tick (simple lifetime)
class ApiPoller {
    __New(url, intervalMs, onData) {
        this.url := url, this.intervalMs := intervalMs, this.onData := onData
        this.timerFn := 0
    }
    Start() {
        this.timerFn := this.Poll.Bind(this)    ; cycle this → timerFn → this ...
        SetTimer(this.timerFn, this.intervalMs)
    }
    Stop() {
        if this.timerFn {
            SetTimer(this.timerFn, 0)
            this.timerFn := 0                   ; ... broken here
        }
    }
    Poll() {
        try {
            xhr := ComObject("WinHttp.WinHttpRequest.5.1")
            xhr.Open("GET", this.url, false)    ; short blocking call inside a timer
            xhr.Send()
            if xhr.Status = 200
                this.onData.Call(xhr.ResponseText)
        }
    }
}
; ✗ if g_xhr.readyState = 4   ; WinHttp has no readyState
```

## TIER 3 — HttpPromise: Concurrent Requests
> METHODS COVERED: HttpPromise.__New · then · catch · abort · _Poll · _resolve · _reject

```ahk
#Requires AutoHotkey v2.0.3                   ; .catch() as a method name needs v2.0.3+
Persistent()

class HttpPromise {
    static PENDING   := 0
    static FULFILLED := 1
    static REJECTED  := 2

    __New(method, url, opts := Map()) {
        this._state := HttpPromise.PENDING
        this._value := "", this._reason := ""
        this._thens := [], this._catches := []
        this._xhr := ComObject("WinHttp.WinHttpRequest.5.1")
        this._xhr.SetTimeouts(0, opts.Get("connectMs", 10000), opts.Get("sendMs", 30000), opts.Get("receiveMs", 30000))
        this._xhr.Open(method, url, true)
        if opts.Has("headers")
            for k, v in opts["headers"]
                this._xhr.SetRequestHeader(k, v)
        body := opts.Get("body", "")
        if body != ""
            this._xhr.SetRequestHeader("Content-Type", opts.Get("contentType", "application/json; charset=UTF-8"))
        this._xhr.Send(body)
        this._pollFn := this._Poll.Bind(this)     ; cycle — cleared in _Stop()
        SetTimer(this._pollFn, 50)
    }

    _Stop() {
        if this._pollFn {
            SetTimer(this._pollFn, 0)
            this._pollFn := 0                     ; ✓ break the cycle (not `:= unset`)
        }
    }

    _Poll() {
        try {
            if !this._xhr.WaitForResponse(0)
                return
        } catch as e {
            this._Stop()
            return this._reject(e)
        }
        this._Stop()
        status := this._xhr.Status
        if status >= 200 && status < 300
            this._resolve(Map("status", status, "body", this._xhr.ResponseText,
                              "headers", this._xhr.GetAllResponseHeaders()))
        else
            this._reject(Error("HTTP " status, -1, SubStr(this._xhr.ResponseText, 1, 300)))
    }

    _resolve(value) {
        if this._state != HttpPromise.PENDING
            return
        this._state := HttpPromise.FULFILLED, this._value := value
        for cb in this._thens
            cb.Call(value)
    }

    _reject(reason) {
        if this._state != HttpPromise.PENDING
            return
        this._state := HttpPromise.REJECTED, this._reason := reason
        for cb in this._catches
            cb.Call(reason)
        if !this._catches.Length
            throw reason                          ; unhandled → standard error dialog
    }

    then(onFulfilled) {
        if this._state = HttpPromise.FULFILLED
            onFulfilled.Call(this._value)
        else if this._state = HttpPromise.PENDING
            this._thens.Push(onFulfilled)
        return this
    }

    catch(onRejected) {
        if this._state = HttpPromise.REJECTED
            onRejected.Call(this._reason)
        else if this._state = HttpPromise.PENDING
            this._catches.Push(onRejected)
        return this
    }

    abort() {
        this._Stop()
        try this._xhr.Abort()
        this._reject(Error("Request aborted", -1))
    }
}

HandleUser(res)  => MsgBox("User: " SubStr(res["body"], 1, 200))
HandleError(err) => MsgBox("Failed: " err.Message, "Error", 16)

p1 := HttpPromise("GET", "https://api.example.com/users/1")
p2 := HttpPromise("POST", "https://api.example.com/log", Map("body", '{"event":"startup"}'))
p1.then(HandleUser).catch(HandleError)       ; returns immediately
p2.catch(HandleError)
```

### Performance Notes

- One responsive `WaitForResponse()` per request is the simplest correct choice; polling timers add overhead only when code must return immediately.
- A 50 ms poll interval is a reasonable default; each pending request owns one timer.
- Limit concurrent requests (for example 10–20) and respect HTTP 429 responses.

## DROP-IN RECIPES

```ahk
; WaitWithDeadline — responsive wait with a timeout; aborts on expiry
WaitWithDeadline(xhr, seconds) {
    if xhr.WaitForResponse(seconds)          ; true = response arrived
        return true
    try xhr.Abort()
    return false
}
; Call site:
; xhr := ComObject("WinHttp.WinHttpRequest.5.1"), xhr.Open("GET", url, true), xhr.Send()
; if !WaitWithDeadline(xhr, 15)
;     MsgBox("Timed out")
```

## SEE ALSO

> This module does NOT cover: request construction, headers, auth, Download → see Module_HttpRequests.md
> This module does NOT cover: JSON parsing and REST client classes → see Module_JsonAndRestClients.md
> This module does NOT cover: class design and reference-cycle theory in depth → see Module_ClassLifecycle.md

- `Module_HttpRequests.md` — WinHttp members, GET/POST, auth, Download.
- `Module_JsonAndRestClients.md` — JSON strategies and a REST client.
- `Module_ClassLifecycle.md` — BoundFunc, `__Delete`, reference counting.
- `Module_ExceptionHandling.md` — error propagation from timer threads.
