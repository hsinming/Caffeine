# Module_ReviewPerformanceSecurity.md
<!-- DOMAIN: Code Review — Dimension 5: Performance, Security & Resource Management -->
<!-- SCOPE: Review checklist for loop-invariant work, repeated linear lookups, COM object lifetime (ComObject, ComObjQuery, ObjRelease), CoordMode scope, file handles, and untrusted input reaching DllCall, file paths, RegWrite keys, or regex patterns. DllCall/Buffer semantics are in Module_DllCallBasics.md (ahk-ctx-system). -->
<!-- TRIGGERS: "security review", "slow script", "performance", "memory leak", "COM cleanup", ObjRelease(), ComObjQuery(), ComObject(), CoordMode(), DllCall(), RegWrite(), RegExMatch(), "user input", "path traversal", "injection", "loop is slow" -->
<!-- CONSTRAINTS: ObjRelease takes an Integer pointer, never a wrapper object. ComObject and ComObjQuery return wrapper objects that release their interface automatically when freed. CoordMode and similar settings start fresh in every new thread; changing them inside a hotkey does not leak into other hotkeys. The 100 most recently used regex patterns are cached in compiled form. Map keys are case-sensitive by default. Severity choices and performance heuristics here are repo convention. -->
<!-- CROSS-REF: Module_ReviewFramework.md, Module_ReviewErrorHandling.md, Module_DllCallBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## API QUICK-REFERENCE

- **`ComObject(CLSID, IID?)`** — returns a wrapper object; clearing the last reference (`obj := ""`) releases it
- **`ComObjQuery(ComObj, [SID,] IID)`** — returns a wrapper object (`ComObject` for IID_IDispatch, otherwise `ComValue` with a `Ptr` property). It is released automatically; do not `ObjRelease` it (lib/ComObjQuery.htm)
- **`ObjAddRef(Ptr)` / `ObjRelease(Ptr)`** — `Ptr` is an Integer: an unmanaged object pointer or COM interface pointer. Returns the new reference count, for debugging only (lib/ObjAddRef.htm)
- **`ComValue(13, ptr)`** — wraps a raw interface pointer (e.g. from DllCall/ComCall) so it is released automatically (lib/ComValue.htm)
- **`CoordMode(TargetType, RelativeTo?)`** — returns the previous setting. Each new thread starts with the default; calling it during startup changes that default (lib/CoordMode.htm)
- **`Map.Has(Key)`** — keys are case-sensitive unless `CaseSense` is changed before adding items
- **`FileOpen(...)` / `File.Close()`** — a File closes when its object is freed, but the docs recommend closing it as soon as possible

## AHK V2 CONSTRAINTS

