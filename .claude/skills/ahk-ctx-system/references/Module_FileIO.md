# Module_FileIO.md
<!-- DOMAIN: File System — reading and writing file content (text and binary) -->
<!-- SCOPE: FileRead, FileAppend, FileOpen and the File object (Read/Write/ReadLine/WriteLine, ReadNum/WriteNum, RawRead/RawWrite, Seek/Pos/Length/AtEOF/Encoding/Handle), text encodings and BOMs, binary I/O with Buffer. Existence checks, copy/move/delete, directories, SplitPath, Loop Files, Loop Read/CSV and INI files are in Module_FilesAndFolders.md. String transformation of file content is in Module_StringFunctions.md. -->
<!-- TRIGGERS: FileRead, FileAppend, FileOpen, File object, ReadLine, WriteLine, RawRead, RawWrite, ReadUInt, WriteUInt, Seek, AtEOF, FileEncoding, A_FileEncoding, UTF-8, UTF-8-RAW, BOM, "read file", "write file", "append to file", "log data repeatedly", "binary file", "stream file", "text encoding", "stdout" -->
<!-- CONSTRAINTS: FileOpen throws OSError on failure — handle with try/catch, not `if !f`. Without an explicit encoding, files that lack a BOM are decoded with A_FileEncoding (CP0 if never set). FileRead without the RAW option decodes bytes as text; use FileRead(path, "RAW") (returns a Buffer) or FileOpen + RawRead for binary data. Creating a file with "UTF-8"/"UTF-16" writes a BOM; use "UTF-8-RAW"/"UTF-16-RAW" to avoid it. File objects close when freed, but the docs recommend closing as soon as possible. -->
<!-- CROSS-REF: Module_FilesAndFolders.md, Module_ExceptionHandling.md, Module_StringFunctions.md, Module_BufferAndMemory.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `FileRead, var, path` (command syntax) | `var := FileRead(path, "UTF-8")` | Syntax error — v2 has no command syntax with output variables |
| `FileAppend, text, path` | `FileAppend(text, path, "UTF-8")` | Syntax error; omitted encoding uses `A_FileEncoding` |
| `FileReadLine, var, path, N` | `Loop Read` with an `A_Index` check, or `FileOpen` + `ReadLine()` | `FileReadLine` does not exist in v2 |
| `if !f` after `FileOpen()` | `try f := FileOpen(...)` / `catch OSError as e` | In v2 `FileOpen` throws `OSError` on failure, so an `if !f` guard never runs |
| `FileRead(path)` on a binary file | `FileRead(path, "RAW")` → Buffer, or `FileOpen` + `RawRead` | Without RAW the bytes are decoded as text and the data changes |

## API QUICK-REFERENCE

### Standalone Read/Write Functions

| Function | Signature | Returns | Throws | Notes |
|----------|-----------|---------|--------|-------|
| `FileRead()` | `FileRead(Filename, Options?)` | String, or Buffer with `RAW` | `OSError`; `MemoryError` for files over 4 GB without `m` | Options (space-separated): an encoding name, `RAW`, `m1024` (load only the first N bytes), `` `n `` (translate `` `r`n `` to `` `n ``) |
| `FileAppend()` | `FileAppend(Text, Filename?, Options?)` | — | `OSError` | Creates the file if needed; the destination directory must already exist. `Text` may be a Buffer-like object (written as-is). Omitting `Filename` inside `Loop Read` writes to the loop's output file. `"*"` = stdout, `"**"` = stderr |

Both resolve relative paths against `A_WorkingDir`.

### FileOpen and the File Object

