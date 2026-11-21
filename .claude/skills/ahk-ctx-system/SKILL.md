---
name: ahk-ctx-system
description: >
  AutoHotkey v2 system interaction. Use when writing, modifying, or reviewing .ahk code that
  involves DllCall and Win32 memory (Buffer, callbacks), file I/O, HTTP and JSON, COM automation,
  registry, clipboard, processes and environment variables, or script setup and lifecycle (tray,
  elevation, OnExit).
metadata:
  version: "2026.10.16"
---

# AHK v2 System Context

Read `../ahk-ctx-core/references/Module_Instructions.md` in full first; its `<how_to_use>` is the
flow for this Skill. Then load `../ahk-ctx-core/references/Module_CodeStyle.md` in full when writing
or editing AHK, and `../ahk-ctx-logic/references/Module_ExceptionHandling.md` when file I/O, COM,
registry, or network operations are present.

## Router

Read the listed heading through the next `## ` heading. `references/SECTION_INDEX.md` lists every
heading per Module, including TIER examples. A task spanning several topics loads only the named
Modules.

| Signal | Module | Heading |
|---|---|---|
| `DllCall`, type strings, `Ptr`/`UPtr`, `A_LastError`, `HRESULT`, Win32 handles, mutex | `Module_DllCallBasics.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `Buffer`, `NumGet`, `NumPut`, `StrGet`, `StrPut`, structs, `VirtualAlloc`, `HeapAlloc`, `GlobalAlloc` | `Module_BufferAndMemory.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `CallbackCreate`, `EnumWindows`, hooks, `OnMessage`, `SendMessage`, `PostMessage`, `WM_COPYDATA` | `Module_CallbacksAndMessages.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| `FileRead`, `FileAppend`, `FileOpen`, File object, encoding, BOM, binary file | `Module_FileIO.md` | `## API QUICK-REFERENCE` + matching TIER |
| `FileExist`, copy/move/delete, folders, `SplitPath`, `Loop Files`, `Loop Read`, CSV, INI | `Module_FilesAndFolders.md` | `## API QUICK-REFERENCE` + matching TIER |
| `Download`, WinHttp, GET/POST, headers, auth, status code | `Module_HttpRequests.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| async HTTP, `WaitForResponse(0)`, polling, concurrent requests, `HttpPromise` | `Module_HttpAsync.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| JSON parse/stringify, REST client, retry, rate limit | `Module_JsonAndRestClients.md` | `## API QUICK-REFERENCE` + matching TIER |
| `#Requires`, `#SingleInstance`, `#Include`, Lib folders, `A_Script*`, Ahk2Exe | `Module_ScriptSetup.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| tray menu, `A_IsAdmin`, `*RunAs`, `OnExit`, `ExitApp`, `Reload`, `Persistent` | `Module_ScriptLifecycle.md` | `## API QUICK-REFERENCE` + `## AHK V2 CONSTRAINTS` |
| clipboard, `Run`/`RunWait`, `ProcessWait`, `WinWait`, registry, `EnvGet`/`EnvSet` | `Module_ProcessAndSystem.md` | `## API QUICK-REFERENCE` + matching TIER |
| COM, Excel, Word, WMI, `ComObjConnect`, `ComObjArray`, `ComValue` | `Module_COMAutomation.md` | `## API QUICK-REFERENCE` + matching TIER |

Descend into a `## TIER` section when the task needs a runnable example.

## Critical Rules

### Low-Level / DllCall
- Declare DllCall return types that are not 32-bit `Int`; use `"Ptr"` for handles and pointers.
- `Buffer()` holds script-owned raw memory (`VarSetCapacity` does not exist in v2); use raw pointers only when the API requires them and ownership is clear.
- `NumPut(Type, Value, Target, Offset)` / `NumGet(Source, Offset, Type)`.
- Give every `CallbackCreate()` address a `CallbackFree()` path; bind methods before passing them.
- Match string types to the API: `"Str"`/`"WStr"` for Unicode, `"AStr"` for ANSI input.

### System & COM
- Use `A_Clipboard`; the v1 `Clipboard` variable does not exist.
- Quit script-owned COM hosts before releasing references; a `ComObjActive()` session is attached and is never quit.
- Pass timeouts to `WinWait`/`ProcessWait` unless an indefinite wait is intended (convention).
- `RegRead(Key, Value, Default)` returns the default instead of throwing for a missing value.
- Exit codes come from `RunWait()`'s return value; `ErrorLevel` was removed.

### File System
- Text without a BOM is decoded with `A_FileEncoding` (CP0 if unset); passing an explicit encoding is the repo convention.
- `FileOpen` throws `OSError` on failure: use `try`, not `if !f`.
- Prefer one `FileOpen` handle over many `FileAppend` calls; close owned File objects in `finally`.
- `FileExist`/`DirExist` return `""` when nothing matches and can be used as booleans.
- Relative paths resolve against `A_WorkingDir`, which defaults to `A_ScriptDir`; `A_InitialWorkingDir` holds the launcher's folder. `SetWorkingDir` changes it script-wide.

### Network & HTTP
- Use `ComObject("WinHttp.WinHttpRequest.5.1")`; check `.Status`, because 4xx/5xx do not throw.
- In GUI scripts use `Open(..., true)` + `WaitForResponse()` to stay responsive.
- AHK v2 has no built-in JSON: include a library or use the flat helpers.
- Handle network, registry, and file failures with `try/catch` where recovery, fallback, or diagnostics are required.

### Script Environment
- Directives are never conditional.
- Use `A_TrayMenu` and the Menu object for the tray.
- Elevation: `A_IsAdmin` guard, `try Run('*RunAs ... /restart ...')`, then `ExitApp()`.
- `ExitApp` skips Finally blocks and local `__Delete`; put exit cleanup in `OnExit`, which does not run on external termination.