- **COM lifetime:** `ObjRelease(xlApp)` on a `ComObject()` wrapper is wrong — the
  parameter is an Integer pointer. Release a wrapper by clearing references
  (`xlApp := ""`). Use `ObjRelease` only for raw pointers the script owns
  (for example one it `ObjAddRef`'d), or wrap the raw pointer in `ComValue(13, ptr)`.
  Rate a misuse 🔴 Critical (convention).
- **CoordMode scope:** a `CoordMode` call inside a hotkey or timer affects only that
  thread. Do not flag "leaks into other hotkeys". Flag it only when code later in
  the **same** thread expects the old mode, or when a startup call silently
  changes the default for every thread.
- **Regex caching:** do not recommend storing pattern strings in static
  properties "to cache compilation" — AutoHotkey already keeps the 100 most recently
  used patterns compiled (lib/RegExMatch.htm, Remarks).
- **Map vs loop:** replacing `for c in list` + `c = cmd` (case-insensitive `=`) with
  `Map.Has(cmd)` makes the check case-sensitive. Set `m.CaseSense := "Off"` before
  adding keys when the old behavior must be kept.
- **Untrusted input** (InputBox, files, registry, clipboard, command line) reaching
  `DllCall`, file paths, `RegWrite` key names, or regex patterns without
  validation → 🔴 Critical (convention).
- **Dynamic regex:** `RegExMatch`/`RegExReplace` throw an Error on a pattern syntax
  error, so a pattern built from input needs try/catch.
- **`.=` in loops:** the docs state no cost model for `.=`. Do not report it as
  O(n²) by default; raise it only with evidence (large data, measured slowness).

## TIER 5 — Performance, Security & Resource Management
> METHODS COVERED: `FileRead()` · `FileOpen()` · `ComObject()` · `ComObjQuery()` · `ObjRelease()` · `CoordMode()` · `Map.Has()` · `DllCall()` · `RegExMatch()` · `RegWrite()` · `InputBox()`

```ahk
; CHECK 1: Loop-invariant work — hoist it (🟠 Major, convention)
; ✗
CountHitsSlow() {
    total := 0
    Loop 100 {
        data := FileRead("config.txt")      ; same file read 100 times
        total += InStr(data, "hit") ? 1 : 0
    }
    return total
}
; ✓
CountHits() {
    try {
        data := FileRead("config.txt")
    } catch as e {
        MsgBox("Read failed: " e.Message)
        return 0
    }
    total := 0
    Loop 100
        total += InStr(data, "hit") ? 1 : 0
    return total
}

; ----------------------------------------------------------------
; CHECK 2: Writing many lines — one open file instead of many FileAppend calls
WriteReport(items, path) {
    try {
        f := FileOpen(path, "w", "UTF-8")
        for item in items
            f.WriteLine(item)
        f.Close()
    } catch as e {
        OutputDebug("WriteReport: " e.Message)
    }
}

; ----------------------------------------------------------------
; CHECK 3: COM object lifetime
; ✗ ObjRelease(xl)            ; xl is a wrapper object, not an Integer pointer
; ✓
UseExcel() {
    xl := ComObject("Excel.Application")
    ; ... use xl ...
    xl.Quit()
    xl := ""                    ; last reference cleared → interface released
}
; ✓ ComObjQuery also returns a wrapper; no ObjRelease needed
; svc := ComObjQuery(obj, "{IID-GUID}")

; ----------------------------------------------------------------
; CHECK 4: CoordMode is per-thread
^F2:: {
    CoordMode("Mouse", "Screen")    ; ✓ affects this hotkey thread only
    Click(100, 200)
}

; ----------------------------------------------------------------
; CHECK 5: Reused membership test → Map (keep case rules in mind)
VALID_COMMANDS := Map()
VALID_COMMANDS.CaseSense := "Off"   ; match the old case-insensitive '=' loop
for cmd in ["open", "save", "close", "quit", "refresh"]
    VALID_COMMANDS[cmd] := true
IsValidCommand(cmd) => VALID_COMMANDS.Has(cmd)

; ----------------------------------------------------------------
; CHECK 6: Untrusted path reaching DllCall / file functions
; ✗ DllCall("DeleteFileW", "Str", InputBox("Path:").Value)   ; 🔴 Critical
; ✓ Restrict to an allowed folder and reject parent references
SafeDeleteInWorkDir(name) {
    static baseDir := A_ScriptDir "\work\"
    if (name = "" || InStr(name, "..") || RegExMatch(name, "[\\/:*?`"<>|]"))
        return false
    path := baseDir name
    if !FileExist(path)
        return false
    return DllCall("DeleteFileW", "Str", path)
}

; ----------------------------------------------------------------
; CHECK 7: Dynamic regex pattern — malformed input throws Error
FindUserPattern(data) {
    userPattern := InputBox("Enter search pattern:").Value
    try {
        return RegExMatch(data, userPattern)
    } catch as e {
        MsgBox("Invalid pattern: " e.Message, "Regex Error", 0x10)
        return 0
    }
}

; ----------------------------------------------------------------
; CHECK 8: Registry key built from input → whitelist it
ALLOWED_SETTINGS := Map("theme", true, "lang", true, "timeout", true)
SaveSetting(name, value) {
    if !ALLOWED_SETTINGS.Has(name)
        throw ValueError("Unknown setting", -1, name)
    RegWrite(value, "REG_SZ", "HKCU\Software\MyApp\" name, "Data")
}
```

## REVIEW NOTES (convention)

- **COM creation cost:** creating COM objects inside a hot loop or a frequently
  fired hotkey is a performance finding; create once and reuse.
- **Lookup tradeoff:** a Map makes a reused membership set explicit; a short list
  scanned once is fine.

## ANTI-PATTERNS

| Pattern | Wrong | Correct | Cause |
|---------|-------|---------|-------|
| `ObjRelease()` on a wrapper | `ObjRelease(xlApp)` after `ComObject()` | `xlApp := ""` | C/C++ manual refcount habits |
| `ObjRelease()` after `ComObjQuery()` | `ObjRelease(ComObjQuery(...))` | Let the returned wrapper be freed | v1 could return a raw pointer; v2 always returns a wrapper (v2-changes.htm) |
| "CoordMode leaks" finding | Save/restore CoordMode in every hotkey | Per-thread setting; no finding | Global-state assumption |
| Pattern "compile cache" class | Static property holding a pattern string | Call RegExMatch directly; AHK caches compiled patterns | Other languages' compiled-regex objects |
| Weak path whitelist | `^[A-Za-z]:\\[\w\\.\-]+$` (still allows `..`) | Fixed base folder, reject `..` and separators | Regex looks strict but is not |
| Unguarded dynamic regex | `RegExMatch(data, userPattern)` | try/catch, surface `e.Message` | Risk rarely shown in examples |

## SEE ALSO

- `Module_ReviewErrorHandling.md` — throwing-operations table
- `Module_DllCallBasics.md` (ahk-ctx-system) — DllCall types, Buffer, and pointers