| Member | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `FileOpen()` | `FileOpen(Filename, Flags, Encoding?)` | File object | Throws `OSError` if the file cannot be opened. Flags: `r` read (fails if missing), `w` write (creates/overwrites), `a` append (creates if missing), `rw` read/write (creates if missing); `h` wraps a handle. Sharing: `-rwd` locks read/write/delete (`-` alone = `-rwd`); default shares all. EOL: `` `n `` translates `` `r`n ``↔`` `n ``, `` `r `` translates lone `` `r `` when reading |
| `.Read()` | `.Read(Characters?)` | String | Omit to read the rest of the file |
| `.Write()` | `.Write(String)` | Bytes written | |
| `.ReadLine()` | `.ReadLine()` | String without the line ending | Always accepts `` `n ``, `` `r`n `` and `` `r ``; lines up to 65,534 chars |
| `.WriteLine()` | `.WriteLine(String?)` | Bytes written | Appends `` `n `` or `` `r`n `` depending on the EOL flags |
| `.ReadNumType()` | e.g. `.ReadUInt()`, `.ReadInt64()`, `.ReadDouble()` | Number, or `""` on failure | NumType: UInt, Int, Int64, Short, UShort, Char, UChar, Double, Float |
| `.WriteNumType()` | e.g. `.WriteUInt(n)` | Bytes written | `.WriteUInt(42)` returns 4 |
| `.RawRead()` | `.RawRead(Buffer, Bytes?)` | Bytes read | `Bytes` defaults to the Buffer size; required for a raw address; throws if larger than the buffer |
| `.RawWrite()` | `.RawWrite(Data, Bytes?)` | Bytes written | `Data` = Buffer-like object, string, or address (address needs `Bytes`) |
| `.Seek()` | `.Seek(Distance, Origin?)` | 1 on success, 0 on failure | Origin 0 = start, 1 = current, 2 = end; default is 2 when `Distance` < 0, else 0 |
| `.Close()` | `.Close()` | — | Flushes and releases share locks; the file also closes when the object is freed |
| `.Pos` | read/write | Integer | Byte offset; assigning is the same as `.Seek(n)` |
| `.Length` | read/write | Integer | File size in bytes; assigning resizes the file |
| `.AtEOF` | read-only | Non-zero at end of file | Not meaningful for pipes/console handles |
| `.Encoding` | read/write | `"UTF-8"`, `"UTF-16"` or `"CPnnn"` | Changing it never adds or removes a BOM |
| `.Handle` | read-only | Win32 handle | Flushes pending writes / discards the read buffer first; for DllCall |

### Encoding Rules

| Situation | What happens (official behavior) |
|-----------|----------------------------------|
| Encoding omitted on `FileRead`/`FileAppend`/`FileOpen` | Uses `A_FileEncoding` (set by `FileEncoding`); CP0 (system ANSI code page) if never set |
| File has a UTF-8 or UTF-16 BOM and is opened for reading | The BOM decides; the Encoding argument is ignored (except write-only opens) |
| New file created with `"UTF-8"` or `"UTF-16"` | A BOM is written. Use `"UTF-8-RAW"` / `"UTF-16-RAW"` for no BOM |
| `FileAppend` with a Buffer as `Text` | Data written as-is; a BOM only if `UTF-8`/`UTF-16` is in Options and the file is new |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- `FileOpen()` throws `OSError` when the file cannot be opened — put every `FileOpen()` inside `try` (with `catch OSError` where recovery is needed); `e.Number` holds the Win32 error code. The `if !f` wrong form is in V1 → V2 BREAKING CHANGES.
- Text without a BOM is decoded with `A_FileEncoding` (CP0 if unset). Passing an explicit encoding such as `"UTF-8"` on every text read/write is a **repo convention, not a language limit**; relying on a project-wide `FileEncoding` setting is also valid.
- `FileRead` without `RAW` treats bytes as text. For binary data use `FileRead(path, "RAW")` (returns a Buffer) or `FileOpen` + `RawRead`/`ReadNum`. `RAW` is a FileRead/FileAppend option, not a `FileOpen` encoding: `FileOpen(path, "w", "RAW")` throws `ValueError`. The text-read wrong form is in V1 → V2 BREAKING CHANGES.
- For binary writes to a **new** file, do not pass `"UTF-8"` or `"UTF-16"` to `FileOpen` — a BOM would be written first. Omit the encoding (if `A_FileEncoding` is not UTF-8/16) or pass `"UTF-8-RAW"`. Encoding does not affect `RawRead`/`RawWrite`/`ReadNum`/`WriteNum`.
  ✗ `FileOpen(p, "w", "UTF-8")` then `RawWrite` → ✓ omit the encoding or use `"UTF-8-RAW"`
- Each `FileAppend` call opens and closes the file. For many writes, open one `FileOpen(path, "a", ...)` handle and close it in `finally` (the docs describe `FileOpen` in append mode as keeping the file open instead of reopening it each time).
  ✗ `Loop { FileAppend(t, p) }` → ✓ one `FileOpen(p, "a", enc)`, `WriteLine` in the loop, `Close()` in `finally`
- `FileRead` loads the whole file (and throws `MemoryError` above 4 GB unless `m` is used). Check `FileGetSize()` first, or stream with `Loop Read` / `FileOpen`, when the size is unknown.
  ✗ `FileRead(hugeLog)` → ✓ size check, `m` option, or streaming
- Close owned File objects with `.Close()` in `finally`; objects close when freed, but the docs recommend closing as soon as possible.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `OSError` | `FileOpen`, `FileRead` or `FileAppend` on a missing, locked or access-denied file; `FileAppend` into a missing directory | `e.Number` = Win32 error code; `e.Message` includes the OS description | `try`/`catch OSError`; create the directory first; retry briefly for transient locks |
| `MemoryError` | `FileRead` of a file over 4 GB without `m`, or not enough memory | `e is MemoryError` | Use `m<bytes>`, `Loop Read`, or `FileOpen` + chunked reads |
| `Error` | `RawRead` with `Bytes` larger than the Buffer | `e.Message` | Size the Buffer first or omit `Bytes` |

## TIER 1 — Simple Text Read and Append
> METHODS COVERED: FileExist · FileRead · FileAppend

```ahk
#Requires AutoHotkey v2.0
cfgPath := A_ScriptDir "\config.txt"

