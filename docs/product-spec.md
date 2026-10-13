# A · Product specification

## Positioning

Meeting Nudge is **not a notification app**. A notification is easy to miss while you are in flow; Meeting Nudge puts a large, glass, unmistakable card in the middle of your screen at the moment that matters, then gets out of the way the instant you act.

Principles:

1. **Hard to miss, easy to escape.** Strong visuals, never a lock-in.
2. **You stay in control.** Every disruptive behaviour has a setting.
3. **Small and calm.** Menu-bar utility, no Dock icon, almost no idle cost.
4. **Honest.** Says what it needs (calendar Full Access) and what it can't know (whether you already joined).

## Feature set

### Calendar and meeting detection

- Reads all calendars macOS knows about; per-calendar on/off.
- Looks 36 hours ahead (plus any event still in progress), refreshed on change.
- Filters by default: all-day events, events you declined, cancelled events, events with no join link (toggle).
- Recognises **Google Meet** and **Microsoft Teams** links in the event `url`, `location`, then `notes`, preferring a recognised provider over any generic link.
- Handles Outlook Safe Links wrapping and HTML-escaped notes.
- Same meeting present in two calendars (for example a personal and a work copy) alerts once.

### Reminder

- One or more lead times per meeting (default: 3 min before and at start).
- A single overlay per moment: if several meetings start together, one card with a compact stack.
- Primary actions: **Join Meeting**, **Snooze** (1 / 2 / 5 min, configurable), **Dismiss**.
- After Join: opens the link, plays a short confirmation, and fades the overlay.
- The overlay ends automatically at the meeting's end time.

### Attention modes

| Mode | Window | Motion / sound | Dim | Lifetime |
| --- | --- | --- | --- | --- |
| **Gentle** | Compact glass notification card, top-right of the active screen | Soft slide-in, no sound by default | No | Auto-hides after 15 s, then waits in the menu bar; re-shows per repeat setting |
| **Focused** | Large centred glass card | Spring appearance, ring animation, optional sound | Optional | Stays until acted on, repeats on the repeat interval if ignored |
| **Unmissable** | Prominent centred card, larger type | Spring appearance, escalating tint, optional repeating chime | Optional (default on) | Persists until Join / Snooze / Dismiss, or the meeting ends |

Hard rules for all modes: never cover the menu bar or Dock, never block Cmd-Tab, Force Quit, Mission Control or the lock screen, never steal typed keystrokes (the panel is non-activating).

### Urgency escalation

Time relative to start drives a visual stage (details in [UI spec](/ui-spec#urgency-stages)): Upcoming → Now → Late → Overdue. Only tint, ring state, wording and a slow pulse change; layout never moves.

### Menu bar

Icon with optional compact label ("in 12m"). Popover shows next meeting, countdown, today's meetings with quick Join, reminder status (on / paused / permission problem), and settings.

### Settings

Calendars, reminder timing, behaviour (mode, sound, snooze, repeat, dim), system (launch at login, Dock icon, start minimised, privacy mode). Full list in the [UI spec](/ui-spec#settings).

### Pause

"Pause reminders" for 1 hour or until tomorrow, from the menu bar. Visible state so you never wonder why nothing fired.

## Key flows

### First launch

```
Launch ─▶ Welcome (concept + live demo card)
       ─▶ Calendar access (explains Full Access; system prompt)
              ├─ granted ─▶ Pick calendars + attention mode ─▶ "Send test reminder"
              └─ denied  ─▶ Recovery screen with deep link to System Settings → Privacy → Calendars
       ─▶ Launch at login? ─▶ Done: menu bar shows next meeting
```

### A normal meeting

```
T-3 min   lead reminder (one step gentler than selected mode)
T-0       at-start reminder in the selected mode
T+1..5    overlay warms in tint, label reads "Started 2 min ago"
Join      URL opens (Teams app if installed, else browser) ─▶ overlay fades ─▶ ledger: joined
```

### Snooze

Snooze stores `snoozedUntil` in the ledger, so it survives relaunch and sleep. Snoozing never extends past the meeting's end time.

### Many meetings at once

Highest-priority meeting (has a link, earliest start) is the main card. Others appear as compact rows with their own Join buttons. Acting on the main card does not dismiss the others.

### Calendar changes while visible

- Meeting cancelled: card changes to "Meeting cancelled" and closes after 3 s.
- Meeting moved: card closes; a new reminder is planned for the new time.
- Permission revoked: reminders pause, menu-bar icon shows a warning, and the next popover open explains how to restore access.

## Non-goals

- Joining automatically without a click.
- Detecting whether you are already in the call.
- Editing calendar events.
- Syncing across devices; no accounts, no analytics, no servers.
- Waking a sleeping Mac.
