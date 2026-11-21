# Module_BufferAndMemory.md
<!-- DOMAIN: Memory — Buffer objects, numeric and string memory I/O, Win32 memory APIs, struct simulation -->
<!-- SCOPE: Buffer (Ptr, Size, FillByte, reallocation), NumPut/NumGet, StrPut/StrGet and encodings, ntdll block operations (RtlMoveMemory etc.), VirtualAlloc/VirtualProtect/VirtualFree, process heap (HeapAlloc/HeapFree), global memory (GlobalAlloc/GlobalLock) for the clipboard, WideCharToMultiByte/MultiByteToWideChar, struct layouts (RECT, SYSTEMTIME, WINDOWPLACEMENT) and a struct wrapper class. DllCall syntax and type strings are in Module_DllCallBasics.md. Callbacks and messages are in Module_CallbacksAndMessages.md. -->
<!-- TRIGGERS: Buffer, "Buffer.Ptr", "Buffer.Size", FillByte, NumPut, NumGet, StrPut, StrGet, StrPtr, "raw memory", "memory copy", "struct", "struct simulation", "struct offset", RtlMoveMemory, RtlZeroMemory, RtlFillMemory, RtlCompareMemory, VirtualAlloc, VirtualFree, HeapAlloc, HeapFree, GlobalAlloc, GlobalLock, SetClipboardData, WideCharToMultiByte, MultiByteToWideChar, "UTF-8 bytes", RECT, SYSTEMTIME, WINDOWPLACEMENT, VarSetCapacity -->
<!-- CONSTRAINTS: Buffer(ByteCount, FillByte?) is the AHK-managed allocator; without FillByte the bytes are arbitrary. A Buffer's address becomes invalid when it is freed or reallocated (Size changed) — keep the Buffer object, not a saved Ptr. NumPut(Type, Number, ..., Target, Offset?) puts the type first; NumGet(Source, Offset?, Type) puts it last. StrGet's Length is a maximum (stops at the first null) unless negative. StrPut/StrGet throw ValueError for invalid parameters and OSError when conversion fails. Native allocations (Virtual*/Heap*/Global*) are not tracked by AutoHotkey and must be freed explicitly. -->
<!-- CROSS-REF: Module_DllCallBasics.md, Module_CallbacksAndMessages.md, Module_FileIO.md, Module_ClassBasics.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `VarSetCapacity(v, 64, 0)` | `v := Buffer(64, 0)` | `VarSetCapacity` was removed (load-time VarUnset warning / `UnsetError`) |
| `NumPut(val, var, offset, "UInt")` | `NumPut("UInt", val, buf, offset)` | v2 puts Type(s) first; the v1 order passes a number where a type is expected |
| `NumGet(&var + 4, "UInt")` | `NumGet(buf, 4, "UInt")` | `&var` is a VarRef in v2; pass the Buffer and an offset |
| `*(addr)` deref operator | `NumGet(addr, "UChar")` | The `*` deref operator was removed |
| `StrPut(str, &var, ...)` | `StrPut(str, buf, "UTF-8")` | Use a Buffer target |

## API QUICK-REFERENCE

### Buffer Object

| Member | Signature | Notes |
|--------|-----------|-------|
| `Buffer()` | `Buffer(ByteCount?, FillByte?)` | FillByte 0–255 fills every byte; omitted → contents arbitrary (the docs advise omitting it when you write before reading). ByteCount omitted → null Ptr, Size 0. `MemoryError` if allocation fails |
| `.Ptr` | read-only | Current address; invalid after the Buffer is freed or reallocated |
| `.Size` | read/write | Assigning reallocates: the address typically changes; data is preserved (truncated if smaller); new bytes are arbitrary |
| `.__New()` | `buf.__New(ByteCount?, FillByte?)` | Reallocate and/or refill an existing Buffer |

Functions that accept a Buffer (NumGet/NumPut/StrGet/StrPut/RawRead/DllCall `"Ptr"` …) also accept any object with `Ptr` and `Size` properties (a `DllCall` `"Ptr"` argument needs only `Ptr`).