if FileExist(cfgPath) {                       ; ✓ FileExist returns "" when absent — usable as a boolean
    content := FileRead(cfgPath, "UTF-8")      ; ✓ explicit encoding for files without a BOM
} else {
    FileAppend("Setting=1`n", cfgPath, "UTF-8") ; ✓ creates the file; a new UTF-8 file gets a BOM
    content := "Setting=1`n"
}

; ✗ content := FileRead(cfgPath)   ; uses A_FileEncoding (CP0 if unset) for non-BOM files
; ✗ FileRead, content, %cfgPath%   ; v1 command syntax — syntax error in v2
```

## TIER 2 — FileOpen Lifecycle for Repeated Writes
> METHODS COVERED: FileOpen · File.WriteLine · File.Close · try/finally

```ahk
#Requires AutoHotkey v2.0
logPath := A_ScriptDir "\bulk_log.txt"
f := ""
try {
    f := FileOpen(logPath, "a", "UTF-8")      ; ✓ throws OSError on failure
    Loop 1000
        f.WriteLine("Log entry " A_Index)
} catch OSError as err {
    MsgBox("Write failed (" err.Number "): " err.Message)
} finally {
    if f
        f.Close()                             ; ✓ runs on success and on error
}

; ✗ Loop 1000
;       FileAppend("entry`n", logPath, "UTF-8")   ; opens and closes the file 1000 times
```

A wrapper class can add `__Delete` as a fallback, but explicit `Close()` stays the primary release point:

```ahk
class SafeFileWriter {
    __New(path, mode := "a", encoding := "UTF-8") {
        this.f := FileOpen(path, mode, encoding)   ; OSError propagates to the caller
    }
    WriteLine(text) => this.f.WriteLine(text)
    Close() {
        if this.f {
            this.f.Close()
            this.f := ""
        }
    }
    __Delete() => this.Close()                    ; fallback only
}
```

## TIER 3 — Binary I/O: Numbers, Chunked Copy, File Pointer
> METHODS COVERED: FileOpen · File.WriteUInt · File.ReadUInt · File.Pos · File.AtEOF · File.RawRead · File.RawWrite · FileRead RAW · Buffer

```ahk
#Requires AutoHotkey v2.0
src := ""
dst := ""
try {
    src := FileOpen(A_ScriptDir "\data.bin", "rw")   ; ✓ no UTF-8/UTF-16 → no BOM on a new file
    src.WriteUInt(0x1A2B3C4D)                        ; writes 4 bytes
    src.Pos := 0                                     ; same as src.Seek(0)
    value := src.ReadUInt()

    dst := FileOpen(A_ScriptDir "\copy.bin", "w")
    chunk := Buffer(4096)                            ; FillByte omitted — contents arbitrary until read into
    src.Pos := 0
    while !src.AtEOF {
        n := src.RawRead(chunk)                      ; returns bytes actually read
        dst.RawWrite(chunk, n)                       ; ✓ pass n — the last chunk may be short
    }
} finally {
    if dst
        dst.Close()
    if src
        src.Close()
}

