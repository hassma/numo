# C · System architecture

## Layering

Pure logic is separated from system frameworks so it can be tested without a calendar, a screen or a clock.

```
┌───────────────────────────────────────────────────────────────────────┐
│ App target (SwiftUI + AppKit, @MainActor UI)                          │
│                                                                       │
│  MenuBar UI   Settings UI   Onboarding   Reminder cards (SwiftUI)     │
│        ▲            ▲            ▲              ▲                     │
│        └──────── AppModel (@Observable) ────────┘                     │
│                         ▲                                             │
│  ReminderCoordinator ───┤──▶ ReminderWindowController (NSPanel + dim) │
│          ▲              │                                             │
├──────────┼──────────────┼─────────────────────────────────────────────┤
│ System adapters         │                                             │
│  EventKitCalendarProvider (actor)   PowerAndClockEvents               │
│  URLOpener (NSWorkspace)            LoginItemService (SMAppService)   │
│  DisplayMonitor   SoundPlayer   FocusMonitor?   NotificationFallback? │
├──────────┼──────────────┼─────────────────────────────────────────────┤
│ NumoCore (local Swift package, Foundation only, fully unit-tested)   │
│                                                                       │
│  Meeting  MeetingLinkDetector  MeetingFilter  ReminderPlanner         │
│  ReminderEngine (actor)  ReminderLedger  AppSettings  NumoClock      │
└───────────────────────────────────────────────────────────────────────┘
```

Dependencies point downwards only. `NumoCore` defines protocols (`CalendarProviding`, `URLOpening`, `ReminderLedgerStore`, `Clock`); adapters implement them.

## Components

| Component | Responsibility | Concurrency |
| --- | --- | --- |
| `EventKitCalendarProvider` | Owns `EKEventStore`. Requests access, lists calendars, fetches the window, converts to `Meeting` snapshots, emits a change stream. | `actor` |
| `MeetingLinkDetector` | Finds and classifies links (Meet, Teams, Zoom?) in url / location / notes. Pure. | `Sendable` struct |
| `MeetingFilter` | Applies settings: calendars, declined, all-day, cancelled, link required, dedupe across calendars. Pure. | struct |
| `ReminderPlanner` | `(meetings, settings, ledger, now) → [PlannedReminder]`. Pure function, the heart of the unit tests. | struct |
| `ReminderEngine` | Holds the one sleeping `Task`, re-plans on triggers, emits `ReminderDue` events, writes ledger transitions. | `actor` |
| `ReminderLedger` | Per-reminder state: scheduled, presented, snoozed, joined, dismissed, expired. Persisted as JSON, pruned after 7 days. | `actor` + file store |
| `ReminderCoordinator` | Receives due reminders, queues and merges simultaneous ones, decides presentation (privacy mode, mode downgrade), drives windows, applies user actions. | `@MainActor` |
| `ReminderWindowController` | Creates/destroys `ReminderPanel` and per-screen dim windows, chooses the screen, observes display changes. | `@MainActor` |
| `AppModel` | Observable view-state for menu bar and settings: next meeting, today's list, status, permission state. | `@MainActor @Observable` |
| `SettingsStore` | Versioned Codable `AppSettings` in `UserDefaults`; publishes changes. | `@MainActor @Observable` |
| `PowerAndClockEvents` | Bridges wake, screens-wake, clock change, time-zone change, day change into one `AsyncStream<SystemEvent>`. | nonisolated, `Sendable` |

## Data flow

```
EKEventStoreChanged ─┐
didWake / clock / tz ─┼─▶ ReminderEngine.replan(reason)
heartbeat (15 min)   ─┘            │
                                   ▼
        CalendarProviding.fetch(window) ─▶ [Meeting]
                                   │
                  MeetingFilter ─▶ ReminderPlanner(ledger, settings, now)
                                   │
                         [PlannedReminder] sorted by fireAt
                                   │
                 arm: Task.sleep(until: min(nextFireAt, now + 15 min))
                                   │ wakes
                                   ▼
                   fire due reminders ─▶ AsyncStream<ReminderDue>
                                   │
                                   ▼   (MainActor)
                       ReminderCoordinator ─▶ ReminderWindowController
                                   ▲                    │
                  user action (Join / Snooze / Dismiss) ┘
                                   │
                                   ▼
                    ledger transition ─▶ replan
```

