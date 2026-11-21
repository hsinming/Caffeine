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

; Parsers return {Time, Error}: a target timestamp, or "" and the message to show the user.

; Active Until dialog sync math. The slider counts 15-minute steps; durations are in minutes.

EndTimeFor(minutes, now) {
    return DateAdd(now, minutes, "Minutes")
}

; `hhmm` is the picker's "HH:mm"; the ParseTargetTime next-day rule keeps it in (0, 24 h].
MinutesUntil(hhmm, now) {
    return Ceil(DateDiff(ParseTargetTime(hhmm, now).Time, now, "Seconds") / 60)
}

; Nearest 15-minute step, within the slider range of 15 min to 24 h.
SnapMinutes(minutes) {
    return Min(Max(Round(minutes / 15) * 15, 15), 1440)
}

UntilLabel(minutes, now) {
    return minutes // 60 "h " Mod(minutes, 60) "m → until " FormatTime(EndTimeFor(minutes, now), "HH:mm")
}
; A time not after `now` rolls to the next day.
ParseTargetTime(input, now) {
    if !RegExMatch(input, "^\s*(\d{1,2}):(\d{2})\s*$", &match) {
        return {Time: "", Error: "Invalid format. Please use 24-hour format 'HH:MM' (e.g., 17:30)."}
    }
    target_hours := Integer(match[1])
    target_minutes := Integer(match[2])
    if target_hours > 23 || target_minutes > 59 {
        return {Time: "", Error: "Invalid time values. Hours must be 0-23, and minutes must be 0-59."}
    }
    target_timestamp := SubStr(now, 1, 8) . Format("{:02d}", target_hours) . Format("{:02d}", target_minutes) . "00"
    if DateDiff(target_timestamp, now, "Seconds") <= 0 {
        target_timestamp := DateAdd(target_timestamp, 1, "Days")
    }
    return {Time: target_timestamp, Error: ""}
}
