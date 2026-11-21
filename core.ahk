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

ParseDuration(input, now) {
    if !RegExMatch(input, "^\s*(\d+):(\d{1,2})\s*$", &match) {
        return {Time: "", Error: "Invalid format. Please use 'hour:minute' (e.g., 1:30)."}
    }
    hours := Integer(match[1])
    minutes := Integer(match[2])
    if minutes > 59 {
        return {Time: "", Error: "Invalid values. Hours must be >= 0, and minutes must be between 0 and 59."}
    }
    if hours == 0 && minutes == 0 {
        return {Time: "", Error: "Duration must be greater than zero."}
    }
    return {Time: DateAdd(now, hours * 60 + minutes, "Minutes"), Error: ""}
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
