import AppKit
import SwiftUI

/// Creates, positions, resizes and removes the reminder panel as the view model's reminders change.
@MainActor
final class ReminderWindowController {
    private let viewModel: ReminderViewModel
    private var panel: ReminderPanel?
    private var hostingView: FirstMouseHostingView<ReminderRootView>?
    private var hideTask: Task<Void, Never>?

    init(viewModel: ReminderViewModel) {
        self.viewModel = viewModel
    }

    /// Call after `viewModel.reminders` changed.
    func refresh() {
        if viewModel.reminders.isEmpty {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Show

    private func show() {
        hideTask?.cancel()
        hideTask = nil

        let isNew = panel == nil
        if isNew { createPanel() }
        guard let panel, let hostingView else { return }

        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize

        if isNew {
            let area = targetScreenFrame()
            let origin = NSPoint(
                x: area.midX - size.width / 2,
                // Slightly above the vertical centre reads as "in front of you" rather than "stuck".
                y: area.midY - size.height / 2 + area.height * 0.06
            )
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()  // not makeKey: must not steal the user's typing focus
            fade(to: 1)
            announce()
        } else {
            // Content height changed (another meeting joined or left): keep the top edge in place.
            let old = panel.frame
            let origin = NSPoint(x: old.midX - size.width / 2, y: old.maxY - size.height)
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
            panel.alphaValue = 1
        }
    }

    private func createPanel() {
        let panel = ReminderPanel()
        let hosting = FirstMouseHostingView(rootView: ReminderRootView(model: viewModel))
        panel.contentView = hosting
        self.panel = panel
        self.hostingView = hosting
    }

    // MARK: - Hide

    private func hide() {
        guard panel != nil, hideTask == nil else { return }
        fade(to: 0)
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled, let self else { return }
            self.panel?.orderOut(nil)
            self.panel = nil
            self.hostingView = nil
            self.hideTask = nil
        }
    }

    // MARK: - Helpers

    private func fade(to alpha: CGFloat) {
        guard let panel else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.01 : 0.22
            panel.animator().alphaValue = alpha
        }
    }

    /// The screen under the mouse pointer (where the user is most likely looking), else the main screen.
    private func targetScreenFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func announce() {
        guard let first = viewModel.reminders.first else { return }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "Meeting reminder: \(first.meeting.title)",
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
