import Foundation

public enum MeetingPlatform: String, Codable, Sendable, CaseIterable {
    case googleMeet
    case microsoftTeams
    case zoom

    public var displayName: String {
        switch self {
        case .googleMeet: "Google Meet"
        case .microsoftTeams: "Microsoft Teams"
        case .zoom: "Zoom"
        }
    }
}

public struct MeetingLink: Hashable, Codable, Sendable {
    public let url: URL
    public let platform: MeetingPlatform

    public init(url: URL, platform: MeetingPlatform) {
        self.url = url
        self.platform = platform
    }
}

/// Identity of one calendar occurrence. For a recurring series `externalID` is shared by
/// every occurrence, so `occurrence` is what tells them apart.
public struct MeetingID: Hashable, Codable, Sendable {
    public let externalID: String
    public let occurrence: Date

    public init(externalID: String, occurrence: Date) {
        self.externalID = externalID
        self.occurrence = occurrence
    }
}

/// An immutable snapshot of a calendar event. Never holds an EventKit object.
public struct Meeting: Hashable, Codable, Sendable, Identifiable {
    public var id: MeetingID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var isCancelled: Bool
    public var isDeclined: Bool
    public var calendarID: String
    public var calendarTitle: String
    public var link: MeetingLink?

    public init(
        id: MeetingID,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        isCancelled: Bool = false,
        isDeclined: Bool = false,
        calendarID: String = "",
        calendarTitle: String = "",
        link: MeetingLink? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.isCancelled = isCancelled
        self.isDeclined = isDeclined
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.link = link
    }

    /// Reminders are tracked per occurrence *and* start time, so a moved meeting alerts again.
    public var occurrenceKey: OccurrenceKey {
        OccurrenceKey(meeting: id, startAt: startDate)
    }
}

public struct OccurrenceKey: Hashable, Codable, Sendable {
    public let meeting: MeetingID
    public let startAt: Date

    public init(meeting: MeetingID, startAt: Date) {
        self.meeting = meeting
        self.startAt = startAt
    }
}

public struct ReminderKey: Hashable, Codable, Sendable {
    public let occurrence: OccurrenceKey
    public let leadSeconds: Int

    public init(occurrence: OccurrenceKey, leadSeconds: Int) {
        self.occurrence = occurrence
        self.leadSeconds = leadSeconds
    }
}
