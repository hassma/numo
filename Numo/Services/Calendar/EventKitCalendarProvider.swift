import EventKit
import Foundation
import NumoCore
import os

/// Reads events from every calendar account macOS knows about (iCloud, Google, Microsoft 365/Exchange, CalDAV).
///
/// The `EKEventStore` never leaves this actor; callers only ever see immutable `Meeting` snapshots.
///
/// Two kinds of store are involved on purpose. `observerStore` is long-lived: it keeps macOS posting
/// `EKEventStoreChanged` to the process and it is the one that asks for permission. Every read goes through a
/// brand-new store instead, because a long-lived store caches, and a store created before the user granted
/// access can keep returning nothing. A fresh store always reads what the calendar database holds now.
actor EventKitCalendarProvider: CalendarProviding {
    private var observerStore = EKEventStore()
    private let detector = MeetingLinkDetector()
    private let logger = Logger(subsystem: "app.numo.Numo", category: "calendar")

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
        let store = observerStore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.requestFullAccessToEvents { _, _ in
                continuation.resume()
            }
        }
        // A store that existed before the grant may never see the calendars: start over with a new one.
        observerStore = EKEventStore()
        let status = await authorizationStatus()
        logger.info("calendar access request finished, status: \(String(describing: status), privacy: .public)")
        return status
    }

    /// Asks the system to pull fresh data from the servers; called after wake and by "Refresh".
    func refreshSources() {
        observerStore.refreshSourcesIfNecessary()
    }

    func calendars() async -> [CalendarInfo] {
        EKEventStore().calendars(for: .event)
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
        observerStore.refreshSourcesIfNecessary()
        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        let meetings = events
            .compactMap { snapshot(of: $0) }
            .sorted { $0.startDate < $1.startDate }
        let linked = meetings.filter { $0.link != nil }.count
        logger.info("read \(events.count, privacy: .public) events, \(meetings.count, privacy: .public) usable, \(linked, privacy: .public) with a meeting link")
        return meetings
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
