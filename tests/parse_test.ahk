#Include %A_LineFile%\..\Assert.ahk
#Include %A_LineFile%\..\..\core.ahk

Now := "20260101120000"

Test("end time later today stays today", () => AssertEqual("20260101173000", ParseEndTime("17:30", Now)))
Test("end time already past rolls to next day", () => AssertEqual("20260102110000", ParseEndTime("11:00", Now)))
Test("end time equal to now rolls to next day", () => AssertEqual("20260102120000", ParseEndTime("12:00", Now)))
Test("end time keeps leading zero hour", () => AssertEqual("20260102090500", ParseEndTime("09:05", Now)))
