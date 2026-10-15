import Foundation

// MARK: - Clock

/// Time source and sleeper, injectable so tests can drive time manually.
public protocol SchedulerClock: Sendable {
    func now() -> Date
    /// Returns when `deadline` has passed, or throws `CancellationError` if the task is cancelled.
    func sleep(until deadline: Date) async throws
}

public struct SystemSchedulerClock: SchedulerClock {
    public init() {}

    public func now() -> Date { Date() }

    /// Uses the continuous clock underneath, which keeps counting while the Mac sleeps, so a long
    /// sleep returns promptly after wake. The app layer also forces a replan on wake.
    public func sleep(until deadline: Date) async throws {
        let interval = deadline.timeIntervalSince(Date())
        guard interval > 0 else { return }
        try await Task.sleep(for: .seconds(interval))
    }
}

// MARK: - Engine output

public struct DueReminder: Hashable, Sendable, Identifiable {
    public let key: ReminderKey
    public let meeting: Meeting
    public let firedAt: Date

    public var id: ReminderKey { key }

    public init(key: ReminderKey, meeting: Meeting, firedAt: Date) {
        self.key = key
        self.meeting = meeting
        self.firedAt = firedAt
    }
}

public enum WithdrawReason: Sendable, Equatable {
    /// The meeting was cancelled, moved, declined or its calendar was switched off.
    case meetingChanged
    case meetingEnded
}

public enum ReminderEvent: Sendable, Equatable {
    case due(DueReminder)
    case withdrawn(ReminderKey, WithdrawReason)
}

/// What the UI needs to render the menu bar and settings. Published after every plan.
public struct EngineSnapshot: Sendable, Equatable {
    public var generatedAt: Date
    public var authorization: CalendarAuthorization
    public var calendars: [CalendarInfo]
    /// Filtered meetings that are in progress or upcoming, soonest first.
    public var meetings: [Meeting]
    public var pausedUntil: Date?
    /// How many events the calendar returned before any filtering. Lets the UI tell "no events" from "all filtered out".
    public var eventsRead: Int
    /// When the calendar was last read successfully; nil if it never was.
    public var lastSuccessfulRead: Date?

    public init(
        generatedAt: Date,
        authorization: CalendarAuthorization,
        calendars: [CalendarInfo],
        meetings: [Meeting],
        pausedUntil: Date?,
        eventsRead: Int = 0,
        lastSuccessfulRead: Date? = nil
    ) {
        self.generatedAt = generatedAt
        self.authorization = authorization
        self.calendars = calendars
        self.meetings = meetings
        self.pausedUntil = pausedUntil
        self.eventsRead = eventsRead
        self.lastSuccessfulRead = lastSuccessfulRead
    }
}

// MARK: - Engine

