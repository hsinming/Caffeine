# ahk-ctx-system Section Index

Per-heading detail for the routing table in `SKILL.md`. Find the row for the task, `grep -n "^## heading text"` the Reference module, and read that section through the next heading of the same level.

`## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` cover most routine tasks. Load a TIER section only when a complete, runnable example is needed.

### DLL Calls (Module_DllCallBasics.md)

| Task | Grep for heading |
|------|-----------------|
| DllCall syntax, default return type, `A_LastError`, `A_PtrSize` | `### DllCall` |
| `Str`/`WStr`/`AStr`, `Ptr`/`UPtr`, `Type*` + `&var`, `HRESULT` | `### Type Strings (official)` |
| Win32 typedef → DllCall type | `### Win32 Typedef → DllCall Type (common mapping)` |
| Which error DllCall throws | `### Errors Thrown by DllCall (official list)` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — simple calls, output values, error codes | `## TIER 1 — Simple Calls, Output Values, Error Codes` |
| **Example** — FormatMessageW, `OSError(code)`, GetSystemInfo | `## TIER 2 — Error Text and System Information` |
| **Example** — named mutex, handle cleanup | `## TIER 3 — Kernel Handles and a Named Mutex` |
| Performance (preloaded DLLs, GetProcAddress) | `### Performance Notes` |

### Buffers and Memory (Module_BufferAndMemory.md)

| Task | Grep for heading |
|------|-----------------|
| `Buffer()`, `.Ptr`, `.Size`, FillByte | `### Buffer Object` |
| `NumPut` / `NumGet` | `### Numeric Memory I/O` |
| `StrPut` / `StrGet` / `StrPtr` | `### String Memory I/O` |
| ntdll block ops, Virtual*/Heap*/Global*, code-page conversion | `### Win32 Memory and Conversion APIs (outside AHK docs)` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — Buffer, NumPut/NumGet, StrPut/StrGet | `## TIER 1 — Buffer, NumPut/NumGet, StrPut/StrGet` |
| **Example** — block operations, native allocators | `## TIER 2 — Block Operations and Native Allocators` |
| **Example** — clipboard HGLOBAL, WideCharToMultiByte | `## TIER 3 — Clipboard via Global Memory, Encoding Conversion` |
| **Example** — RECT/SYSTEMTIME/WINDOWPLACEMENT, struct class | `## TIER 4 — Struct Layouts and a Wrapper Class` |

### Callbacks and Messages (Module_CallbacksAndMessages.md)

| Task | Grep for heading |
|------|-----------------|
| `CallbackCreate`/`CallbackFree`, Fast, ParamCount | `### Callbacks` |
| `OnMessage`, `SendMessage`, `PostMessage` | `### Window Messages` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — EnumWindows/EnumChildWindows | `## TIER 1 — Enumeration Callbacks` |
| **Example** — low-level keyboard hook | `## TIER 2 — Low-Level Keyboard Hook in a Class` |
| **Example** — OnMessage, WM_COPYDATA IPC | `## TIER 3 — OnMessage, SendMessage, PostMessage, WM_COPYDATA` |

### File I/O (Module_FileIO.md)

| Task | Grep for heading |
|------|-----------------|
| `FileRead` / `FileAppend` options | `### Standalone Read/Write Functions` |
| `FileOpen` flags and File object members | `### FileOpen and the File Object` |
| A_FileEncoding, BOMs, `-RAW` encodings | `### Encoding Rules` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — simple text read/append | `## TIER 1 — Simple Text Read and Append` |
| **Example** — one handle for repeated writes | `## TIER 2 — FileOpen Lifecycle for Repeated Writes` |
| **Example** — binary I/O | `## TIER 3 — Binary I/O: Numbers, Chunked Copy, File Pointer` |

### Files and Folders (Module_FilesAndFolders.md)

| Task | Grep for heading |
|------|-----------------|
| `FileExist`, `DirExist`, `FileGetSize` | `### Existence and Size` |
| `FileCopy`/`FileMove`/`FileDelete`/`FileRecycle` | `### File Mutation Functions` |
| `DirCreate`/`DirDelete`/`DirCopy`/`DirMove` | `### Directory Functions` |
| `SplitPath`, `A_WorkingDir`, `A_InitialWorkingDir` | `### Path Functions and Variables` |
| `Loop Files`, `Loop Read`, `Loop Parse` CSV | `### Loop Constructs and Loop Variables` |
| `IniRead`/`IniWrite`/`IniDelete` | `### INI Functions` |
| **Example** — copy/move/delete | `## TIER 1 — Existence Checks, Copy, Move, Delete` |
| **Example** — path parsing, traversal | `## TIER 2 — Path Parsing and Directory Traversal` |
| **Example** — line loops, CSV | `## TIER 3 — Line Loops and CSV` |
| **Example** — INI | `## TIER 4 — INI Configuration` |

### HTTP Requests (Module_HttpRequests.md)

