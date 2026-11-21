#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetMainIcon    %A_ScriptDir%\app.ico
;@Ahk2Exe-AddResource %A_ScriptDir%\on.ico, 206
;@Ahk2Exe-AddResource %A_ScriptDir%\off.ico, 207
;@Ahk2Exe-SetProductName Caffeine
;@Ahk2Exe-SetDescription  Prevents Windows from sleeping or turning off the display
;@Ahk2Exe-SetVersion      1.1.1
;@Ahk2Exe-SetCopyright    Copyright 2025

#Include %A_LineFile%\..\core.ahk

ES_CONTINUOUS       := 0x80000000
ES_DISPLAY_REQUIRED := 0x00000002

UpdateIcon("on.ico")
State := CaffeineState()

MenuItems := [
    "Active Indefinitely",
    "Active for 1 Hour",
    "Active for 2 Hours",
    "Active for 3 Hours",
    "Active for 4 Hours",
    "Active for Custom Duration...",
    "Active till Custom Time...",
    "Inactive"
]

; Set up tray menu
A_TrayMenu.Delete()
A_TrayMenu.Add("Active Indefinitely", SetIndefinite)
A_TrayMenu.Add("Active for 1 Hour", (*) => SetHours(1))
A_TrayMenu.Add("Active for 2 Hours", (*) => SetHours(2))
A_TrayMenu.Add("Active for 3 Hours", (*) => SetHours(3))
A_TrayMenu.Add("Active for 4 Hours", (*) => SetHours(4))
A_TrayMenu.Add("Active for Custom Duration...", SetCustomDuration)
A_TrayMenu.Add("Active till Custom Time...", SetCustomTime)
A_TrayMenu.Add("Inactive", SetInactive)
A_TrayMenu.Add("Report a Bug", (*) => Run(BugReportUrl()))
A_TrayMenu.Add() ; Separator
A_TrayMenu.Add("Stop && Exit", (*) => ExitApp())

SetMenuSelection("Active Indefinitely")
Caffeinate(true)
UpdateStatus()
TrayTip("Caffeine", "Sleep prevention enabled", 2)

SetTimer(UpdateStatus, 30000)
OnMessage(0x404, OnTrayClick)

UpdateStatus() {
    global State
    status := State.Status(A_Now)
    Caffeinate(status.Active)
    UpdateIcon(status.Active ? "on.ico" : "off.ico")
    A_IconTip := status.Tip
    if status.Expired {
        SetMenuSelection("Inactive")
        TrayTip("Caffeine duration completed. Sleep prevention disabled.", "Caffeine", 1)
    }
}

Caffeinate(enable) {
    global ES_CONTINUOUS, ES_DISPLAY_REQUIRED
    if enable {
        DllCall("kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS | ES_DISPLAY_REQUIRED)
    } else {
        DllCall("kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS)
    }
}

SetMenuSelection(activeItem) {
    global MenuItems
    for item in MenuItems {
        if item == activeItem {
            A_TrayMenu.Check(item)
        } else {
            A_TrayMenu.Uncheck(item)
        }
    }
}

; 0x404 is the tray notification message; lParam 0x202 is WM_LBUTTONUP.
OnTrayClick(wParam, lParam, *) {
    global State
    if lParam != 0x202 {
        return
    }
    State.Toggle()
    SetMenuSelection(State.IsActive ? "Active Indefinitely" : "Inactive")
    UpdateStatus()
}

SetInactive(itemName, *) {
    global State
    State.Deactivate()
    SetMenuSelection("Inactive")
    UpdateStatus()
}

SetIndefinite(itemName, *) {
    global State
    State.ActivateIndefinite()
    SetMenuSelection("Active Indefinitely")
    UpdateStatus()
}

SetHours(n) {
    global State
    State.ActivateUntil(DateAdd(A_Now, n, "Hours"))
    SetMenuSelection("Active for " n " Hour" (n == 1 ? "" : "s"))
    UpdateStatus()
}

SetCustomDuration(itemName, *) {
    global State
    result := InputBox("Enter duration (hour:minute, e.g. 1:30):", "Custom Duration", "w250 h130")
    if result.Result == "Cancel" {
        return
    }
    parsed := ParseDuration(result.Value, A_Now)
    if parsed.Error != "" {
        MsgBox(parsed.Error, "Error", 0x10)
        return
    }
    State.ActivateUntil(parsed.Time)
    SetMenuSelection("Active for Custom Duration...")
    UpdateStatus()
}

SetCustomTime(itemName, *) {
    global State
    result := InputBox("Enter target time (24-hour format, e.g. 17:30):", "Custom Target Time", "w250 h130")
    if result.Result == "Cancel" {
        return
    }
    parsed := ParseTargetTime(result.Value, A_Now)
    if parsed.Error != "" {
        MsgBox(parsed.Error, "Error", 0x10)
        return
    }
    State.ActivateUntil(parsed.Time)
    SetMenuSelection("Active till Custom Time...")
    UpdateStatus()
}

; Version and OS strings are URL-safe (digits and dots), so no encoding is needed.
BugReportUrl() {
    version := A_IsCompiled ? FileGetVersion(A_ScriptFullPath) : "script"
    return "https://github.com/hsinming/Caffeine/issues/new?template=bug.yml&version=" version "&os=" A_OSVersion
}

UpdateIcon(iconName) {
    if A_IsCompiled {
        if iconName == "on.ico" {
            TraySetIcon(A_ScriptFullPath, -206)
        } else if iconName == "off.ico" {
            TraySetIcon(A_ScriptFullPath, -207)
        }
    } else {
        iconPath := A_ScriptDir "\" iconName
        if FileExist(iconPath) {
            TraySetIcon(iconPath)
        }
    }
}

OnExit((*) => Caffeinate(false))
