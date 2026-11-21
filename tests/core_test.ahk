#Include %A_LineFile%\..\Assert.ahk
#Include %A_LineFile%\..\..\core.ahk

Now := "20260101120000"

Test("new state is active indefinitely", () => AssertStatus(CaffeineState().Status(Now), true, "Caffeine (Active Indefinitely)", false))
Test("indefinite mode status and tooltip", IndefiniteStatus)
Test("timed mode remaining seconds", TimedRemaining)
Test("timed mode tooltip shows hours and minutes", () => AssertStatus(Timed("20260101133000").Status(Now), true, "Caffeine (Active - 1h 30m remaining)", false))
Test("timed mode tooltip rounds 1 s up to 1 min", () => AssertStatus(Timed("20260101120001").Status(Now), true, "Caffeine (Active - 0h 1m remaining)", false))
Test("timed mode tooltip rounds 61 s up to 2 min", () => AssertStatus(Timed("20260101120101").Status(Now), true, "Caffeine (Active - 0h 2m remaining)", false))
Test("timed mode expires exactly at end time", () => AssertStatus(Timed(Now).Status(Now), false, "Caffeine (Inactive)", true))
Test("timed mode expires after end time", () => AssertStatus(Timed("20260101115959").Status(Now), false, "Caffeine (Inactive)", true))
Test("expiry is reported once", ExpiryReportedOnce)
Test("deactivate gives inactive status", DeactivateStatus)
Test("timed before end time", () => AssertEqual(true, Timed("20260101133000").IsTimed(Now)))
Test("not timed once end time has passed", () => AssertEqual(false, Timed("20260101115959").IsTimed(Now)))
Test("not timed when indefinite", () => AssertEqual(false, CaffeineState().IsTimed(Now)))

Timed(endTime) {
    s := CaffeineState()
    s.ActivateUntil(endTime)
    return s
}

AssertStatus(status, active, tip, expired) {
    AssertEqual(active, status.Active)
    AssertEqual(tip, status.Tip)
    AssertEqual(expired, status.Expired)
}

IndefiniteStatus() {
    s := Timed("20260101133000")
    s.ActivateIndefinite()
    AssertStatus(s.Status(Now), true, "Caffeine (Active Indefinitely)", false)
}

TimedRemaining() {
    AssertEqual(5400, Timed("20260101133000").RemainingSeconds(Now))
}

ExpiryReportedOnce() {
    s := Timed(Now)
    s.Status(Now)
    AssertStatus(s.Status("20260101120100"), false, "Caffeine (Inactive)", false)
}

DeactivateStatus() {
    s := Timed("20260101133000")
    s.Deactivate()
    AssertStatus(s.Status(Now), false, "Caffeine (Inactive)", false)
}
