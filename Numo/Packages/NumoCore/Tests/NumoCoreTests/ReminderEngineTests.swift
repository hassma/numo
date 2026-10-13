import Foundation
import Testing

@testable import NumoCore

/// End-to-end engine behaviour against a fake calendar, an in-memory ledger and a manual clock.
/// `engine.replan()` runs a plan inline and deterministically; the `start()` test drives the real loop.
@Suite(.timeLimit(.minutes(1)))
struct ReminderEngineTests {
    let start = t0.addingTimeInterval(600)  // 10 minutes after `t0`

    private func makeEngine(
        meetings: [Meeting],
        settings: AppSettings = AppSettings(),
        store: InMemoryLedgerStore = InMemoryLedgerStore(),
        calendar: FakeCalendar? = nil,
        clock: ManualClock? = nil
    ) -> (engine: ReminderEngine, clock: ManualClock, calendar: FakeCalendar, store: InMemoryLedgerStore) {
        let clock = clock ?? ManualClock(t0)
        let calendar = calendar ?? FakeCalendar(meetings)
        let engine = ReminderEngine(calendar: calendar, store: store, clock: clock, settings: settings)
        return (engine, clock, calendar, store)
    }

    private func dueLeads(_ events: [ReminderEvent]) -> [Int] {
        events.compactMap {
            if case .due(let reminder) = $0 { return reminder.key.leadSeconds }
            return nil
        }
    }

