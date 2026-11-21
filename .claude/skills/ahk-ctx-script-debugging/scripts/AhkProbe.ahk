#Requires AutoHotkey v2.0
; AhkProbe.ahk - in-process probe for debugging AutoHotkey v2 scripts.
; Method adapted from ahkh (https://github.com/owhs/AHKTestHarness).
;
; Inject without editing the target (Invoke-AhkProbe.ps1 does this for you):
;     AutoHotkey64.exe /ErrorStdOut /include AhkProbe.ahk target.ahk
; or opt in from a test script:  #Include <path>\AhkProbe.ahk
;
; Output protocol, one stdout line per event:   AHKPROBE|<kind>|<json>
;     kinds: ready log mark assert step error dialog done
;
; Environment:
;     AHKPROBE_ONERROR   exit (default): report an uncaught error, then ExitApp(3), no popup
;                        continue      : report it, suppress the popup, keep running

class AhkProbe {
    static OnErrMode := EnvGet("AHKPROBE_ONERROR") || "exit"
    static Pass := 0
    static Fail := 0
    static T0 := A_TickCount

    static __New() {
        OnError(ObjBindMethod(AhkProbe, "_OnError"), -1)
        AhkProbe.Emit("ready", '{"pid":' ProcessExist() ',"script":' AhkProbe.Str(A_ScriptFullPath) '}')
    }

    ; ---------------------------------------------------------------- output
    static Emit(kind, json) {
        try FileAppend("AHKPROBE|" kind "|" json "`n", "*", "UTF-8")
    }

    static Log(msg) {
        AhkProbe.Emit("log", '{"msg":' AhkProbe.Str(msg) '}')
    }

    static Mark(label) {
        AhkProbe.Emit("mark", '{"label":' AhkProbe.Str(label) ',"ms":' (A_TickCount - AhkProbe.T0) '}')
    }

    ; ---------------------------------------------------------------- assertions
    static Assert(cond, msg := "assertion") {
        caller := Error("", -1)
        if cond {
            AhkProbe.Pass++
            return true
        }
        AhkProbe.Fail++
        AhkProbe.Emit("assert", '{"ok":false,"msg":' AhkProbe.Str(msg)
            . ',"file":' AhkProbe.Str(caller.File) ',"line":' caller.Line '}')
        return false
    }

    static Expect(actual, expected, msg := "") {
        caller := Error("", -1)
        if (String(actual) == String(expected)) {
            AhkProbe.Pass++
            return true
        }
        AhkProbe.Fail++
        AhkProbe.Emit("assert", '{"ok":false,"msg":' AhkProbe.Str(msg)
            . ',"expected":' AhkProbe.Str(expected) ',"actual":' AhkProbe.Str(actual)
            . ',"file":' AhkProbe.Str(caller.File) ',"line":' caller.Line '}')
        return false
    }

    static Step(name, fn) {
        started := A_TickCount
        try {
            fn()
            AhkProbe.Pass++
            AhkProbe.Emit("step", '{"name":' AhkProbe.Str(name) ',"ok":true,"ms":' (A_TickCount - started) '}')
            return true
        } catch as err {
            AhkProbe.Fail++
            AhkProbe.Emit("step", '{"name":' AhkProbe.Str(name) ',"ok":false,"ms":' (A_TickCount - started)
                . ',"error":' AhkProbe.ErrJson(err) '}')
            return false
        }
    }

    ; Poll a condition instead of sleeping a fixed time.
    static WaitFor(fn, timeoutMs := 5000, intervalMs := 25) {
        deadline := A_TickCount + timeoutMs
        while (A_TickCount < deadline) {
            if fn()
                return true
            Sleep(intervalMs)
        }
        return false
    }

    static Done(exitCode?) {
        AhkProbe.Emit("done", '{"pass":' AhkProbe.Pass ',"fail":' AhkProbe.Fail '}')
        ExitApp(IsSet(exitCode) ? exitCode : (AhkProbe.Fail > 0 ? 1 : 0))
    }

    ; ---------------------------------------------------------------- errors
    static ErrJson(err) {
        json := '{"type":' AhkProbe.Str(Type(err)) ',"message":' AhkProbe.Str(err.Message)
        try json .= ',"what":' AhkProbe.Str(err.What)
        try json .= ',"extra":' AhkProbe.Str(err.Extra)
        try json .= ',"file":' AhkProbe.Str(err.File) ',"line":' err.Line
        try json .= ',"stack":' AhkProbe.Str(err.Stack)
        return json "}"
    }

    static _OnError(err, mode) {
        AhkProbe.Emit("error", AhkProbe.ErrJson(err))
        if (AhkProbe.OnErrMode = "continue")
            return 1
        ExitApp(3)
    }

    ; ---------------------------------------------------------------- JSON string
    static Str(value) {
        text := String(value)
        text := StrReplace(text, "\", "\\")
        text := StrReplace(text, '"', '\"')
        text := StrReplace(text, "`r", "\r")
        text := StrReplace(text, "`n", "\n")
        text := StrReplace(text, "`t", "\t")
        loop 31 {
            if (A_Index != 9 && A_Index != 10 && A_Index != 13)
                text := StrReplace(text, Chr(A_Index), Format("\u{:04x}", A_Index))
        }
        return '"' text '"'
    }
}
