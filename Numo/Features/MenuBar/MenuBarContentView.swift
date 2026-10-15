import AppKit
import NumoCore
import SwiftUI

/// Things the views can ask the app to do, without knowing who does them.
@MainActor
struct AppActions {
    var join: @MainActor (Meeting) -> Void
    var requestCalendarAccess: @MainActor () -> Void
    var refresh: @MainActor () -> Void
    var sendTestReminder: @MainActor () -> Void
    var quit: @MainActor () -> Void
}

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.menuBarSymbol)
            if let title = model.menuBarTitle {
                Text(title)
            }
        }
    }
}

struct MenuBarContentView: View {
    let model: AppModel
    @ObservedObject var settings: SettingsStore
    let actions: AppActions

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // The popover is only alive while open, so a 1 s tick here costs nothing at idle.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                switch model.authorization {
                case .authorized:
                    meetingContent(now: context.date)
                case .notDetermined:
                    accessPrompt
                case .denied, .restricted, .writeOnly:
                    accessProblem
                }

                Divider()
                statusRow(now: context.date)
                footer
            }
            .padding(16)
            .frame(width: 340)
        }
    }

    // MARK: - Meetings

    @ViewBuilder
    private func meetingContent(now: Date) -> some View {
        let upcoming = model.upcoming(at: now)
        if let next = upcoming.first {
            nextUp(next, now: now)
            let rows = model.today(at: now).filter { $0.id != next.id }
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LATER TODAY")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(rows.prefix(6)) { meeting in
                        row(meeting)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("No more meetings", systemImage: "checkmark.circle")
                    .font(.headline)
                Text(emptyExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Why the list is empty, so "nothing found" is never confused with "everything filtered out".
    private var emptyExplanation: String {
        if model.eventsRead == 0 {
            return "numo found no events in the next 36 hours in the calendars macOS shares with it."
        }
        if settings.settings.requireMeetingLink {
            return "numo read \(model.eventsRead) events but none has a Meet, Teams or Zoom link. "
                + "Turn off \"Only events with a link\" in Settings → Calendars to be reminded about every event."
        }
        return "numo read \(model.eventsRead) events, but your calendar, all-day and declined settings hide all of them."
    }

    private func nextUp(_ meeting: Meeting, now: Date) -> some View {
        let untilStart = meeting.startDate.timeIntervalSince(now)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(untilStart <= 0 ? "HAPPENING NOW" : "NEXT UP")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let countdown = ReminderCopy.compactCountdown(secondsUntilStart: untilStart) {
                    Text(countdown)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(meeting.title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            HStack(spacing: 6) {
                if let link = meeting.link {
                    PlatformBadge(platform: link.platform)
                    Text("·")
                }
                Text(meeting.startDate, format: .dateTime.hour().minute())
                Text("–")
                Text(meeting.endDate, format: .dateTime.hour().minute())
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if meeting.link != nil {
                Button {
                    actions.join(meeting)
                } label: {
                    Label("Join", systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
    }

    private func row(_ meeting: Meeting) -> some View {
        HStack(spacing: 10) {
            Text(meeting.startDate, format: .dateTime.hour().minute())
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(meeting.title)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let link = meeting.link {
                Image(systemName: link.platform.symbolName)
                    .foregroundStyle(.secondary)
                    .help(link.platform.displayName)
                Button {
                    actions.join(meeting)
                } label: {
                    Image(systemName: "arrow.up.right.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Join \(meeting.title)")
                .accessibilityLabel("Join \(meeting.title)")
            }
        }
    }

    // MARK: - Calendar access

    private var accessPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Calendar access needed", systemImage: "calendar.badge.exclamationmark")
                .font(.headline)
            Text("numo reads your events on this Mac to find meeting links. macOS only offers full calendar access, and nothing leaves your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Allow Calendar Access") { actions.requestCalendarAccess() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
    }

    private var accessProblem: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Calendar access is off", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text("Reminders are paused because numo cannot read your calendars. Turn on Full Calendar Access for numo in System Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Status and footer

    private func statusRow(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            reminderStatus(now: now)
            if model.authorization == .authorized { readStatus }
        }
    }

    /// When the calendar was last read and how much came back: the first thing to look at when
    /// reminders seem to be missing.
    private var readStatus: some View {
        HStack {
            if let read = model.lastSuccessfulRead {
                Text("Calendar read \(read.formatted(date: .omitted, time: .standard)) · \(model.eventsRead) events")
            } else {
                Text("Calendar not read yet")
            }
            Spacer()
            Button("Refresh") { actions.refresh() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func reminderStatus(now: Date) -> some View {
        HStack {
            if model.isPaused(at: now), let until = model.pausedUntil {
                Label {
                    Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
                } icon: {
                    Image(systemName: "bell.slash.fill")
                }
                .foregroundStyle(.orange)
            } else {
                Label("Reminders on", systemImage: "bell.fill")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu("Pause") {
                Button("Pause for 1 hour") {
                    settings.settings.pausedUntil = now.addingTimeInterval(3600)
                }
                Button("Pause until tomorrow") {
                    let startOfToday = Calendar.current.startOfDay(for: now)
                    settings.settings.pausedUntil = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)
                }
                if model.isPaused(at: now) {
                    Divider()
                    Button("Resume reminders") { settings.settings.pausedUntil = nil }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack {
            Button("Settings…") {
                NSApplication.shared.activate()
                openSettings()
            }
            Button("Send test reminder") { actions.sendTestReminder() }
            Spacer()
            Button("Quit") { actions.quit() }
        }
        .buttonStyle(.plain)
        .font(.callout)
    }
}
