import NumoCore
import SwiftUI

/// The content of the floating reminder window: a Liquid Glass card with a countdown ring,
/// a dominant Join button, and Snooze / Dismiss.
struct ReminderRootView: View {
    let model: ReminderViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Group {
            if let main = model.reminders.first {
                // One tick per second drives the ring, the countdown text and the urgency stage.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ReminderCard(
                        reminder: main,
                        others: Array(model.reminders.dropFirst()),
                        now: context.date,
                        model: model
                    )
                }
            }
        }
        .scaleEffect(reduceMotion || appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.5, bounce: 0.25)) {
                appeared = true
            }
        }
    }
}

private struct ReminderCard: View {
    let reminder: DueReminder
    let others: [DueReminder]
    let now: Date
    let model: ReminderViewModel

    private var meeting: Meeting { reminder.meeting }
    private var secondsSinceStart: TimeInterval { now.timeIntervalSince(meeting.startDate) }
    private var stage: UrgencyStage { .stage(secondsSinceStart: secondsSinceStart) }

    private var tint: Color {
        switch stage {
        case .upcoming, .now: .accentColor
        case .late: .orange
        case .overdue: .red
        }
    }

    /// Icon as well as colour, so urgency never depends on colour alone.
    private var stageSymbol: String {
        switch stage {
        case .upcoming: "clock"
        case .now: "bell.fill"
        case .late, .overdue: "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            VStack(spacing: 22) {
                CountdownRing(
                    secondsSinceStart: secondsSinceStart,
                    horizon: max(180, TimeInterval(reminder.key.leadSeconds)),
                    tint: tint
                )

                VStack(spacing: 6) {
                    Label(ReminderCopy.eyebrow(secondsSinceStart: secondsSinceStart), systemImage: stageSymbol)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(meeting.title)
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .help(meeting.title)

                    HStack(spacing: 6) {
                        if let link = meeting.link {
                            PlatformBadge(platform: link.platform)
                            Text("·")
                        }
                        Text(meeting.startDate, format: .dateTime.hour().minute())
                    }
                    .font(.title3)
                    .foregroundStyle(.secondary)
                }

                actions

                if model.isBlocking {
                    Text("Your screen stays dimmed until you join, snooze or dismiss. The menu bar and Dock still work.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !others.isEmpty {
                    Divider()
                    alsoStarting
                }
            }
            .padding(32)
            .frame(width: 440)
            .glassEffect(.regular.tint(tint.opacity(0.18)), in: .rect(cornerRadius: 40))
        }
        .padding(28)  // room for the glass edge and shadow inside the transparent window
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meeting reminder: \(meeting.title). \(ReminderCopy.eyebrow(secondsSinceStart: secondsSinceStart))")
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if meeting.link != nil {
                Button {
                    model.onJoin(reminder)
                } label: {
                    Label("Join Meeting", systemImage: "video.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 12) {
                Menu {
                    ForEach(model.snoozeOptions, id: \.self) { minutes in
                        Button("\(minutes) min") { model.onSnooze(reminder, minutes) }
                    }
                } label: {
                    Label("Snooze", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                } primaryAction: {
                    model.onSnooze(reminder, model.defaultSnooze)
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .controlSize(.large)
                .help("Remind me again in \(model.defaultSnooze) min (Esc)")

                Button {
                    model.onDismiss(reminder)
                } label: {
                    Label("Dismiss", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .keyboardShortcut(".", modifiers: .command)
                .help("Dismiss this reminder for this meeting (⌘.)")
            }

            // Esc = snooze (never a silent dismiss). A zero-size button gives the shortcut a home.
            Button("Snooze") { model.onSnooze(reminder, model.defaultSnooze) }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private var alsoStarting: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Also starting")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(others.prefix(3)) { other in
                HStack(spacing: 10) {
                    Text(other.meeting.title)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if other.meeting.link != nil {
                        Button("Join") { model.onJoin(other) }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                    Button {
                        model.onDismiss(other)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .accessibilityLabel("Dismiss \(other.meeting.title)")
                }
            }

            if others.count > 3 {
                Text("+\(others.count - 3) more in the menu bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
