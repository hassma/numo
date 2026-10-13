import Foundation

@testable import NumoCore

/// 2027-01-15T08:00:00Z. Arbitrary but fixed, so tests never depend on the real time.
let t0 = Date(timeIntervalSince1970: 1_800_000_000)

let meetLink = MeetingLink(url: URL(string: "https://meet.google.com/abc-defg-hij")!, platform: .googleMeet)
let teamsLink = MeetingLink(
    url: URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_X%40thread.v2/0")!,
    platform: .microsoftTeams
)

func makeMeeting(
    _ externalID: String = "m1",
    start: Date,
    minutes: Int = 30,
    title: String = "Weekly Product Sync",
    calendarID: String = "cal",
    link: MeetingLink? = meetLink,
    isAllDay: Bool = false,
    isCancelled: Bool = false,
    isDeclined: Bool = false
) -> Meeting {
    Meeting(
        id: MeetingID(externalID: externalID, occurrence: start),
        title: title,
        startDate: start,
        endDate: start.addingTimeInterval(TimeInterval(minutes) * 60),
        isAllDay: isAllDay,
        isCancelled: isCancelled,
        isDeclined: isDeclined,
        calendarID: calendarID,
        calendarTitle: calendarID,
        link: link
    )
}

func iso(_ string: String) -> Date {
    ISO8601DateFormatter().date(from: string)!
}

// MARK: - Fakes

/// A clock the test moves by hand. `sleep(until:)` suspends until `advance(to:)` passes the deadline.
final class ManualClock: SchedulerClock, @unchecked Sendable {
    private struct Waiter {
        let id: UUID
        let deadline: Date
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var current: Date
    private var waiters: [Waiter] = []

    init(_ start: Date) {
        current = start
    }

    func now() -> Date {
        lock.withLock { current }
    }

    var waiterCount: Int {
        lock.withLock { waiters.count }
    }

    func sleep(until deadline: Date) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let alreadyDue: Bool = lock.withLock {
                    if current >= deadline { return true }
                    waiters.append(Waiter(id: id, deadline: deadline, continuation: continuation))
                    return false
                }
                if alreadyDue {
                    continuation.resume()
                } else if Task.isCancelled {
                    take(id)?.continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            take(id)?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(to date: Date) {
        let ready: [Waiter] = lock.withLock {
            current = date
            let due = waiters.filter { $0.deadline <= date }
            waiters.removeAll { $0.deadline <= date }
            return due
        }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }

    /// Waits (in real time, briefly) until the engine has gone to sleep on this clock.
    func waitForSleeper() async {
        for _ in 0..<500 {
            if waiterCount > 0 { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func take(_ id: UUID) -> Waiter? {
        lock.withLock {
            guard let index = waiters.firstIndex(where: { $0.id == id }) else { return nil }
            return waiters.remove(at: index)
        }
    }
}

actor FakeCalendar: CalendarProviding {
    private var authorization: CalendarAuthorization = .authorized
    private var items: [Meeting] = []
    private let infos = [CalendarInfo(id: "cal", title: "Work", sourceTitle: "Google")]

    init(_ items: [Meeting] = []) {
        self.items = items
    }

    func set(_ items: [Meeting]) { self.items = items }
    func set(authorization: CalendarAuthorization) { self.authorization = authorization }

    func authorizationStatus() async -> CalendarAuthorization { authorization }
    func calendars() async -> [CalendarInfo] { infos }
    func meetings(from start: Date, to end: Date) async throws -> [Meeting] {
        items.filter { $0.endDate > start && $0.startDate < end }
    }
}

actor InMemoryLedgerStore: LedgerStore {
    private var ledger: ReminderLedger
    private(set) var saveCount = 0

    init(_ ledger: ReminderLedger = ReminderLedger()) {
        self.ledger = ledger
    }

    func load() async -> ReminderLedger { ledger }
    func save(_ ledger: ReminderLedger) async {
        self.ledger = ledger
        saveCount += 1
    }
}

/// Collects engine events so tests can wait for them without blocking forever.
actor EventRecorder {
    private(set) var events: [ReminderEvent] = []

    func append(_ event: ReminderEvent) { events.append(event) }

    /// Returns once at least `count` events arrived, or after ~5 s so a failing test fails instead of hanging.
    func waitForCount(_ count: Int) async {
        for _ in 0..<500 {
            if events.count >= count { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// For "nothing else should happen" assertions: give stray events a moment to arrive.
    func settle() async {
        try? await Task.sleep(for: .milliseconds(80))
    }
}

func record(_ engine: ReminderEngine) -> (recorder: EventRecorder, task: Task<Void, Never>) {
    let recorder = EventRecorder()
    let stream = engine.events
    let task = Task {
        for await event in stream {
            await recorder.append(event)
        }
    }
    return (recorder, task)
}
