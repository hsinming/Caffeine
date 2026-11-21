# Module_DllCallBasics.md
<!-- DOMAIN: DLL Calls — calling Win32 and other DLL functions with DllCall -->
<!-- SCOPE: DllCall syntax, argument/return type strings and the Win32 type mapping, Str/WStr/AStr, * and P suffixes with VarRefs, HRESULT, error classes, A_LastError, A_PtrSize, performance (preloaded DLLs, GetProcAddress), FormatMessageW error text, system information, kernel handles and named mutexes. Buffer/NumGet/NumPut/StrGet/StrPut, Win32 memory allocators and struct layouts are in Module_BufferAndMemory.md. CallbackCreate, OnMessage, SendMessage/PostMessage and hooks are in Module_CallbacksAndMessages.md. COM automation is in Module_COMAutomation.md. -->
<!-- TRIGGERS: DllCall, "call Windows API", "Win32 API", "DLL function", ReturnType, "Ptr", "UPtr", "Int64", "Str", "WStr", "AStr", "UInt*", "UIntP", HRESULT, A_LastError, A_PtrSize, LoadLibrary, GetProcAddress, FreeLibrary, GetModuleHandle, FormatMessageW, "error code to string", GetSystemInfo, GetComputerNameW, CreateMutexW, WaitForSingleObject, ReleaseMutex, CloseHandle, HANDLE, HWND, "64-bit truncation", CDecl -->
<!-- CONSTRAINTS: Return type defaults to Int — declare "Ptr" for handles/pointers and "UInt"/"UPtr" etc. when the C return type is not a 32-bit int. Use "Ptr" for HANDLE/HWND/pointer arguments. An object passed to a "Ptr" argument contributes its Ptr property (PropertyError if it has none). "HRESULT" return type throws OSError on failure (Extra holds the hex code). DllCall throws TypeError/ValueError/Error for bad types, missing DLLs/functions, native exceptions, and (32-bit only) wrong argument sizes. Read A_LastError right after the call. VarSetCapacity does not exist in v2. -->
<!-- CROSS-REF: Module_BufferAndMemory.md, Module_CallbacksAndMessages.md, Module_COMAutomation.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `VarSetCapacity(v, 64, 0)` + `&v` | `v := Buffer(64, 0)` and pass `v` to a `"Ptr"` argument | `VarSetCapacity` was removed (load-time VarUnset warning / `UnsetError`) |
| `&var` as an address | `buf.Ptr`, `StrPtr(var)`; `&var` is a VarRef for `*`/`P` and `Str` output args | In v2 `&` creates a VarRef, not an address |
| `"UInt*", var` (output into var) | `"UInt*", &var` | Without `&`, the value is passed but the result is not written back to `var` |
| `DllCall("GetModuleHandleW", "Str", n)` with no return type | `..., "Ptr")` | Default return type `Int` truncates 64-bit handles |
| `ErrorLevel` after DllCall | `try`/`catch` + `A_LastError` | ErrorLevel was removed; DllCall throws for call failures |

## API QUICK-REFERENCE

### DllCall

| Item | Signature / Value | Notes |
|------|-------------------|-------|
| `DllCall()` | `DllCall("[DllFile\]Function", Type1, Arg1, ..., "ReturnType"?)` | `Function` may also be an address (integer). DllFile may be omitted for functions in User32, Kernel32, ComCtl32 or Gdi32. Add `"CDecl"` before the return type for C-convention functions (ignored on 64-bit) |
| Default return type | `Int` | Declare the real type otherwise |
| `A_LastError` | Integer | `GetLastError()` result after DllCall (and many built-ins); read it immediately |
| `A_PtrSize` | 4 or 8 | Pointer size; use for struct offsets |

### Type Strings (official)

