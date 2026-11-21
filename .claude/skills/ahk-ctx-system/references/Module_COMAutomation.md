# Module_COMAutomation.md
<!-- DOMAIN: System — COM automation: creating and attaching to COM objects, Office automation, WMI queries, COM events, SafeArrays and typed values -->
<!-- SCOPE: ComObject, ComObjActive, ComObjGet (WMI monikers), ComObjConnect (event sinks), ComObjArray, ComValue, owned vs attached host lifecycle (Quit/Close then release), Excel bulk writes. WinHttp.WinHttpRequest.5.1 is in Module_HttpRequests.md. ComCall/ComObjQuery/raw interface pointers via DllCall are in Module_DllCallBasics.md. Clipboard, processes and registry are in Module_ProcessAndSystem.md. -->
<!-- TRIGGERS: ComObject, ComObjActive, ComObjGet, ComObjConnect, ComObjArray, ComValue, ComObjCreate, "COM automation", "Excel automation", "Word automation", "read excel cell", "WMI query", winmgmts, ExecQuery, "COM event", WorkbookBeforeClose, SafeArray, "zombie Excel process", Quit -->
<!-- CONSTRAINTS: ComObject() replaces the removed v1 ComObjCreate(). ComObject/ComObjActive/ComObjGet/ComObjConnect throw on failure. When the script owns the host (ComObject), call .Quit()/.Close() before dropping references; never Quit a session obtained with ComObjActive. Event handlers receive the event's parameters plus the original COM wrapper as an extra last parameter. ComObjArray creates a SAFEARRAY whose indexes start at 0 (its own lower bound). The script must keep a reference to an object passed to ComObjConnect and may need Persistent() while listening. -->
<!-- CROSS-REF: Module_ProcessAndSystem.md, Module_DllCallBasics.md, Module_HttpRequests.md, Module_ExceptionHandling.md, Module_ClassLifecycle.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `ComObjCreate("Excel.Application")` | `ComObject("Excel.Application")` | `ComObjCreate` was removed — load-time VarUnset warning / `UnsetError` on call |
| `ComObjParameter(vt, v)` / `ComObject(vt, v)` wrapper | `ComValue(vt, v)` | Typed-value wrappers moved to `ComValue` |
| `ComObjEnwrap(ptr)` | `ComValue(9, ptr)` or `ComObjFromPtr(ptr)` | No wildcard `ComObj...()` names in v2 |
| `pbCancel[] := true` / `NumPut` on a ComObjRef for ByRef event params | Declare the handler parameter as `&cancel` and assign `cancel := true` | v2 passes VT_BYREF parameters transparently |

## API QUICK-REFERENCE

### COM Functions

| Function | Signature | Returns | Throws | Notes |
|----------|-----------|---------|--------|-------|
| `ComObject()` | `ComObject(CLSID, IID?)` | ComObject wrapper | exception on failure | `CLSID` may be a ProgID such as `"Excel.Application"`; IID defaults to IDispatch |
| `ComObjActive()` | `ComObjActive(CLSID)` | Wrapper for a running, registered object | exception if none | Attaches; the script does not own the host |
| `ComObjGet()` | `ComObjGet(Name)` | Wrapper | exception on failure | Monikers such as `"winmgmts:"` (WMI) or a file path |
| `ComObjConnect()` | `ComObjConnect(ComObj, PrefixOrSink?)` | — | exception on failure | String prefix → global functions `PrefixEventName`; object → its methods. Omit the 2nd parameter to disconnect |
| `ComObjArray()` | `ComObjArray(VarType, Count1, Count2?, ... Count8?)` | SAFEARRAY wrapper | — | Methods `.MaxIndex(n)`, `.MinIndex(n)`, `.Clone()`; indexes start at 0 |
| `ComValue()` | `ComValue(VarType, Value, Flags?)` | Typed wrapper | exception if conversion fails | e.g. `ComValue(0xB, true)` = VT_BOOL true; wrapping an interface pointer makes the wrapper release it |
| `ComObjValue()` / `ComObjType()` | `ComObjValue(ComObj)` / `ComObjType(ComObj, "Name"?)` | Raw value / type info | — | Inspection helpers |

Common VARTYPEs: `3` VT_I4, `8` VT_BSTR, `9` VT_DISPATCH, `0xB` VT_BOOL, `12` VT_VARIANT, `13` VT_UNKNOWN, `0x2000` VT_ARRAY flag, `0x4000` VT_BYREF flag.

### Event Handler Shape (ComObjConnect)

```
PrefixEventName(EventParams..., ComObj)   ; function form (string prefix)
EventName(EventParams..., ComObj)         ; method form (sink object; `this` = the sink)
```

