import Foundation

/// Applies the user's settings to raw calendar meetings and removes cross-calendar duplicates.
public enum MeetingFilter {
    public static func apply(_ meetings: [Meeting], settings: AppSettings) -> [Meeting] {
        let eligible = meetings.filter { meeting in
            guard !meeting.isCancelled else { return false }
            guard settings.isCalendarEnabled(meeting.calendarID) else { return false }
            guard settings.includeAllDayEvents || !meeting.isAllDay else { return false }
            guard settings.includeDeclinedEvents || !meeting.isDeclined else { return false }
            guard !settings.requireMeetingLink || meeting.link != nil else { return false }
            return true
        }

        // Deterministic order so the same copy wins every time.
        let ordered = eligible.sorted {
            ($0.startDate, $0.calendarID, $0.title) < ($1.startDate, $1.calendarID, $1.title)
        }

        var seen = Set<String>()
        return ordered.filter { seen.insert(fingerprint($0)).inserted }
    }

    /// The same meeting invited into two calendars must alert once. The start time is part of the
    /// fingerprint because a recurring series reuses one join link for every occurrence.
    static func fingerprint(_ meeting: Meeting) -> String {
        let start = Int(meeting.startDate.timeIntervalSince1970)
        if let link = meeting.link,
           let components = URLComponents(url: link.url, resolvingAgainstBaseURL: false) {
            let host = components.host?.lowercased() ?? ""
            return "link|\(host)\(components.path.lowercased())|\(start)"
        }
        let end = Int(meeting.endDate.timeIntervalSince1970)
        return "meeting|\(meeting.title.lowercased())|\(start)|\(end)"
    }
}
