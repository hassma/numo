# numo

Your little helper to finally get into the meeting.

**numo** (from the Ukrainian «нумо», "come on, let's go") is a native macOS menu-bar app that makes it hard to accidentally miss a meeting. A notification is easy to ignore when you are deep in focus. numo puts a large Liquid Glass card in the middle of your screen when a meeting is about to start, with a big **Join** button, and gets out of the way the moment you act. You can always snooze or dismiss it.

> **Status: Phase 1 MVP.** The app compiles on macOS 26 with Xcode 26. Runtime behaviour and the test suite are still being verified on real hardware, so expect rough edges. See [`docs/implementation.md`](docs/implementation.md) for what is built and what to check first.

The documentation is a [VitePress](https://vitepress.dev) site in [`docs/`](docs/): `just docs-dev` serves it at http://localhost:5173.

## Table of contents

- [What it does](#what-it-does)
- [Requirements](#requirements)
- [Installation](#installation)
  - [1. Set up Xcode](#1-set-up-xcode)
  - [2. Install XcodeGen and just](#2-install-xcodegen-and-just)
  - [3. Get the code](#3-get-the-code)
  - [4. Check your setup](#4-check-your-setup)
  - [5. Build and install](#5-build-and-install)
  - [6. Grant calendar access](#6-grant-calendar-access)
  - [Run without installing](#run-without-installing)
  - [Update and uninstall](#update-and-uninstall)
- [Using numo](#using-numo)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Contributing](#contributing)

## What it does

- Reads your calendars through macOS (iCloud, Google, Microsoft 365/Exchange). No sign-in, no servers, no network access.
- Finds Google Meet, Microsoft Teams and Zoom links in an event's URL, location and notes.
- Shows a floating glass card at 3 minutes before and at the start, with a countdown ring that grows more urgent the later you are.
- **Join** opens the meeting (the Teams app if it is installed), **Snooze** brings it back in 1–10 minutes, **Dismiss** silences that meeting.
- Menu-bar item with the next meeting's countdown, today's meetings and quick Join buttons.
- Survives sleep, relaunch, clock and time-zone changes without missing or repeating a reminder.
- Cancelled, declined and all-day events are skipped; the same meeting in two calendars alerts once.

Optional **blocking screen**: set Settings → Reminders → Reminder style to *Blocking screen* and the screen dims behind the card when a meeting starts, until you join, snooze or dismiss.

Not in the MVP yet: sound, the Gentle mode, onboarding. They are in the [roadmap](docs/roadmap.md).

## Requirements

| Requirement | Version | Needed for |
| --- | --- | --- |
| macOS | 26 (Tahoe) or later | building and running (Liquid Glass APIs) |
| Xcode | 26, the full app | building (the Command Line Tools alone are **not** enough) |
| [Homebrew](https://brew.sh), [XcodeGen](https://github.com/yonaskolb/XcodeGen), [just](https://just.systems) | any recent | `brew install xcodegen just` |
| Calendar accounts and **Full** Calendar Access | added in System Settings → Internet Accounts | something to remind you about; macOS has no read-only calendar permission |
| Apple Developer account | not required | `just install` signs ad hoc, or with a free local certificate |
| Node `^20.19` or `>=22.12` and [pnpm](https://pnpm.io) | optional | the docs site only |

The full table, with the reasons, is in the [requirements guide](docs/guide/requirements.md).

## Installation

numo is not distributed as a download yet, so you build it from source. It takes a few minutes. Run every command from the repository root. The [installation guide](docs/guide/installation.md) has the same steps with more detail.

### 1. Set up Xcode

1. Install **Xcode 26** from the App Store or [developer.apple.com](https://developer.apple.com/xcode/).
2. Make it the active developer directory, accept the license and install its components:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # adjust the path if your Xcode has another name
   sudo xcodebuild -license accept
   sudo xcodebuild -runFirstLaunch
   ```

3. Check: `xcodebuild -version` should print `Xcode 26.x`.

### 2. Install XcodeGen and just

```sh
brew install xcodegen just
```

The Xcode project is generated from `Numo/project.yml` and is not committed, so XcodeGen is required. [just](https://just.systems) runs the commands below; run `just` on its own to list them.

### 3. Get the code

```sh
git clone https://github.com/hassma/numo.git
cd numo
```

### 4. Check your setup

```sh
just doctor     # prints the toolchain state; fix anything it flags
just test       # optional: the logic tests
```

### 5. Build and install

```sh
just install
```

This builds a Release version, signs it ad hoc (no Apple account needed) and copies it to `/Applications/numo.app`. Start it from Launchpad or Finder, or run `open -a numo`. To keep macOS from asking for calendar access again after every rebuild, sign with your own certificate: `just self-sign-setup`, then `just install self` (see [Signing the app](docs/guide/signing.md)).

### 6. Grant calendar access

On first launch macOS asks whether numo may access your calendars. Choose **Allow Full Access**.

numo has no window and no Dock icon. Look for its icon (a calendar, or a countdown such as "in 12m") in the **menu bar** at the top right. Click it, then choose **Send test reminder** to see the reminder card right away.

### Run without installing

| Command | What it does |
| --- | --- |
| `just run` | Builds a Debug version with ad-hoc signing and launches it from `build/`. |
| `just run self` | Same, signed with your local certificate. |
| `just run none` | Skips signing altogether. The app then runs unsandboxed, which is fine for trying it out. |
| `just stop` | Quits the running app. |
| `just open` | Generates the Xcode project and opens it. Choose your **Team** under Signing & Capabilities, then press ⌘R. |

### Update and uninstall

```sh
git pull && just install    # update
just uninstall              # remove /Applications/numo.app
```

Uninstalling keeps your settings; [the installation guide](docs/guide/installation.md#uninstall) shows how to remove them too.

## Using numo

- **Reminders** appear 3 minutes before a meeting and when it starts. **Join Meeting** (Return) opens the link, **Snooze** (Esc) brings the card back, **Dismiss** (⌘.) silences that meeting.
- **Blocking screen (optional):** Settings → Reminders → *Reminder style* → *Blocking screen* dims every display behind the card once the meeting starts. It never covers the menu bar or the Dock and ends after 10 minutes at most.
- **Menu bar:** the icon shows the next meeting's countdown; the popover lists today's meetings, with Join, Refresh, Pause, Settings and *Send test reminder*.

All of it is described in [Using numo](docs/guide/using.md).

## Development

Run `just` from the repository root to list every command: `just test` runs the logic tests, `just build` compile-checks the app, `just open` opens it in Xcode, and `just docs-dev` serves the docs. See [Development](docs/guide/development.md).

## Troubleshooting

Run `just doctor` first. The most common problems:

| Problem | Fix |
| --- | --- |
| `xcode-select: error: tool 'xcodebuild' requires Xcode …` | Only the Command Line Tools are active. Follow [step 1](#1-set-up-xcode). |
| `swift: bad interpreter: …python3.11…` | A stale Homebrew `swift` is first on your `PATH`. Use `just test`, which calls `xcrun swift`. |
| No calendar prompt appears / access was denied | System Settings → Privacy & Security → Calendars → Full Calendar Access → numo. To get the prompt again: `tccutil reset Calendar app.numo.Numo`, then relaunch. |
| Reminders don't appear, or the menu shows outdated meetings | Open numo's menu: the line under "Reminders on" shows when the calendar was last read and how many events came back. Click **Refresh**. `0 events` means macOS is not sharing the calendar; a number with an empty list means every event was filtered out, usually for lacking a Meet, Teams or Zoom link. |
| The screen is dimmed and I want out | Click **Snooze** or **Dismiss**, or use the numo menu-bar icon → **Quit**, or press ⌥⌘⎋. The dimming ends by itself after 10 minutes. |

More fixes are in the [troubleshooting guide](docs/guide/troubleshooting.md).

## How it works

The logic that decides *when* to remind lives in `NumoCore`, a Foundation-only Swift package with no UI, so it can be tested without a calendar, a screen or a clock:

```
EventKit ──▶ Meeting snapshots ──▶ MeetingFilter ──▶ ReminderPlanner ◀── ReminderLedger (persisted)
                                                          │
                       ReminderEngine: one sleeping task, re-armed on wake / clock /
                       time-zone / calendar changes and a 5-minute heartbeat
                                                          │
                              ReminderCoordinator ──▶ floating NSPanel (SwiftUI + Liquid Glass)
```

Every plan is recomputed from calendar, ledger and settings, so a missed or duplicated trigger is harmless. The full design is in [`docs/architecture.md`](docs/architecture.md).

## Repository layout

```
.
├── justfile                    developer commands (run `just` to list them)
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

The guide, the product plan and the MVP status are a [VitePress 2](https://vitepress.dev) site in `docs/`:

```sh
just docs-install
just docs-dev       # http://localhost:5173
just docs-build     # static site in docs/.vitepress/dist
```

Start with the [introduction](docs/guide/index.md) and the [installation guide](docs/guide/installation.md). The plan is in the [overview](docs/overview.md), [architecture](docs/architecture.md) and [roadmap](docs/roadmap.md); what is built is in [MVP status](docs/implementation.md). To publish on GitHub Pages, build with `DOCS_BASE=/numo/ pnpm docs:build`.

## Contributing

- Swift 6 with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`). Keep `NumoCore` free of AppKit, SwiftUI and EventKit.
- New scheduling behaviour needs a test in `NumoCore` using the manual clock in `Tests/NumoCoreTests/TestSupport.swift`.
- No new entitlement or permission without a documented reason. The MVP deliberately has no network entitlement.
- Docs use pnpm, not npm.
