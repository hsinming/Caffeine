;@Ahk2Exe-SetMainIcon    %A_ScriptDir%\Coffee.ico
;@Ahk2Exe-SetProductName Caffeine
;@Ahk2Exe-SetDescription  Prevents Windows from sleeping or turning off the display
;@Ahk2Exe-SetVersion      1.1.0
;@Ahk2Exe-SetCopyright    Copyright 2025

#Requires AutoHotkey v2.0
#SingleInstance Force

ES_CONTINUOUS       := 0x80000000
ES_DISPLAY_REQUIRED := 0x00000002

A_Icon := A_ScriptDir "\Coffee.ico"

EndTime := ""

MenuItems := [
    "Active Indefinitely",
    "Active for 1 Hour",
    "Active for 2 Hours",
    "Active for 3 Hours",
    "Active for 4 Hours",
    "Active for Custom Duration...",
    "Active till Custom Time..."
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
A_TrayMenu.Add() ; Separator
A_TrayMenu.Add("Stop && Exit", (*) => ExitApp())

SetMenuSelection("Active Indefinitely")
Caffeinate(true)
TrayTip("Caffeine", "Sleep prevention enabled", 2)

SetTimer(KeepAwake, 30000)

KeepAwake() {
    global EndTime
    UpdateStatus()
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

UpdateStatus() {
    global EndTime
    if EndTime == "" {
        Caffeinate(true)
        A_IconTip := "Caffeine (Active Indefinitely)"
    } else {
        remaining_seconds := DateDiff(EndTime, A_Now, "Seconds")
        if remaining_seconds <= 0 {
            Caffeinate(false)
            EndTime := ""
            SetMenuSelection("Active Indefinitely")
            A_IconTip := "Caffeine (Active Indefinitely)"
            TrayTip("Caffeine duration completed. Sleep prevention disabled.", "Caffeine", 1)
        } else {
            Caffeinate(true)
            remaining_minutes := Ceil(remaining_seconds / 60)
            hours := remaining_minutes // 60
            minutes := Mod(remaining_minutes, 60)
            A_IconTip := "Caffeine (Active - " hours "h " minutes "m remaining)"
        }
    }
}

SetIndefinite(itemName, *) {
    global EndTime
    EndTime := ""
    SetMenuSelection("Active Indefinitely")
    UpdateStatus()
}

SetHours(n) {
    global EndTime
    EndTime := DateAdd(A_Now, n, "Hours")
    SetMenuSelection("Active for " n " Hour" (n == 1 ? "" : "s"))
    UpdateStatus()
}

SetCustomDuration(itemName, *) {
    global EndTime
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
    EndTime := DateAdd(A_Now, total_minutes, "Minutes")
    SetMenuSelection("Active for Custom Duration...")
    UpdateStatus()
}

SetCustomTime(itemName, *) {
    global EndTime
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
    EndTime := target_timestamp
    SetMenuSelection("Active till Custom Time...")
    UpdateStatus()
}

OnExit((*) => Caffeinate(false))
