# H · Testing strategy

Principle: put as much logic as possible in `NumoCore` where it can be tested deterministically, then verify the thin system layers with scripted manual runs.

## Test pyramid

| Layer | Tooling | What it covers |
| --- | --- | --- |
| Unit (`NumoCore`) | Swift Testing (`@Test`), manual `Clock`, fixture files | Link detection, filtering, planning, dedupe, ledger state machine, catch-up policy, DST |
| Adapter | XCTest/Swift Testing in the app test target | EventKit snapshot mapping, URL opening via fake `URLOpening`, settings migration |
| Integration | Debug-only seeding tool + real EventKit | End-to-end calendar → overlay on a dev Mac |
| UI smoke | XCUITest | Onboarding, menu-bar popover, settings navigation |
| Manual QA | Checklists below | Spaces, displays, sleep/wake, real link opening, visual review |

## Unit tests that must exist

### Meeting link detection

Fixture-driven (`Fixtures/*.txt`, one input and expected result per file):

- Meet: `meet.google.com/abc-defg-hij`, with query strings, in plain text, in HTML, in `location`, in `url`.
- Teams: `/l/meetup-join/…`, `/meet/<id>?p=…`, `teams.live.com/meet/…`, gov hosts.
- Safe Links wrapped URLs; entity-escaped (`&amp;`) URLs; trailing punctuation.
- Several links (dial-in, doc link, agenda): the provider link wins.
- No link; look-alike hosts (`meet.google.com.evil.example`) must **not** classify.

### Planner and filter

- Offsets produce correct `fireAt`s; past offsets are skipped or caught up per policy.
- Declined / cancelled / all-day / no-link filters follow settings.
- Recurring: three occurrences yield three independent reminder sets.
- Moved meeting: old key cancelled, new key planned, no duplicate.
- Two calendars with the same meeting: one reminder.
- Simultaneous meetings: ordering and grouping.

### Ledger and engine (with a manual clock)

- Each transition in the [state machine](/architecture#reminder-state-machine), including snooze surviving a simulated relaunch.
- Wake after sleeping through a reminder: one late reminder, not two.
- Clock jumps forward and backward: no duplicates, no lost reminders.
- Heartbeat replan finds an event added without a change notification.
- Corrupt ledger file: engine recovers and logs.

### Time

Run planner tests in several `TimeZone`s and around transitions:

| Scenario | Date |
| --- | --- |
| EU DST end | 2026-10-25 (Europe/Berlin) |
| US DST end | 2026-11-01 (America/New_York) |
| EU DST start | 2027-03-28 |
| US DST start | 2027-03-14 |
| Zone change mid-day | Berlin → New York with a floating event |
| Midnight rollover | 23:59 → 00:00 |

## Testing calendar syncing

1. **Seed tool** (debug menu): creates an "On My Mac" calendar named *numo Test* and events at now+1, +2, +3 min, two at the same minute, one recurring daily, one all-day, one with a Teams link, one with a Meet link, one with both, one without a link.
2. **Edit tests** (in Calendar.app): move an event, change its link, delete it, delete one occurrence of a series, and verify popover and pending reminders update within a few seconds of `EKEventStoreChanged`.
3. **Account tests** with real Google, Microsoft 365 and iCloud accounts: create an invite from another account, accept, decline, cancel; record end-to-end latency in a table.
4. **Permission tests:** deny at first prompt, revoke in System Settings while running, re-grant; check recovery UI each time.
5. Note: EventKit cannot set your own attendee status, so declined-event behaviour is covered by unit tests on snapshots plus an observed real invite.

## Testing reminder timing

- Debug action "Send test reminder in 5 s".
- Seed events at +2 min and watch the log for `fireAt` vs. actual presentation time; accept drift under 1 s.
- Check the log for exactly one `presented` line per `ReminderKey`.
- Leave the app running for 8+ hours over a normal day; compare reminders to the calendar.

## Sleep / wake recovery

| Test | Steps | Expected |
| --- | --- | --- |
| Short sleep before reminder | Seed meeting +5 min, `pmset sleepnow`, wake at +2 min | Reminder fires at the correct time after wake |
| Sleep through reminder | Sleep until meeting +3 min, wake | One late reminder "Started 3 min ago" |
| Sleep past catch-up window | Sleep until +15 min, wake | No overlay; meeting listed as started |
| Scheduled wake | `sudo pmset schedule wake "<date time>"` | Reminder shows promptly after the scheduled wake |
| Lid close/open with external display | Close lid, reopen | Card on the right display, no stray dim windows |
| Screen lock | Lock before reminder, unlock after | Late reminder shows after unlock |

## Clock and time-zone

- Change the zone in System Settings with a floating event and a fixed-zone event; confirm replans.
- Change the clock forward 10 minutes and back 10 minutes (virtual machine or `sudo date`), confirm no duplicates.

## Multi-screen, Spaces and full-screen matrix

For each cell: does the card appear, on the right display, without switching Spaces, stealing typing focus, or hiding the menu bar/Dock?

| Setup | Gentle | Focused | Unmissable (+dim) |
| --- | --- | --- | --- |
| Single display, normal windows | | | |
| Single display, Safari full-screen | | | |
| Two displays, pointer on display 2 | | | |
| Two displays, full-screen app on display 2 | | | |
| Different Space on each display | | | |
| Stage Manager on | | | |
| Mission Control open | | | |
| Display unplugged mid-reminder | | | |
| Screen mirroring active (privacy mode) | | | |
| Dark and light appearance | | | |
| Reduce Motion / Reduce Transparency / Increase Contrast | | | |

Also verify that while Unmissable is visible you can still: click menu-bar items, open the Dock, Cmd-Tab, open Force Quit (Cmd-Opt-Esc), and type in another app until you click the card.

## Meeting link opening

- Unit: Teams `https` → `msteams` rewrite, provider-host allow-list.
- Manual with Teams app installed: both link styles open the right meeting.
- Manual without Teams: clean fallback to the browser.
- Manual Meet in each browser the user has set as default (Safari, Chrome, Arc if used).
- Failure path: block the URL scheme or use an invalid URL; confirm the error and **Copy link** action.

## Performance and energy

- Instruments *Time Profiler*, *Allocations* and *Energy Log* over 30 idle minutes: no recurring wakeups other than the heartbeat; memory flat.
- Activity Monitor: 0.0 % CPU idle; under 40 MB RSS.
- Overlay visible for 10 minutes: CPU stays low (1 Hz tick plus one slow animation).

## Accessibility

- VoiceOver walk-through of overlay, popover, onboarding, settings.
- Keyboard-only: Tab order, Return/Esc behaviour, popover navigation.
- Accessibility Inspector audit for contrast and labels in both appearances.

## Continuous integration

- Linux or macOS runner: `swift test` for `NumoCore`.
- macOS 26 runner (check image availability): `xcodebuild test` for app and UI smoke tests.
- Manual QA matrices run before each tagged release and recorded in the release notes.
