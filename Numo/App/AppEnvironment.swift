import AppKit
import Foundation
import NumoCore

/// Composition root: the only place that knows concrete types and wires them together.
@MainActor
final class AppEnvironment {
    let settingsStore: SettingsStore
    let model = AppModel()
    let loginItem = LoginItemModel()

    private let provider: EventKitCalendarProvider
    private let engine: ReminderEngine
    private let coordinator: ReminderCoordinator
    private let systemEvents = SystemEventBridge()

    init() {
        let settingsStore = SettingsStore()
        let provider = EventKitCalendarProvider()
        let engine = ReminderEngine(
            calendar: provider,
            store: FileLedgerStore(url: Self.ledgerURL()),
            settings: settingsStore.settings
        )
        self.settingsStore = settingsStore
        self.provider = provider
        self.engine = engine
        self.coordinator = ReminderCoordinator(
            engine: engine,
            settings: settingsStore,
            opener: WorkspaceURLOpener()
        )
    }

    /// What the SwiftUI views may ask the app to do.
    var actions: AppActions {
        AppActions(
            join: { [coordinator] meeting in coordinator.join(meeting: meeting) },
            requestCalendarAccess: { [weak self] in self?.requestCalendarAccess() },
            refresh: { [weak self] in self?.refreshNow() },
            sendTestReminder: { [coordinator] in coordinator.sendTestReminder() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    /// Starts every long-running task. They live as long as the app does.
    func start() {
        let engine = engine
        settingsStore.onChange = { settings in
            Task { await engine.updateSettings(settings) }
        }

        Task { await engine.start() }
        Task { await self.model.run(snapshots: engine.snapshots) }
        Task { await self.model.runMenuBarUpdates() }
        Task { await self.coordinator.run() }
        Task { await self.handleSystemEvents() }
        Task { await self.requestCalendarAccessIfUndecided() }
    }

    // MARK: - Calendar access

    private func requestCalendarAccess() {
        let provider = provider
        let engine = engine
        Task {
            _ = await provider.requestAccess()
            await engine.requestReplan()
        }
    }

    /// "Refresh" in the menu bar: ask macOS to sync its accounts, then read the calendar again.
    private func refreshNow() {
        let provider = provider
        let engine = engine
        Task {
            await provider.refreshSources()
            await engine.requestReplan()
        }
    }

    private func requestCalendarAccessIfUndecided() async {
        if await provider.authorizationStatus() == .notDetermined {
            requestCalendarAccess()
        }
    }

    // MARK: - System events

    /// Wake, clock, time-zone, day and calendar changes all mean "the plan may be wrong": replan.
    private func handleSystemEvents() async {
        for await event in systemEvents.events {
            if event == .wake {
                await provider.refreshSources()
            }
            await engine.requestReplan()
        }
    }

    // MARK: - Storage

    private static func ledgerURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("numo", isDirectory: true).appendingPathComponent("ledger.json")
    }
}