### Numeric Memory I/O

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `NumPut()` | `NumPut(Type, Number, [Type2, Number2, ...], Target, Offset := 0)` | Address after the last item written | Several Type/Number pairs in one call; too-large integers keep only the low bytes (`NumPut("Char", 257, buf)` stores 1) |
| `NumGet()` | `NumGet(Source, Offset := 0, Type)` / `NumGet(Source, Type)` | Number | With two parameters, the second is the Type |

Types: `UInt`, `Int`, `Int64`, `Short`, `UShort`, `Char`, `UChar`, `Double`, `Float`, `Ptr`, `UPtr`, plus `UInt64` for `NumPut` only (`NumGet` has no unsigned 64-bit type). Passing a Buffer (rather than an address) lets AHK validate the range; invalid raw addresses can crash the script.

### String Memory I/O

| Function | Signature | Returns | Notes |
|----------|-----------|---------|-------|
| `StrPut()` | `StrPut(String, Encoding?)` | Required size in **bytes**, including the null | 2-parameter "measure" mode |
| `StrPut()` | `StrPut(String, Target, Length?, Encoding?)` | Bytes written | Null terminator written only if there is room. `Length` is in characters; required for a raw address unless the size is known |
| `StrGet()` | `StrGet(Source, Length?, Encoding?)` | String | Positive `Length` = maximum chars, stops at the first null; negative `Length` = exact count including nulls. With a Buffer or a Length, null termination is not required |
| `StrPtr()` | `StrPtr(Var)` | Address of the string's UTF-16 buffer | Valid until the string changes |

Encodings: `"UTF-8"`, `"UTF-16"`, `"CP0"` (ANSI), `"CPnnn"` or a number. Either Length or a non-numeric Encoding may follow Source/Target directly.

### Win32 Memory and Conversion APIs (outside AHK docs)

| Function | DllCall types | Returns | Notes |
|----------|---------------|---------|-------|
| `RtlMoveMemory` | `"Ptr", dst, "Ptr", src, "UPtr", len` | void | memmove; overlap-safe |
| `RtlFillMemory` / `RtlZeroMemory` | `"Ptr", dst, "UPtr", len[, "UChar", fill]` | void | memset |
| `RtlCompareMemory` | `"Ptr", a, "Ptr", b, "UPtr", len, "UPtr"` | Count of matching leading bytes | Equal only if result = len |
| `VirtualAlloc` | `"Ptr", 0, "UPtr", size, "UInt", 0x3000, "UInt", prot, "Ptr"` | Address or 0 | `MEM_COMMIT\|MEM_RESERVE = 0x3000` |
| `VirtualFree` | `"Ptr", addr, "UPtr", 0, "UInt", 0x8000, "Int"` | BOOL | `MEM_RELEASE` needs size 0 |
| `VirtualProtect` | `"Ptr", addr, "UPtr", size, "UInt", newProt, "UInt*", &old, "Int"` | BOOL | |
| `GetProcessHeap` / `HeapAlloc` / `HeapFree` / `HeapSize` | handle `"Ptr"`, size `"UPtr"` | — | `HEAP_ZERO_MEMORY = 8`; free with the same heap |
| `GlobalAlloc` / `GlobalLock` / `GlobalUnlock` / `GlobalFree` / `GlobalSize` | flags `"UInt"`, size `"UPtr"`, HGLOBAL `"Ptr"` | — | `GMEM_MOVEABLE = 2`, `GMEM_ZEROINIT = 0x40`; do not free after a successful `SetClipboardData` |
| `WideCharToMultiByte` / `MultiByteToWideChar` | code page `"UInt"` (65001 = UTF-8), lengths `"Int"` | Count; 0 on failure | Call once with output size 0 to get the needed size |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- No v1 memory form from V1 → V2 BREAKING CHANGES remains: `VarSetCapacity`, `&var` addresses, `*` deref.
- Use `Buffer()` for memory the script owns; use Win32 allocators only when an API requires that allocator (clipboard `HGLOBAL`, executable pages, heap ownership transfer).
- Keep the Buffer object alive while its memory is in use. Do not store `.Ptr` and drop the Buffer; do not reuse a saved `.Ptr` after changing `.Size` or after the Buffer is freed.
  ✗ `p := Buffer(8).Ptr` → ✓ keep the Buffer in a variable
