# Module_ScriptLifecycle.md
<!-- DOMAIN: Script Environment — runtime lifecycle: tray icon and menu, admin elevation, exit handling, reload, persistence -->
<!-- SCOPE: A_TrayMenu (Menu object), TraySetIcon, A_IconTip, A_IconHidden, A_IsAdmin, Run "*RunAs" with /restart, OnExit, ExitApp, Exit reasons, Reload, Persistent, ProcessClose for child cleanup. Directives, #Include, A_Script* variables and Ahk2Exe are in Module_ScriptSetup.md. GUI windows opened from tray items are in Module_GuiBasics.md. -->
<!-- TRIGGERS: A_TrayMenu, TraySetIcon, A_IconTip, A_IconHidden, A_AllowMainWindow, A_IsAdmin, "*RunAs", "/restart", OnExit, ExitApp, ExitReason, Reload, Persistent, "tray menu", "tray icon", "admin elevation", "run as administrator", "exit handler", "cleanup on exit", "script lifecycle", "keep script running" -->
<!-- CONSTRAINTS: The tray menu is the Menu object A_TrayMenu — the v1 Menu, Tray command does not exist. OnExit callbacks receive (ExitReason, ExitCode); returning a non-zero integer cancels the exit and stops later callbacks. OnExit callbacks do not run when the process is killed (e.g. End Task) and can be interrupted by tray Exit, Reload or #SingleInstance. ExitApp does not run Finally blocks or call __Delete for objects in local variables. Elevation uses Run "*RunAs ..." guarded by A_IsAdmin; the documented pattern adds /restart to avoid a single-instance prompt and a relaunch loop when UAC is disabled. -->
<!-- CROSS-REF: Module_ScriptSetup.md, Module_GuiBasics.md, Module_ExceptionHandling.md, Module_ProcessAndSystem.md -->
<!-- VERSION: AHK v2.0+ -->

## V1 → V2 BREAKING CHANGES

| v1 pattern (LLM commonly writes) | v2 correct form | Consequence |
|----------------------------------|-----------------|-------------|
| `Menu, Tray, Add, Label, Handler` | `A_TrayMenu.Add("Label", Handler)` | The `Menu` command was removed; use the Menu class, `TraySetIcon`, `A_IconTip`, `A_IconHidden`, `A_AllowMainWindow` |
| `Menu, Tray, Icon, file.ico` | `TraySetIcon("file.ico")` | Same removal |
| `OnExit, LabelName` / `ExitReason` label | `OnExit(Callback)` with `Callback(ExitReason, ExitCode)` | Labels are not callbacks in v2 |
| `Run *RunAs ...` without a guard | `if !A_IsAdmin` + `try Run('*RunAs ...')` + `ExitApp()` | Unguarded elevation relaunches every time and leaves UAC failure unhandled |
| `OnExit(this.Cleanup)` | `OnExit(this.Cleanup.Bind(this))` or `ObjBindMethod(this, "Cleanup")` | A method's hidden first parameter is `this`; called as a plain callback, ExitReason lands in `this` and the parameters shift |

## API QUICK-REFERENCE

### Tray Icon and Menu

| Member | Signature | Notes |
|--------|-----------|-------|
| `A_TrayMenu` | read-only | Menu object for the tray icon |
| `.Add()` | `.Add(MenuItemName?, CallbackOrSubmenu?, Options?)` | No parameters → separator. Existing name → updates that item. Callback signature `(ItemName, ItemPos, MyMenu)`; use `*` to ignore extras |
| `.Delete()` | `.Delete(MenuItemName?)` | No parameter → deletes **all** items (standard ones too). Delete a separator by position, e.g. `"3&"` |
| `.Rename()` | `.Rename(MenuItemName, NewName?)` | Blank `NewName` turns the item into a separator |
| `.AddStandard()` | `.AddStandard()` | Re-adds missing standard tray items |
| `.Default` | read/write | Item selected by double-clicking the tray icon; `""` = none. Initially `&Open` if present |
| `.ClickCount` | read/write | `1` = single click selects the default item, `2` = double-click (default) |
| `TraySetIcon()` | `TraySetIcon(FileName?, IconNumber?, Freeze?)` | Also used by GUI and dialog windows |
| `A_IconTip` | read/write | Tooltip; blank → script name. Only the first 127 characters are shown; text stops at the first tab |
| `A_IconHidden` | read/write | `0` visible, `1` hidden (runtime counterpart of `#NoTrayIcon`) |
| `A_ScriptHwnd` | read-only | HWND of the script's hidden main window |

### Elevation and Process

| Item | Notes |
|------|-------|
| `A_IsAdmin` | `1` when running elevated, else `0`. Programs launched by an elevated script also run elevated |
| `Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')` | Interpreted script: relaunch the interpreter elevated |
| `Run('*RunAs "' A_ScriptFullPath '" /restart')` | Compiled script: relaunch the EXE elevated |
| `Run()` failure | Throws an exception (for example when UAC is cancelled) |
| `ProcessClose(PIDOrName)` | Returns the PID, or 0 if not found / cannot be closed |

