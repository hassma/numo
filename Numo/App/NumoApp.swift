import SwiftUI

@main
struct NumoApp: App {
    @State private var environment: AppEnvironment

    init() {
        // Reminders must work from launch, long before anyone opens the menu bar popover.
        let environment = AppEnvironment()
        environment.start()
        _environment = State(initialValue: environment)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                model: environment.model,
                settings: environment.settingsStore,
                actions: environment.actions
            )
        } label: {
            MenuBarLabel(model: environment.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                store: environment.settingsStore,
                model: environment.model,
                loginItem: environment.loginItem,
                actions: environment.actions
            )
        }
    }
}
