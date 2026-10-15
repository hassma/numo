import NumoCore
import SwiftUI

extension MeetingPlatform {
    var symbolName: String {
        switch self {
        case .googleMeet: "video.fill"
        case .microsoftTeams: "person.2.fill"
        case .zoom: "video.circle.fill"
        }
    }
}

extension AttentionMode {
    var title: String {
        switch self {
        case .focused: "Floating card"
        case .unmissable: "Blocking screen"
        }
    }

    var summary: String {
        switch self {
        case .focused:
            "A glass card appears over your work. Nothing else changes."
        case .unmissable:
            "When the meeting starts, the screen dims behind the card until you join, snooze or dismiss. The menu bar and Dock stay usable, and the dimming ends on its own after 10 minutes."
        }
    }
}

struct PlatformBadge: View {
    let platform: MeetingPlatform

    var body: some View {
        Label(platform.displayName, systemImage: platform.symbolName)
    }
}

extension Binding where Value: Sendable {
    /// A binding to main-actor state. SwiftUI may declare `Binding`'s closures `@Sendable`, which would
    /// not allow touching main-actor stores directly; SwiftUI always calls them on the main thread.
    @MainActor
    static func main(
        get: @escaping @MainActor () -> Value,
        set: @escaping @MainActor (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { MainActor.assumeIsolated { get() } },
            set: { newValue in MainActor.assumeIsolated { set(newValue) } }
        )
    }
}
