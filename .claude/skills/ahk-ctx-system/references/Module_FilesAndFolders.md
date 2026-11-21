# Module_FilesAndFolders.md
<!-- DOMAIN: File System — files, folders, paths, file/line loops, INI configuration -->
<!-- SCOPE: FileExist, DirExist, FileGetSize, FileCopy, FileMove, FileDelete, FileRecycle, DirCreate, DirDelete, DirCopy, DirMove, SplitPath, A_WorkingDir, Loop Files, Loop Read, Loop Parse CSV, IniRead, IniWrite, IniDelete. Reading/writing file content, encodings and binary I/O are in Module_FileIO.md. File attributes/timestamps (FileGetAttrib, FileSetTime) and shortcuts are not covered. -->
<!-- TRIGGERS: FileExist, DirExist, FileGetSize, FileCopy, FileMove, FileDelete, FileRecycle, DirCreate, DirDelete, DirCopy, DirMove, SplitPath, Loop Files, A_LoopFilePath, A_LoopFileFullPath, Loop Read, A_LoopReadLine, Loop Parse CSV, IniRead, IniWrite, IniDelete, A_WorkingDir, "check if file exists", "get file extension", "create folder", "copy file", "delete file", "directory traversal", "parse csv", "ini config" -->
<!-- CONSTRAINTS: FileExist/DirExist return an attribute string or "" — the result can be used directly as a boolean. FileCopy/FileMove/FileDelete throw Error with Extra = number of failures; a wildcard pattern that matches nothing is success. FileCopy/FileMove need an existing destination directory. Relative paths resolve against A_WorkingDir, which defaults to A_ScriptDir (A_InitialWorkingDir holds the launcher's folder) and changes script-wide with SetWorkingDir. IniRead throws OSError only when Default is omitted. -->
<!-- CROSS-REF: Module_FileIO.md, Module_ExceptionHandling.md, Module_ArrayAlgorithms.md, Module_ArrayBasics.md, Module_StringFunctions.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `IfExist, path` / `IfNotExist` | `if FileExist(path)` / `if !FileExist(path)` | The `IfExist` commands do not exist in v2 |
| `FileCopy, src, dst, 1` (command syntax) | `FileCopy(src, dst, 1)` | Command syntax with commas is a syntax error |
| `SplitPath, path, name, dir` (plain output vars) | `SplitPath(path, &name, &dir)` | Output parameters need `&` (VarRef) |
| `Loop, %pattern%` / `Loop, Files` with v1 options | `Loop Files pattern, "R"` | v2 uses `Loop Files` with a Mode string (`D`, `F`, `R`) |
| `IniRead, var, file, sec, key, default` | `var := IniRead(file, sec, key, default)` | Function form returns the value |

## API QUICK-REFERENCE

### Existence and Size

| Function | Signature | Returns | Throws | Notes |
|----------|-----------|---------|--------|-------|
| `FileExist()` | `FileExist(FilePattern)` | Attribute string (subset of `RASHNDOCTL`, `"X"` if no attributes) or `""` | — | Matches files **and** folders; supports wildcards. The docs state it can be used as a quasi-boolean: `if FileExist(path)` |
| `DirExist()` | `DirExist(FilePattern)` | Attribute string or `""` | — | Folders only; `DirExist("MyFolder\*")` tests for a subfolder |
| `FileGetSize()` | `FileGetSize(Filename?, Units?)` | Integer (rounded down) | `OSError` | Units `B` (default), `K`, `M`; omit `Filename` inside `Loop Files` to use the current file |

### File Mutation Functions

| Function | Signature | Throws | Notes |
|----------|-----------|--------|-------|
| `FileCopy()` | `FileCopy(SourcePattern, DestPattern, Overwrite := 0)` | `Error` (`Extra` = failure count) | Destination directory must exist. No match throws only when the source has no `*`/`?`. Copying a file onto itself is always an error |
| `FileMove()` | `FileMove(SourcePattern, DestPattern, Overwrite := 0)` | `Error` (`Extra` = failure count) | Same rules as FileCopy; moving a file onto itself is always a success |
| `FileDelete()` | `FileDelete(FilePattern)` | `Error` (`Extra` = failure count) | A wildcard that matches nothing is success |
| `FileRecycle()` | `FileRecycle(FilePattern)` | exception (type not stated) | Sends to the Recycle Bin |

Overwrite: `0` = fail if the destination exists, `1` = overwrite. These functions continue after individual failures.

### Directory Functions

| Function | Signature | Throws | Notes |
|----------|-----------|--------|-------|
| `DirCreate()` | `DirCreate(DirName)` | `OSError` | Also creates missing parent directories |
| `DirDelete()` | `DirDelete(DirName, Recurse := false)` | exception | Without `Recurse`, a non-empty folder throws |
| `DirCopy()` | `DirCopy(Source, Dest, Overwrite := 0)` | exception | Creates the destination structure if possible |
| `DirMove()` | `DirMove(Source, Dest, OverwriteOrRename := 0)` | exception | `0` no overwrite, `1` overwrite (same-volume existing folder: Source moves *into* it), `2` overwrite without that limitation, `"R"` rename (all-or-none, same volume only) |

### Path Functions and Variables

| Item | Signature | Notes |
|------|-----------|-------|
| `SplitPath()` | `SplitPath(Path, &OutFileName?, &OutDir?, &OutExtension?, &OutNameNoExt?, &OutDrive?)` | All outputs optional VarRefs; handles UNC paths and URLs |
| `A_WorkingDir` | read/write | Where relative paths resolve; defaults to `A_ScriptDir`, no trailing backslash except for a root |
| `A_InitialWorkingDir` | read-only | Working directory set by the launching process (for example a shortcut's "Start in"); not what `A_WorkingDir` starts as |
| `SetWorkingDir()` | `SetWorkingDir(DirName)` | Throws `OSError` on failure |

### Loop Constructs and Loop Variables

| Construct / Variable | Description |
|----------------------|-------------|
| `Loop Files FilePattern, Mode?` | Mode letters: `F` files, `D` folders, `R` recurse. Blank/omitted = files only, no recursion |
| `A_LoopFileName` | Name and extension, no path |
| `A_LoopFilePath` | Path and name; **relative** if `FilePattern` was relative |
| `A_LoopFileFullPath` | Always absolute, long-name path |
| `A_LoopFileDir` | Folder of the file (relative if the pattern was relative) |
| `A_LoopFileSize` | Size in bytes |
| `Loop Read InputFile, OutputFile?` | One iteration per line; inside the loop `FileAppend` without a filename writes to `OutputFile` (`"*"` = stdout). Without an `Else` branch, a missing input file throws `OSError` |
| `A_LoopReadLine` | Current line without its line ending |
| `Loop Parse String, Delimiters?, OmitChars?` | `"CSV"` as Delimiters parses one comma-separated line (quoted fields allowed) |
| `A_LoopField` | Current field of `Loop Parse` |

### INI Functions

| Function | Signature | Returns / Throws | Notes |
|----------|-----------|------------------|-------|
| `IniRead()` | `IniRead(Filename, Section?, Key?, Default?)` | Value; `OSError` only if `Default` is omitted | Omit `Key` → whole section; omit `Section` and `Key` → `` `n ``-delimited section names. Leading/trailing spaces are stripped unless quoted |
| `IniWrite()` | `IniWrite(Value, Filename, Section, Key)` or `IniWrite(Pairs, Filename, Section)` | `OSError` | New files are created with a UTF-16 BOM |
| `IniDelete()` | `IniDelete(Filename, Section, Key?)` | `OSError` | Omit `Key` to delete the whole section |

IniRead/IniWrite use the Windows profile APIs, which support Unicode only in UTF-16 files; other files are treated as the system ANSI code page.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- `FileExist()`/`DirExist()` return `""` when nothing matches and a non-empty attribute string otherwise, so `if FileExist(path)` is correct. To require a file (not a folder), test the attributes: `(attr := FileExist(p)) && !InStr(attr, "D")`.
  ✗ `if FileExist(p)` when only files are valid → ✓ `IsFile(p)` / check that `"D"` is absent
- `FileExist` accepts wildcards, so it is not a filename validator: `FileExist("*.txt")` can be true although `*.txt` is not a valid file name.
- `FileCopy`, `FileMove` and `FileDelete` throw `Error` (not `OSError`) with `Extra` = number of failed files. Wrap destructive calls in `try` when the caller needs a recovery path, and pass `Overwrite` explicitly when it matters.
- `FileCopy`/`FileMove` do not create the destination directory — call `DirCreate()` first (it creates parents too).
  ✗ `FileCopy(a, "C:\new\a.txt")` → ✓ `DirCreate("C:\new")` first
- Relative paths resolve against `A_WorkingDir`, which defaults to `A_ScriptDir` regardless of how the script was launched (`A_InitialWorkingDir` is the launcher's folder). Any `SetWorkingDir` or `A_WorkingDir` assignment changes it for every thread, so building paths from `A_ScriptDir` is the safer habit (convention).
  ✗ `FileRead("cfg.txt")` after `SetWorkingDir` elsewhere (or a library that changes it) → ✓ `FileRead(A_ScriptDir "\cfg.txt")`
- Always pass a `Default` to `IniRead` when a missing key is a normal case; without it, a missing key/section/file throws `OSError`.
  ✗ `IniRead(f, s, k)` → ✓ `IniRead(f, s, k, "")`
- Use `SplitPath` for path decomposition; preferring it over `StrSplit`/RegEx for every case is a **repo convention, not a language limit**.
  ✗ `StrSplit(path, "\")` → ✓ `SplitPath(path, &name, &dir)`
- `Loop Parse ..., "CSV"` works on one line; records with embedded newlines need a different parser.

## RUNTIME ERROR MAPPING

| Exception Class | Trigger Condition | Detection | Fix |
|----------------|-------------------|-----------|-----|
| `Error` | `FileCopy`/`FileMove`/`FileDelete` failed for one or more files; non-wildcard source missing; destination exists with `Overwrite = 0` | `e.Extra` = number of failures; `A_LastError` = last OS error | Pass `Overwrite`, create the destination folder, check `FileExist` first |
| `OSError` | `DirCreate`, `FileGetSize`, `SetWorkingDir` failure; `IniRead` without `Default` on a missing key | `e.Number` = Win32 error code | Supply `Default`; check `DirExist`; wrap in `try` |
| `OSError` | `Loop Read` on a missing file without an `Else` branch | `e.Number` | Add `else` after the loop or check `FileExist` first |

## TIER 1 — Existence Checks, Copy, Move, Delete
> METHODS COVERED: FileExist · DirExist · DirCreate · FileCopy · FileMove · FileDelete · FileRecycle

```ahk
#Requires AutoHotkey v2.0
src     := A_ScriptDir "\data.txt"
backup  := A_ScriptDir "\backup"

try {
    if !DirExist(backup)
        DirCreate(backup)                       ; ✓ destination folder must exist for FileCopy
    FileCopy(src, backup "\data.txt", 1)        ; ✓ explicit overwrite
    if FileExist(src)                           ; ✓ "" when absent — usable as a boolean
        FileDelete(src)
} catch Error as err {
    MsgBox("Failed (" err.Extra " file(s)): " err.Message)   ; Extra = failure count
}

; FileRecycle(src)   ; sends to the Recycle Bin instead of deleting permanently

; ✗ FileCopy(src, backup "\data.txt")   ; Overwrite defaults to 0 → Error if the destination exists
; ✗ FileCopy(src, A_ScriptDir "\missing\data.txt", 1)   ; destination directory must already exist
```

## TIER 2 — Path Parsing and Directory Traversal
> METHODS COVERED: SplitPath · Loop Files · A_LoopFileFullPath · A_LoopFileSize · FileGetSize

```ahk
#Requires AutoHotkey v2.0
SplitPath(A_ScriptDir "\images\photo.jpg", &name, &dir, &ext, &nameNoExt, &drive)
; name = "photo.jpg", ext = "jpg", nameNoExt = "photo"

files := []
total := 0
Loop Files, A_ScriptDir "\images\*.jpg", "R"   ; ✓ R recurses; files only by default
{
    files.Push(A_LoopFileFullPath)              ; ✓ absolute even if the pattern were relative
    total += A_LoopFileSize                     ; ✓ no FileGetSize call needed
}
MsgBox(files.Length " files, " total " bytes")

; ✗ Loop Files, A_ScriptDir "\images\*.jpg"    ; no R → top folder only
; ✗ SplitPath(path, name, dir)                 ; outputs need & in v2
```

## TIER 3 — Line Loops and CSV
> METHODS COVERED: Loop Read · A_LoopReadLine · Loop Parse CSV · A_LoopField · FileRead · StrSplit

```ahk
#Requires AutoHotkey v2.0
rows := []
Loop Read, A_ScriptDir "\data.csv"
{
    fields := []
    Loop Parse, A_LoopReadLine, "CSV"           ; ✓ handles "Smith, John" inside quotes
        fields.Push(A_LoopField)
    rows.Push(fields)
}

; In-memory filter of a size-checked file
logPath := A_ScriptDir "\log.txt"
if FileGetSize(logPath, "M") > 100
    throw Error("Log too large for in-memory filter")
errors := []
for line in StrSplit(FileRead(logPath, "UTF-8"), "`n", "`r")   ; ✓ omit `r → CRLF and LF both work
    if InStr(line, "ERROR")
        errors.Push(line)

; ✗ Loop Parse, logPath, "CSV"            ; parses the path string, not the file
; ✗ Loop Parse, A_LoopReadLine, ","       ; splits inside quoted fields
```

## TIER 4 — INI Configuration
> METHODS COVERED: IniWrite · IniRead · IniDelete

```ahk
#Requires AutoHotkey v2.0
ini := A_ScriptDir "\settings.ini"

IniWrite("Dark", ini, "UI", "Theme")          ; creates file/section/key; a new file gets a UTF-16 BOM
theme    := IniRead(ini, "UI", "Theme", "Light")   ; ✓ Default → no throw when missing
sections := IniRead(ini)                       ; `n-delimited section names (throws if none and no Default)
IniDelete(ini, "TempSection")                  ; omit Key → delete the whole section

; ✗ val := IniRead(ini, "UI", "MissingKey")    ; no Default → OSError when the key is missing
```

### Performance Notes

- `Loop Files` provides `A_LoopFileSize` and other properties without extra calls per file.
- `FileMove` is preferred over `FileCopy` + `FileDelete` for renames; `DirMove(..., "R")` gives all-or-none folder renames on one volume.
- Read INI values once and cache them if they are used in hot paths.

## DROP-IN RECIPES

```ahk
; EnsureDir — create a folder (and parents) only if missing
EnsureDir(path) {
    if !DirExist(path)
        DirCreate(path)                          ; OSError on failure
    return path
}

; IsFile — true only for an existing file, not a folder
IsFile(path) => (attr := FileExist(path)) != "" && !InStr(attr, "D")

; CopyTree — copy a folder's contents into an existing or new folder
CopyTree(src, dest, overwrite := 1) {
    EnsureDir(dest)
    DirCopy(src, dest, overwrite)                ; throws on error
}
```

## SEE ALSO

> This module does NOT cover: FileRead/FileAppend/FileOpen, encodings, binary I/O → see Module_FileIO.md
> This module does NOT cover: storing parsed rows in Arrays/Maps and sorting them → see Module_ArrayAlgorithms.md
> This module does NOT cover: try/catch patterns in depth → see Module_ExceptionHandling.md

- `Module_FileIO.md` — reading and writing file content, encodings and BOMs, File object lifecycle, binary I/O.
- `Module_ArrayBasics.md` — storing parsed CSV rows and filtered lines in Arrays.
- `Module_StringFunctions.md` — string transformation of file content.
- `Module_ExceptionHandling.md` — Error/OSError handling for file system operations.