| Type | Meaning |
|------|---------|
| `Str` / `WStr` | UTF-16 string (`WStr` = `Str` in v2). A plain variable or VarRef argument is updated if the function writes into it; reserve space with `VarSetStrCapacity(&v, n)` first. A number expression passed as `Str` throws `TypeError` |
| `AStr` | Converted to ANSI; anything the function writes is discarded — for ANSI output use a Buffer and `StrGet(buf, "cp0")` |
| `Int64`, `Int`, `Short`, `Char` (+ `U` prefix) | Integers of 8/4/2/1 bytes |
| `Ptr` / `UPtr` | Pointer-sized integer; use for handles, pointers, structs and Buffers. `UPtr` is unsigned only in 32-bit builds (no unsigned 64-bit in AHK) and does not accept objects |
| `Float`, `Double` | Floating point |
| `Type*` or `TypeP` | Pointer to one value; pass `&var` to receive the output (e.g. `"UInt*", &size`). Not for strings, structs or arrays |
| `Ptr*` | Pointer output (LPVOID*); an object passed here has its `Ptr` read before and written after the call |
| `HRESULT` | Return type only; failures throw `OSError` |

### Win32 Typedef → DllCall Type (common mapping)

| C / Win32 type | DllCall type |
|----------------|--------------|
| `HWND`, `HANDLE`, `HMODULE`, `HDC`, `HKEY`, `HHOOK`, any `*`/`LP...` to a struct or array | `"Ptr"` |
| `WPARAM`, `UINT_PTR`, `SIZE_T`, `ULONG_PTR` | `"UPtr"` |
| `LPARAM`, `LRESULT`, `INT_PTR`, `LONG_PTR` | `"Ptr"` |
| `DWORD`, `UINT`, `ULONG`, `COLORREF` | `"UInt"` |
| `LONG`, `INT`, `BOOL` (32-bit) | `"Int"` |
| `WORD`, `USHORT`, `WCHAR`, `ATOM` / `SHORT` | `"UShort"` / `"Short"` |
| `BYTE`, `UCHAR`, `BOOLEAN` / `CHAR` | `"UChar"` / `"Char"` |
| `LONGLONG`, `LARGE_INTEGER` / `ULONGLONG`, `DWORD64` | `"Int64"` / `"UInt64"` (64-bit unsigned values above 2^63 are not representable) |
| `FLOAT` / `DOUBLE` | `"Float"` / `"Double"` |
| `LPWSTR`, `LPCWSTR` / `LPSTR`, `LPCSTR` | `"Str"` / `"AStr"` |
| `LPDWORD` (one output value) | `"UInt*"` with `&var` |

### Errors Thrown by DllCall (official list)

| Class | Condition |
|-------|-----------|
| `OSError` | `HRESULT` return type and a failure code; `Extra` holds the hex code |
| `TypeError` | Function parameter is a float; an argument has the wrong kind of value (number to `Str`, object to a non-`Ptr` type, non-numeric string to a number type) |
| `ValueError` | Invalid return or argument type string |
| `PropertyError` | Object passed to `Ptr` has no `Ptr` property |
| `Error` | DLL cannot be loaded; function not found; native exception (Extra = exception code, e.g. `0xC0000005`); wrong argument-list size (32-bit only, Extra = byte difference) |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 memory form from V1 → V2 BREAKING CHANGES remains: `VarSetCapacity`, `&var` used as an address, `ErrorLevel`.
- Declare every return type that is not a 32-bit signed int (`int`/`BOOL`). Pointer/handle results without `"Ptr"` are truncated on 64-bit; the missing-return-type wrong form is in V1 → V2 BREAKING CHANGES.
- Use `"Ptr"` for handles and pointers. A Buffer (or any object with a `Ptr` property) can be passed directly to a `"Ptr"` argument.
  ✗ `"Int", hwnd` → ✓ `"Ptr", hwnd`
- To receive an output number, use a `*`/`P` type with a VarRef: `"UInt*", &count`. Initialize in place if needed: `&count := 0`. The wrong form without `&` is in V1 → V2 BREAKING CHANGES.
- Read `A_LastError` immediately after the call that failed — later calls overwrite it. Check the function's documented failure value (often 0/NULL) first.
- `DllCall` can still crash the script when given a bad pointer, a too-small `Str`, or a wrong type; only some failures become exceptions.
- Every kernel handle from `Create*`/`Open*` must be closed with `CloseHandle` (Win32 rule, outside AHK docs); AutoHotkey does not track native handles. Every native handle has a matching close/free path.
  ✗ `CreateMutexW` without `CloseHandle` → ✓ close in `__Delete`/cleanup
