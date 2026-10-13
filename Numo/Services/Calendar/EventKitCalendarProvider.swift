import EventKit
import Foundation
import NumoCore

/// Reads events from every calendar account macOS knows about (iCloud, Google, Microsoft 365/Exchange, CalDAV).
///
/// The `EKEventStore` never leaves this actor; callers only ever see immutable `Meeting` snapshots.
actor EventKitCalendarProvider: CalendarProviding {
    private let store = EKEventStore()
    private let detector = MeetingLinkDetector()

    func authorizationStatus() async -> CalendarAuthorization {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess { return .authorized }
        if status == .writeOnly { return .writeOnly }
        if status == .notDetermined { return .notDetermined }
        if status == .restricted { return .restricted }
        return .denied
    }

    /// Shows the system prompt if the user has not decided yet. Reading events needs *full* access:
    /// macOS has no read-only calendar permission.
    func requestAccess() async -> CalendarAuthorization {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.requestFullAccessToEvents { _, _ in
                continuation.resume()
            }
        }
        return await authorizationStatus()
    }

    /// Asks the system to pull fresh data from the servers; called after wake from sleep.
    func refreshSources() {
        store.refreshSourcesIfNecessary()
    }

    func calendars() async -> [CalendarInfo] {
        store.calendars(for: .event)
            .filter { $0.type != .birthday }
            .map { calendar in
                let source: EKSource? = calendar.source
                return CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: source?.title ?? "Other"
                )
            }
    }

    func meetings(from start: Date, to end: Date) async throws -> [Meeting] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .compactMap { snapshot(of: $0) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Mapping

    private func snapshot(of event: EKEvent) -> Meeting? {
        // EventKit declares several of these as implicitly unwrapped; binding to optionals is
        // correct whether or not a given SDK marks them nullable.
        let optionalStart: Date? = event.startDate
        let optionalEnd: Date? = event.endDate
        guard let start = optionalStart, let end = optionalEnd else { return nil }

        let calendar: EKCalendar? = event.calendar
        if calendar?.type == .birthday { return nil }

        let title: String? = event.title
        let externalID: String? = event.calendarItemExternalIdentifier
        let localID: String? = event.eventIdentifier
        let occurrence: Date? = event.occurrenceDate

        let identifier = [externalID, localID]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? "\(title ?? "")|\(start.timeIntervalSince1970)"

        let isDeclined = event.attendees?.contains {
            $0.isCurrentUser && $0.participantStatus == .declined
        } ?? false

        return Meeting(
            id: MeetingID(externalID: identifier, occurrence: occurrence ?? start),
            title: (title?.isEmpty == false ? title : nil) ?? "Untitled meeting",
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
            isCancelled: event.status == .canceled,
            isDeclined: isDeclined,
            calendarID: calendar?.calendarIdentifier ?? "",
            calendarTitle: calendar?.title ?? "",
            link: detector.detect(
                url: event.url?.absoluteString,
                location: event.location,
                notes: event.notes
            )
        )
    }
}
