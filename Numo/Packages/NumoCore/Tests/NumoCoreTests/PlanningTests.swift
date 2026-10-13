import Foundation
import Testing

@testable import NumoCore

struct MeetingFilterTests {
    let start = t0.addingTimeInterval(600)

    @Test func dropsCancelledDeclinedAllDayAndLinkless() {
        let meetings = [
            makeMeeting("ok", start: start),
            makeMeeting("cancelled", start: start, isCancelled: true),
            makeMeeting("declined", start: start, isDeclined: true),
            makeMeeting("allday", start: start, isAllDay: true),
            makeMeeting("nolink", start: start, link: nil),
        ]
        let result = MeetingFilter.apply(meetings, settings: AppSettings())
        #expect(result.map(\.id.externalID) == ["ok"])
    }

    @Test func settingsCanReadmitEverythingButCancelled() {
        var settings = AppSettings()
        settings.includeAllDayEvents = true
        settings.includeDeclinedEvents = true
        settings.requireMeetingLink = false
        // Distinct start times so the cross-calendar duplicate filter does not merge them.
        let meetings = [
            makeMeeting("a", start: start, title: "A"),
            makeMeeting("cancelled", start: start.addingTimeInterval(60), title: "B", isCancelled: true),
            makeMeeting("declined", start: start.addingTimeInterval(120), title: "C", isDeclined: true),
            makeMeeting("allday", start: start.addingTimeInterval(180), title: "D", isAllDay: true),
            makeMeeting("nolink", start: start.addingTimeInterval(240), title: "E", link: nil),
        ]
        let result = MeetingFilter.apply(meetings, settings: settings)
        #expect(Set(result.map(\.id.externalID)) == ["a", "declined", "allday", "nolink"])
    }

    @Test func disabledCalendarIsExcluded() {
        var settings = AppSettings()
        settings.disabledCalendarIDs = ["personal"]
        let meetings = [
            makeMeeting("work", start: start, calendarID: "work"),
            makeMeeting("home", start: start, calendarID: "personal", link: teamsLink),
        ]
        #expect(MeetingFilter.apply(meetings, settings: settings).map(\.id.externalID) == ["work"])
    }

    @Test func sameMeetingInTwoCalendarsAlertsOnce() {
        let meetings = [
            makeMeeting("a-copy", start: start, calendarID: "work"),
            makeMeeting("b-copy", start: start, calendarID: "personal"),
        ]
        #expect(MeetingFilter.apply(meetings, settings: AppSettings()).count == 1)
    }

    @Test func recurringSeriesSharingOneLinkIsNotCollapsed() {
        let week = 7 * 24 * 3600.0
        let meetings = [
            makeMeeting("series", start: start),
            makeMeeting("series", start: start.addingTimeInterval(week)),
        ]
        #expect(MeetingFilter.apply(meetings, settings: AppSettings()).count == 2)
    }

    @Test func linklessDuplicatesCollapseByTitleAndTime() {
        var settings = AppSettings()
        settings.requireMeetingLink = false
        let meetings = [
            makeMeeting("x", start: start, title: "Standup", calendarID: "a", link: nil),
            makeMeeting("y", start: start, title: "standup", calendarID: "b", link: nil),
        ]
        #expect(MeetingFilter.apply(meetings, settings: settings).count == 1)
    }

    @Test func resultIsSortedByStart() {
        let meetings = [
            makeMeeting("late", start: start.addingTimeInterval(3600), link: teamsLink),
            makeMeeting("early", start: start),
        ]
        #expect(MeetingFilter.apply(meetings, settings: AppSettings()).map(\.id.externalID) == ["early", "late"])
    }
}

struct ReminderPlannerTests {
    let start = t0.addingTimeInterval(600)  // meeting starts 10 minutes after `t0`

