#Include %A_LineFile%\..\Assert.ahk
#Include %A_LineFile%\..\..\core.ahk

Now := "20260101120000"

Test("duration gives end time from now", () => AssertEqual("20260101133000", EndTimeFor(90, Now)))
Test("picker time later today gives minutes until it", () => AssertEqual(330, MinutesUntil("17:30", Now)))
Test("picker time not after now means tomorrow", () => AssertEqual(1380, MinutesUntil("11:00", Now)))
Test("picker time equal to now means 24 h", () => AssertEqual(1440, MinutesUntil("12:00", Now)))
Test("partial minute rounds up", () => AssertEqual(330, MinutesUntil("17:30", "20260101120030")))
Test("snap keeps a grid value", () => AssertEqual(90, SnapMinutes(90)))
Test("snap rounds down to nearest step", () => AssertEqual(90, SnapMinutes(97)))
Test("snap rounds up to nearest step", () => AssertEqual(105, SnapMinutes(98)))
Test("snap has 15 min as lower limit", () => AssertEqual(15, SnapMinutes(1)))
Test("snap has 24 h as upper limit", () => AssertEqual(1440, SnapMinutes(1440)))
Test("label shows duration and end time", () => AssertEqual("1h 30m → until 13:30", UntilLabel(90, Now)))
Test("label shows an off-grid duration exactly", () => AssertEqual("0h 7m → until 12:07", UntilLabel(7, Now)))
Test("label crosses midnight", () => AssertEqual("23h 0m → until 11:00", UntilLabel(1380, Now)))