- Matching every `SIZE_T` length to `"UPtr"` rather than `"UInt"` is a **repo convention** that keeps 64-bit sizes intact.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `Error` | DLL not found / function not found | `e.Message` names the DLL or function | Check the name, `W`/`A` suffix, bitness, PATH |
| `Error` (Extra `0xC0000005`) | Access violation inside the function | `e.Extra` | Fix pointers, buffer sizes, argument types |
| `TypeError` / `ValueError` | Wrong value kind or invalid type string | `e.Message`, `e.Extra` | Correct the type list |
| `OSError` | `"HRESULT"` return reported failure | `e.Extra` = hex HRESULT | Handle or translate with `FormatMessageW` |
| Silent wrong value | Missing `"Ptr"` return type on 64-bit | Handle looks small or 0 while `A_LastError` = 0 | Add the return type |
| VarUnset warning / `UnsetError` | `VarSetCapacity(...)` | Load-time warning | Use `Buffer()` |

## TIER 1 — Simple Calls, Output Values, Error Codes
> METHODS COVERED: DllCall · return types · "Ptr" Buffer argument · "UInt*" VarRef · A_LastError · GetModuleHandleW · LoadLibraryW · FreeLibrary

```ahk
#Requires AutoHotkey v2.0
ticks := DllCall("GetTickCount", "UInt")                   ; DWORD → "UInt"

ret := DllCall("User32\MessageBoxW", "Ptr", 0, "Str", "Hello", "Str", "DllCall", "UInt", 0x41, "Int")

pt := Buffer(8, 0)                                          ; POINT {LONG x, y}
if DllCall("User32\GetCursorPos", "Ptr", pt, "Int")         ; Buffer passed to "Ptr"
    MsgBox("Cursor: " NumGet(pt, 0, "Int") ", " NumGet(pt, 4, "Int"))

if !DllCall("User32\SetWindowTextW", "Ptr", WinExist("A"), "Str", "Renamed", "Int")
    MsgBox("SetWindowTextW failed: " A_LastError)           ; ✓ read immediately

hMod := DllCall("GetModuleHandleW", "Str", "kernel32.dll", "Ptr")   ; ✓ HMODULE → "Ptr"

hLib := DllCall("LoadLibraryW", "Str", "winmm.dll", "Ptr")
if hLib {
    DllCall("winmm\PlaySoundW", "Str", "SystemAsterisk", "Ptr", 0, "UInt", 0x10000, "Int")   ; SND_ALIAS
    DllCall("FreeLibrary", "Ptr", hLib, "Int")
}

size := 16
nameBuf := Buffer(size * 2, 0)
if DllCall("GetComputerNameW", "Ptr", nameBuf, "UInt*", &size, "Int")   ; ✓ &size receives the length
    MsgBox("Computer: " StrGet(nameBuf, size, "UTF-16"))

; ✗ DllCall("GetModuleHandleW", "Str", "kernel32.dll")   ; Int return truncates the handle on 64-bit
; ✗ DllCall("GetComputerNameW", "Ptr", nameBuf, "UInt*", size)   ; result not written back to size
```

## TIER 2 — Error Text and System Information
> METHODS COVERED: FormatMessageW · OSError(code) · GetSystemInfo · A_PtrSize offsets

```ahk
#Requires AutoHotkey v2.0
; Built-in alternative: OSError(code).Message → "(5) Access is denied."
Win32ErrorText(code) {
    buf := Buffer(1024, 0)                                   ; 512 UTF-16 chars
    len := DllCall("FormatMessageW", "UInt", 0x1200,         ; FROM_SYSTEM | IGNORE_INSERTS
        "Ptr", 0, "UInt", code, "UInt", 0x0400, "Ptr", buf, "UInt", 512, "Ptr", 0, "UInt")
    return len ? RTrim(StrGet(buf, "UTF-16"), "`r`n ") : Format("Unknown error 0x{:08X}", code)
}
MsgBox(Win32ErrorText(5) "`n" OSError(5).Message)