### Lifecycle Functions

| Function | Signature | Notes |
|----------|-----------|-------|
| `OnExit()` | `OnExit(Callback, AddRemove := 1)` | `1` = call after earlier callbacks, `-1` = before, `0` = unregister. Callback `(ExitReason, ExitCode)`; non-zero integer return cancels the exit and skips later callbacks |
| `ExitApp()` | `ExitApp(ExitCode := 0)` | Same as tray "Exit". Runs OnExit callbacks first; does **not** run Finally blocks or call `__Delete` for objects held in local variables |
| `Reload()` | `Reload()` | Replaces the instance; command-line parameters are not passed on (except `/include`). If reloading fails (e.g. syntax error), the old instance keeps running |
| `Persistent()` | `Persistent(Setting := true)` | Returns the previous setting. Needed when only `OnMessage`/`CallbackCreate`/COM events keep the script busy; hotkeys, timers and GUIs make a script persistent automatically |

### Exit Reasons passed to OnExit callbacks

| Reason | Meaning |
|--------|---------|
| `Logoff` | User is logging off |
| `Shutdown` | System is shutting down or restarting |
| `Close` | WM_CLOSE/WM_QUIT, a critical error, or closed some other way |
| `Error` | Runtime error in a script that is **not** persistent |
| `Menu` | Exit chosen from the main window menu or the standard tray menu |
| `Exit` | `Exit` or `ExitApp` was used (includes custom menu items) |
| `Reload` | `Reload` function or menu item |
| `Single` | Replaced by a new instance via `#SingleInstance` |

## AHK V2 CONSTRAINTS

Check generated code against every rule before output. ✗ marks a common wrong form, ✓ the fix.

- All tray work goes through `A_TrayMenu`, `TraySetIcon`, `A_IconTip` and `A_IconHidden`; the v1 `Menu` command is gone (V1 → V2 BREAKING CHANGES).
- Bind instance methods used as callbacks (`this.Method.Bind(this)` or `ObjBindMethod(this, "Method")`). This applies to `OnExit`, tray items, timers and `OnMessage` alike. The unbound `OnExit(this.Cleanup)` wrong form is in V1 → V2 BREAKING CHANGES.
- Guard elevation with `A_IsAdmin`, wrap `Run("*RunAs ...")` in `try`, and call `ExitApp()` afterwards. The documented pattern also checks the command line for `/restart` so that a UAC-disabled system (where `*RunAs` does not elevate) cannot loop forever. The unguarded wrong form is in V1 → V2 BREAKING CHANGES.
- OnExit callbacks: keep them short. The OnExit thread cannot be interrupted by hotkeys or timers, but tray Exit, `Reload` and `#SingleInstance` replacement terminate it; End Task skips it entirely. A runtime error inside the callback terminates the script. Return `1` only to cancel the exit deliberately (see `OnExit()` in API QUICK-REFERENCE).
  ✗ network upload on `Shutdown` → ✓ local quick save; defer heavy work
- `ExitApp` skips Finally blocks and local-variable `__Delete`; cleanup that must happen on exit belongs in an OnExit callback (or in objects held by global variables).
  ✗ `try ... finally Cleanup()` around `ExitApp()` → ✓ OnExit callback
- A callback should normally not call `ExitApp` itself — that terminates immediately.
- Call `Persistent()` when only `OnMessage`, callbacks or COM events keep the script alive (see `Persistent()` in API QUICK-REFERENCE).
  ✗ script with only `OnMessage` exits at once → ✓ `Persistent()`

## RUNTIME ERROR MAPPING

| Exception / Failure | Trigger Condition | Detection | Fix |
|---------------------|-------------------|-----------|-----|
| Exception from `Run` | `*RunAs` cancelled in the UAC prompt or launch failed | `catch as e` → `e.Message` | Report, then `ExitApp()` or continue unelevated by design |
| Endless relaunch | UAC disabled, so `*RunAs` starts an unelevated copy that relaunches again | Many instances appear | Use the `/restart` command-line check from the docs pattern |
| Wrong `this` / parameter count error in a callback | Unbound method passed to `OnExit`, `A_TrayMenu.Add`, `SetTimer` | Error inside the method on first call | `.Bind(this)` / `ObjBindMethod` |
| Script exits immediately | Script only uses `OnMessage`/`CallbackCreate` | Exit reason is not a user action | Call `Persistent()` |

## TIER 1 — Tray Menu Customization
> METHODS COVERED: A_TrayMenu.Delete · A_TrayMenu.Add · A_TrayMenu.Rename · A_TrayMenu.Default · A_IconTip · TraySetIcon · .Bind

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()                                  ; nothing else keeps this demo running

A_IconTip := "MyApp v1.0"
try TraySetIcon(A_ScriptDir "\Assets\app.ico")

A_TrayMenu.Delete()                           ; removes all items, including the standard ones
A_TrayMenu.Add("About", ShowAbout)
A_TrayMenu.Add("Pause", TogglePause)
A_TrayMenu.Add()                              ; separator
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "About"                 ; double-click target

