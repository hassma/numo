import AppKit
import EventKit
import Foundation
import NumoCore

/// Turns the OS notifications that can invalidate a schedule into one `AsyncStream<SystemEvent>`.
/// No polling: each of these is delivered by the system when it actually happens.
@MainActor
final class SystemEventBridge {
    let events: AsyncStream<SystemEvent>
    private let continuation: AsyncStream<SystemEvent>.Continuation
    private var tokens: [NSObjectProtocol] = []

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: SystemEvent.self, bufferingPolicy: .bufferingNewest(16))
        events = stream
        self.continuation = continuation

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification, .wake)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, .wake)

        let center = NotificationCenter.default
        observe(center, .NSSystemClockDidChange, .clockChanged)
        observe(center, .NSSystemTimeZoneDidChange, .timeZoneChanged)
        observe(center, .NSCalendarDayChanged, .dayChanged)
        observe(center, .EKEventStoreChanged, .calendarChanged)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ event: SystemEvent) {
        let continuation = continuation
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            continuation.yield(event)
        }
        tokens.append(token)
    }
}
