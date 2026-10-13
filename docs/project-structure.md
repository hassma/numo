# D · Project structure

One Xcode app target plus one local Swift package for the pure logic. No third-party dependencies.

```
MeetingNudge/
├── MeetingNudge.xcodeproj
│
├── App/
│   ├── MeetingNudgeApp.swift          # @main: MenuBarExtra, Settings scene, onboarding window
│   ├── AppDelegate.swift              # activation policy, termination, dock-icon toggle
│   ├── AppEnvironment.swift           # composition root: builds and wires all services
│   ├── Info.plist                     # LSUIElement=YES, NSCalendarsFullAccessUsageDescription
│   ├── MeetingNudge.entitlements      # app-sandbox, personal-information.calendars
│   └── Assets.xcassets
│
├── Packages/NudgeCore/                # Foundation only. Builds and tests anywhere Swift runs
│   ├── Package.swift
│   ├── Sources/NudgeCore/
│   │   ├── Models/
│   │   │   ├── Meeting.swift          # Sendable snapshot of a calendar occurrence
│   │   │   ├── MeetingID.swift
│   │   │   ├── MeetingLink.swift      # url + MeetingPlatform
│   │   │   ├── MeetingPlatform.swift  # .googleMeet .teams .zoom .other
│   │   │   ├── AppSettings.swift      # versioned Codable settings
│   │   │   └── ReminderKey.swift
│   │   ├── Detection/
│   │   │   ├── MeetingLinkDetector.swift   # NSDataDetector + host classification
│   │   │   ├── SafeLinksUnwrapper.swift
│   │   │   ├── HTMLText.swift              # strip tags / decode entities from notes
│   │   │   └── TeamsDeepLink.swift         # https → msteams:// rewrite
│   │   ├── Planning/
│   │   │   ├── MeetingFilter.swift
│   │   │   ├── ReminderPlanner.swift       # pure: meetings + settings + ledger + now → plan
│   │   │   └── CatchUpPolicy.swift
│   │   ├── Engine/
│   │   │   ├── ReminderEngine.swift        # actor owning the sleeping task
│   │   │   ├── ReminderLedger.swift        # state machine + persistence protocol
│   │   │   └── SystemEvent.swift
│   │   └── Protocols/
│   │       ├── CalendarProviding.swift
│   │       ├── URLOpening.swift
│   │       └── LedgerStore.swift
│   └── Tests/NudgeCoreTests/
│       ├── MeetingLinkDetectorTests.swift  # fixture-driven (Fixtures/*.txt)
│       ├── ReminderPlannerTests.swift
│       ├── ReminderEngineTests.swift       # manual Clock, wake/clock-change scenarios
│       ├── LedgerTests.swift
│       ├── DSTTests.swift
│       └── Fixtures/
│
├── Services/                          # System adapters
│   ├── Calendar/
│   │   ├── EventKitCalendarProvider.swift  # actor, owns EKEventStore
│   │   ├── EventSnapshotMapper.swift       # EKEvent → Meeting
│   │   └── CalendarAuthorization.swift
│   ├── System/
│   │   ├── PowerAndClockEvents.swift       # wake, clock, tz, day-change → AsyncStream
│   │   ├── DisplayMonitor.swift            # screen changes, mirroring
│   │   ├── LoginItemService.swift          # SMAppService
│   │   ├── WorkspaceURLOpener.swift        # NSWorkspace, Teams app detection
│   │   ├── SoundPlayer.swift
│   │   ├── PrivacyModeMonitor.swift        # manual + heuristic presenting detection
│   │   └── FocusMonitor.swift              # Phase 3, optional
│   └── Persistence/
│       ├── SettingsStore.swift
│       └── FileLedgerStore.swift
│
├── Coordination/
│   ├── ReminderCoordinator.swift      # @MainActor: due events → presentation → actions
│   ├── AppModel.swift                 # @Observable view state
│   └── PresentationPolicy.swift       # mode downgrade, privacy mode, multi-meeting merge
│
├── Windowing/                         # AppKit
│   ├── ReminderPanel.swift            # NSPanel subclass
│   ├── ReminderWindowController.swift
│   ├── DimmingWindowController.swift  # one window per NSScreen
│   ├── ScreenResolver.swift           # which screen gets the card
│   └── SettingsOpener.swift           # activation dance for accessory apps
│
├── Features/
│   ├── Reminder/
│   │   ├── ReminderRootView.swift     # picks Gentle / Focused / Unmissable layout
│   │   ├── GentleCard.swift
│   │   ├── FocusedCard.swift
│   │   ├── UnmissableCard.swift
│   │   ├── CountdownRing.swift
│   │   ├── UrgencyStage.swift         # time → stage → tint / copy
│   │   └── MeetingStack.swift         # extra simultaneous meetings
│   ├── MenuBar/
│   │   ├── MenuBarContentView.swift
│   │   ├── NextMeetingHeader.swift
│   │   ├── TodayList.swift
│   │   └── MenuBarLabel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift         # tabbed
│   │   ├── CalendarsPane.swift
│   │   ├── RemindersPane.swift
│   │   ├── AppearancePane.swift
│   │   ├── PrivacyPane.swift
│   │   └── GeneralPane.swift
│   └── Onboarding/
│       ├── OnboardingFlow.swift
│       ├── WelcomeStep.swift
│       ├── CalendarAccessStep.swift
│       ├── PreferencesStep.swift
│       └── FinishStep.swift
│
├── DesignSystem/
│   ├── GlassSurface.swift             # glassEffect + container wrappers
│   ├── GlassButtons.swift
│   ├── PlatformBadge.swift            # SF Symbol + label per MeetingPlatform
│   ├── Motion.swift                   # spring presets, reduce-motion aware
│   └── Typography.swift
│
├── Resources/
│   ├── Sounds/                        # short CAF files
│   └── Localizable.xcstrings
│
├── MeetingNudgeTests/                 # adapter and coordinator tests
├── MeetingNudgeUITests/               # onboarding, menu bar, settings smoke tests
└── Tools/
    └── SeedTestCalendar.swift         # debug-only: creates a calendar and timed events
```

## Notes

- **Why a package for the core:** it compiles with `swift test` without Xcode, enforces the "no UI imports" boundary at the module level, and keeps tests fast.
- **Composition root:** `AppEnvironment` is the only place that knows concrete types. Everything else takes protocols, which keeps previews and tests trivial.
- **Debug menu:** a `#if DEBUG` menu in the status item offers "Send test reminder", "Seed test events", "Simulate wake" and "Show panel on every screen".
- **Deployment target:** macOS 26.0. Swift language mode 6 with strict concurrency.
- **Bundle ID:** placeholder `app.meetingnudge.MeetingNudge` until you supply a real one.