; ✓ Whole-file binary read: returns a Buffer, no text decoding
buf := FileRead(A_ScriptDir "\data.bin", "RAW")
MsgBox(buf.Size " bytes")

; ✗ FileOpen(path, "w", "UTF-8") for binary output — a BOM is written before your data
; ✗ FileRead(path) on binary data — bytes are decoded as text
```

### Performance Notes

- `FileRead` performs much better than a file-reading loop when the goal is to load all or most of a file (official remark); check `FileGetSize` first if memory is a concern.
- One open File object for many writes avoids an open/close per call.
- Stream binary data in fixed-size Buffer chunks (`RawRead`/`RawWrite`) to keep memory bounded.
- The `` `n `` option of `FileRead` reduces performance and is usually unnecessary; `Loop Parse, text, "`n", "`r"` handles both line endings.

## DROP-IN RECIPES

```ahk
; SafeReadText — size-guarded text read with a typed error
SafeReadText(path, encoding := "UTF-8", maxMB := 50) {
    if !FileExist(path)
        throw Error("SafeReadText: file not found — " path, -1)
    sizeMB := FileGetSize(path, "M")
    if sizeMB > maxMB
        throw Error("SafeReadText: " sizeMB " MB exceeds " maxMB " MB — " path, -1)
    return FileRead(path, encoding)               ; OSError propagates with e.Number
}

; AppendLines — one handle for many lines, one retry on a transient lock
AppendLines(path, lines, encoding := "UTF-8") {
    if !(lines is Array)
        throw TypeError("AppendLines: lines must be an Array", -1)
    Loop 2 {
        f := ""
        try {
            f := FileOpen(path, "a", encoding)
            for line in lines
                f.WriteLine(line)
            return
        } catch OSError as e {
            if A_Index = 2
                throw
            Sleep(200)
        } finally {
            if f
                f.Close()
        }
    }
}
; Call site: AppendLines(A_ScriptDir "\events.log", [FormatTime(, "yyyy-MM-dd HH:mm:ss") " startup"])
```

## SEE ALSO

> This module does NOT cover: FileExist/DirExist, copy/move/delete, directories, SplitPath, Loop Files, Loop Read/CSV, INI files → see Module_FilesAndFolders.md
> This module does NOT cover: StrReplace, RegExReplace, Format and other text transformation → see Module_StringFunctions.md
> This module does NOT cover: try/catch/finally patterns and OSError structure in depth → see Module_ExceptionHandling.md

- `Module_FilesAndFolders.md` — existence checks, file and directory mutation, path parsing, file and line loops, INI configuration.
- `Module_BufferAndMemory.md` — Buffer, NumGet/NumPut and StrGet/StrPut for parsing binary data read with `RAW`/`RawRead`.
- `Module_ExceptionHandling.md` — OSError structure and error propagation for I/O failures.
- `Module_StringFunctions.md` — string transformation of content read with FileRead or Loop Read.
