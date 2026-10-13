import Foundation

/// User settings, persisted as one versioned JSON blob. Every field decodes with a default,
/// so adding a field never invalidates settings written by an older build.
public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = AppSettings.currentVersion
    /// Calendars the user switched off. A new calendar is therefore on by default.
    public var disabledCalendarIDs: Set<String> = []
    /// Minutes before the start at which to remind. `0` means "at the start".
    public var leadTimesMinutes: [Int] = [3, 0]
    public var snoozeOptionsMinutes: [Int] = [1, 2, 5]
    public var defaultSnoozeMinutes = 2
    /// How late (after the start) a never-shown reminder may still appear. Beyond that the
    /// meeting is assumed to be under way and the reminder is dropped silently.
    public var catchUpWindowMinutes = 10
    public var requireMeetingLink = true
    public var includeAllDayEvents = false
    public var includeDeclinedEvents = false
    public var preferNativeTeamsApp = true
    public var pausedUntil: Date?

    public init() {}

    public func isCalendarEnabled(_ id: String) -> Bool {
        !disabledCalendarIDs.contains(id)
    }

    public func isPaused(at date: Date) -> Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > date
    }

    private enum CodingKeys: String, CodingKey {
        case version, disabledCalendarIDs, leadTimesMinutes, snoozeOptionsMinutes
        case defaultSnoozeMinutes, catchUpWindowMinutes, requireMeetingLink
        case includeAllDayEvents, includeDeclinedEvents, preferNativeTeamsApp, pausedUntil
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try c.decodeIfPresent(Int.self, forKey: .version) { version = v }
        if let v = try c.decodeIfPresent(Set<String>.self, forKey: .disabledCalendarIDs) { disabledCalendarIDs = v }
        if let v = try c.decodeIfPresent([Int].self, forKey: .leadTimesMinutes) { leadTimesMinutes = v }
        if let v = try c.decodeIfPresent([Int].self, forKey: .snoozeOptionsMinutes) { snoozeOptionsMinutes = v }
        if let v = try c.decodeIfPresent(Int.self, forKey: .defaultSnoozeMinutes) { defaultSnoozeMinutes = v }
        if let v = try c.decodeIfPresent(Int.self, forKey: .catchUpWindowMinutes) { catchUpWindowMinutes = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .requireMeetingLink) { requireMeetingLink = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .includeAllDayEvents) { includeAllDayEvents = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .includeDeclinedEvents) { includeDeclinedEvents = v }
        if let v = try c.decodeIfPresent(Bool.self, forKey: .preferNativeTeamsApp) { preferNativeTeamsApp = v }
        pausedUntil = try c.decodeIfPresent(Date.self, forKey: .pausedUntil)
    }
}
