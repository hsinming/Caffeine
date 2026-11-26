#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
; AhkProbeIsolation.ahk - run by Invoke-AhkProbe.ps1 in the window station of a drive, before the drive. Prints what it
; found; the runner judges it. It sends and writes only when the station is not the user's.

ahkProbeStation := DllCall("GetProcessWindowStation", "Ptr")
ahkProbeName := Buffer(512, 0), ahkProbeFlags := Buffer(12, 0)
DllCall("GetUserObjectInformationW", "Ptr", ahkProbeStation, "Int", 2, "Ptr", ahkProbeName, "UInt", 512, "Ptr", 0)      ; UOI_NAME
if !DllCall("GetUserObjectInformationW", "Ptr", ahkProbeStation, "Int", 1, "Ptr", ahkProbeFlags, "UInt", 12, "Ptr", 0)  ; UOI_FLAGS
    NumPut("UInt", 1, ahkProbeFlags, 8)
ahkProbeInteractive := NumGet(ahkProbeFlags, 8, "UInt") & 1                                                             ; WSF_VISIBLE
ahkProbeFound := "station=" StrGet(ahkProbeName) " interactive=" ahkProbeInteractive
if (!ahkProbeInteractive && StrGet(ahkProbeName) != "WinSta0") {
    ; vkE8 is unassigned: no program reacts to it, should it get out.
    ahkProbeKeys := Buffer(80, 0)
    loop 2
        NumPut("UInt", 1, ahkProbeKeys, (A_Index - 1) * 40), NumPut("UShort", 0xE8, ahkProbeKeys, (A_Index - 1) * 40 + 8)
    NumPut("UInt", 2, ahkProbeKeys, 52)                                                                                 ; key up
    ahkProbeFound .= " sendInput=" DllCall("SendInput", "UInt", 2, "Ptr", ahkProbeKeys, "Int", 40, "UInt") " error=" A_LastError
    ahkProbeSecret := "ahkprobe " A_TickCount
    A_Clipboard := ahkProbeSecret
    ahkProbeFound .= " clipboard=" (A_Clipboard = ahkProbeSecret ? "own" : "none")
    A_Clipboard := ""
}
FileAppend(ahkProbeFound "`n", "*", "UTF-8-RAW")
ExitApp()
