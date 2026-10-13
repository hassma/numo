import Foundation

/// How urgent a reminder feels, as a function of time relative to the meeting start.
/// Only tint, wording and ring state follow this; layout never changes.
public enum UrgencyStage: Sendable, Equatable {
    case upcoming
    case now
    case late
    case overdue

    public static func stage(secondsSinceStart s: TimeInterval) -> UrgencyStage {
        if s < -60 { return .upcoming }
        if s <= 60 { return .now }
        if s <= 300 { return .late }
        return .overdue
    }
}

/// User-facing strings derived from time. Kept here so they can be unit tested.
public enum ReminderCopy {
    public static func eyebrow(secondsSinceStart s: TimeInterval) -> String {
        switch UrgencyStage.stage(secondsSinceStart: s) {
        case .upcoming:
            return "Starting in \(minutes(ceil: -s)) min"
        case .now:
            return "Meeting starting now"
        case .late, .overdue:
            return "Started \(minutes(floor: s)) min ago"
        }
    }

    /// `2:59` before the start, `+1:05` after it.
    public static func clock(secondsSinceStart s: TimeInterval) -> String {
        let total = Int(abs(s).rounded(.down))
        let text = String(format: "%d:%02d", total / 60, total % 60)
        return s > 0 ? "+" + text : text
    }

    /// Short label for the menu bar: `in 12m`, `Now`, or nil when the meeting is over an hour away.
    public static func compactCountdown(secondsUntilStart s: TimeInterval) -> String? {
        if s <= 0 { return "Now" }
        if s > 3600 { return nil }
        return "in \(minutes(ceil: s))m"
    }

    private static func minutes(ceil seconds: TimeInterval) -> Int {
        max(1, Int((seconds / 60).rounded(.up)))
    }

    private static func minutes(floor seconds: TimeInterval) -> Int {
        max(1, Int((seconds / 60).rounded(.down)))
    }
}