/// Owns the single sleeping task that decides when to remind.
///
/// Event-driven: it recomputes the plan from calendar + ledger + settings whenever something
/// may have changed (`requestReplan`), and otherwise sleeps until the next reminder is due,
/// capped by a heartbeat that catches changes nobody told us about. Because every plan is derived
/// from scratch, a duplicate or missed trigger is harmless.
public actor ReminderEngine {
    public struct Timing: Sendable {
        public var heartbeat: TimeInterval
        public var lookahead: TimeInterval
        public var ledgerRetention: TimeInterval
        /// Lower bound on the sleep so a bug can never turn the loop into a busy spin.
        public var minimumSleep: TimeInterval

        public init(
            heartbeat: TimeInterval = 5 * 60,
            lookahead: TimeInterval = 36 * 3600,
            ledgerRetention: TimeInterval = 7 * 24 * 3600,
            minimumSleep: TimeInterval = 0.25
        ) {
            self.heartbeat = heartbeat
            self.lookahead = lookahead
            self.ledgerRetention = ledgerRetention
            self.minimumSleep = minimumSleep
        }
    }

    public nonisolated let events: AsyncStream<ReminderEvent>
    public nonisolated let snapshots: AsyncStream<EngineSnapshot>

    private let eventContinuation: AsyncStream<ReminderEvent>.Continuation
    private let snapshotContinuation: AsyncStream<EngineSnapshot>.Continuation

    private let calendar: any CalendarProviding
    private let store: any LedgerStore
    private let clock: any SchedulerClock
    private let timing: Timing

    private var settings: AppSettings
    private var ledger = ReminderLedger()
    private var ledgerLoaded = false
    /// Reminders currently on screen, with the meeting they belong to.
    private var presenting: [ReminderKey: Meeting] = [:]
    /// The most recent filtered meeting list.
    private var meetings: [Meeting] = []
    private var eventsRead = 0
    private var lastSuccessfulRead: Date?

    private var loopTask: Task<Void, Never>?
    private var sleeperTask: Task<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var wakePending = false
    private var planGeneration = 0
    private var lastDeadline: Date

    public init(
        calendar: any CalendarProviding,
        store: any LedgerStore,
        clock: any SchedulerClock = SystemSchedulerClock(),
        settings: AppSettings = AppSettings(),
        timing: Timing = Timing()
    ) {
        let (events, eventContinuation) = AsyncStream.makeStream(of: ReminderEvent.self)
        let (snapshots, snapshotContinuation) = AsyncStream.makeStream(
            of: EngineSnapshot.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.events = events
        self.eventContinuation = eventContinuation
        self.snapshots = snapshots
        self.snapshotContinuation = snapshotContinuation
        self.calendar = calendar
        self.store = store
        self.clock = clock
        self.settings = settings
        self.timing = timing
        self.lastDeadline = clock.now().addingTimeInterval(timing.heartbeat)
    }

    // MARK: Lifecycle

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
        sleeperTask?.cancel()
        sleeperTask = nil
        waiter?.resume()
        waiter = nil
    }

    /// Cheap, coalescing "something may have changed". Safe to call from any trigger, any number of times.
    public func requestReplan() {
        wake()
    }

    /// Replan right now and wait for it. Used by tests and by user actions that need an up-to-date state.
    public func replan() async {
        await performPlan()
        wake()
    }

    public func updateSettings(_ newSettings: AppSettings) {
        guard newSettings != settings else { return }
        settings = newSettings
        wake()
    }

    // MARK: User actions

    public func join(_ occurrence: OccurrenceKey) async {
        await resolve(occurrence, as: .joined)
    }

    public func dismiss(_ occurrence: OccurrenceKey) async {
        await resolve(occurrence, as: .dismissed)
    }

    /// Hides the reminder and brings it back after `minutes`, never later than the meeting's end.
    public func snooze(_ key: ReminderKey, minutes: Int) async {
        await loadLedgerIfNeeded()
        let now = clock.now()
        guard let meeting = presenting[key] ?? meetings.first(where: { $0.occurrenceKey == key.occurrence }) else {
            return
        }
        let until = min(now.addingTimeInterval(TimeInterval(max(1, minutes)) * 60), meeting.endDate)
        guard until > now else {
            await resolve(key.occurrence, as: .dismissed)
            return
        }
        removePresenting(for: key.occurrence)
        ledger.setState(.snoozed(until: until), for: key, meetingEnd: meeting.endDate)
        await store.save(ledger)
        wake()
    }

    /// Keys currently on screen. Exposed for tests and diagnostics.
    public func presentingKeys() -> Set<ReminderKey> {
        Set(presenting.keys)
    }

    // MARK: Loop

    private func runLoop() async {
        while !Task.isCancelled {
            let deadline = await performPlan()
            await waitUntil(deadline)
        }
    }

    private func waitUntil(_ deadline: Date) async {
        if wakePending {
            wakePending = false
            return
        }
        sleeperTask?.cancel()
        sleeperTask = Task { [clock] in
            do {
                try await clock.sleep(until: deadline)
            } catch {
                return
            }
            self.wake()
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter = continuation
        }
        sleeperTask?.cancel()
        sleeperTask = nil
    }

    private func wake() {
        if let waiter {
            self.waiter = nil
            waiter.resume()
        } else {
            wakePending = true
        }
    }

    // MARK: Planning

    /// Fetch, plan, emit. Everything between the fetch and the commit is synchronous, so actor
    /// re-entrancy cannot interleave two plans and emit a reminder twice.
    @discardableResult
    private func performPlan() async -> Date {
        await loadLedgerIfNeeded()
        planGeneration += 1
        let generation = planGeneration

        let authorization = await calendar.authorizationStatus()
        var calendars: [CalendarInfo] = []
        var fetched: [Meeting]?
        if authorization == .authorized {
            calendars = await calendar.calendars()
            let from = clock.now()
            fetched = try? await calendar.meetings(from: from, to: from.addingTimeInterval(timing.lookahead))
        }

        // A newer plan started while we were fetching: let it win.
        guard generation == planGeneration else { return lastDeadline }

        let now = clock.now()
        let ledgerBefore = ledger

        if let fetched {
            meetings = MeetingFilter.apply(fetched, settings: settings)
            eventsRead = fetched.count
            lastSuccessfulRead = now
        } else if authorization != .authorized {
            meetings = []
        }  // else: the fetch failed; keep the last known meetings rather than showing nothing.

        ledger.prune(before: now.addingTimeInterval(-timing.ledgerRetention))
        withdrawStaleReminders(now: now, calendarWasRead: fetched != nil)

        let plan = ReminderPlanner.plan(
            meetings: meetings,
            settings: settings,
            ledger: ledger,
            presenting: Set(presenting.keys),
            now: now
        )

        for key in plan.expired {
            ledger.setState(.expired, for: key, meetingEnd: meetingEnd(for: key.occurrence))
        }

        let paused = settings.isPaused(at: now)
        if !paused {
            for item in plan.due {
                emitDue(item, now: now)
            }
        }

        snapshotContinuation.yield(
            EngineSnapshot(
                generatedAt: now,
                authorization: authorization,
                calendars: calendars,
                meetings: meetings.filter { $0.endDate > now },
                pausedUntil: paused ? settings.pausedUntil : nil,
                eventsRead: eventsRead,
                lastSuccessfulRead: lastSuccessfulRead
            )
        )

        var deadline = now.addingTimeInterval(timing.heartbeat)
        if let next = plan.upcoming.first?.fireAt { deadline = min(deadline, next) }
        if paused, let pausedUntil = settings.pausedUntil { deadline = min(deadline, pausedUntil) }
        for meeting in presenting.values where meeting.endDate > now {
            deadline = min(deadline, meeting.endDate)
        }
        deadline = max(deadline, now.addingTimeInterval(timing.minimumSleep))
        lastDeadline = deadline

        if ledger != ledgerBefore {
            await store.save(ledger)
        }
        return deadline
    }

    private func withdrawStaleReminders(now: Date, calendarWasRead: Bool) {
        for (key, meeting) in presenting {
            let ended = meeting.endDate <= now
            let stillScheduled = meetings.contains { $0.occurrenceKey == key.occurrence }
            guard ended || (calendarWasRead && !stillScheduled) else { continue }
            presenting[key] = nil
            ledger.setState(.expired, for: key, meetingEnd: meeting.endDate)
            eventContinuation.yield(.withdrawn(key, ended ? .meetingEnded : .meetingChanged))
        }
    }

    private func emitDue(_ item: PlannedReminder, now: Date) {
        // A newer reminder for the same meeting replaces the one on screen (3 min before -> at start).
        for (key, _) in presenting where key.occurrence == item.key.occurrence && key != item.key {
            presenting[key] = nil
            ledger.setState(.expired, for: key, meetingEnd: item.meeting.endDate)
        }
        presenting[item.key] = item.meeting
        ledger.setState(.presented, for: item.key, meetingEnd: item.meeting.endDate)
        eventContinuation.yield(.due(DueReminder(key: item.key, meeting: item.meeting, firedAt: now)))
    }

    // MARK: Helpers

    private func resolve(_ occurrence: OccurrenceKey, as resolution: ReminderLedger.Resolution) async {
        await loadLedgerIfNeeded()
        let end = meetingEnd(for: occurrence)
        removePresenting(for: occurrence)
        ledger.resolve(occurrence, as: resolution, meetingEnd: end)
        await store.save(ledger)
        wake()
    }

    private func removePresenting(for occurrence: OccurrenceKey) {
        for key in presenting.keys where key.occurrence == occurrence {
            presenting[key] = nil
        }
    }

    private func meetingEnd(for occurrence: OccurrenceKey) -> Date {
        if let meeting = meetings.first(where: { $0.occurrenceKey == occurrence }) { return meeting.endDate }
        if let meeting = presenting.first(where: { $0.key.occurrence == occurrence })?.value { return meeting.endDate }
        return occurrence.startAt.addingTimeInterval(4 * 3600)
    }

    private func loadLedgerIfNeeded() async {
        guard !ledgerLoaded else { return }
        let loaded = await store.load()
        // Re-check: another call may have loaded (and already mutated) the ledger while we waited.
        guard !ledgerLoaded else { return }
        ledger = loaded
        ledgerLoaded = true
    }
}
