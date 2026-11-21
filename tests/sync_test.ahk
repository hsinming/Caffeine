#Include %A_LineFile%\..\Assert.ahk
#Include %A_LineFile%\..\..\core.ahk

Now := "20260101120000"

Test("duration gives end time from now", () => AssertEqual("20260101133000", EndTimeFor(90, Now)))
Test("minutes until a later end time", () => AssertEqual(330, MinutesUntil("20260101173000", Now)))
Test("minutes until an end time tomorrow", () => AssertEqual(1380, MinutesUntil("20260102110000", Now)))
Test("partial minute rounds up", () => AssertEqual(330, MinutesUntil("20260101173000", "20260101120030")))
Test("slider position counts 15-minute steps", () => AssertEqual(90, SliderMinutes(6)))
Test("slider position keeps a grid value", () => AssertEqual(6, SliderPos(90)))
Test("slider position rounds down to nearest step", () => AssertEqual(6, SliderPos(97)))
Test("slider position rounds up to nearest step", () => AssertEqual(7, SliderPos(98)))
Test("slider position has 15 min as lower limit", () => AssertEqual(1, SliderPos(1)))
Test("slider position has 24 h as upper limit", () => AssertEqual(96, SliderPos(2000)))
Test("label shows duration and end time", () => AssertEqual("1h 30m → until 13:30", UntilLabel(90, Now)))
Test("label shows an off-grid duration exactly", () => AssertEqual("0h 7m → until 12:07", UntilLabel(7, Now)))
Test("label crosses midnight", () => AssertEqual("23h 0m → until 11:00", UntilLabel(1380, Now)))
