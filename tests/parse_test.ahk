#Include %A_LineFile%\..\Assert.ahk
#Include %A_LineFile%\..\..\core.ahk

Now := "20260101120000"

Test("duration h:mm", () => AssertTime("20260101133000", ParseDuration("1:30", Now)))
Test("duration trims whitespace", () => AssertTime("20260101124500", ParseDuration("  0:45 ", Now)))
Test("duration rejects 0:00", () => AssertError("Duration must be greater than zero.", ParseDuration("0:00", Now)))
Test("duration rejects minutes over 59", () => AssertError("Invalid values. Hours must be >= 0, and minutes must be between 0 and 59.", ParseDuration("1:60", Now)))
Test("duration rejects bad format", () => AssertError("Invalid format. Please use 'hour:minute' (e.g., 1:30).", ParseDuration("90", Now)))

Test("target time later today stays today", () => AssertTime("20260101173000", ParseTargetTime("17:30", Now)))
Test("target time trims whitespace", () => AssertTime("20260101130500", ParseTargetTime(" 13:05 ", Now)))
Test("target time already past rolls to next day", () => AssertTime("20260102110000", ParseTargetTime("11:00", Now)))
Test("target time equal to now rolls to next day", () => AssertTime("20260102120000", ParseTargetTime("12:00", Now)))
Test("target time rejects hour 24", () => AssertError("Invalid time values. Hours must be 0-23, and minutes must be 0-59.", ParseTargetTime("24:00", Now)))
Test("target time rejects minute 60", () => AssertError("Invalid time values. Hours must be 0-23, and minutes must be 0-59.", ParseTargetTime("12:60", Now)))
Test("target time rejects bad format", () => AssertError("Invalid format. Please use 24-hour format 'HH:MM' (e.g., 17:30).", ParseTargetTime("17:3", Now)))

AssertTime(expected, result) {
    AssertEqual("", result.Error)
    AssertEqual(expected, result.Time)
}

AssertError(expected, result) {
    AssertEqual(expected, result.Error)
    AssertEqual("", result.Time)
}