- Zero-fill a Buffer (`FillByte` 0) when the API reads it before writing (struct inputs).
  ✗ `Buffer(n)` passed as a struct input → ✓ `Buffer(n, 0)`
- `NumPut` takes Type first; `NumGet` takes Type last: `NumPut(Type, Value, Target, Offset)` / `NumGet(Source, Offset, Type)`. Two-parameter `NumGet(src, type)` reads at offset 0.
- `StrPut` in measure mode returns **bytes** including the null; allocate `Buffer(StrPut(s, enc))`. `StrGet(buf, n, enc)` reads at most `n` characters.
  ✗ `StrGet(p, 10)` expecting embedded nulls → ✓ `StrGet(p, -10)`
- Struct offsets must come from the Windows SDK layout, including padding before pointer-sized fields (use `A_PtrSize`). Never guess offsets.
- Never pass a Buffer's `.Ptr` to `HeapFree`/`GlobalFree`/`VirtualFree` — Buffers use AutoHotkey's own allocator (Win32 rule, outside AHK docs).
- Every `VirtualAlloc`, `HeapAlloc` and `GlobalAlloc` needs a matching free, unless ownership was transferred (e.g. to the clipboard). `SIZE_T` lengths use `"UPtr"`.
  ✗ `GlobalFree` after `SetClipboardData` succeeded → ✓ free only when not transferred

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| VarUnset warning / `UnsetError` | `VarSetCapacity` | Load-time warning | `Buffer()` |
| `ValueError` from `NumPut` | v1 argument order (number where a type is expected) | `e.Message` | Type first |
| Exception / crash | `NumGet`/`NumPut` with an invalid raw address | Script error or termination | Pass the Buffer; validate offsets |
| `ValueError` | `StrPut` target too small; invalid parameters | `e.Message` | Size with `StrPut(s, enc)` first |
| `OSError` | `StrPut`/`StrGet` conversion failed | `e.Number` | Check the code page |
| `MemoryError` | `Buffer`/`.Size` allocation failed | `e is MemoryError` | Smaller size; check for runaway sizes |

## TIER 1 — Buffer, NumPut/NumGet, StrPut/StrGet
> METHODS COVERED: Buffer · .Ptr · .Size · NumPut · NumGet · StrPut · StrGet · A_PtrSize

```ahk
#Requires AutoHotkey v2.0
buf := Buffer(24, 0)                                   ; zero-filled
NumPut("Int", -1000, "UInt", 4294967295, buf, 0)       ; two values at offsets 0 and 4
NumPut("Int64", 9007199254, buf, 8)
MsgBox(NumGet(buf, 0, "Int") " " NumGet(buf, 4, "UInt") " " NumGet(buf, 8, "Int64"))

scratch := Buffer(32)                                  ; arbitrary contents — write before reading
buf.Size := 48                                         ; reallocate: data kept, Ptr may change

; Pointer-sized slot
slots := Buffer(A_PtrSize * 2, 0)
inner := Buffer(8, 0xAB)
NumPut("Ptr", inner.Ptr, slots, 0)                     ; inner must stay alive while this is used

; Encode / decode
s := "Hello, 世界"
u8 := Buffer(StrPut(s, "UTF-8"))                       ; bytes incl. null
StrPut(s, u8, "UTF-8")
MsgBox(StrGet(u8, "UTF-8"))
w := Buffer(StrPut(s, "UTF-16"))
StrPut(s, w, "UTF-16")
MsgBox(StrGet(w, 5, "UTF-16"))                         ; at most 5 chars → "Hello"

; ✗ NumPut(-1000, buf, 0, "Int")    ; v1 order
; ✗ p := Buffer(16).Ptr             ; Buffer freed at once → p dangles
```

