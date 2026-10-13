# Overview & MVP

## Goal

> When a meeting starts, I should not be able to accidentally overlook it.
> The experience must be impossible to ignore accidentally, but always possible to intentionally dismiss or snooze.

numo is a small, native, menu-bar-resident macOS app (Swift 6, SwiftUI, AppKit only for window management, macOS 26+, Liquid Glass). It reads calendars, finds meeting links, and shows an escalating glass overlay.

## About the name

**numo** comes from the Ukrainian word «нумо» ("come on", "let's go"): the nudge you need to actually get into the meeting. Code identifiers use `Numo` (for example `NumoCore`, `NumoApp`), and the placeholder bundle ID is `app.numo.Numo`.

## How to read the confidence markers

| Marker | Meaning |
| --- | --- |
| ✅ | Documented public API or well-established behaviour |
| 🔬 | Believed to work, but must be verified on real macOS 26 hardware in a Phase 0 spike before we build on it |
| ⚠️ | Real platform limitation: we design around it |

## Requirements analysis

| Requirement | Verdict | Approach |
| --- | --- | --- |
| Apple / Google / Microsoft calendars, multiple accounts | ✅ via EventKit | Accounts added in System Settings → Internet Accounts surface in EventKit. No OAuth in MVP. |
| Minimal permissions | ⚠️ | Since macOS 14 reading events needs **Full Access**; there is no read-only tier. We say so honestly in onboarding. |
| Detect Meet / Teams links | 🔬 | Parse `url`, `location`, `notes`. Whether Google's structured conference data reaches EventKit must be checked per account type. |
| Cancelled / rescheduled / recurring | ✅ | `EKEventStoreChanged` + re-query; identity = external ID + occurrence date. |
| No duplicate alerts | ✅ | Persistent reminder ledger keyed by occurrence, start time and offset. |
| Floating, always-on-top reminder | ✅/🔬 | Non-activating `NSPanel` in an accessory app. Full-screen Space behaviour needs a hardware spike. |
| Appear over full-screen apps | 🔬 | `.canJoinAllSpaces` + `.fullScreenAuxiliary` + `.accessory` policy. Community-verified, not in Apple's docs. |
| Dim background | ✅ | One borderless dimming window per `NSScreen`, below the card, below the menu bar. |
| Native Liquid Glass | ✅ | `glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent` button styles. |
| Honour Focus / DND | ⚠️ | No reliable public API to read the active Focus. Offer a conservative opt-in (see [feasibility](/feasibility#focus-and-do-not-disturb)). |
| Detect screen sharing | ⚠️ | No public "am I sharing?" API. Use a *privacy mode* with heuristics and a manual toggle. |
| Wake a sleeping Mac for a meeting | ⚠️ Out of scope | Needs privileged power APIs. We catch up on wake instead. |
| Low idle CPU / memory | ✅ | Event-driven; single sleeping task; no ticking timers while idle. |

## Key architectural decisions

1. **EventKit first, OAuth later (and only if needed).** It covers all three providers with one code path, no credentials stored, no network access in the MVP.
2. **Pure Swift core in a local package.** Link detection, filtering, planning, dedupe and the reminder state machine have no EventKit/AppKit imports. They are unit-testable with an injected clock.
3. **`NSPanel` for the overlay, SwiftUI for its content.** AppKit owns window level, Spaces behaviour and focus. SwiftUI owns everything visual.
4. **Wall-clock-aware scheduling.** Arm one sleep for the next reminder, then re-arm on wake, clock change, time-zone change, day change, calendar change and a 15-minute heartbeat.
5. **Escalation, not noise.** The visual urgency changes colour, ring and wording only. Layout never jumps.
6. **Every disruptive behaviour is user-controlled and escapable.** Persistent mode still ends at the meeting's end time and never covers the menu bar or Dock.

## Recommended simplest reliable MVP

Ship this before anything else:

- Accessory (no Dock icon) app with a menu-bar item.
- EventKit read access, calendar on/off list, declined/all-day/cancelled filtering.
- Meet and Teams link detection with unit-test fixtures.
- Reminder engine with ledger, dedupe, sleep/wake and clock-change recovery.
- **One** overlay style ("Focused": centred glass card, countdown ring, Join / Snooze / Dismiss).
- Menu-bar popover: next meeting, countdown, today's list, quick join.
- Settings: calendars, lead times, snooze durations, launch at login.
- A "Send test reminder" action.

Deliberately **not** in the MVP: onboarding polish, dimming, sound, Gentle/Unmissable modes, Focus/screen-share logic, notification fallback, OAuth. See the [roadmap](/roadmap).

## What happens next

No Xcode project is generated until you answer the questions in [Decisions awaiting approval](/decisions). The recommended defaults are pre-selected, so a reply of "approved with defaults" is enough.
