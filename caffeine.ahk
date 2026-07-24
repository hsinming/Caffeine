#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetMainIcon    %A_ScriptDir%\app.ico
;@Ahk2Exe-AddResource %A_ScriptDir%\on.ico, 206
;@Ahk2Exe-AddResource %A_ScriptDir%\off.ico, 207
;@Ahk2Exe-SetProductName Caffeine
;@Ahk2Exe-SetDescription  Prevents Windows from sleeping or turning off the display
;@Ahk2Exe-SetVersion      1.1.1
;@Ahk2Exe-SetCopyright    Copyright 2025

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
A_TrayMenu.Add() ; Separator
A_TrayMenu.Add("Stop && Exit", (*) => ExitApp())

SetMenuSelection("Active Indefinitely")
Caffeinate(true)
State.UpdateStatus()
TrayTip("Caffeine", "Sleep prevention enabled", 2)

SetTimer(KeepAwake, 30000)

KeepAwake() {
    global State
    State.UpdateStatus()
}

class CaffeineState {
    IsActive := true
    EndTime := ""

    ActivateIndefinite() {
        this.IsActive := true
        this.EndTime := ""
    }

    ActivateUntil(timestamp) {
        this.IsActive := true
        this.EndTime := timestamp
    }

    Deactivate() {
        this.IsActive := false
        this.EndTime := ""
    }

    RemainingSeconds() {
        return DateDiff(this.EndTime, A_Now, "Seconds")
    }

    UpdateStatus() {
        if !this.IsActive {
            Caffeinate(false)
            UpdateIcon("off.ico")
            A_IconTip := "Caffeine (Inactive)"
            return
        }
        if this.EndTime == "" {
            Caffeinate(true)
            UpdateIcon("on.ico")
            A_IconTip := "Caffeine (Active Indefinitely)"
        } else {
            remaining_seconds := this.RemainingSeconds()
            if remaining_seconds <= 0 {
                this.IsActive := false
                Caffeinate(false)
                this.EndTime := ""
                UpdateIcon("off.ico")
                SetMenuSelection("Inactive")
                A_IconTip := "Caffeine (Inactive)"
                TrayTip("Caffeine duration completed. Sleep prevention disabled.", "Caffeine", 1)
            } else {
                Caffeinate(true)
                UpdateIcon("on.ico")
                remaining_minutes := Ceil(remaining_seconds / 60)
                hours := remaining_minutes // 60
                minutes := Mod(remaining_minutes, 60)
                A_IconTip := "Caffeine (Active - " hours "h " minutes "m remaining)"
            }
        }
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

SetInactive(itemName, *) {
    global State
    State.Deactivate()
    SetMenuSelection("Inactive")
    State.UpdateStatus()
}

SetIndefinite(itemName, *) {
    global State
    State.ActivateIndefinite()
    SetMenuSelection("Active Indefinitely")
    State.UpdateStatus()
}

SetHours(n) {
    global State
    State.ActivateUntil(DateAdd(A_Now, n, "Hours"))
    SetMenuSelection("Active for " n " Hour" (n == 1 ? "" : "s"))
    State.UpdateStatus()
}

SetCustomDuration(itemName, *) {
    global State
    result := InputBox("Enter duration (hour:minute, e.g. 1:30):", "Custom Duration", "w250 h130")
    if result.Result == "Cancel" {
        return
    }
    if !RegExMatch(result.Value, "^\s*(\d+):(\d{1,2})\s*$", &match) {
        MsgBox("Invalid format. Please use 'hour:minute' (e.g., 1:30).", "Error", 0x10)
        return
    }
    hours := Integer(match[1])
    minutes := Integer(match[2])
    if hours < 0 || minutes < 0 || minutes > 59 {
        MsgBox("Invalid values. Hours must be >= 0, and minutes must be between 0 and 59.", "Error", 0x10)
        return
    }
    if hours == 0 && minutes == 0 {
        MsgBox("Duration must be greater than zero.", "Error", 0x10)
        return
    }
    total_minutes := hours * 60 + minutes
    State.ActivateUntil(DateAdd(A_Now, total_minutes, "Minutes"))
    SetMenuSelection("Active for Custom Duration...")
    State.UpdateStatus()
}

SetCustomTime(itemName, *) {
    global State
    result := InputBox("Enter target time (24-hour format, e.g. 17:30):", "Custom Target Time", "w250 h130")
    if result.Result == "Cancel" {
        return
    }
    if !RegExMatch(result.Value, "^\s*(\d{1,2}):(\d{2})\s*$", &match) {
        MsgBox("Invalid format. Please use 24-hour format 'HH:MM' (e.g., 17:30).", "Error", 0x10)
        return
    }
    target_hours := Integer(match[1])
    target_minutes := Integer(match[2])
    if target_hours < 0 || target_hours > 23 || target_minutes < 0 || target_minutes > 59 {
        MsgBox("Invalid time values. Hours must be 0-23, and minutes must be 0-59.", "Error", 0x10)
        return
    }
    current_date := SubStr(A_Now, 1, 8)
    target_timestamp := current_date . Format("{:02d}", target_hours) . Format("{:02d}", target_minutes) . "00"
    if DateDiff(target_timestamp, A_Now, "Seconds") <= 0 {
        target_timestamp := DateAdd(target_timestamp, 1, "Days")
    }
    State.ActivateUntil(target_timestamp)
    SetMenuSelection("Active till Custom Time...")
    State.UpdateStatus()
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