    @Test func nothingFiresBeforeTheFirstLeadTime() async {
        let (engine, _, _, _) = makeEngine(meetings: [makeMeeting(start: start)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        await engine.replan()
        await recorder.settle()

        #expect(await recorder.events.isEmpty)
        #expect(await engine.presentingKeys().isEmpty)
    }

    @Test func leadReminderFiresOnceEvenIfPlannedRepeatedly() async {
        let (engine, clock, _, _) = makeEngine(meetings: [makeMeeting(start: start)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await engine.replan()
        await engine.replan()
        await recorder.waitForCount(1)
        await recorder.settle()

        #expect(dueLeads(await recorder.events) == [180])
        #expect(await engine.presentingKeys().count == 1)
    }

    @Test func atStartReminderReplacesTheLeadReminderOnScreen() async {
        let (engine, clock, _, _) = makeEngine(meetings: [makeMeeting(start: start)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        clock.advance(to: start)
        await engine.replan()
        await recorder.waitForCount(2)

        #expect(dueLeads(await recorder.events) == [180, 0])
        let keys = await engine.presentingKeys()
        #expect(keys.map(\.leadSeconds) == [0])
    }

    @Test func runningLoopWakesAtEachFireTimeWithoutAnyExternalTrigger() async {
        let (engine, clock, _, _) = makeEngine(meetings: [makeMeeting(start: start)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        await engine.start()
        await clock.waitForSleeper()
        clock.advance(to: start.addingTimeInterval(-180))
        await recorder.waitForCount(1)

        await clock.waitForSleeper()
        clock.advance(to: start)
        await recorder.waitForCount(2)
        await engine.stop()

        #expect(dueLeads(await recorder.events) == [180, 0])
    }

    @Test func joiningSilencesEveryLaterReminderOfThatMeeting() async {
        let meeting = makeMeeting(start: start)
        let (engine, clock, _, _) = makeEngine(meetings: [meeting])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(1)
        await engine.join(meeting.occurrenceKey)
        #expect(await engine.presentingKeys().isEmpty)

        clock.advance(to: start.addingTimeInterval(30))
        await engine.replan()
        await recorder.settle()

        #expect(dueLeads(await recorder.events) == [180])
    }

    @Test func dismissIsPermanentForThatOccurrenceOnly() async {
        let week = 7 * 24 * 3600.0
        let first = makeMeeting("series", start: start)
        let next = makeMeeting("series", start: start.addingTimeInterval(week))
        let (engine, clock, _, _) = makeEngine(meetings: [first, next])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(1)
        await engine.dismiss(first.occurrenceKey)

        clock.advance(to: start.addingTimeInterval(60))
        await engine.replan()
        await recorder.settle()
        #expect(dueLeads(await recorder.events) == [180])

        clock.advance(to: next.startDate.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(2)
        #expect(dueLeads(await recorder.events) == [180, 180])
    }

    @Test func snoozeBringsTheSameReminderBack() async {
        let meeting = makeMeeting(start: start)
        let (engine, clock, _, _) = makeEngine(meetings: [meeting])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(1)
        let key = await engine.presentingKeys().first!

        await engine.snooze(key, minutes: 1)
        #expect(await engine.presentingKeys().isEmpty)

        clock.advance(to: start.addingTimeInterval(-170 + 59))
        await engine.replan()
        await recorder.settle()
        #expect(await recorder.events.count == 1, "still snoozed after 59 s")

        clock.advance(to: start.addingTimeInterval(-170 + 60))
        await engine.replan()
        await recorder.waitForCount(2)
        #expect(dueLeads(await recorder.events) == [180, 180])
    }

    @Test func snoozeIsCappedAtTheEndOfTheMeeting() async {
        let meeting = makeMeeting(start: start, minutes: 2)
        let (engine, clock, _, store) = makeEngine(meetings: [meeting])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        // One minute before the meeting ends, a 5 minute snooze must not outlive it.
        clock.advance(to: start.addingTimeInterval(60))
        await engine.replan()
        await recorder.waitForCount(1)
        let key = await engine.presentingKeys().first!
        await engine.snooze(key, minutes: 5)

        let saved = await store.load()
        #expect(saved.state(for: key) == .snoozed(until: meeting.endDate))
    }

    @Test func sleepingThroughLeadAndStartShowsOneLateReminder() async {
        let (engine, clock, _, _) = makeEngine(meetings: [makeMeeting(start: start)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(120))  // woke 2 minutes after the start
        await engine.replan()
        await recorder.waitForCount(1)
        await recorder.settle()

        #expect(dueLeads(await recorder.events) == [0])
    }

    @Test func wakingLongAfterTheStartStaysSilent() async {
        let (engine, clock, _, _) = makeEngine(meetings: [makeMeeting(start: start, minutes: 60)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(20 * 60))
        await engine.replan()
        await recorder.settle()

        #expect(await recorder.events.isEmpty)
        #expect(await engine.presentingKeys().isEmpty)
    }

    @Test func cancelledMeetingWithdrawsTheVisibleReminder() async {
        let meeting = makeMeeting(start: start)
        let (engine, clock, calendar, _) = makeEngine(meetings: [meeting])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(1)

        await calendar.set([])
        await engine.replan()
        await recorder.waitForCount(2)

        let events = await recorder.events
        guard case .withdrawn(_, let reason) = events[1] else {
            Issue.record("expected a withdrawal, got \(events[1])")
            return
        }
        #expect(reason == .meetingChanged)
        #expect(await engine.presentingKeys().isEmpty)
    }

    @Test func movedMeetingWithdrawsAndRemindsAtTheNewTime() async {
        let original = makeMeeting("m", start: start)
        let (engine, clock, calendar, _) = makeEngine(meetings: [original])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(1)

        let moved = makeMeeting("m", start: start.addingTimeInterval(3600))
        await calendar.set([moved])
        await engine.replan()
        await recorder.waitForCount(2)  // the withdrawal of the old reminder
        #expect(await engine.presentingKeys().isEmpty)

        clock.advance(to: moved.startDate.addingTimeInterval(-170))
        await engine.replan()
        await recorder.waitForCount(3)
        #expect(dueLeads(await recorder.events) == [180, 180])
    }

    @Test func reminderOnScreenIsWithdrawnWhenTheMeetingEnds() async {
        let meeting = makeMeeting(start: start, minutes: 5)
        let (engine, clock, _, _) = makeEngine(meetings: [meeting])
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start)
        await engine.replan()
        await recorder.waitForCount(1)

        clock.advance(to: meeting.endDate)
        await engine.replan()
        await recorder.waitForCount(2)

        guard case .withdrawn(_, let reason) = await recorder.events[1] else {
            Issue.record("expected a withdrawal")
            return
        }
        #expect(reason == .meetingEnded)
    }

    @Test func revokedCalendarAccessIsReportedAndNeverAlerts() async {
        let (engine, clock, calendar, _) = makeEngine(meetings: [makeMeeting(start: start)])
        let (recorder, task) = record(engine)
        defer { task.cancel() }
        await calendar.set(authorization: .denied)

        clock.advance(to: start)
        await engine.replan()
        await recorder.settle()

        var iterator = engine.snapshots.makeAsyncIterator()
        let snapshot = await iterator.next()
        #expect(snapshot?.authorization == .denied)
        #expect(snapshot?.meetings.isEmpty == true)
        #expect(await recorder.events.isEmpty)
    }

    @Test func pausingHoldsRemindersBackAndResumingCatchesUp() async {
        var paused = AppSettings()
        paused.pausedUntil = t0.addingTimeInterval(3600)
        let (engine, clock, _, _) = makeEngine(meetings: [makeMeeting(start: start)], settings: paused)
        let (recorder, task) = record(engine)
        defer { task.cancel() }

        clock.advance(to: start.addingTimeInterval(-170))
        await engine.replan()
        await recorder.settle()
        #expect(await recorder.events.isEmpty, "paused: nothing may fire")

        await engine.updateSettings(AppSettings())
        await engine.replan()
        await recorder.waitForCount(1)
        #expect(dueLeads(await recorder.events) == [180])
    }

    @Test func snoozeSurvivesARelaunch() async {
        let meeting = makeMeeting(start: start)
        let store = InMemoryLedgerStore()
        let calendar = FakeCalendar([meeting])
        let clock = ManualClock(t0)

        // First run: reminder shows, user snoozes for 2 minutes, app quits.
        let first = ReminderEngine(calendar: calendar, store: store, clock: clock)
        let (firstRecorder, firstTask) = record(first)
        clock.advance(to: start.addingTimeInterval(-170))
        await first.replan()
        await firstRecorder.waitForCount(1)
        let key = await first.presentingKeys().first!
        await first.snooze(key, minutes: 2)
        firstTask.cancel()

        // Second run, a minute later: still snoozed, nothing shown.
        let second = ReminderEngine(calendar: calendar, store: store, clock: clock)
        let (secondRecorder, secondTask) = record(second)
        defer { secondTask.cancel() }
        clock.advance(to: start.addingTimeInterval(-110))
        await second.replan()
        await secondRecorder.settle()
        #expect(await secondRecorder.events.isEmpty)

        // The snooze elapses: it comes back exactly once.
        clock.advance(to: start.addingTimeInterval(-50))
        await second.replan()
        await secondRecorder.waitForCount(1)
        await second.replan()
        await secondRecorder.settle()
        #expect(dueLeads(await secondRecorder.events) == [180])
    }

    @Test func reminderShownBeforeACrashIsShownAgainOnRelaunch() async {
        let meeting = makeMeeting(start: start)
        let store = InMemoryLedgerStore()
        let calendar = FakeCalendar([meeting])
        let clock = ManualClock(t0)

        let first = ReminderEngine(calendar: calendar, store: store, clock: clock)
        let (firstRecorder, firstTask) = record(first)
        clock.advance(to: start.addingTimeInterval(-170))
        await first.replan()
        await firstRecorder.waitForCount(1)
        firstTask.cancel()  // "crash": nobody acted on it, the ledger says `presented`

        let second = ReminderEngine(calendar: calendar, store: store, clock: clock)
        let (secondRecorder, secondTask) = record(second)
        defer { secondTask.cancel() }
        await second.replan()
        await secondRecorder.waitForCount(1)

        #expect(dueLeads(await secondRecorder.events) == [180])
    }
}
