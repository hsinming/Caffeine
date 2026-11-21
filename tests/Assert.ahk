; In-house assertion runner. Include it first in every test file:
;   #Include %A_LineFile%\..\Assert.ahk
; On exit it writes the results to stdout as JSON for test.ps1. No dialogs.

TestResults := Map("suite", RegExReplace(A_ScriptName, "i)\.ahk$"), "total", 0, "failures", [])
OnError(TestOnError)
OnExit(TestEmit)

Test(name, fn) {
    TestResults["total"] += 1
    try {
        fn()
    } catch Error as e {
        TestRecord(name, e)
    }
}

AssertEqual(expected, actual) {
    if (expected == actual)
        return
    e := Error("Expected " expected ", got " actual, -1) ; -1: report the caller's file and line
    e.Expected := expected
    e.Actual := actual
    throw e
}

TestRecord(name, e) {
    if !(e is Error)
        e := Error(String(e))
    TestResults["failures"].Push(Map(
        "suite", TestResults["suite"],
        "test", name,
        "expected", e.HasOwnProp("Expected") ? e.Expected : "no error",
        "actual", e.HasOwnProp("Actual") ? e.Actual : Type(e) ": " e.Message,
        "file", e.File,
        "line", e.Line,
        "stack", e.Stack
    ))
}

; Uncaught error outside Test(): record it and exit instead of showing a dialog.
TestOnError(e, mode) {
    TestRecord("(uncaught)", e)
    ExitApp(1)
    return 1
}

TestEmit(*) {
    FileAppend(TestJson(TestResults), "*", "UTF-8-RAW")
}

TestJson(v) {
    if (v is Array) {
        s := ""
        for item in v
            s .= (A_Index > 1 ? "," : "") TestJson(item)
        return "[" s "]"
    }
    if (v is Map) {
        s := ""
        for k, item in v
            s .= (A_Index > 1 ? "," : "") TestJson(String(k)) ":" TestJson(item)
        return "{" s "}"
    }
    if (v is Number)
        return String(v)
    v := StrReplace(v, "\", "\\")
    v := StrReplace(v, '"', '\"')
    v := StrReplace(v, "`r", "\r")
    v := StrReplace(v, "`n", "\n")
    v := StrReplace(v, "`t", "\t")
    return '"' v '"'
}
