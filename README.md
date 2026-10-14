# numo

Your little helper to finally get into the meeting.

**numo** (from the Ukrainian «нумо», "come on, let's go") is a native macOS menu-bar app that makes it hard to accidentally miss a meeting. A notification is easy to ignore when you are deep in focus. numo puts a large Liquid Glass card in the middle of your screen when a meeting is about to start, with a big **Join** button, and gets out of the way the moment you act. You can always snooze or dismiss it.

> **Status: Phase 1 MVP.** The app compiles on macOS 26 with Xcode 26. Runtime behaviour and the test suite are still being verified on real hardware, so expect rough edges. See [`docs/implementation.md`](docs/implementation.md) for what is built and what to check first.

## Table of contents

- [What it does](#what-it-does)
- [Requirements](#requirements)
- [Installation](#installation)
  - [1. Set up Xcode](#1-set-up-xcode)
  - [2. Install XcodeGen](#2-install-xcodegen)
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

| Requirement | Version | Needed for | Notes |
| --- | --- | --- | --- |
| macOS | 26 (Tahoe) or later | building and running | The UI uses Liquid Glass APIs that do not exist earlier. |
| Xcode | 26, the full app | building | The Command Line Tools alone are **not** enough: `xcodebuild` is missing from them. |
| [Homebrew](https://brew.sh) | any recent | installing XcodeGen | Or install XcodeGen another way. |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | any recent | generating the Xcode project | `brew install xcodegen` |
| Git | any recent | getting the code | Included with Xcode. |
| Calendar accounts | Added in System Settings → Internet Accounts | having something to remind you about | iCloud, Google, Microsoft 365/Exchange, CalDAV. |
| Calendar permission | **Full** Calendar Access | running | macOS has no read-only calendar permission. Events never leave your Mac. |
| Apple Developer account | not required | nothing | `make run` and `make install` sign ad hoc. You only need a team to distribute the app or to run it from Xcode with your own signing. |
| Node 20+ and [pnpm](https://pnpm.io) | optional | the docs site only | Not needed to build or run the app. |

## Installation

numo is not distributed as a download yet, so you build it from source. It takes a few minutes. Run every command from the repository root.

### 1. Set up Xcode

1. Install **Xcode 26** from the App Store or [developer.apple.com](https://developer.apple.com/xcode/).
2. Make it the active developer directory, accept the license and install its components:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # adjust the path if your Xcode has another name
   sudo xcodebuild -license accept
   sudo xcodebuild -runFirstLaunch
   ```

3. Check: `xcodebuild -version` should print `Xcode 26.x`.

### 2. Install XcodeGen

```sh
brew install xcodegen
```

The Xcode project is generated from `Numo/project.yml` and is not committed, so this step is required.

### 3. Get the code

```sh
git clone https://github.com/hassma/numo.git
cd numo
```

### 4. Check your setup

```sh
make doctor
```

It prints the active developer directory, the Swift and Xcode versions, and whether `xcodegen` is found. If something is missing, see [Troubleshooting](#troubleshooting). Optionally run the logic tests:

```sh
make test
```

### 5. Build and install

```sh
make install
```

This builds a Release version, signs it ad hoc (no Apple account needed) and copies it to `/Applications/numo.app`. Then start it from Launchpad or Finder, or run `open -a numo`.

### 6. Grant calendar access

On first launch macOS asks whether numo may access your calendars. Choose **Allow Full Access**. If you miss the prompt or deny it, see [Troubleshooting](#troubleshooting).

numo has no window and no Dock icon. Look for its icon (a calendar, or a countdown such as "in 12m") in the **menu bar** at the top right. Click it, then choose **Send test reminder** to see the reminder card right away.

### Run without installing

To try numo without copying it to `/Applications`:

| Command | What it does |
| --- | --- |
| `make run` | Builds a Debug version with ad-hoc signing and launches it from `build/`. |
| `make run SIGNING=none` | Skips signing altogether. The app then runs unsandboxed, which is fine for trying it out. |
| `make stop` | Quits the running app. |
| `make open` | Generates the Xcode project and opens it. Select the **Numo** target → **Signing & Capabilities** → choose your **Team**, then press ⌘R. Best for debugging. |

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

### Update and uninstall

To update, pull the latest code and install again:

```sh
git pull
make install
```

To remove numo:

```sh
make uninstall
```

This quits numo and deletes `/Applications/numo.app`. Your settings and reminder history stay on disk. To remove them as well:

```sh
rm -rf ~/Library/Containers/app.numo.Numo              # settings and history of the sandboxed app
rm -rf ~/Library/Application\ Support/numo             # only exists if you ran with SIGNING=none
defaults delete app.numo.Numo 2>/dev/null              # only exists if you ran with SIGNING=none
tccutil reset Calendar app.numo.Numo                   # forget the calendar permission
```

## Using numo

- **Reminders** appear 3 minutes before a meeting and when it starts (change this in Settings → Reminders). The card shows the title, platform, time and a countdown ring that turns orange and then red the later you are.
- **Join Meeting** (or Return) opens the link and closes the card. **Snooze** (or Esc) brings it back after your default snooze. **Dismiss** (⌘.) silences that meeting.
- **Blocking screen (optional).** In Settings → Reminders → *Reminder style*, choose *Blocking screen*. The 3-minute card stays a normal floating card. When the meeting starts (or a snoozed reminder comes back after the start), every display dims behind the card, and clicks on the dimmed area are swallowed until you act. You can change the dimming strength, or let clicks pass through. *Send test reminder* previews it.
  - It never covers the **menu bar or the Dock**, so Cmd-Tab, Force Quit, Mission Control and the numo menu-bar icon (with **Quit**) keep working.
  - It ends by itself when you join, snooze or dismiss, when the meeting ends, or **after 10 minutes at most**.
  - It does not take keyboard focus, so keys you type keep going to your app. Click the card once to use Return (join), Esc (snooze) and ⌘. (dismiss).
- **Menu bar:** the icon shows the next meeting's countdown. The popover lists today's meetings with Join buttons, and has **Pause** (an hour or until tomorrow), **Settings…** and **Send test reminder**.
- **Settings:** choose which calendars to watch, which events count (links only, all-day, declined), lead times, snooze options, whether to open Teams in its app, and **Launch at login**.
- **No Dock icon.** numo is a menu-bar app (`LSUIElement`), which is also what lets its reminder appear over full-screen apps. The setting only applies on a clean launch, so if you started it from Xcode and still see a Dock icon, quit and open the installed app instead.

## Development

Run from the repository root; `make help` lists every command.

| Command | What it does |
| --- | --- |
| `make doctor` | Check that the tools are installed. |
| `make test` | Run the `NumoCore` logic tests. |
| `make build` | Compile the app without signing. A compile check; do not run this output. |
| `make run` / `make stop` | Build, launch and quit a Debug app. |
| `make open` | Generate the Xcode project and open it. |
| `make install` / `make uninstall` | Install to or remove from `/Applications`. |
| `make docs-dev` | Serve the docs at http://localhost:5173. |
| `make clean` | Remove generated files. |

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `swift: bad interpreter: /opt/homebrew/opt/python@3.11/bin/python3.11: no such file` | The `swift` first on your `PATH` is a stale Homebrew script, not Xcode's compiler. Use `make test` (it calls `xcrun swift`), or run `xcrun swift …` directly. To fix it for good, run `which -a swift` and `ls -l /opt/homebrew/bin/swift`, then `brew reinstall` or `brew uninstall` the formula it points to. `make doctor` shows what is on your `PATH`. |
| `chdir error … Numo/Numo/Packages/NumoCore` | A command that expects the repository root was run from inside `Numo/`. Run `cd ..` back to the root, or use `make`. |
| `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' …` | Only the Command Line Tools are active. Follow [Set up Xcode](#1-set-up-xcode). `make build`, `make test` and `make install` detect this and say so. |
| `xcodegen: command not found` | `brew install xcodegen` |
| Xcode: "Signing requires a development team" | Pick your team under Signing & Capabilities, or use `make run` / `make install`, which sign ad hoc. |
| No calendar prompt appears / access was denied | System Settings → Privacy & Security → Calendars → Full Calendar Access → numo. To get the prompt again: `tccutil reset Calendar app.numo.Numo`, then relaunch. |
| numo shows no meetings | Add your accounts in System Settings → Internet Accounts, check they are ticked in numo's Settings → Calendars, and remember that by default only events with a Meet, Teams or Zoom link are shown. |
| A Dock icon appears | See [Using numo](#using-numo). |
| The screen is dimmed and I want out | Click **Snooze** or **Dismiss** on the card. If the card does not respond: click the numo icon in the menu bar → **Quit**, or press ⌥⌘⎋ (Force Quit). The dimming also ends by itself after 10 minutes. Switch the style back under Settings → Reminders. |
| Reminders don't appear, or the menu shows outdated meetings | Open numo's menu. The line under "Reminders on" says when the calendar was last read and how many events came back. Click **Refresh** to force a read. `0 events` means macOS is not sharing the calendar (check Calendar.app shows the event, and that Full Calendar Access is on for numo). A number with an empty list means every event was filtered out, usually because it has no Meet, Teams or Zoom link. For details run `log stream --predicate 'subsystem == "app.numo.Numo"' --info`. |
| Menu-bar item missing | The notch or a crowded menu bar can hide it. Quit other menu-bar apps, or hold ⌘ and drag icons to make room. |
| macOS says the app "can't be opened" | Right-click `/Applications/numo.app` (or `build/Build/Products/Debug/numo.app`) and choose **Open**. An app built on your own Mac is normally not quarantined, so this should not happen. |

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