; SYSTEM_INFO: WORD arch @0, DWORD pageSize @4, then pointer fields
si := Buffer(48, 0)                                          ; 48 bytes on x64 (Win32 layout)
DllCall("GetSystemInfo", "Ptr", si)
arch     := NumGet(si, 0, "UShort")                          ; 0 x86, 9 x64, 12 ARM64
pageSize := NumGet(si, 4, "UInt")
numCPUs  := NumGet(si, 8 + A_PtrSize * 3, "UInt")            ; dwNumberOfProcessors
MsgBox("Arch " arch ", page " pageSize ", CPUs " numCPUs)
```

## TIER 3 — Kernel Handles and a Named Mutex
> METHODS COVERED: CreateMutexW · A_LastError (183) · WaitForSingleObject · ReleaseMutex · CloseHandle · __Delete

```ahk
#Requires AutoHotkey v2.0
class MutexGuard {
    __New(name, timeoutMs := 0) {                            ; 0 = try once; 0xFFFFFFFF = INFINITE
        this.h := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "Str", name, "Ptr")
        if !this.h
            throw OSError(A_LastError, -1)                    ; OSError(code) builds the message
        this.alreadyExisted := (A_LastError = 183)           ; ERROR_ALREADY_EXISTS — read before the next call
        r := DllCall("WaitForSingleObject", "Ptr", this.h, "UInt", timeoutMs, "UInt")
        if r != 0 && r != 0x80 {                             ; WAIT_OBJECT_0 / WAIT_ABANDONED
            DllCall("CloseHandle", "Ptr", this.h, "Int")
            this.h := 0
            throw Error(r = 0x102 ? "Mutex '" name "' is held elsewhere" : "Wait failed: " A_LastError, -1)
        }
        this.owned := true
    }
    __Delete() {
        if this.HasOwnProp("owned") && this.owned
            DllCall("ReleaseMutex", "Ptr", this.h, "Int")   ; release before closing
        if this.HasOwnProp("h") && this.h
            DllCall("CloseHandle", "Ptr", this.h, "Int")
    }
}

try guard := MutexGuard("MyApp_SingleInstance")
catch as e {
    MsgBox("Another instance is running.`n" e.Message)
    ExitApp()
}
; ... exclusive work ...
guard := unset          ; variables may be un-set; __Delete releases and closes
```

### Performance Notes

- When the function name is a literal string and its DLL is loaded before the script starts (or via `#DllLoad`), the address is resolved automatically — the docs call this more effective than manual `GetProcAddress` caching.
- For other DLLs called repeatedly, load them once with `LoadLibrary` to avoid a load/free per call; `GetProcAddress` + calling the address saves the lookup as well.
- Passing `StrPtr(var)` as `"Ptr"` is faster than `"Str"` for long strings the function does not resize.
- Reuse Buffers across calls instead of allocating inside hot loops.

## DROP-IN RECIPES

```ahk
; CallOrThrow — call a BOOL-returning Win32 function; throw OSError with the OS message on failure
CallOrThrow(fn, args*) {
    result := DllCall(fn, args*)            ; args must include the "Int" return type last
    if !result
        throw OSError(A_LastError, -1)
    return result
}
; Call site: CallOrThrow("User32\SetWindowTextW", "Ptr", WinExist("A"), "Str", "Title", "Int")

; ProcAddress — cache a function address for a DLL that is not preloaded
ProcAddress(dll, fn) {
    static cache := Map()
    key := dll "\" fn
    if !cache.Has(key) {
        h := DllCall("GetModuleHandleW", "Str", dll, "Ptr") || DllCall("LoadLibraryW", "Str", dll, "Ptr")
        cache[key] := DllCall("GetProcAddress", "Ptr", h, "AStr", fn, "Ptr")   ; ANSI name
    }
    return cache[key]
}
```

## SEE ALSO

> This module does NOT cover: Buffer, NumGet/NumPut, StrGet/StrPut, Win32 memory APIs, structs → see Module_BufferAndMemory.md
> This module does NOT cover: CallbackCreate, OnMessage, SendMessage/PostMessage, hooks → see Module_CallbacksAndMessages.md
> This module does NOT cover: try/catch patterns in depth → see Module_ExceptionHandling.md

- `Module_BufferAndMemory.md` — memory for DllCall arguments and struct layouts.
- `Module_CallbacksAndMessages.md` — native callbacks and window messages.
- `Module_COMAutomation.md` — COM objects as an alternative to raw DllCall.
- `Module_ExceptionHandling.md` — OSError and diagnostic workflows.