    private func plan(
        _ meetings: [Meeting],
        now: Date,
        settings: AppSettings = AppSettings(),
        ledger: ReminderLedger = ReminderLedger(),
        presenting: Set<ReminderKey> = []
    ) -> ReminderPlan {
        ReminderPlanner.plan(meetings: meetings, settings: settings, ledger: ledger, presenting: presenting, now: now)
    }

    @Test func plansOneReminderPerLeadTime() {
        let result = plan([makeMeeting(start: start)], now: t0)
        #expect(result.due.isEmpty)
        #expect(result.upcoming.map(\.fireAt) == [start.addingTimeInterval(-180), start])
        #expect(result.upcoming.map(\.key.leadSeconds) == [180, 0])
    }

    @Test func leadTimeBecomesDueExactlyAtItsFireTime() {
        let fire = start.addingTimeInterval(-180)
        #expect(plan([makeMeeting(start: start)], now: fire.addingTimeInterval(-1)).due.isEmpty)
        let result = plan([makeMeeting(start: start)], now: fire)
        #expect(result.due.map(\.key.leadSeconds) == [180])
        #expect(result.upcoming.map(\.key.leadSeconds) == [0])
    }

    @Test func overdueLeadsAreCollapsedToTheMostUrgent() {
        // Woke from sleep 1 minute after the start: both reminders are overdue, show only "at start".
        let now = start.addingTimeInterval(60)
        let result = plan([makeMeeting(start: start)], now: now)
        #expect(result.due.map(\.key.leadSeconds) == [0])
        #expect(result.expired.map(\.leadSeconds) == [180])
    }

    @Test func staleFirstShowingsAreDroppedSilently() {
        let now = start.addingTimeInterval(11 * 60)  // beyond the 10 minute catch-up window
        let result = plan([makeMeeting(start: start, minutes: 60)], now: now)
        #expect(result.due.isEmpty)
        #expect(Set(result.expired.map(\.leadSeconds)) == [180, 0])
    }

    @Test func snoozedReminderIsHonouredEvenPastTheCatchUpWindow() {
        let meeting = makeMeeting(start: start, minutes: 60)
        let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: 0)
        var ledger = ReminderLedger()
        let until = start.addingTimeInterval(12 * 60)
        ledger.setState(.snoozed(until: until), for: key, meetingEnd: meeting.endDate)

        let before = plan([meeting], now: until.addingTimeInterval(-1), ledger: ledger)
        #expect(before.due.isEmpty)
        #expect(before.upcoming.contains { $0.key == key && $0.fireAt == until })

