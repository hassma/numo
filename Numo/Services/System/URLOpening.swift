import AppKit
import NumoCore

@MainActor
protocol URLOpening {
    /// Opens the meeting link. Returns false if the system could not open it.
    @discardableResult
    func open(_ link: MeetingLink, preferNativeApp: Bool) -> Bool
}

@MainActor
struct WorkspaceURLOpener: URLOpening {
    @discardableResult
    func open(_ link: MeetingLink, preferNativeApp: Bool) -> Bool {
        let workspace = NSWorkspace.shared
        // Teams: use the desktop app when it is installed and understands the link, else the browser.
        if preferNativeApp,
           let native = TeamsDeepLink.nativeURL(for: link),
           workspace.urlForApplication(toOpen: native) != nil,
           workspace.open(native) {
            return true
        }
        return workspace.open(link.url)
    }
}