## TIER 2 — Block Operations and Native Allocators
> METHODS COVERED: RtlMoveMemory · RtlFillMemory · RtlZeroMemory · RtlCompareMemory · VirtualAlloc · VirtualProtect · VirtualFree · HeapAlloc · HeapFree

```ahk
#Requires AutoHotkey v2.0
src := Buffer(16, 0x11), dst := Buffer(16, 0)
DllCall("ntdll\RtlMoveMemory", "Ptr", dst, "Ptr", src, "UPtr", src.Size)   ; void
DllCall("ntdll\RtlFillMemory", "Ptr", dst, "UPtr", 8, "UChar", 0xFF)
same := DllCall("ntdll\RtlCompareMemory", "Ptr", src, "Ptr", dst, "UPtr", 16, "UPtr")
MsgBox(same = 16 ? "identical" : "first " same " bytes match")   ; ✓ count, not boolean
DllCall("ntdll\RtlZeroMemory", "Ptr", dst, "UPtr", dst.Size)

addr := DllCall("VirtualAlloc", "Ptr", 0, "UPtr", 4096, "UInt", 0x3000, "UInt", 0x04, "Ptr")
if addr {
    NumPut("UInt", 0xDEADBEEF, addr, 0)
    DllCall("VirtualProtect", "Ptr", addr, "UPtr", 4096, "UInt", 0x02, "UInt*", &oldProt := 0, "Int")
    DllCall("VirtualFree", "Ptr", addr, "UPtr", 0, "UInt", 0x8000, "Int")   ; MEM_RELEASE, size 0
}

hHeap := DllCall("GetProcessHeap", "Ptr")
p := DllCall("HeapAlloc", "Ptr", hHeap, "UInt", 8, "UPtr", 128, "Ptr")       ; HEAP_ZERO_MEMORY
if p {
    NumPut("UInt", 0xCAFEBABE, p, 0)
    DllCall("HeapFree", "Ptr", hHeap, "UInt", 0, "Ptr", p, "Int")
}
; ✗ DllCall("HeapFree", "Ptr", hHeap, "UInt", 0, "Ptr", src.Ptr)   ; never free a Buffer's memory
```

## TIER 3 — Clipboard via Global Memory, Encoding Conversion
> METHODS COVERED: GlobalAlloc · GlobalLock · GlobalUnlock · GlobalFree · OpenClipboard · SetClipboardData · WideCharToMultiByte

```ahk
#Requires AutoHotkey v2.0
; (A_Clipboard := text is the normal way; this shows HGLOBAL ownership rules.)
CopyTextToClipboard(text) {
    bytes := StrPut(text, "UTF-16")
    hMem := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", bytes, "Ptr")    ; MOVEABLE | ZEROINIT
    if !hMem
        throw OSError(A_LastError, -1)
    p := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    StrPut(text, p, bytes // 2, "UTF-16")                ; raw address → give Length (chars)
    DllCall("GlobalUnlock", "Ptr", hMem)
    if !DllCall("OpenClipboard", "Ptr", A_ScriptHwnd, "Int") {
        DllCall("GlobalFree", "Ptr", hMem, "Ptr")         ; still ours → free
        throw Error("OpenClipboard failed", -1)
    }
    DllCall("EmptyClipboard")
    if !DllCall("SetClipboardData", "UInt", 13, "Ptr", hMem, "Ptr")     ; CF_UNICODETEXT
        DllCall("GlobalFree", "Ptr", hMem, "Ptr")         ; not transferred → free
    DllCall("CloseClipboard")                             ; on success the system owns hMem
}

WideToUtf8Buffer(str) {
    n := DllCall("WideCharToMultiByte", "UInt", 65001, "UInt", 0, "Str", str, "Int", -1,
        "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr", 0, "Int")    ; size incl. null
    out := Buffer(n)
    DllCall("WideCharToMultiByte", "UInt", 65001, "UInt", 0, "Str", str, "Int", -1,
        "Ptr", out, "Int", n, "Ptr", 0, "Ptr", 0, "Int")
    return out                                            ; same bytes as StrPut(str, buf, "UTF-8")
}
```

