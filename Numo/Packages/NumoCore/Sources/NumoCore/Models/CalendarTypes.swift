import Foundation

public enum CalendarAuthorization: Sendable, Equatable {
    case notDetermined
    case authorized
    /// Write-only access cannot read events, so it is as useless to numo as a denial.
    case writeOnly
    case denied
    case restricted
}

public struct CalendarInfo: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    /// The account the calendar belongs to (iCloud, Google, Exchange, ...).
    public let sourceTitle: String

    public init(id: String, title: String, sourceTitle: String) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
    }
}

/// The seam between the engine and a calendar backend. EventKit implements it today;
/// direct Google/Graph providers could implement it later (see docs, Phase 4).
public protocol CalendarProviding: Sendable {
    func authorizationStatus() async -> CalendarAuthorization
    func calendars() async -> [CalendarInfo]
    /// Events overlapping `[start, end]`, including ones already in progress.
    func meetings(from start: Date, to end: Date) async throws -> [Meeting]
}

/// Things that mean "the schedule may be wrong now": the app layer maps OS notifications to these.
public enum SystemEvent: Sendable, Equatable {
    case wake
    case clockChanged
    case timeZoneChanged
    case dayChanged
    case calendarChanged
}
