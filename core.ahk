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

    ; Any Active period goes Inactive; Inactive goes Active Indefinite.
    Toggle() {
        if this.IsActive {
            this.Deactivate()
        } else {
            this.ActivateIndefinite()
        }
    }

    ; True when an End Time is set and still ahead of `now`.
    IsTimed(now) {
        return this.IsActive && this.EndTime != "" && this.RemainingSeconds(now) > 0
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

; Active Until dialog sync math. Durations are in minutes; slider position p means p 15-minute steps.

EndTimeFor(minutes, now) {
    return DateAdd(now, minutes, "Minutes")
}

MinutesUntil(endTime, now) {
    return Ceil(DateDiff(endTime, now, "Seconds") / 60)
}

SliderMinutes(pos) {
    return pos * 15
}

; Nearest slider position, within the slider range of 1 (15 min) to 96 (24 h).
SliderPos(minutes) {
    return Min(Max(Round(minutes / SliderMinutes(1)), 1), 96)
}

UntilLabel(minutes, now) {
    return minutes // 60 "h " Mod(minutes, 60) "m → until " FormatTime(EndTimeFor(minutes, now), "HH:mm")
}

; `hhmm` is the picker's FormatTime "HH:mm". A time not after `now` rolls to the next day.
ParseEndTime(hhmm, now) {
    endTime := SubStr(now, 1, 8) StrReplace(hhmm, ":") "00"
    return DateDiff(endTime, now, "Seconds") <= 0 ? DateAdd(endTime, 1, "Days") : endTime
}
