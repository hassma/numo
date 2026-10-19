# Introduction

**numo** (from the Ukrainian «нумо», "come on, let's go") is a native macOS menu-bar app that makes it hard to accidentally miss a meeting. A notification is easy to ignore when you are deep in focus. numo puts a large Liquid Glass card in the middle of your screen when a meeting is about to start, with a big **Join** button, and gets out of the way the moment you act. You can always snooze or dismiss it.

::: warning Status: Phase 1 MVP
The app compiles on macOS 26 with Xcode 26. Runtime behaviour and the test suite are still being verified on real hardware, so expect rough edges. See [MVP status](/implementation) for what is built and what to check first.
:::

## What it does

- Reads your calendars through macOS (iCloud, Google, Microsoft 365/Exchange, CalDAV). No sign-in, no servers, no network access.
- Finds Google Meet, Microsoft Teams and Zoom links in an event's URL, location and notes.
- Shows a floating glass card 3 minutes before and at the start, with a countdown ring that grows more urgent the later you are.
- **Join** opens the meeting (the Teams app if it is installed), **Snooze** brings it back in 1–10 minutes, **Dismiss** silences that meeting.
- An optional [blocking screen](/guide/using#blocking-screen) dims every display behind the card until you act.
- A menu-bar item shows the next meeting's countdown, today's meetings and quick Join buttons.
- Survives sleep, relaunch, clock and time-zone changes without missing or repeating a reminder.
- Skips cancelled, declined and all-day events; the same meeting in two calendars alerts once.

Not in the MVP yet: sound, the gentle mode and onboarding. They are in the [roadmap](/roadmap).

## Where to start

numo is not distributed as a download yet, so you build it from source. It takes about ten minutes, most of it waiting for Xcode.

1. Check the [requirements](/guide/requirements): a Mac with macOS 26 and the full Xcode 26 app.
2. Follow the [installation](/guide/installation): five commands from `git clone` to a running app.
3. If you rebuild often, set up [self-signing](/guide/signing) so macOS keeps the calendar permission.
4. Read [Using numo](/guide/using) for the card, the blocking screen and the settings.

The short version, once Xcode 26 is installed and active:

```sh
brew install xcodegen just
git clone https://github.com/hassma/numo.git && cd numo
just doctor      # checks the toolchain
just install     # builds and copies numo.app to /Applications
open -a numo     # then choose "Allow Full Access" for Calendar
```

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

Every plan is recomputed from calendar, ledger and settings, so a missed or duplicated trigger is harmless. The full design is in [System architecture](/architecture).