The trailing `ComObj` parameter is not in the COM event's documentation. A variadic `(params*)` handler works when the count is unknown. Nested functions are not supported with the string-prefix form.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 COM name from V1 → V2 BREAKING CHANGES remains: `ComObjCreate`, `ComObjParameter`, `ComObjEnwrap`.
- Ownership decides teardown. Script-owned host (`ComObject`): close documents, call `.Quit()`, then release references (`ref := ""`), in a `finally` path. Attached host (`ComObjActive`): release references only — never `.Quit()` the user's session.
  ✗ `xl := ""` then `xl.Quit()` → ✓ `xl.Quit()` then `xl := ""`
  ✗ `ComObjActive(...).Quit()` → ✓ release the reference only
- COM calls that fail throw. Handle failures at operation boundaries where recovery or a message is needed; wrapping every property access in its own `try` is a **repo convention for diagnostics, not a language requirement**.
- Keep a reference to the object passed to `ComObjConnect` — if it is freed, the connection ends. Disconnect with `ComObjConnect(obj)` when done. Call `Persistent()` if nothing else keeps the script running while it waits for events.
- Event handlers must accept the extra trailing COM wrapper parameter, or be variadic; otherwise the call has too many parameters.
  ✗ `OnQuit()` for a no-arg event → ✓ `OnQuit(comObj)` or `OnQuit(params*)`
- Pass a named function where a multi-statement function argument is needed. A function expression has no block body; `=>` takes one expression.
  ✗ `(xl) { ... }` as an argument → ✓ named function
- `ComObjArray` indexes start at 0, unlike AHK `Array` (1-based). Use it to pass a whole 2-D block to `Range.Value` in one call.
  ✗ `arr[1, 1]` for the first cell → ✓ `arr[0, 0]`
  ✗ `for ... sheet.Cells(i,1).Value := v` for big data → ✓ `ComObjArray` + one `Range.Value`
- Office object-model constants are numbers in AHK (e.g. `xlCalculationManual = -4135`); there is no type-library constant import.

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| Error from `ComObject` | ProgID not registered (application not installed) | `e.Message` | `try`; tell the user the app is missing |
| Error from `ComObjActive` | No running instance registered | `e.Message` | Fall back to `ComObject()` if owning a new instance is acceptable |
| Error from a COM method | Invalid range, locked file, dialog open in the host | `e.Message` contains the HRESULT/description | Catch at the operation boundary; check host state |
| Too many parameters in an event handler | Handler lacks the trailing ComObj parameter | Error on first event | Add the parameter or use `params*` |
| Host process stays in Task Manager | References dropped before `.Quit()`, or other references still alive | `ProcessExist("EXCEL.EXE")` | Quit first, then clear every reference (workbooks, sheets, ranges) |

## TIER 1 — WMI Query into a Map
> METHODS COVERED: ComObjGet · ExecQuery · for-in over a COM collection · Map

```ahk
#Requires AutoHotkey v2.0
GetRunningServices() {
    services := Map()
    try {
        wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
        for svc in wmi.ExecQuery("SELECT Name, DisplayName FROM Win32_Service WHERE State='Running'")
            services[svc.Name] := svc.DisplayName       ; for-in enumerates COM collections
    } catch as err {
        MsgBox("WMI query failed: " err.Message)
    }
    return services
}

running := GetRunningServices()
if running.Has("Spooler")                ; ✓ Has() before indexing
    MsgBox(running["Spooler"])
; ✗ running["Missing"]                  ; UnsetItemError when the key is absent
```

## TIER 2 — Owned vs Attached Excel Sessions
> METHODS COVERED: ComObject · ComObjActive · Workbooks.Add · Range.Value · Close · Quit · try/finally

```ahk
#Requires AutoHotkey v2.0
OwnedExcel() {
    xl := "", wb := ""
    try {
        xl := ComObject("Excel.Application")    ; script owns this instance
        xl.Visible := false
        wb := xl.Workbooks.Add()
        wb.ActiveSheet.Range("A1").Value := "Hello"
        wb.Close(0)                             ; 0 = do not save
    } catch as err {
        MsgBox("Excel automation failed: " err.Message)
    } finally {
        if xl
            try xl.Quit()                       ; ✓ Quit BEFORE releasing references
        wb := "", xl := ""
    }
}

AttachedExcel() {
    xl := ""
    try {
        xl := ComObjActive("Excel.Application")  ; user's running session
        xl.ActiveSheet.Range("A1").Value := "Updated"
    } catch as err {
        MsgBox("No usable Excel session: " err.Message)
    } finally {
        xl := ""                                 ; ✓ release only — never Quit()
    }
}

; ✗ xl := "", xl.Quit()      ; reference already gone; Excel may stay running
; ✗ ComObjActive(...).Quit() ; closes the user's own Excel
```

