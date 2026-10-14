# MVP implementation status

The Phase 1 MVP from the [roadmap](/roadmap#phase-1-mvp-it-reliably-reminds-me) is written. It lives in `Numo/`.

::: warning Compiles; not yet fully verified
The code was written in a Linux sandbox with no Swift toolchain, then built on a Mac: `make build` succeeds with Xcode 26. Still to confirm on hardware: that the `NumoCore` tests pass (`make test`), and the runtime behaviour in the checklist below (panel over full-screen apps, glass rendering, link opening, sleep/wake).
:::

## What is built

| Roadmap item | Where | Status |
| --- | --- | --- |
| Link detection (Meet, Teams, Zoom), Safe Links, HTML escapes | `NumoCore/Detection` | written, 18 parameterised cases |
| Filtering and cross-calendar dedupe | `NumoCore/Planning/MeetingFilter.swift` | written, tested |
| Planner: lead times, catch-up, snooze, supersede | `NumoCore/Planning/ReminderPlanner.swift` | written, tested incl. DST |
| Ledger: persisted state machine, relaunch recovery | `NumoCore/Engine/ReminderLedger.swift` | written, tested |
| Engine: one sleeping task, replan on triggers, withdraw | `NumoCore/Engine/ReminderEngine.swift` | written, 17 end-to-end tests with a manual clock |
| EventKit provider, access request, change notifications | `Numo/Services/Calendar`, `Services/System` | written, **needs a Mac** |
| Floating non-activating `NSPanel` | `Numo/Windowing` | written, **needs spike S1** |
| Liquid Glass reminder card, ring, Join / Snooze / Dismiss | `Numo/Features/Reminder` | written, **needs spike S2** |
| Menu-bar item and popover | `Numo/Features/MenuBar` | written, **needs spike S4** |
| Settings: calendars, lead times, snooze, launch at login | `Numo/Features/Settings` | written |
| "Send test reminder" | popover footer and Settings → General | written |
| **Blocking screen** (Unmissable mode): dimming on every display, click-swallowing, 10-minute cap | `Numo/Windowing/DimmingWindowController.swift`, `NumoCore/Models/AttentionMode.swift` | written, policy tested, **needs hardware check** |
| Pause reminders (1 h / until tomorrow) | popover | written |

## Build it

You need a Mac with macOS 26, Xcode 26 and `brew install xcodegen`. Run every command from the **repository root**; the `Makefile` does the right thing regardless:

```sh
make doctor     # check the toolchain
make test       # NumoCore logic tests
make build      # compile the app without signing (a compile check, not meant to be run)
make run        # build ad-hoc signed and launch it (make stop quits it)
make open       # generate Numo.xcodeproj and open it; pick your team, then ⌘R
```

Without `make`:

```sh
(cd Numo && xcodegen generate)
open Numo/Numo.xcodeproj
xcrun swift test --package-path Numo/Packages/NumoCore
```

Run once from Xcode, then quit and relaunch from Finder: `LSUIElement` only takes effect on a clean launch, so launching from the debugger can still show a Dock icon.

::: tip Common errors
- `swift: bad interpreter: …python3.11…`: the `swift` on your `PATH` is a stale Homebrew script. Use `xcrun swift` (the `make` targets already do).
- `chdir error … Numo/Numo/Packages/NumoCore`: you ran a root-relative command from inside `Numo/`. Go back to the root.

The README has a full troubleshooting table.
:::

## Deviations from the plan

| Plan | MVP | Why |
| --- | --- | --- |
| Hand-made `.xcodeproj` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec (`Numo/project.yml`) | A `.pbxproj` written without Xcode is fragile and unreviewable; the spec is short and diffable |
| `SettingsStore` as `@Observable` | `ObservableObject` | Needs a `didSet` that fires for writes made through SwiftUI bindings; avoids relying on property observers inside `@Observable` |
| `URLOpening` in `NumoCore` | In the app target, `@MainActor` | `NSWorkspace` is an AppKit type and nothing in the core tests needs it |
| Gentle and Unmissable modes, dimming | Only *Floating card* (Focused) and *Blocking screen* (Unmissable) | Gentle is still Phase 2 |
| Sound, onboarding | Not built | Phase 2 |
| Snooze durations fully editable | Choose which of 1 / 2 / 3 / 5 / 10 min appear, plus a default | Enough for the MVP |
| Custom lead time | Fixed choices 5 / 3 / 1 min and at start | Enough for the MVP |
| Notification fallback if the app dies | Not built | Phase 3 |

## Things to check first on a Mac

These are the unverified assumptions the code depends on, in the order worth checking:

1. **It builds.** Fix whatever the compiler finds (most likely: Swift 6 isolation diagnostics and exact Liquid Glass signatures).
2. **Panel over a full-screen app** (spike S1): put Safari in full screen, use *Send test reminder*, and check the card appears without switching Spaces and without stealing typing.
3. **Glass renders** in the transparent panel (spike S2), including the `Menu` with `.buttonStyle(.glass)`.
4. **Panel sizing**: `ReminderWindowController` sizes the panel from `NSHostingView.fittingSize`; confirm the card is not clipped, especially when a second meeting is added.
5. **First click**: buttons should respond to the first click even though numo is not the active app.
6. **Meet and Teams links** for each of your account types (spike S3).
7. **Settings** opens in front from the menu bar (spike S4).
8. **Blocking screen** (Settings → Reminders → Blocking screen → Send test reminder):
   - every display is dimmed, the card is above the dimming, and clicks on the dimmed area do nothing;
   - the **menu bar and Dock stay above** the dimming and clickable, so Quit and Force Quit remain reachable;
   - it also appears over a full-screen app (spike S1), and on a second display;
   - the dimming disappears after Join / Snooze / Dismiss and after 10 minutes at the latest;
   - unplugging or adding a display while it is up covers the new layout.
9. **Sleep and wake**: schedule a test event, sleep the Mac across it, wake, and check you get one late reminder.

## Layout

```
Numo/
├── project.yml                 XcodeGen spec
├── App/                        @main, composition root, Info.plist, entitlements
├── Services/                   EventKit provider, system events, login item, URL opener, settings store
├── Coordination/               AppModel (menu bar state), ReminderCoordinator
├── Windowing/                  ReminderPanel, ReminderWindowController
├── Features/                   Reminder card, MenuBar, Settings
├── DesignSystem/               PlatformBadge, main-actor Binding helper
└── Packages/NumoCore/          Foundation-only logic and its tests
```