        let after = plan([meeting], now: until, ledger: ledger)
        #expect(after.due.map(\.key) == [key])
    }

    @Test func joinedAndDismissedMeetingsAreSilent() {
        let meeting = makeMeeting(start: start)
        for resolution in [ReminderLedger.Resolution.joined, .dismissed] {
            var ledger = ReminderLedger()
            ledger.resolve(meeting.occurrenceKey, as: resolution, meetingEnd: meeting.endDate)
            let result = plan([meeting], now: start, ledger: ledger)
            #expect(result.due.isEmpty && result.upcoming.isEmpty && result.expired.isEmpty)
        }
    }

    @Test func expiredReminderIsNeverPlannedAgain() {
        let meeting = makeMeeting(start: start)
        let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: 180)
        var ledger = ReminderLedger()
        ledger.setState(.expired, for: key, meetingEnd: meeting.endDate)
        let result = plan([meeting], now: t0, ledger: ledger)
        #expect(result.upcoming.map(\.key.leadSeconds) == [0])
    }

    @Test func persistedPresentedStateWithoutAScreenIsTreatedAsFresh() {
        // The app died after showing the reminder; on relaunch it must be shown again.
        let meeting = makeMeeting(start: start)
        let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: 180)
        var ledger = ReminderLedger()
        ledger.setState(.presented, for: key, meetingEnd: meeting.endDate)
        let now = start.addingTimeInterval(-120)
        #expect(plan([meeting], now: now, ledger: ledger).due.map(\.key) == [key])
    }

    @Test func reminderOnScreenIsNotPlannedAgain() {
        let meeting = makeMeeting(start: start)
        let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: 180)
        let now = start.addingTimeInterval(-120)
        #expect(plan([meeting], now: now, presenting: [key]).due.isEmpty)
    }

    @Test func endedMeetingsAreIgnored() {
        let meeting = makeMeeting(start: start, minutes: 30)
        let result = plan([meeting], now: meeting.endDate)
        #expect(result.due.isEmpty && result.upcoming.isEmpty && result.expired.isEmpty)
    }

    @Test func movedMeetingGetsFreshReminders() {
        let original = makeMeeting("m", start: start)
        let key = ReminderKey(occurrence: original.occurrenceKey, leadSeconds: 180)
        var ledger = ReminderLedger()
        ledger.setState(.expired, for: key, meetingEnd: original.endDate)

        let moved = makeMeeting("m", start: start.addingTimeInterval(3600))
        let result = plan([moved], now: t0, ledger: ledger)
        #expect(result.upcoming.map(\.key.leadSeconds) == [180, 0])
    }

    @Test func customLeadTimesAreRespectedAndSanitised() {
        var settings = AppSettings()
        settings.leadTimesMinutes = [5, 1, 1, -2, 0]
        let result = plan([makeMeeting(start: start)], now: t0, settings: settings)
        // Negative leads and duplicates are dropped; the rest fire in time order (5 min, 1 min, at start).
        #expect(result.upcoming.map(\.key.leadSeconds) == [300, 60, 0])
    }

    @Test func leadsAreAbsoluteAcrossTheDSTSpringForward() {
        // Europe/Berlin jumps from 02:00 CET to 03:00 CEST on 2027-03-28. A meeting at 03:00 CEST
        // (01:00Z) with a 3 minute lead must fire at 00:57Z, even though the local clock reads 01:57.
        let startUTC = iso("2027-03-28T01:00:00Z")
        let now = iso("2027-03-28T00:00:00Z")
        let result = plan([makeMeeting(start: startUTC)], now: now)
        #expect(result.upcoming.first?.fireAt == iso("2027-03-28T00:57:00Z"))
    }

    @Test func recurringOccurrencesAreIndependent() {
        let week = 7 * 24 * 3600.0
        let first = makeMeeting("series", start: start)
        let second = makeMeeting("series", start: start.addingTimeInterval(week))
        var ledger = ReminderLedger()
        ledger.resolve(first.occurrenceKey, as: .dismissed, meetingEnd: first.endDate)
        let result = plan([first, second], now: t0, ledger: ledger)
        #expect(result.upcoming.allSatisfy { $0.meeting.startDate == second.startDate })
        #expect(result.upcoming.count == 2)
    }
}

struct ReminderLedgerTests {
    @Test func roundTripsThroughJSON() throws {
        let meeting = makeMeeting(start: t0.addingTimeInterval(600))
        let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: 180)
        var ledger = ReminderLedger()
        ledger.setState(.snoozed(until: t0.addingTimeInterval(300)), for: key, meetingEnd: meeting.endDate)
        ledger.resolve(meeting.occurrenceKey, as: .joined, meetingEnd: meeting.endDate)

