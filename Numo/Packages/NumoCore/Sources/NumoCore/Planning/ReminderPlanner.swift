import Foundation

public struct PlannedReminder: Hashable, Sendable {
    public let key: ReminderKey
    public let meeting: Meeting
    public let fireAt: Date
    /// True when this is a snoozed reminder coming back, not a first showing.
    public let isSnoozeReturn: Bool

    public init(key: ReminderKey, meeting: Meeting, fireAt: Date, isSnoozeReturn: Bool) {
        self.key = key
        self.meeting = meeting
        self.fireAt = fireAt
        self.isSnoozeReturn = isSnoozeReturn
    }
}

public struct ReminderPlan: Sendable, Equatable {
    /// Not yet due, soonest first.
    public var upcoming: [PlannedReminder] = []
    /// Due now: at most one per meeting (the most urgent), ordered by meeting start.
    public var due: [PlannedReminder] = []
    /// Reminders that should be recorded as expired: too late to be useful, or superseded.
    public var expired: [ReminderKey] = []

    public init() {}
}

/// Pure function of (meetings, settings, ledger, what is on screen, now). Everything time related
/// is derived from absolute `Date`s, so DST and time-zone changes cannot shift a reminder.
public enum ReminderPlanner {
    public static func plan(
        meetings: [Meeting],
        settings: AppSettings,
        ledger: ReminderLedger,
        presenting: Set<ReminderKey>,
        now: Date
    ) -> ReminderPlan {
        let leads = Array(Set(settings.leadTimesMinutes.filter { $0 >= 0 })).sorted(by: >)
        let catchUp = TimeInterval(settings.catchUpWindowMinutes) * 60
        var plan = ReminderPlan()

        for meeting in meetings.sorted(by: { $0.startDate < $1.startDate }) {
            guard meeting.endDate > now, ledger.resolution(for: meeting.occurrenceKey) == nil else { continue }

            var past: [PlannedReminder] = []
            for lead in leads {
                let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: lead * 60)
                // On screen right now. (A persisted `presented` state without being on screen means
                // the app died after showing it, so it is treated like a fresh reminder.)
                if presenting.contains(key) { continue }

                var fireAt = meeting.startDate.addingTimeInterval(-TimeInterval(lead * 60))
                var isSnoozeReturn = false
                switch ledger.state(for: key) {
                case .expired:
                    continue
                case .snoozed(let until):
                    fireAt = until
                    isSnoozeReturn = true
                case .presented, .none:
                    break
                }

                let item = PlannedReminder(key: key, meeting: meeting, fireAt: fireAt, isSnoozeReturn: isSnoozeReturn)
                if fireAt > now {
                    plan.upcoming.append(item)
                } else {
                    past.append(item)
                }
            }

            // A first showing that is already too late is dropped silently; a snooze the user asked
            // for is always honoured until the meeting ends.
            let tooLate = now.timeIntervalSince(meeting.startDate) > catchUp
            var candidates: [PlannedReminder] = []
            for item in past {
                if tooLate && !item.isSnoozeReturn {
                    plan.expired.append(item.key)
                } else {
                    candidates.append(item)
                }
            }

            // Several reminders of one meeting are overdue (e.g. after sleep): show only the latest.
            if let best = candidates.max(by: { $0.fireAt < $1.fireAt }) {
                plan.due.append(best)
                plan.expired.append(contentsOf: candidates.filter { $0.key != best.key }.map(\.key))
            }
        }

        plan.upcoming.sort { $0.fireAt < $1.fireAt }
        return plan
    }
}
