import NumoCore
import Observation

/// State and callbacks for the reminder card. The coordinator owns it and wires the callbacks.
@MainActor
@Observable
final class ReminderViewModel {
    /// Visible reminders, soonest meeting first. The first one is the main card.
    var reminders: [DueReminder] = []
    var snoozeOptions: [Int] = [1, 2, 5]
    var defaultSnooze = 2
    /// True while the blocking screen is up; the card shows a short explanation.
    var isBlocking = false

    @ObservationIgnored var onJoin: @MainActor (DueReminder) -> Void = { _ in }
    @ObservationIgnored var onSnooze: @MainActor (DueReminder, Int) -> Void = { _, _ in }
    @ObservationIgnored var onDismiss: @MainActor (DueReminder) -> Void = { _ in }
}
