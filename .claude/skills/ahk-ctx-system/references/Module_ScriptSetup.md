# Module_ScriptSetup.md
<!-- DOMAIN: Script Environment — load-time setup: directives, #Include and libraries, script A_* variables, Ahk2Exe compiler directives -->
<!-- SCOPE: #Requires, #SingleInstance, #Include/#IncludeAgain, Lib folders, #NoTrayIcon, A_ScriptDir/A_ScriptName/A_ScriptFullPath/A_LineFile/A_WorkingDir/A_InitialWorkingDir/A_IsCompiled/A_AhkPath/A_AhkVersion/A_Args, SetWorkingDir, Ahk2Exe ;@Ahk2Exe- directives. Tray menu, admin elevation, OnExit/ExitApp/Reload/Persistent are in Module_ScriptLifecycle.md. -->
<!-- TRIGGERS: #Requires, #SingleInstance, #Include, #IncludeAgain, "#Include <Lib>", Lib folder, #NoTrayIcon, A_ScriptDir, A_ScriptName, A_ScriptFullPath, A_LineFile, A_WorkingDir, A_InitialWorkingDir, A_IsCompiled, A_AhkPath, A_AhkVersion, A_Args, SetWorkingDir, Ahk2Exe, ";@Ahk2Exe-", "compiler directive", "compiled script", "script startup", "single instance", "multi-file project", "command-line arguments" -->
<!-- CONSTRAINTS: Directives are processed before the script runs and cannot be executed conditionally — an #Include inside an if-block still takes effect. A missing #SingleInstance behaves as Prompt; a bare #SingleInstance means Force. Relative #Include paths resolve against the directory of the file that contains the directive (or the last #Include <Dir>), not A_WorkingDir. #Include <Name> searches A_ScriptDir "\Lib\", then A_MyDocuments "\AutoHotkey\Lib\", then the running EXE's Lib folder; v2 never auto-includes libraries for undefined function calls. Ahk2Exe directives are special comments read only by the compiler. -->
<!-- CROSS-REF: Module_ScriptLifecycle.md, Module_ExceptionHandling.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| Calling a Lib function without `#Include` | `#Include <MyLib>` before use | v2 no longer auto-includes scripts from Lib folders for undefined function calls |
| v1 assumptions about relative `#Include` paths | Relative `#Include` is relative to the directory of the file that contains it | v2 changed this default; the parameter may now be quoted |
| `#NoEnv`, `SetBatchLines -1`, `SendMode Input` boilerplate | Remove them | `#NoEnv` and `SetBatchLines` were removed (their v1 "best" settings are the v2 default); `SendMode` already defaults to Input |
| `MsgBox, text` | `MsgBox("text")` or `MsgBox "text"` | v1 command syntax with a comma is a syntax error |
| No `#Requires` in a v2 file | `#Requires AutoHotkey v2.0` | The v2 launcher uses `#Requires` to pick the interpreter; without it a v1 interpreter may try to run the file and report unrelated errors |

## API QUICK-REFERENCE

### Directives (load-time, never conditional)

| Directive | Syntax | Notes |
|-----------|--------|-------|
| `#Requires` | `#Requires AutoHotkey v2.0` | Version must be ≥ the given version and < the next major version; `>=2.0.11`, `64-bit`/`32-bit` are also accepted. Shows an error and exits when unmet |
| `#SingleInstance` | `#SingleInstance Force\|Ignore\|Prompt\|Off` | Parameter omitted → `Force`. Directive absent → behaves as `Prompt`. Ignored with `/force` or `/restart` |
| `#Include` | `#Include FileOrDirName` / `#Include <LibName>` | Optional quotes; built-in variables in `%...%` are allowed (e.g. `"%A_ScriptDir%\Lib\x.ahk"`). Relative files resolve against the including file's directory; a directory argument changes the base for later `#Include`s. `*i ` prefix ignores a missing file. Each file is included once |
| `#IncludeAgain` | `#IncludeAgain File` | Like `#Include` but allows repeated inclusion |
| `#NoTrayIcon` | `#NoTrayIcon` | No tray icon at startup; `A_IconHidden` changes it at runtime |

### Library Folders for `#Include <LibName>` (searched in order)

