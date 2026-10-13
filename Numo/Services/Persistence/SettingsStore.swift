import Combine
import Foundation
import NumoCore

/// Holds `AppSettings` and persists every change to UserDefaults.
///
/// This is an `ObservableObject` rather than `@Observable` on purpose: SwiftUI needs `$store.settings.x`
/// bindings, and the `didSet` below must fire for every write, including writes through those bindings.
@MainActor
final class SettingsStore: ObservableObject {
    private static let defaultsKey = "numo.settings"

    private let defaults: UserDefaults

    @Published var settings: AppSettings {
        didSet {
            persist()
            onChange?(settings)
        }
    }

    /// Called after every change; the app environment forwards it to the reminder engine.
    var onChange: (@MainActor (AppSettings) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = stored
        } else {
            settings = AppSettings()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
