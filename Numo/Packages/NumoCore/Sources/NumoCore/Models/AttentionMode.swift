import Foundation

/// How hard a reminder tries to get your attention.
public enum AttentionMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// A floating glass card. Nothing else on screen changes.
    case focused
    /// The card plus a dimmed "blocking screen" over every display once the meeting starts.
    case unmissable

    public var id: String { rawValue }
}

/// When the blocking screen applies and how long it may last. Pure, so the safety rules are tested.
public enum AttentionPolicy {
    /// A reminder shown earlier than this before the start (the "3 minutes before" nudge) is never blocking:
    /// the blocking screen is for the moment the meeting actually starts.
    public static let blockingLeadTolerance: TimeInterval = 60

    /// Upper limit on how long the screen stays blocked, however long the meeting is. After this the dimming
    /// is dropped and only the card remains, so a stuck or ignored reminder can never lock you out of your Mac.
    public static let maxBlockingDuration: TimeInterval = 10 * 60

    public static func blocks(mode: AttentionMode, meetingStart: Date, firedAt: Date) -> Bool {
        mode == .unmissable && firedAt >= meetingStart.addingTimeInterval(-blockingLeadTolerance)
    }

    /// The latest moment the blocking screen may still be up: the time cap, or the end of the meeting if sooner.
    public static func blockingExpiry(since: Date, meetingEnd: Date) -> Date {
        min(since.addingTimeInterval(maxBlockingDuration), meetingEnd)
    }
}