## TIER 3 — Bulk Write with ComObjArray
> METHODS COVERED: ComObjArray · Range.Value · ScreenUpdating · Calculation

```ahk
#Requires AutoHotkey v2.0
WriteMapToExcel(data) {
    if !(data is Map)
        throw TypeError("data must be a Map", -1)
    xl := "", wb := ""
    try {
        xl := ComObject("Excel.Application")
        xl.ScreenUpdating := false
        xl.Calculation := -4135                   ; xlCalculationManual
        wb := xl.Workbooks.Add()

        arr := ComObjArray(12, data.Count, 2)     ; 12 = VT_VARIANT; indexes start at 0
        row := 0
        for key, val in data {
            arr[row, 0] := key
            arr[row, 1] := val
            row++
        }
        wb.ActiveSheet.Range("A1:B" data.Count).Value := arr   ; one call for the whole block

        xl.Calculation := -4105                   ; xlCalculationAutomatic
        xl.ScreenUpdating := true
        xl.Visible := true                        ; hand the workbook to the user
        xl := "", wb := ""                        ; release without quitting — user now owns the window
    } catch as err {
        if xl
            try xl.Quit()
        throw
    }
}
```

## TIER 4 — COM Event Sink and Owner Class
> METHODS COVERED: ComObjConnect · event handler signature · &ByRef event parameter · __Delete · Persistent

```ahk
#Requires AutoHotkey v2.0
Persistent()

class ExcelEvents {
    __New() {
        this.xl := ComObject("Excel.Application")
        this.xl.Visible := true
        this.xl.Workbooks.Add()
        ComObjConnect(this.xl, this)              ; methods below handle events by name
    }

    ; Event params first, then the extra COM wrapper parameter
    WorkbookBeforeClose(wb, &cancel, xlApp) {
        if MsgBox("Close " wb.Name "?", "Confirm", "YesNo") = "No"
            cancel := true                        ; ✓ VT_BYREF handled via &param
    }

    SheetSelectionChange(sheet, target, xlApp) {
        ToolTip("Selected: " target.Address)
        SetTimer(() => ToolTip(), -2000)          ; one-shot timer
    }

    Dispose() {
        if this.xl {
            ComObjConnect(this.xl)                ; disconnect events
            try this.xl.Quit()
            this.xl := ""
        }
    }
}
listener := ExcelEvents()
; Later: listener.Dispose()
; Note: the sink holds this.xl and the COM object holds the sink, so rely on an
; explicit Dispose() rather than __Delete for teardown.

; ✗ WorkbookBeforeClose(wb, &cancel)   ; missing trailing parameter → too many parameters error
```

### Performance Notes

- Every COM property read or method call crosses into the host application; for large data use one `Range.Value := ComObjArray(...)` assignment instead of per-cell writes.
- Disable `ScreenUpdating` and switch calculation to manual during bulk writes; restore both afterwards.
- WQL `SELECT` with explicit columns returns less data than `SELECT *`.

## DROP-IN RECIPES

```ahk
; WithComObject — create an owned COM host, run an action, always Quit and release
WithComObject(progId, action) {
    if !HasMethod(action)
        throw TypeError("WithComObject: action must be callable", -1)
    obj := ComObject(progId)                      ; throws if not available
    try {
        return action(obj)
    } finally {
        try obj.Quit()
        obj := ""
    }
}

; Call site (named function — v2.0 has no block-bodied anonymous functions):
FillSheet(xl) {
    wb := xl.Workbooks.Add()
    wb.ActiveSheet.Range("A1").Value := "Done"
    wb.SaveAs(A_ScriptDir "\out.xlsx")
    wb.Close()
}
; WithComObject("Excel.Application", FillSheet)
```

## SEE ALSO

> This module does NOT cover: HTTP through WinHttp.WinHttpRequest.5.1 → see Module_HttpRequests.md
> This module does NOT cover: ComCall, raw interface pointers, DllCall → see Module_DllCallBasics.md
> This module does NOT cover: Run/RunWait, clipboard, registry → see Module_ProcessAndSystem.md

- `Module_ProcessAndSystem.md` — processes, clipboard, registry, environment variables.
- `Module_DllCallBasics.md` — DllCall, ComCall and Win32 handle work.
- `Module_HttpRequests.md` — WinHttp COM requests.
- `Module_ClassLifecycle.md` — owner/wrapper class design and `__Delete`.
- `Module_ExceptionHandling.md` — error handling at COM operation boundaries.