1. `A_ScriptDir "\Lib\"` — local library
2. `A_MyDocuments "\AutoHotkey\Lib\"` — user library
3. `<directory of the running AutoHotkey.exe>\Lib\` — standard library

If `<MyPrefix_MyFunc>` is not found, the search repeats with the prefix only (`MyPrefix.ahk`).

### Script Properties (A_* variables)

| Variable | Access | Notes |
|----------|--------|-------|
| `A_ScriptDir` | read-only | Folder of the script, no trailing backslash |
| `A_ScriptName` | read/write | File name without path; assigning changes the default title of MsgBox, InputBox, FileSelect, DirSelect and Gui |
| `A_ScriptFullPath` | read-only | Full path of the script (or of the compiled EXE) |
| `A_LineFile` | read-only | Full path of the file that contains the current line (differs from `A_ScriptFullPath` inside `#Include` files) |
| `A_WorkingDir` | read/write | Base for relative paths at runtime; defaults to `A_ScriptDir`; `SetWorkingDir` changes it |
| `A_InitialWorkingDir` | read-only | Working directory set by the launching process (e.g. a shortcut's "Start in"); `A_WorkingDir` does not start from it |
| `A_IsCompiled` | read-only | `1` for a compiled EXE, otherwise `0` |
| `A_AhkPath` | read-only | EXE running the script. Compiled from a `.bin` base: the installed AutoHotkey.exe path read from the registry, or blank if not installed. Compiled from an `.exe` base: the compiled script's own path |
| `A_AhkVersion` | read-only | Interpreter version string |
| `A_Args` | Array | Command-line parameters (built-in switches like `/restart` are not included) |
| `A_IsAdmin`, `A_TrayMenu`, `A_IconTip`, `A_IconHidden`, `A_ScriptHwnd` | — | See Module_ScriptLifecycle.md |

### Ahk2Exe Compiler Directives (comments read by the compiler)

| Directive | Effect |
|-----------|--------|
| `;@Ahk2Exe-SetMainIcon IcoFile` | Main EXE icon (GUI/CLI choice can override it) |
| `;@Ahk2Exe-SetVersion text` | Sets **both** file version and product version |
| `;@Ahk2Exe-SetFileVersion text` / `;@Ahk2Exe-SetProductVersion text` | One of the two versions |
| `;@Ahk2Exe-SetProductName`, `SetCompanyName`, `SetCopyright`, `SetDescription`, `SetName` | Version-info strings (`SetDescription` also changes the Task Manager name on Windows 8+) |
| `;@Ahk2Exe-AddResource FileName, ResourceName?` | Adds a resource to the EXE |
| `;@Ahk2Exe-IgnoreBegin` … `;@Ahk2Exe-IgnoreEnd` | Code between them is removed from the compiled script |
| `;@Ahk2Exe-ConsoleApp` | Builds a console-mode EXE |

Directive parameters may use `%A_ScriptDir%`, `%A_ScriptName%` and other listed built-in variables. Commas inside a parameter must be escaped (`` `, ``). Version properties are processed in alphabetical order regardless of their order in the file.

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- Directives are applied at load time. `if cond` around `#Include` does not make the include conditional — the docs show that the file is included regardless. Gate behavior inside the included code with normal runtime checks instead.
  ✗ `if x` + `#Include "a.ahk"` → ✓ runtime checks inside the included code
- Include library code explicitly (`#Include <Name>` or a path). The v1 Lib auto-include and boilerplate wrong forms are in V1 → V2 BREAKING CHANGES.
- Put `#Requires AutoHotkey v2.0` at the top of runnable scripts (official recommendation for the launcher and for readers; V1 → V2 BREAKING CHANGES). Directive order `#Requires` → `#SingleInstance` → `#Include` → code is a **repo convention, not a language limit**.
- Write `#SingleInstance Force` explicitly when replacement is wanted: an absent directive means `Prompt`. Choosing `Force` for every script is a **repo convention, not a language limit**.
- Relative `#Include` paths resolve against the including file's folder; `SetWorkingDir` has no effect on `#Include`. Anchoring includes with `%A_ScriptDir%` is a **repo convention** for clarity.
- `A_WorkingDir` defaults to `A_ScriptDir` regardless of how the script was launched; `A_InitialWorkingDir` holds the launcher's folder. Anything that calls `SetWorkingDir` (including an included library) moves it for all threads, so `A_ScriptDir`-based paths are the safer habit (convention).
  ✗ `FileRead("data.txt")` after `SetWorkingDir` elsewhere → ✓ `A_ScriptDir "\data.txt"`
- When compiling, `%var%` in `#Include` is evaluated by the compiler, so values such as `A_ScriptDir` reflect the compile-time location.
- Placing all `;@Ahk2Exe-` directives at the top of the file is a **repo convention, not a compiler requirement**.

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| Load-time error, script does not start | `#Include` file not found (without `*i`) | Error dialog before the script runs | Fix the path; remember the base is the including file's folder |
| `#Requires` error, script exits | Interpreter version or bitness does not match | Message names path, version and build | Run with a matching AutoHotkey v2 build |
| `OSError` | `SetWorkingDir` to a missing folder | `e.Number` | Check `DirExist` first |
| VarUnset warning / `UnsetError` | Calling a Lib function that was never `#Include`d | Load-time warning names the function | Add `#Include <LibName>` |

## TIER 1 — Standard Script Header and Environment Info
> METHODS COVERED: #Requires · #SingleInstance · SetWorkingDir · A_ScriptDir · A_WorkingDir · A_IsCompiled · A_AhkVersion · A_Args

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force                  ; absent directive would mean Prompt

SetWorkingDir(A_ScriptDir)             ; optional: this is already the default; it pins the folder if something else may change it

class AppConfig {                      ; central constants — repo convention
    static Name    := "MyApp"
    static Version := "1.0.0"
}

info := AppConfig.Name " v" AppConfig.Version
    . "`nScript dir:  " A_ScriptDir
    . "`nLaunch dir:  " A_InitialWorkingDir
    . "`nCompiled:    " (A_IsCompiled ? "yes" : "no")
    . "`nAHK version: " A_AhkVersion
    . "`nArgs:        " A_Args.Length
MsgBox(info, "Startup Info", 64)

; #Requires AutoHotkey >=2.0.11 64-bit   ; ✓ minimum version plus bitness
```

## TIER 2 — #Include and the Library System
> METHODS COVERED: #Include · #Include <Lib> · A_LineFile

```ahk
#Requires AutoHotkey v2.0
#Include "%A_ScriptDir%\Lib\StringUtils.ahk"   ; ✓ explicit anchor (convention)
#Include <DateTimeLib>                         ; Lib\ in script dir → user Lib → EXE Lib
#Include "*i %A_ScriptDir%\local_overrides.ahk" ; *i = ignore if missing

; ✗ if !A_IsCompiled
;       #Include "debug.ahk"    ; still included — directives are never conditional

WhereAmI() => A_LineFile       ; path of the file that defines this line
MsgBox(WhereAmI())

; Recommended layout (convention):
; Project\Main.ahk        ; #Requires, #SingleInstance, #Includes, entry call
; Project\Lib\Logger.ahk
; Project\Lib\Utils.ahk
```

## TIER 3 — Ahk2Exe Compiler Directives
> METHODS COVERED: ;@Ahk2Exe-SetMainIcon · SetVersion · SetProductName · SetCompanyName · SetCopyright · SetDescription · AddResource · IgnoreBegin/IgnoreEnd · A_IsCompiled

```ahk
;@Ahk2Exe-SetMainIcon    %A_ScriptDir%\Assets\app.ico
;@Ahk2Exe-SetVersion     1.2.0
;@Ahk2Exe-SetProductName MyApp
;@Ahk2Exe-SetCompanyName Acme Corp
;@Ahk2Exe-SetCopyright   Copyright 2025 Acme Corp
;@Ahk2Exe-SetDescription Automation Tool
;@Ahk2Exe-AddResource    %A_ScriptDir%\Assets\splash.png, SPLASH_IMAGE

#Requires AutoHotkey v2.0

;@Ahk2Exe-IgnoreBegin
MsgBox("Running from source — this line is removed from the compiled EXE")
;@Ahk2Exe-IgnoreEnd

MsgBox(A_IsCompiled ? "Compiled: " A_ScriptFullPath : "Interpreted by " A_AhkPath)
```

### Performance Notes

- Directives cost nothing at runtime; `#Include` simply inlines code.
- Read configuration once at startup and cache it rather than re-reading files in hot paths.

## DROP-IN RECIPES

```ahk
; ArgOrDefault — read a positional command-line argument with a fallback
ArgOrDefault(index, default := "") => A_Args.Length >= index ? A_Args[index] : default
; Call site: mode := ArgOrDefault(1, "normal")

; ScriptFile — absolute path for a file that ships next to the script
ScriptFile(name) => A_ScriptDir "\" name
```

## SEE ALSO

> This module does NOT cover: tray menu, admin elevation, OnExit/ExitApp/Reload/Persistent → see Module_ScriptLifecycle.md
> This module does NOT cover: error handling patterns in depth → see Module_ExceptionHandling.md

- `Module_ScriptLifecycle.md` — tray icon/menu, elevation with `*RunAs`, exit handling, reload and persistence.
- `Module_ExceptionHandling.md` — try/catch patterns for startup failures.
