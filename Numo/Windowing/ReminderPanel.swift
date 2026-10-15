import AppKit
import SwiftUI

/// The floating glass card's window.
///
/// - `.nonactivatingPanel`: showing it does not activate numo, so a full-screen app does not leave its
///   Space and keystrokes keep going to whatever the user is typing in. Clicking it still works.
/// - `.canJoinAllSpaces` + `.fullScreenAuxiliary`: lets it appear on every Space, including full-screen
///   ones. This is the community-verified recipe and needs the app to be an accessory (LSUIElement).
///   See docs, spike S1: it must be confirmed on hardware.
/// - `.floating` level: above normal windows but below the menu bar, Dock and system UI, so the
///   reminder can never trap the user.
final class ReminderPanel: NSPanel {
    /// While the screen is blocked the card must sit one level above the dimming windows.
    static let blockingLevel = NSWindow.Level(rawValue: DimmingWindowController.level.rawValue + 1)

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // the glass card draws its own depth
        isMovableByWindowBackground = true
        animationBehavior = .none
    }

    /// Needed so buttons and keyboard shortcuts work once the user clicks the card.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A hosting view that handles the very first click, even though the panel is not the key window yet.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
