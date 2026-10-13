import Foundation
import NumoCore
import Observation

/// View state for the menu bar item and popover, fed by the engine's snapshots.
@MainActor
@Observable
final class AppModel {
    private(set) var hasSnapshot = false
    private(set) var authorization: CalendarAuthorization = .notDetermined
    private(set) var meetings: [Meeting] = []
    private(set) var calendars: [CalendarInfo] = []
    private(set) var pausedUntil: Date?

    private(set) var menuBarTitle: String?
    private(set) var menuBarSymbol = "calendar.badge.clock"

    /// Meetings not yet over at `now`, soonest first.
    func upcoming(at now: Date) -> [Meeting] {
        meetings.filter { $0.endDate > now }
    }

    /// What the popover lists under "Today": still-relevant meetings that start today or are running.
    func today(at now: Date) -> [Meeting] {
        upcoming(at: now).filter {
            $0.startDate <= now || Calendar.current.isDate($0.startDate, inSameDayAs: now)
        }
    }

    func isPaused(at now: Date) -> Bool {
        if let pausedUntil { return pausedUntil > now }
        return false
    }

    func run(snapshots: AsyncStream<EngineSnapshot>) async {
        for await snapshot in snapshots {
            hasSnapshot = true
            authorization = snapshot.authorization
            meetings = snapshot.meetings
            calendars = snapshot.calendars
            pausedUntil = snapshot.pausedUntil
            refreshMenuBar(now: Date())
        }
    }

    /// Keeps the menu bar countdown fresh without a per-second timer: it only wakes when the text
    /// can actually change (each minute while a meeting is within the hour, otherwise rarely).
    func runMenuBarUpdates() async {
        while !Task.isCancelled {
            let now = Date()
            refreshMenuBar(now: now)
            try? await Task.sleep(for: .seconds(nextMenuBarDelay(now: now)))
        }
    }

    func refreshMenuBar(now: Date) {
        if hasSnapshot, authorization != .authorized {
            menuBarSymbol = "exclamationmark.triangle"
            menuBarTitle = nil
        } else if isPaused(at: now) {
            menuBarSymbol = "bell.slash"
            menuBarTitle = nil
        } else if let next = upcoming(at: now).first {
            let untilStart = next.startDate.timeIntervalSince(now)
            menuBarTitle = ReminderCopy.compactCountdown(secondsUntilStart: untilStart)
            menuBarSymbol = untilStart <= 0 ? "video.fill" : "calendar.badge.clock"
        } else {
            menuBarSymbol = "calendar"
            menuBarTitle = nil
        }
    }

    private func nextMenuBarDelay(now: Date) -> TimeInterval {
        var delay: TimeInterval = 300
        if let pausedUntil, pausedUntil > now {
            delay = min(delay, pausedUntil.timeIntervalSince(now) + 0.5)
        }
        if let next = upcoming(at: now).first {
            let untilStart = next.startDate.timeIntervalSince(now)
            if untilStart <= 0 {
                delay = min(delay, next.endDate.timeIntervalSince(now) + 0.5)
            } else if untilStart > 3600 {
                delay = min(delay, untilStart - 3600 + 0.5)
            } else {
                // The label shows whole minutes rounded up: it next changes when a minute boundary passes.
                let remainder = untilStart.truncatingRemainder(dividingBy: 60)
                delay = min(delay, (remainder == 0 ? 60 : remainder) + 0.5)
            }
        }
        return max(1, delay)
    }
}
