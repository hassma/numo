# Using numo

numo lives in the menu bar. It has no window and no Dock icon, which is also what lets its reminder appear over full-screen apps.

## Reminders

Reminders appear 3 minutes before a meeting and when it starts. You can change this in Settings → Reminders. The card shows the title, the platform, the time and a countdown ring that turns orange and then red the later you are.

| Action | Keys | What it does |
| --- | --- | --- |
| **Join Meeting** | Return | Opens the link and closes the card. Teams links open in the Teams app if it is installed. |
| **Snooze** | Esc | Brings the reminder back after your default snooze (1–10 minutes). |
| **Dismiss** | ⌘. | Silences that meeting. |

Esc never dismisses a meeting by accident: it only snoozes. The card does not take keyboard focus, so keys you type keep going to your app. Click the card once to use the shortcuts.

## Blocking screen

For meetings you must not miss, set **Settings → Reminders → Reminder style** to *Blocking screen*.

- The 3-minute card stays a normal floating card.
- When the meeting starts, or a snoozed reminder comes back after the start, every display dims behind the card, and clicks on the dimmed area are swallowed until you act.
- You can change the dimming strength, or let clicks pass through.
- **Send test reminder** previews it.

It is designed so you cannot get stuck:

- It never covers the **menu bar or the Dock**, so Cmd-Tab, Force Quit, Mission Control and the numo icon (with **Quit**) keep working.
- It ends by itself when you join, snooze or dismiss, when the meeting ends, or **after 10 minutes at most**.
- If something goes wrong, press ⌥⌘⎋ (Force Quit) or quit numo from its menu-bar icon.

## The menu bar

The icon shows the next meeting's countdown, for example "in 12m", or a calendar when nothing is coming up. Click it to see:

- today's meetings, with a **Join** button for those that have a link;
- the status line: *Calendar read HH:MM:SS · N events*, with a **Refresh** button that reads the calendar again;
- **Pause** reminders for an hour or until tomorrow;
- **Settings…** and **Send test reminder**.

## Settings

| Tab | What you can change |
| --- | --- |
| Calendars | Which calendars to watch, and which events count: only those with a Meet, Teams or Zoom link (the default), all-day events, and events you declined. |
| Reminders | When to remind (5 / 3 / 1 minute before and at the start), the reminder style (floating card or blocking screen) with its dimming options, which snooze durations to offer and the default for Snooze and Esc. |
| General | **Launch numo at login**, whether Teams meetings open in the Teams app, and **Send test reminder**. |

## What numo skips

- Cancelled events, declined events and all-day events (each can be switched on in Settings).
- Events without a Meet, Teams or Zoom link, unless you turn that filter off.
- Birthday calendars.
- The same meeting in two calendars: it alerts once.

## Privacy

numo reads your calendars through macOS and keeps everything on your Mac. It has no network entitlement, no account and no analytics. Reminder history (which reminders were shown) is stored locally so a relaunch does not repeat or miss one.
