#Requires AutoHotkey v2.0
; AhkProbeDialogStubs.ahk - replaces MsgBox and InputBox for a test run, so no dialog reaches
; the user's screen. Each call is reported as AHKPROBE|dialog|{...} and answered with the
; safe choice (No / Cancel / Abort / OK), never Yes or Retry.
; Invoke-AhkProbe.ps1 -StubDialogs includes this file; never ship it with a real script.

#Include %A_LineFile%\..\AhkProbe.ahk

MsgBox(text := "", title := "", options := "") {
    answer := AhkProbeSafeAnswer(options)
    AhkProbe.Emit("dialog", '{"fn":"MsgBox","title":' AhkProbe.Str(title) ',"text":' AhkProbe.Str(text)
        . ',"options":' AhkProbe.Str(options) ',"answer":' AhkProbe.Str(answer) '}')
    return answer
}

InputBox(prompt := "", title := "", options := "", default := "") {
    AhkProbe.Emit("dialog", '{"fn":"InputBox","title":' AhkProbe.Str(title) ',"text":' AhkProbe.Str(prompt)
        . ',"answer":"Cancel"}')
    return {Result: "Cancel", Value: default}
}

AhkProbeSafeAnswer(options) {
    buttonType := 0
    if RegExMatch(String(options), "^\s*(\d+)", &number)
        buttonType := number[1] & 0xF
    text := String(options)
    if (buttonType = 3 || buttonType = 4 || InStr(text, "YesNo"))
        return "No"
    if (buttonType = 2 || InStr(text, "AbortRetryIgnore"))
        return "Abort"
    if (buttonType = 1 || buttonType = 5 || buttonType = 6 || InStr(text, "Cancel"))
        return "Cancel"
    return "OK"
}