        let data = try JSONEncoder().encode(ledger)
        let decoded = try JSONDecoder().decode(ReminderLedger.self, from: data)
        #expect(decoded == ledger)
        #expect(decoded.state(for: key) == .snoozed(until: t0.addingTimeInterval(300)))
        #expect(decoded.resolution(for: meeting.occurrenceKey) == .joined)
    }

    @Test func pruneRemovesOnlyOldMeetings() {
        let old = makeMeeting("old", start: t0)
        let recent = makeMeeting("recent", start: t0.addingTimeInterval(10 * 24 * 3600))
        var ledger = ReminderLedger()
        ledger.resolve(old.occurrenceKey, as: .dismissed, meetingEnd: old.endDate)
        ledger.resolve(recent.occurrenceKey, as: .dismissed, meetingEnd: recent.endDate)

        ledger.prune(before: t0.addingTimeInterval(5 * 24 * 3600))
        #expect(ledger.resolution(for: old.occurrenceKey) == nil)
        #expect(ledger.resolution(for: recent.occurrenceKey) == .dismissed)
    }

    @Test func corruptOrMissingFileYieldsEmptyLedger() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("numo-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileLedgerStore(url: directory.appendingPathComponent("ledger.json"))

        #expect(await store.load().isEmpty)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        #expect(await store.load().isEmpty)
    }

    @Test func fileStorePersistsAcrossInstances() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("numo-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("nested/ledger.json")

        let meeting = makeMeeting(start: t0.addingTimeInterval(600))
        var ledger = ReminderLedger()
        ledger.resolve(meeting.occurrenceKey, as: .dismissed, meetingEnd: meeting.endDate)
        await FileLedgerStore(url: url).save(ledger)

        let reloaded = await FileLedgerStore(url: url).load()
        #expect(reloaded.resolution(for: meeting.occurrenceKey) == .dismissed)
    }
}

struct SettingsAndCopyTests {
    @Test func emptyJSONDecodesToDefaults() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(decoded == AppSettings())
    }

    @Test func partialJSONKeepsOtherDefaults() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"defaultSnoozeMinutes": 5}"#.utf8))
        #expect(decoded.defaultSnoozeMinutes == 5)
        #expect(decoded.leadTimesMinutes == [3, 0])
    }

    @Test func settingsRoundTrip() throws {
        var settings = AppSettings()
        settings.disabledCalendarIDs = ["a", "b"]
        settings.pausedUntil = t0
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func pauseExpires() {
        var settings = AppSettings()
        settings.pausedUntil = t0.addingTimeInterval(60)
        #expect(settings.isPaused(at: t0))
        #expect(!settings.isPaused(at: t0.addingTimeInterval(60)))
    }

    @Test(arguments: [
        (-300.0, UrgencyStage.upcoming), (-61.0, .upcoming), (-60.0, .now), (0.0, .now),
        (60.0, .now), (61.0, .late), (300.0, .late), (301.0, .overdue),
    ])
    func stageBoundaries(_ seconds: Double, _ expected: UrgencyStage) {
        #expect(UrgencyStage.stage(secondsSinceStart: seconds) == expected)
    }

    @Test func eyebrowCopy() {
        #expect(ReminderCopy.eyebrow(secondsSinceStart: -180) == "Starting in 3 min")
        #expect(ReminderCopy.eyebrow(secondsSinceStart: -61) == "Starting in 2 min")
        #expect(ReminderCopy.eyebrow(secondsSinceStart: 0) == "Meeting starting now")
        #expect(ReminderCopy.eyebrow(secondsSinceStart: 125) == "Started 2 min ago")
        #expect(ReminderCopy.eyebrow(secondsSinceStart: 7 * 60) == "Started 7 min ago")
    }

    @Test func clockAndCompactCountdown() {
        #expect(ReminderCopy.clock(secondsSinceStart: -179) == "2:59")
        #expect(ReminderCopy.clock(secondsSinceStart: 65) == "+1:05")
        #expect(ReminderCopy.compactCountdown(secondsUntilStart: 12 * 60 + 10) == "in 13m")
        #expect(ReminderCopy.compactCountdown(secondsUntilStart: 30) == "in 1m")
        #expect(ReminderCopy.compactCountdown(secondsUntilStart: 0) == "Now")
        #expect(ReminderCopy.compactCountdown(secondsUntilStart: -90) == "Now")
        #expect(ReminderCopy.compactCountdown(secondsUntilStart: 3601) == nil)
    }
}
