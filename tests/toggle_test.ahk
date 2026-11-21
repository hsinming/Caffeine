#Include %A_LineFile%\..\Assert.ahk
#Include %A_LineFile%\..\..\core.ahk

Now := "20260101120000"

Test("toggle from inactive gives active indefinite", ToggleFromInactive)
Test("toggle from active indefinite gives inactive", ToggleFromIndefinite)
Test("toggle from timed active gives inactive and clears end time", ToggleFromTimed)

ToggleFromInactive() {
    s := CaffeineState()
    s.Deactivate()
    s.Toggle()
    AssertEqual(true, s.IsActive)
    AssertEqual("", s.EndTime)
    AssertEqual("Caffeine (Active Indefinitely)", s.Status(Now).Tip)
}

ToggleFromIndefinite() {
    s := CaffeineState()
    s.Toggle()
    AssertEqual("Caffeine (Inactive)", s.Status(Now).Tip)
}

ToggleFromTimed() {
    s := CaffeineState()
    s.ActivateUntil("20260101133000")
    s.Toggle()
    AssertEqual(false, s.IsActive)
    AssertEqual("", s.EndTime)
}
