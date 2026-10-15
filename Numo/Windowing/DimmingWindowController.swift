import AppKit

/// What the blocking screen should look like right now.
struct BlockingState: Equatable {
    /// Opacity of the dimmed layer.
    var strength: Double
    /// True: clicks on the dimmed screen are swallowed. False: they pass through to the apps below.
    var blocksClicks: Bool
    /// The latest moment the blocking screen may stay up (see `AttentionPolicy`).
    var expires: Date
}

/// One borderless dimming window per display.
///
/// Level `.modalPanel` sits above normal and floating windows but *below* the Dock and the menu bar, so
/// the menu-bar icon (and with it Quit), the Dock, Cmd-Tab, Force Quit and Mission Control keep working.
/// The windows are non-activating panels: showing them does not activate numo, and clicking them does not
/// steal focus; the click is simply absorbed.
@MainActor
final class DimmingWindowController {
    static let level = NSWindow.Level.modalPanel

    private var windows: [DimPanel] = []
    private var state: BlockingState?
    private var screenObserver: NSObjectProtocol?
    private var removal: Task<Void, Never>?

    var isShowing: Bool { state != nil }

    func show(_ newState: BlockingState) {
        removal?.cancel()
        removal = nil
        state = newState

        if screenObserver == nil {
            // Displays plugged, unplugged or rearranged while the screen is blocked: cover the new layout.
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.rebuild(fadeIn: false) }
            }
        }

        if windows.isEmpty {
            rebuild(fadeIn: true)
        } else {
            for window in windows {
                window.apply(newState)
                window.alphaValue = 1
            }
        }
    }

    func hide() {
        guard !windows.isEmpty, removal == nil else { return }
        state = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        animate(to: 0)
        removal = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled, let self else { return }
            for window in self.windows { window.orderOut(nil) }
            self.windows = []
            self.removal = nil
        }
    }

    // MARK: - Helpers

    private func rebuild(fadeIn: Bool) {
        guard let state else { return }
        for window in windows { window.orderOut(nil) }
        windows = NSScreen.screens.map { DimPanel(screen: $0, state: state) }
        for window in windows {
            window.alphaValue = fadeIn ? 0 : 1
            window.orderFrontRegardless()
        }
        if fadeIn { animate(to: 1) }
    }

    private func animate(to alpha: CGFloat) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.01 : 0.25
            for window in windows {
                window.animator().alphaValue = alpha
            }
        }
    }
}

private final class DimPanel: NSPanel {
    init(screen: NSScreen, state: BlockingState) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)
        level = DimmingWindowController.level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        hasShadow = false
        animationBehavior = .none
        isMovable = false
        apply(state)
    }

    func apply(_ state: BlockingState) {
        backgroundColor = NSColor.black.withAlphaComponent(min(max(state.strength, 0.2), 0.9))
        ignoresMouseEvents = !state.blocksClicks
    }

    // Never take keyboard focus: typing must keep going where the user was typing.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