ShowAbout(*) => MsgBox("MyApp v1.0", "About", 64)

TogglePause(itemName, *) {
    static paused := false
    paused := !paused
    A_TrayMenu.Rename(itemName, paused ? "Resume" : "Pause")
}

class AppController {
    __New(name) {
        this.name := name
        A_TrayMenu.Add("Status", this.ShowStatus.Bind(this))   ; ✓ bound to the instance
    }
    ShowStatus(*) => MsgBox("Controller '" this.name "' is running.")
}
app := AppController("Main")

; ✗ A_TrayMenu.Add("Status", app.ShowStatus)   ; unbound — ItemName would become `this`
; ✗ Menu, Tray, Add, About, ShowAbout          ; v1 command — removed
```

## TIER 2 — Admin Elevation (documented pattern)
> METHODS COVERED: A_IsAdmin · A_IsCompiled · A_AhkPath · A_ScriptFullPath · Run *RunAs · /restart · ExitApp

```ahk
#Requires AutoHotkey v2.0
fullCmd := DllCall("GetCommandLine", "Str")
if !(A_IsAdmin || RegExMatch(fullCmd, " /restart(?!\S)")) {
    try {
        if A_IsCompiled
            Run('*RunAs "' A_ScriptFullPath '" /restart')
        else
            Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
    } catch as e {
        MsgBox("Administrator rights are required.`n" e.Message, "Elevation", 16)
    }
    ExitApp()                                 ; ✓ the unelevated instance always exits
}
MsgBox("A_IsAdmin: " A_IsAdmin)

; Notes from the docs:
; - /restart prevents a #SingleInstance prompt if the new instance starts before ExitApp.
; - With UAC disabled, *RunAs does not elevate; the /restart check stops a relaunch loop.
;   Check A_IsAdmin again if admin rights are mandatory.
; - /restart is a built-in switch and does not appear in A_Args. To forward A_Args,
;   append each one quoted after the script path.
```

## TIER 3 — Exit Handling with OnExit
> METHODS COVERED: OnExit · ExitApp · ExitReason · Run (&PID) · ProcessClose · IniWrite · .Bind

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent()

class AppLifecycle {
    __New(configFile) {
        this.configFile := configFile
        this.childPid   := 0
        OnExit(this.OnExitHandler.Bind(this))  ; ✓ bound method
        Run("notepad.exe", , , &pid)
        this.childPid := pid
    }

    OnExitHandler(exitReason, exitCode) {
        if exitReason = "Close" || exitReason = "Menu" {
            if MsgBox("Save settings and exit?", "Confirm", "YesNo") = "No"
                return 1                       ; ✓ non-zero cancels the exit
        }
        try IniWrite(A_Now, this.configFile, "State", "LastExit")   ; short, local work only
        if this.childPid
            ProcessClose(this.childPid)
        return 0                               ; allow exit
    }
}
app := AppLifecycle(A_ScriptDir "\config.ini")

; ✗ OnExit(app.OnExitHandler)           ; unbound — ExitReason becomes `this`
; ✗ try { ... } finally { Cleanup() }   ; finally does not run when ExitApp terminates the script
```

### Performance Notes

- Build the tray menu once at startup; rebuild only when its content changes.
- OnExit work should be local and quick (logoff/shutdown give little time; tray Exit or Reload can end the OnExit thread).

## DROP-IN RECIPES

```ahk
; BuildTrayMenu — replace the tray menu from an Array of [label, callback] pairs; "" label = separator
BuildTrayMenu(items, tip := "") {
    if !(items is Array)
        throw TypeError("BuildTrayMenu: items must be an Array", -1)
    A_TrayMenu.Delete()
    for item in items {
        if item[1] = ""
            A_TrayMenu.Add()
        else
            A_TrayMenu.Add(item[1], item[2])
    }
    if tip != ""
        A_IconTip := tip
}
; Call site:
; BuildTrayMenu([["Open", (*) => MsgBox("Open")], [""], ["Exit", (*) => ExitApp()]], "MyApp")

; LogExit — minimal OnExit logger
LogExit(reason, code) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " reason " " code "`n", A_Temp "\myapp_exit.log", "UTF-8")
    return 0
}
; Call site: OnExit(LogExit)
```

## SEE ALSO

> This module does NOT cover: #Requires, #SingleInstance, #Include, A_Script* variables, Ahk2Exe → see Module_ScriptSetup.md
> This module does NOT cover: GUI windows opened from tray items → see Module_GuiBasics.md
> This module does NOT cover: Run/RunWait options and process waiting in depth → see Module_ProcessAndSystem.md

- `Module_ScriptSetup.md` — directives, include system, script properties, compiler directives.
- `Module_ProcessAndSystem.md` — Run/RunWait, ProcessWait/ProcessClose, environment variables.
- `Module_GuiBasics.md` — GUI windows triggered from tray actions.
- `Module_ExceptionHandling.md` — try/catch patterns for elevation and exit-time failures.
