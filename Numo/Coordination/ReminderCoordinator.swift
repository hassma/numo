import Foundation
import NumoCore

/// Connects the engine's due reminders to the floating window, and the user's clicks back to the engine.
@MainActor
final class ReminderCoordinator {
    private let engine: ReminderEngine
    private let settings: SettingsStore
    private let opener: any URLOpening
    private let viewModel = ReminderViewModel()
    private let windows: ReminderWindowController
    /// Keys of "Send test reminder" cards: they must never touch the real ledger.
    private var testKeys = Set<ReminderKey>()

    init(engine: ReminderEngine, settings: SettingsStore, opener: any URLOpening) {
        self.engine = engine
        self.settings = settings
        self.opener = opener
        self.windows = ReminderWindowController(viewModel: viewModel)

        viewModel.onJoin = { [weak self] reminder in self?.join(reminder) }
        viewModel.onSnooze = { [weak self] reminder, minutes in self?.snooze(reminder, minutes: minutes) }
        viewModel.onDismiss = { [weak self] reminder in self?.dismiss(reminder) }
    }

    func run() async {
        for await event in engine.events {
            switch event {
            case .due(let reminder):
                show(reminder)
            case .withdrawn(let key, _):
                update(viewModel.reminders.filter { $0.key != key })
            }
        }
    }

    func sendTestReminder() {
        let start = Date().addingTimeInterval(180)
        let meeting = Meeting(
            id: MeetingID(externalID: "numo-test-\(UUID().uuidString)", occurrence: start),
            title: "Weekly Product Sync",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            link: MeetingLink(url: URL(string: "https://meet.google.com/abc-defg-hij")!, platform: .googleMeet)
        )
        let key = ReminderKey(occurrence: meeting.occurrenceKey, leadSeconds: 180)
        testKeys.insert(key)
        show(DueReminder(key: key, meeting: meeting, firedAt: Date()))
    }

    /// Joins a meeting from the menu bar popover and silences its pending reminders.
    func join(meeting: Meeting) {
        if let link = meeting.link {
            opener.open(link, preferNativeApp: settings.settings.preferNativeTeamsApp)
        }
        let engine = engine
        Task { await engine.join(meeting.occurrenceKey) }
    }

    // MARK: - Showing

    private func show(_ reminder: DueReminder) {
        // A newer reminder for the same meeting (3 min before -> at start) replaces the old card.
        var reminders = viewModel.reminders.filter { $0.key.occurrence != reminder.key.occurrence }
        reminders.append(reminder)
        reminders.sort { $0.meeting.startDate < $1.meeting.startDate }
        update(reminders)
    }

    private func update(_ reminders: [DueReminder]) {
        let current = settings.settings
        viewModel.snoozeOptions = Array(Set(current.snoozeOptionsMinutes + [current.defaultSnoozeMinutes])).sorted()
        viewModel.defaultSnooze = current.defaultSnoozeMinutes
        viewModel.reminders = reminders
        windows.refresh()
    }

    // MARK: - User actions

    private func join(_ reminder: DueReminder) {
        if let link = reminder.meeting.link, !isTest(reminder) {
            opener.open(link, preferNativeApp: settings.settings.preferNativeTeamsApp)
        }
        finish(reminder) { await $0.join(reminder.key.occurrence) }
    }

    private func snooze(_ reminder: DueReminder, minutes: Int) {
        finish(reminder) { await $0.snooze(reminder.key, minutes: minutes) }
    }

    private func dismiss(_ reminder: DueReminder) {
        finish(reminder) { await $0.dismiss(reminder.key.occurrence) }
    }

    private func finish(_ reminder: DueReminder, _ action: @escaping @Sendable (ReminderEngine) async -> Void) {
        update(viewModel.reminders.filter { $0.key.occurrence != reminder.key.occurrence })
        if isTest(reminder) {
            testKeys.remove(reminder.key)
        } else {
            let engine = engine
            Task { await action(engine) }
        }
    }

    private func isTest(_ reminder: DueReminder) -> Bool {
        testKeys.contains(reminder.key)
    }
}