Re-planning is idempotent: it always recomputes from calendar + ledger + settings, so a missed notification or a duplicate trigger is harmless.

## Reminder identity and dedupe

```swift
struct MeetingID: Hashable, Codable, Sendable {
    let externalID: String      // EKEvent.calendarItemExternalIdentifier (falls back to eventIdentifier)
    let occurrence: Date        // EKEvent.occurrenceDate: stable for a recurring instance even if moved
}

struct ReminderKey: Hashable, Codable, Sendable {
    let meeting: MeetingID
    let startAt: Date           // included so a moved meeting alerts again at its new time
    let leadSeconds: Int        // 180, 0, …
}
```

Cross-calendar duplicates (same meeting invited into two calendars) collapse by fingerprint: normalised link, else `(title, start, end)`.

## Reminder state machine

```
              plan
 (none) ───────────────▶ scheduled
                            │ fireAt reached (or catch-up)
                            ▼
                        presented ◀──────────── repeat interval elapsed (not yet acted on)
                       ┌────┼────────┬──────────┐
                  Join │    │Snooze  │Dismiss   │ meeting ends / cancelled / moved
                       ▼    ▼        ▼          ▼
                    joined snoozed(until) dismissed expired
                              │ until reached
                              └──────▶ presented
```

Terminal states: `joined`, `dismissed`, `expired`. `presented` is **not** terminal: if the screen was asleep or locked when it showed, the repeat rule shows it again.

## Catch-up rules (wake, relaunch, late detection)

When a replan finds reminders whose `fireAt` is in the past:

1. If the meeting has ended or is cancelled → mark `expired`, show nothing.
2. If its start is older than the **catch-up window** (default 10 min) and the user never saw a reminder → mark `expired`, show nothing. (The meeting is probably already underway.)
3. Otherwise show **one** reminder per meeting (the most urgent unfired one), labelled "Started 4 min ago", and mark earlier lead reminders for that meeting as superseded.

## Concurrency model (Swift 6)

- Strict concurrency on. `EKEventStore` never leaves its actor; only `Sendable` value snapshots cross boundaries.
- UI types are `@MainActor`. Core logic is value types and actors.
- System notifications are bridged to `AsyncSequence`s consumed by a single `for await` loop in the engine.
- Time is injected via the standard `Clock` protocol so tests can drive a manual clock.
- No `DispatchQueue` except where an AppKit API demands it.

## Persistence

| Data | Store | Notes |
| --- | --- | --- |
| Settings | `UserDefaults`, one versioned JSON blob | Migration function per version bump |
| Reminder ledger | `~/Library/Application Support/Numo/ledger.json` (sandbox container) | Atomic writes, pruned after 7 days, tolerant of corruption (reset, never crash) |
| Secrets | none in MVP; Keychain in optional Phase 4 | |

SwiftData/Core Data were rejected: the data is tiny, short-lived and not relational.

## Privacy and security

- MVP has no network entitlement and no analytics, so it cannot exfiltrate anything.
- Calendar data is held in memory and only reminder IDs and timestamps are persisted (no titles, attendees or notes).
- Logging uses `os.Logger` with meeting titles marked `.private`.
- URLs are opened only if they classify as a known meeting provider host (https), or an explicitly generic link when the user taps it.

## Performance budget

- Idle: no repeating timers; one suspended task. Target 0.0 % CPU and under 40 MB RSS.
- Menu-bar countdown label updates at most once per minute, and only when the next meeting is within 60 min.
- Overlay: 1 Hz countdown plus one slow animation; paused when the panel is hidden.

## Extensibility

`CalendarProviding` is the seam for the optional Phase 4: `GoogleCalendarProvider` and `GraphCalendarProvider` implement it, and an `AggregateCalendarProvider` merges them with the EventKit provider, deduping by fingerprint.
