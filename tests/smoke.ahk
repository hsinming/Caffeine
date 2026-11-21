; Smoke test. test.ps1 loads it with /include before caffeine.ahk:
; runtime errors in the tray app are recorded, and the app exits cleanly after 3 s.
#Include %A_LineFile%\..\Assert.ahk

TestResults["suite"] := "smoke"
Test("tray app runs 3 s and exits cleanly", () => SetTimer(() => ExitApp(0), -3000))
