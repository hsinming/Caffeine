#Requires AutoHotkey v2.0
; AhkProbeInput.ahk - the keyboard and the active window of a drive. Invoke-AhkProbe.ps1 -Mode Drive includes it.
; A window station without a user has no active window, no visible window and no keyboard, so in this process only:
;   GetForegroundWindow answers the window that the registered message "AppDriveForeground" named (wParam, to the app's
;     main window; 0 at first), and IsWindowVisible asks the windows' own styles. AutoHotkey's window functions use both.
;   Send gives ^c, ^v and ^a to the focused control of that window as WM_COPY, WM_PASTE and EM_SETSEL. Any other key throws:
;     a drive that needs it must fail and not pass by accident. Each is reported as AHKPROBE|log|{"send":...}.
; shortcut: SendInput, SendEvent, SendText, SendPlay, Click and ControlSend are not replaced; the station refuses the first
; ones in silence. Extend this file when an app needs one.

#Include %A_LineFile%\..\AhkProbe.ahk

class AhkProbeInput {
    static Foreground := Buffer(8, 0)
    static __New() {
        if A_PtrSize != 8
            throw Error("AhkProbeInput needs 64-bit AutoHotkey.")
        ; mov rax, slot / mov rax, [rax] / ret
        this.Replace("GetForegroundWindow", "48B8", this.Foreground.Ptr, "488B00C3")
        ; for (w = hwnd; style(w) & WS_VISIBLE; ) if ((w = GetAncestor(w, GA_PARENT)) == desktop) return 1; else if (!w) break; return 0
        this.Replace("IsWindowVisible", "534883EC204889CB" "4889D9BAF0FFFFFF48B8", this.Address("GetWindowLongW")
            , "FFD0A900000010742B4889D9BA0100000048B8", this.Address("GetAncestor"), "FFD04889C348B9", DllCall("GetDesktopWindow", "Ptr")
            , "4839C874094885C075BA" "31C0EB05" "B801000000" "4883C4205BC3")
        OnMessage(DllCall("RegisterWindowMessageW", "Str", "AppDriveForeground", "UInt"), (wParam, *) => (NumPut("Ptr", wParam, this.Foreground), 1))
    }
    static Address(name) {
        local address := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "Str", "user32", "Ptr"), "AStr", name, "Ptr")
        if !address
            throw Error("user32 has no " name)
        return address
    }
    ; parts: hex code, or a number that becomes 8 bytes. The function's first bytes jump to the code.
    static Replace(name, parts*) {
        local code := DllCall("VirtualAlloc", "Ptr", 0, "UPtr", 4096, "UInt", 0x3000, "UInt", 0x40, "Ptr"), at := code
        if !code
            throw OSError()
        for part in parts
            at := part is Integer ? NumPut("Int64", part, at) : this.Hex(part, at)
        local entry := this.Address(name), protection := 0
        if !DllCall("VirtualProtect", "Ptr", entry, "UPtr", 12, "UInt", 0x40, "UInt*", &protection)
            throw OSError()
        this.Hex("FFE0", NumPut("Int64", code, this.Hex("48B8", entry)))   ; mov rax, code / jmp rax
        DllCall("VirtualProtect", "Ptr", entry, "UPtr", 12, "UInt", protection, "UInt*", &protection)
    }
    static Hex(text, at) {
        loop StrLen(text) // 2
            at := NumPut("UChar", Integer("0x" SubStr(text, A_Index * 2 - 1, 2)), at)
        return at
    }
    static Focus() {
        local info := Buffer(72, 0), window := NumGet(this.Foreground, "Ptr")
        NumPut("UInt", 72, info)
        if !window || !DllCall("GetGUIThreadInfo", "UInt", DllCall("GetWindowThreadProcessId", "Ptr", window, "Ptr", 0, "UInt"), "Ptr", info)
            return 0
        local focus := NumGet(info, 16, "Ptr")
        return (focus = window || DllCall("IsChild", "Ptr", window, "Ptr", focus)) ? focus : 0
    }
}

Send(keys) {
    static messages := Map("^c", [0x301, 0, 0], "^v", [0x302, 0, 0], "^a", [0xB1, 0, -1])
    if !messages.Has(keys)
        throw Error("App Drive: no way to send " keys)
    local focus := AhkProbeInput.Focus(), name := Buffer(512, 0)
    if focus {   ; no focused control: nothing happens, as with a real keyboard (apps fall back); "control":0 shows it
        DllCall("GetClassNameW", "Ptr", focus, "Ptr", name, "Int", 256)
        DllCall("SendMessageTimeoutW", "Ptr", focus, "UInt", messages[keys][1], "Ptr", messages[keys][2], "Ptr", messages[keys][3], "UInt", 2, "UInt", 5000, "Ptr*", 0)
    }
    AhkProbe.Emit("log", '{"send":' AhkProbe.Str(keys) ',"window":' NumGet(AhkProbeInput.Foreground, "Ptr") ',"control":' focus ',"class":' AhkProbe.Str(StrGet(name)) '}')
}
