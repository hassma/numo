# numo

Your little helper to finally get into the meeting.

**numo** (from the Ukrainian «нумо», "come on, let's go") is a native macOS menu-bar app that makes it hard to accidentally miss a meeting. A notification is easy to ignore when you are deep in focus. numo puts a large Liquid Glass card in the middle of your screen when a meeting is about to start, with a big **Join** button, and gets out of the way the moment you act. You can always snooze or dismiss it.

> **Status: the Phase 1 MVP is written but has not been compiled yet.** It was written without a Swift toolchain, so expect a first round of compiler fixes. See [`docs/implementation.md`](docs/implementation.md) for what is built and what to verify first on a Mac.

## What it does

- Reads your calendars through macOS (iCloud, Google, Microsoft 365/Exchange). No sign-in, no servers, no network access.
- Finds Google Meet, Microsoft Teams and Zoom links in an event's URL, location and notes.
- Shows a floating glass card at 3 minutes before and at the start, with a countdown ring that grows more urgent the later you are.
- **Join** opens the meeting (the Teams app if it is installed), **Snooze** brings it back in 1–10 minutes, **Dismiss** silences that meeting.
- Menu-bar item with the next meeting's countdown, today's meetings and quick Join buttons.
- Survives sleep, relaunch, clock and time-zone changes without missing or repeating a reminder.
- Cancelled, declined and all-day events are skipped; the same meeting in two calendars alerts once.

Not in the MVP yet: sound, background dimming, the Gentle and Unmissable modes, onboarding. They are in the [roadmap](docs/roadmap.md).

## Requirements

- macOS 26 and Xcode 26 (the app uses Liquid Glass APIs)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Node 20+ and [pnpm](https://pnpm.io), only if you want to read the docs locally

## Quick start

Run everything from the repository root. `make` lists the available commands:

```sh
make doctor     # check that the tools are installed
make test       # run the logic tests (NumoCore)
make build      # compile the app without code signing
make run        # build, ad-hoc sign and launch numo from the terminal
make open       # generate the Xcode project and open it in Xcode
```

To start the app, use either:

- `make run`: builds with ad-hoc signing (no Apple developer team needed) and launches `build/Build/Products/Debug/numo.app`. `make stop` quits it.
- `make open`, then in Xcode select the **Numo** target → **Signing & Capabilities** → choose your **Team**, and press ⌘R. Best for debugging.

**What you should see:** no window and no Dock icon. numo lives in the **menu bar** at the top right (a calendar icon, or a countdown such as "in 12m"). macOS asks for calendar access the first time; choose **Allow Full Access**. Click the icon to open the popover, then choose **Send test reminder** to see the reminder card straight away.

Then use **Send test reminder** in the menu-bar popover to see the card without waiting for a meeting.

<details>
<summary>Without <code>make</code></summary>

```sh
(cd Numo && xcodegen generate)                         # writes Numo/Numo.xcodeproj (git-ignored)
open Numo/Numo.xcodeproj
xcrun swift test --package-path Numo/Packages/NumoCore
xcodebuild -project Numo/Numo.xcodeproj -scheme Numo \
  -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The parentheses keep the `cd` from changing your shell's directory, so the later commands still work.

</details>

## First run

- **Calendar access.** numo asks for *Full* Calendar Access. macOS has no read-only calendar permission. Events never leave your Mac.
- **No Dock icon.** numo is a menu-bar app (`LSUIElement`), and that is also what lets its reminder appear over full-screen apps. The setting only applies on a clean launch, so after the first run from Xcode, quit and open the built app from Finder if you still see a Dock icon.
- **Launch at login** is in Settings → General.
- **Pause** reminders for an hour or until tomorrow from the popover.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `swift: bad interpreter: /opt/homebrew/opt/python@3.11/bin/python3.11: no such file` | The `swift` first on your `PATH` is a stale Homebrew script, not Xcode's compiler. Use `make test` (it calls `xcrun swift`), or run `xcrun swift …` directly. To fix it for good, run `which -a swift` and `ls -l /opt/homebrew/bin/swift`, then `brew reinstall` or `brew uninstall` the formula it points to. `make doctor` shows what is on your `PATH`. |
| `chdir error … Numo/Numo/Packages/NumoCore` | A command that expects the repository root was run from inside `Numo/`. Run `cd ..` back to the root, or use `make`. |
| `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' …` | Only the Command Line Tools are active. Install Xcode 26, then `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, `sudo xcodebuild -license accept` and `sudo xcodebuild -runFirstLaunch`. `make build` and `make test` now detect this and say so. |
| `xcodegen: command not found` | `brew install xcodegen` |
| Xcode: "Signing requires a development team" | Pick your team under Signing & Capabilities, or use `make build`, which skips signing. |
| No calendar prompt appears / access was denied | System Settings → Privacy & Security → Calendars → Full Calendar Access → numo. To get the prompt again: `tccutil reset Calendar app.numo.Numo`. |
| A Dock icon appears | See *First run* above. |
| Menu-bar item missing | The notch or a crowded menu bar can hide it. Quit other menu-bar apps, or hold ⌘ and drag icons to make room. |

## How it works

The logic that decides *when* to remind lives in `NumoCore`, a Foundation-only Swift package with no UI, so it can be tested without a calendar, a screen or a clock:

```
EventKit ──▶ Meeting snapshots ──▶ MeetingFilter ──▶ ReminderPlanner ◀── ReminderLedger (persisted)
                                                          │
                       ReminderEngine: one sleeping task, re-armed on wake / clock /
                       time-zone / calendar changes and a 15-minute heartbeat
                                                          │
                              ReminderCoordinator ──▶ floating NSPanel (SwiftUI + Liquid Glass)
```

Every plan is recomputed from calendar, ledger and settings, so a missed or duplicated trigger is harmless. The full design is in [`docs/architecture.md`](docs/architecture.md).

## Repository layout

```
.
├── Makefile                    developer commands (make help)
├── Numo/
│   ├── project.yml             XcodeGen spec for the macOS app
│   ├── App/                    @main, composition root, Info.plist, entitlements
│   ├── Services/               EventKit provider, system events, login item, settings store
│   ├── Coordination/           menu-bar state, reminder coordinator
│   ├── Windowing/              the floating NSPanel
│   ├── Features/               reminder card, menu bar, settings
│   ├── DesignSystem/           shared views and helpers
│   └── Packages/NumoCore/      pure logic and its tests (swift test)
├── docs/                       product and technical plan (VitePress)
└── .github/workflows/ci.yml    logic tests on macOS and Linux, docs build
```

## Documentation

The plan and the MVP status are a [VitePress](https://vitepress.dev) site in `docs/`:

```sh
make docs-install
make docs-dev       # http://localhost:5173
make docs-build     # static site in docs/.vitepress/dist
```

Start with the [overview](docs/overview.md), then [MVP status](docs/implementation.md), the [architecture](docs/architecture.md), and the [roadmap](docs/roadmap.md). To publish on GitHub Pages, set `base` in `docs/.vitepress/config.mts` to `'/numo/'`.

## Contributing

- Swift 6 with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`). Keep `NumoCore` free of AppKit, SwiftUI and EventKit.
- New scheduling behaviour needs a test in `NumoCore` using the manual clock in `Tests/NumoCoreTests/TestSupport.swift`.
- No new entitlement or permission without a documented reason. The MVP deliberately has no network entitlement.
- Docs use pnpm, not npm.
