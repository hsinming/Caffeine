;@Ahk2Exe-SetMainIcon    %A_ScriptDir%\Coffee.ico
;@Ahk2Exe-SetProductName Caffeine
;@Ahk2Exe-SetDescription  Prevents Windows from sleeping or turning off the display
;@Ahk2Exe-SetVersion      1.0.0
;@Ahk2Exe-SetCopyright    Copyright 2025

#Requires AutoHotkey v2.0
#SingleInstance Force

ES_CONTINUOUS       := 0x80000000
ES_DISPLAY_REQUIRED := 0x00000002

A_Icon := A_ScriptDir "\Coffee.ico"

Caffeinate(true)
TrayTip "Caffeine", "Sleep prevention enabled", 2

SetTimer(KeepAwake, 30000)

KeepAwake() {
    global ES_CONTINUOUS, ES_DISPLAY_REQUIRED
    DllCall("kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS | ES_DISPLAY_REQUIRED)
}

Caffeinate(enable) {
    global ES_CONTINUOUS, ES_DISPLAY_REQUIRED
    if enable {
        DllCall("kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS | ES_DISPLAY_REQUIRED)
    } else {
        DllCall("kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS)
    }
}

OnExit((*) => Caffeinate(false))

A_TrayMenu.Delete()
A_TrayMenu.Add("Stop && Exit", (*) => ExitApp())