import NumoCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let model: AppModel
    let loginItem: LoginItemModel
    let actions: AppActions

    var body: some View {
        TabView {
            CalendarsPane(store: store, model: model)
                .tabItem { Label("Calendars", systemImage: "calendar") }
            RemindersPane(store: store)
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
            GeneralPane(store: store, loginItem: loginItem, actions: actions)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 460)
    }
}

// MARK: - Calendars

struct CalendarsPane: View {
    @ObservedObject var store: SettingsStore
    let model: AppModel

    private var groups: [(source: String, calendars: [CalendarInfo])] {
        Dictionary(grouping: model.calendars, by: \.sourceTitle)
            .map { (source: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.source < $1.source }
    }

    var body: some View {
        Form {
            if model.calendars.isEmpty {
                Section {
                    Text(model.authorization == .authorized
                         ? "No calendars found. Add an account in System Settings → Internet Accounts."
                         : "Allow calendar access to choose which calendars numo watches.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(groups, id: \.source) { group in
                Section(group.source) {
                    ForEach(group.calendars) { calendar in
                        Toggle(calendar.title, isOn: calendarBinding(calendar.id))
                    }
                }
            }

            Section("Which events get a reminder") {
                Toggle("Only events with a Meet, Teams or Zoom link", isOn: $store.settings.requireMeetingLink)
                Toggle("Include all-day events", isOn: $store.settings.includeAllDayEvents)
                Toggle("Include events I declined", isOn: $store.settings.includeDeclinedEvents)
            }
        }
        .formStyle(.grouped)
    }

    private func calendarBinding(_ id: String) -> Binding<Bool> {
        Binding.main(
            get: { store.settings.isCalendarEnabled(id) },
            set: { enabled in
                if enabled {
                    store.settings.disabledCalendarIDs.remove(id)
                } else {
                    store.settings.disabledCalendarIDs.insert(id)
                }
            }
        )
    }
}

// MARK: - Reminders

struct RemindersPane: View {
    @ObservedObject var store: SettingsStore

    private static let leadChoices = [5, 3, 1, 0]
    private static let snoozeChoices = [1, 2, 3, 5, 10]

    var body: some View {
        Form {
            Section("Remind me") {
                ForEach(Self.leadChoices, id: \.self) { minutes in
                    Toggle(minutes == 0 ? "When the meeting starts" : "\(minutes) min before",
                           isOn: membership(of: minutes, in: \.leadTimesMinutes, descending: true))
                }
                if store.settings.leadTimesMinutes.isEmpty {
                    Text("Nothing is selected, so no reminders will appear.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section("Snooze") {
                ForEach(Self.snoozeChoices, id: \.self) { minutes in
                    Toggle("\(minutes) min", isOn: membership(of: minutes, in: \.snoozeOptionsMinutes, descending: false))
                }
                Picker("Default (Snooze button and Esc)", selection: $store.settings.defaultSnoozeMinutes) {
                    ForEach(Self.snoozeChoices, id: \.self) { Text("\($0) min").tag($0) }
                }
            }

            Section {
                Stepper(
                    "Skip reminders more than \(store.settings.catchUpWindowMinutes) min late",
                    value: $store.settings.catchUpWindowMinutes,
                    in: 1...30
                )
            } footer: {
                Text("If your Mac was asleep, a reminder that is already this late after the start is skipped, because the meeting is probably under way.")
            }
        }
        .formStyle(.grouped)
    }

    /// A toggle for "is `value` in this list of minutes".
    private func membership(
        of value: Int,
        in keyPath: WritableKeyPath<AppSettings, [Int]> & Sendable,
        descending: Bool
    ) -> Binding<Bool> {
        Binding.main(
            get: { store.settings[keyPath: keyPath].contains(value) },
            set: { isOn in
                var values = Set(store.settings[keyPath: keyPath])
                if isOn { values.insert(value) } else { values.remove(value) }
                store.settings[keyPath: keyPath] = descending ? values.sorted(by: >) : values.sorted()
            }
        )
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var store: SettingsStore
    let loginItem: LoginItemModel
    let actions: AppActions

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch numo at login", isOn: Binding.main(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.requiresApproval {
                    HStack {
                        Text("Approve numo in System Settings → Login Items.")
                            .font(.callout)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open") { loginItem.openLoginItemsSettings() }
                    }
                }
                if let message = loginItem.errorMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            }

            Section("Joining") {
                Toggle("Open Teams meetings in the Teams app when it is installed", isOn: $store.settings.preferNativeTeamsApp)
            }

            Section {
                Button("Send test reminder") { actions.sendTestReminder() }
            } footer: {
                Text("Shows the reminder card now so you can see exactly what it looks like. It never touches your real meetings.")
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
    }
}
