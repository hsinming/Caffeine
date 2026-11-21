; Pure sleep-prevention logic. No top-level side effects: no tray, timers, dialogs or DllCall.
; Every method that needs the current time takes a `now` timestamp (YYYYMMDDHH24MISS).

class CaffeineState {
    IsActive := true
    EndTime := ""

    ActivateIndefinite() {
        this.IsActive := true
        this.EndTime := ""
    }

    ActivateUntil(timestamp) {
        this.IsActive := true
        this.EndTime := timestamp
    }

    Deactivate() {
        this.IsActive := false
        this.EndTime := ""
    }

    RemainingSeconds(now) {
        return DateDiff(this.EndTime, now, "Seconds")
    }

    ; Returns {Active, Tip, Expired}. A timed session that has ended is deactivated
    ; and reported with Expired := true once.
    Status(now) {
        if !this.IsActive {
            return {Active: false, Tip: "Caffeine (Inactive)", Expired: false}
        }
        if this.EndTime == "" {
            return {Active: true, Tip: "Caffeine (Active Indefinitely)", Expired: false}
        }
        remaining_seconds := this.RemainingSeconds(now)
        if remaining_seconds <= 0 {
            this.Deactivate()
            return {Active: false, Tip: "Caffeine (Inactive)", Expired: true}
        }
        remaining_minutes := Ceil(remaining_seconds / 60)
        hours := remaining_minutes // 60
        minutes := Mod(remaining_minutes, 60)
        return {Active: true, Tip: "Caffeine (Active - " hours "h " minutes "m remaining)", Expired: false}
    }
}
