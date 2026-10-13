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