## TIER 4 — Struct Layouts and a Wrapper Class
> METHODS COVERED: GetWindowRect · GetLocalTime · GetWindowPlacement · SetWindowPlacement · class wrapper over Buffer

```ahk
#Requires AutoHotkey v2.0
class WinStruct {
    __New(size) {
        this.buf := Buffer(size, 0)
    }
    Ptr  => this.buf.Ptr            ; lets the object be passed to "Ptr" arguments
    Size => this.buf.Size
    Get(offset, type) => NumGet(this.buf, offset, type)
    Set(offset, type, value) => NumPut(type, value, this.buf, offset)
}

class RECT extends WinStruct {      ; LONG left, top, right, bottom = 16 bytes
    __New() => super.__New(16)
    Left   => this.Get(0, "Int")
    Top    => this.Get(4, "Int")
    Right  => this.Get(8, "Int")
    Bottom => this.Get(12, "Int")
    Width  => this.Right - this.Left
    Height => this.Bottom - this.Top
}

class SYSTEMTIME extends WinStruct { ; 8 × WORD = 16 bytes
    __New() {
        super.__New(16)
        DllCall("GetLocalTime", "Ptr", this)
    }
    Year  => this.Get(0, "UShort")
    Month => this.Get(2, "UShort")
    Day   => this.Get(6, "UShort")  ; offset 4 is DayOfWeek
}

if hwnd := WinExist("A") {
    r := RECT()
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", r, "Int")   ; object's Ptr property is used
    MsgBox(r.Width " x " r.Height)
}
t := SYSTEMTIME()
MsgBox(t.Year "-" t.Month "-" t.Day)

; WINDOWPLACEMENT: UINT length@0, flags@4, showCmd@8, POINT min@12, POINT max@20, RECT normal@28 → 44 bytes
SaveWindowPlacement(hwnd) {
    wp := Buffer(44, 0)
    NumPut("UInt", 44, wp, 0)                             ; length must be set first
    DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", wp, "Int")
    return wp                                             ; keep the whole Buffer
}
RestoreWindowPlacement(hwnd, wp) => DllCall("SetWindowPlacement", "Ptr", hwnd, "Ptr", wp, "Int")
```

### Performance Notes

- Allocate Buffers outside loops and reuse them; `buf.__New(n, 0)` reallocates/refills in place.
- `RtlMoveMemory`/`RtlFillMemory` handle large blocks in native code; per-byte `NumPut` loops are slow.
- Several Type/Number pairs in one `NumPut` call are simpler and faster than chained calls.
- `StrPtr(var)` avoids a copy when an API only reads a long string.

## DROP-IN RECIPES

```ahk
; BufferFromString — encoded bytes without the null terminator
BufferFromString(str, encoding := "UTF-8") {
    size := StrPut(str, encoding)                         ; includes null
    buf := Buffer(size)
    StrPut(str, buf, encoding)
    buf.Size := size - (encoding = "UTF-16" || encoding = "CP1200" ? 2 : 1)
    return buf
}

; HexDump — first n bytes of a Buffer as hex
HexDump(buf, n := 16) {
    out := ""
    Loop Min(n, buf.Size)
        out .= Format("{:02X} ", NumGet(buf, A_Index - 1, "UChar"))
    return RTrim(out)
}
```

## SEE ALSO

> This module does NOT cover: DllCall syntax, type strings, error classes → see Module_DllCallBasics.md
> This module does NOT cover: CallbackCreate, OnMessage, WM_COPYDATA → see Module_CallbacksAndMessages.md
> This module does NOT cover: class design beyond the struct wrapper → see Module_ClassBasics.md

- `Module_DllCallBasics.md` — DllCall types, return values, A_LastError.
- `Module_CallbacksAndMessages.md` — callbacks that read structs from `lParam`.
- `Module_FileIO.md` — reading binary files into Buffers.
- `Module_ClassBasics.md` — property and inheritance patterns used by the struct wrapper.