| Task | Grep for heading |
|------|-----------------|
| `Download()` | `### Download (built-in)` |
| WinHttp members (Open, Send, Status, ResponseBody, SetCredentials…) | `### WinHttp.WinHttpRequest.5.1 — Core Members` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — download | `## TIER 1 — Basic File Download` |
| **Example** — GET, query strings | `## TIER 2 — GET Request (blocking and responsive forms)` |
| **Example** — POST, headers, Basic/Bearer auth | `## TIER 3 — POST, Headers and Authentication` |
| `HttpFetch`, `SafeDownload` | `## DROP-IN RECIPES` |

### Async HTTP (Module_HttpAsync.md)

| Task | Grep for heading |
|------|-----------------|
| Which wait mode to use | `### Waiting Modes` |
| `HttpPromise` API | `### HttpPromise Class (defined in TIER 3)` |
| Constraints, QA checks and anti-patterns (blocking Open, readyState, reference cycles) | `## AHK V2 CONSTRAINTS` |
| **Example** — responsive single request | `## TIER 1 — Responsive Single Request` |
| **Example** — SetTimer polling, periodic poller | `## TIER 2 — Non-Blocking Poll and Periodic Poller` |
| **Example** — concurrent requests | `## TIER 3 — HttpPromise: Concurrent Requests` |

### JSON and REST Clients (Module_JsonAndRestClients.md)

| Task | Grep for heading |
|------|-----------------|
| Choosing a JSON approach | `### JSON Approaches` |
| JSON library adapter functions | `### Library Contract Assumed by TIER 2` |
| Constraints, QA checks and anti-patterns | `## AHK V2 CONSTRAINTS` |
| **Example** — flat JSON without a library | `## TIER 1 — JSON Without a Library (flat data only)` |
| **Example** — RestClient with retries | `## TIER 2 — REST Client Class with Retries` |

### Script Setup (Module_ScriptSetup.md)

| Task | Grep for heading |
|------|-----------------|
| `#Requires`, `#SingleInstance`, `#Include`, `#NoTrayIcon` | `### Directives (load-time, never conditional)` |
| Lib folder search order | `### Library Folders for \`#Include <LibName>\` (searched in order)` |
| `A_ScriptDir`, `A_ScriptName`, `A_IsCompiled`, `A_Args`… | `### Script Properties (A_* variables)` |
| `;@Ahk2Exe-` directives | `### Ahk2Exe Compiler Directives (comments read by the compiler)` |
| **Example** — header and environment info | `## TIER 1 — Standard Script Header and Environment Info` |
| **Example** — #Include and libraries | `## TIER 2 — #Include and the Library System` |
| **Example** — compiler directives | `## TIER 3 — Ahk2Exe Compiler Directives` |

### Script Lifecycle (Module_ScriptLifecycle.md)

| Task | Grep for heading |
|------|-----------------|
| `A_TrayMenu`, `TraySetIcon`, `A_IconTip` | `### Tray Icon and Menu` |
| `A_IsAdmin`, `*RunAs`, `/restart` | `### Elevation and Process` |
| `OnExit`, `ExitApp`, `Reload`, `Persistent` | `### Lifecycle Functions` |
| ExitReason values | `### Exit Reasons passed to OnExit callbacks` |
| **Example** — tray menu | `## TIER 1 — Tray Menu Customization` |
| **Example** — elevation | `## TIER 2 — Admin Elevation (documented pattern)` |
| **Example** — OnExit | `## TIER 3 — Exit Handling with OnExit` |

### Processes and System (Module_ProcessAndSystem.md)

| Task | Grep for heading |
|------|-----------------|
| `A_Clipboard`, `ClipWait`, `ClipboardAll` | `### Clipboard` |
| `Run`/`RunWait`, `Process*` functions | `### Process and Execution` |
| `WinWait`/`WinWaitActive`/`WinWaitClose`/`WinActivate` | `### Window Waits (system-level)` |
| `RegRead`/`RegWrite`/`RegDelete`/`RegDeleteKey` | `### Registry` |
| `EnvGet`/`EnvSet` | `### Environment Variables` |
| **Example** — clipboard and launch | `## TIER 1 — Clipboard and Application Launch` |
| **Example** — exit codes, registry, environment | `## TIER 2 — Exit Codes, Registry, Environment` |
| **Example** — process/window state | `## TIER 3 — Process and Window State` |

### COM Automation (Module_COMAutomation.md)

| Task | Grep for heading |
|------|-----------------|
| `ComObject`, `ComObjActive`, `ComObjGet`, `ComObjArray`, `ComValue` | `### COM Functions` |
| Event handler signature | `### Event Handler Shape (ComObjConnect)` |
| Constraints, QA checks and anti-patterns (owned vs attached teardown) | `## AHK V2 CONSTRAINTS` |
| **Example** — WMI | `## TIER 1 — WMI Query into a Map` |
| **Example** — owned vs attached Excel | `## TIER 2 — Owned vs Attached Excel Sessions` |
| **Example** — bulk SafeArray write | `## TIER 3 — Bulk Write with ComObjArray` |
| **Example** — COM events | `## TIER 4 — COM Event Sink and Owner Class` |
