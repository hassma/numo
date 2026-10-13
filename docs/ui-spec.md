# E · UI / UX specification

Visual direction: premium, minimal, Apple-native. Real Liquid Glass (never faked), SF Symbols, spring motion, adaptive light/dark, generous spacing. Sizes below are starting points to tune on hardware.

## Design tokens

| Token | Value |
| --- | --- |
| Card corner radius | 40 pt (Focused), 44 pt (Unmissable), 28 pt (Gentle). Use concentric inner radii |
| Card padding | 32 pt (Focused/Unmissable), 20 pt (Gentle) |
| Spacing scale | 4 / 8 / 12 / 16 / 24 / 32 |
| Title type | `.largeTitle.weight(.semibold)`, up to 2 lines then truncate |
| Time / countdown | `.title3` with `.monospacedDigit()` |
| Eyebrow label | `.subheadline.weight(.medium)`, secondary colour, uppercase tracking off |
| Icons | SF Symbols, hierarchical rendering; palette for urgency |
| Spring | `.spring(duration: 0.5, bounce: 0.25)` for presence, `.snappy` for state changes |
| Tint colours | System accent (Upcoming/Now), `.orange` (Late), `.red` (Overdue); always with icon + text, never colour alone |

## Reminder overlay

### Focused card (default)

```
                ┌────────────────────────────────────────┐
                │                                        │
                │        ╭──────╮                        │
                │        │ ◜◝   │   Meeting starting now │   eyebrow
                │        │ ◟◞ ⏱ │                        │   ring + icon
                │        ╰──────╯                        │
                │                                        │
                │     Weekly Product Sync                │   title
                │     ▣ Google Meet  ·  10:30 AM         │   platform + time
                │                                        │
                │   ┌──────────────────────────────┐     │
                │   │   ▶  Join Meeting            │     │   glassProminent, extra large
                │   └──────────────────────────────┘     │
                │     ┌───────────┐  ┌───────────┐       │
                │     │ ⏰ Snooze ▾│  │ ✕ Dismiss │       │   glass
                │     └───────────┘  └───────────┘       │
                └────────────────────────────────────────┘
```

- Width 440 pt; height fits content. Centred on the chosen screen, slightly above vertical centre.
- Single `GlassEffectContainer`; card is one `glassEffect(.regular, in: .rect(cornerRadius: 40))`, tinted by urgency stage.
- **Countdown ring** (96 pt, 6 pt stroke, round caps): trims from full to empty across the lead time. At start it is closed and the centre icon changes from countdown digits to the platform symbol. After start the ring becomes a slow elapsed-time arc.
- **Join Meeting**: `.buttonStyle(.glassProminent)`, `.controlSize(.extraLarge)`, SF Symbol `video.fill`. Default action (Return) once the panel is key.
- **Snooze**: split button. Primary tap = default snooze; menu offers 1 / 2 / 5 min and "Until meeting starts" when applicable.
- **Dismiss**: `xmark`, tooltip "Dismiss this reminder for this meeting".
- Draggable by background so the card can be moved off whatever it covers.

### Gentle card

Compact (360 × ~120 pt) glass pill at the top-right of the active screen: platform icon, title, "Starting in 3 min", Join button and a `…` menu (Snooze, Dismiss). Slides in, auto-hides after 15 s, remains available in the menu bar.

### Unmissable card

Same anatomy as Focused with larger type (title `.largeTitle` heavy), 520 pt wide, optional dim, and a persistent footer line: "Esc to snooze · ⌘. to dismiss" (shown only once the panel is key). Optional repeating chime every N minutes while overdue.

### Urgency stages {#urgency-stages}

| Stage | When | Eyebrow copy | Tint | Motion |
| --- | --- | --- | --- | --- |
| Upcoming | lead time → 60 s before | "Starting in 3 min" | accent | ring drains |
| Now | ±60 s around start | "Meeting starting now" | accent, stronger | ring closes; one gentle bounce |
| Late | +1 to +5 min | "Started 2 min ago" | orange | slow 4 s breathing glow |
| Overdue | beyond +5 min | "Started 7 min ago" | red | breathing glow; optional repeating chime |

Layout never moves between stages.

### Multiple simultaneous meetings

The main card is the best candidate (has a link, earliest start). Below the buttons, a compact list shows up to three more: icon, title, time, and a small Join button each. More than three shows "+2 more" which opens the menu-bar popover.

### Join success

On Join, the button morphs (`glassEffectID`) into a check mark for ~0.35 s, then the card scales to 0.96 and fades. Reduced motion: instant cross-fade.

### Cancelled or moved while visible

Eyebrow switches to "Meeting cancelled" (or "Meeting moved to 11:00"), actions collapse to a single **OK**, and the card auto-closes after 3 s.

### Accessibility

- Reduce Motion: no spring scale, no breathing; use 150 ms cross-fades and a static ring.
- Reduce Transparency / Increase Contrast: system glass adapts; add a 1 pt high-contrast stroke and opaque backing for text.
- Differentiate Without Colour: stage icon changes (`clock`, `bell.fill`, `exclamationmark.circle.fill`) in addition to tint.
- VoiceOver: panel announces "Meeting starting now, Weekly Product Sync, Google Meet" via an accessibility announcement when shown; buttons have explicit labels and hints; focus order Join → Snooze → Dismiss.
- Minimum 44 × 44 pt hit areas; contrast verified in both appearances.

## Menu bar

### Status item

| State | Symbol | Label |
| --- | --- | --- |
| Idle | `calendar.badge.clock` | none (or next meeting time if enabled) |
| Meeting within 60 min | same | "in 12m" (compact; optional title) |
| Meeting now / overdue | `video.fill` with accent badge | "Now" |
| Paused | `bell.slash` | "Paused" |
| Problem (permission revoked) | `exclamationmark.triangle` | none |

Compact by default because notched MacBooks have limited menu-bar space.

### Popover (about 340 pt wide, glass)

```
┌──────────────────────────────────────────┐
│  NEXT UP                           ◔ 12m │
│  Weekly Product Sync                     │
│  ▣ Google Meet · 10:30 – 11:00           │
│  [        ▶ Join        ]                │
├──────────────────────────────────────────┤
│  TODAY                                   │
│  10:30  Weekly Product Sync     ▣  ▶     │
│  13:00  1:1 with Sam            ▣  ▶     │
│  15:30  Design review                    │
├──────────────────────────────────────────┤
│  ● Reminders on · Focused        Pause ▾ │
│  ⚙ Settings…               Quit          │
└──────────────────────────────────────────┘
```

- Rows are keyboard navigable; the join arrow is always visible, not hover-only.
- "Pause" offers 1 hour / until tomorrow / resume.
- Permission problem replaces the list with an explanatory card and a **Open System Settings** button.
- Empty state: "No more meetings today", with the next one tomorrow if any.

## Onboarding

A single 560 × 460 pt glass window, four steps, with a progress indicator and Back / Continue.

1. **Welcome.** Headline "Never miss the start of a meeting." A live, looping demo of the Focused card, with Reduce Motion fallback to a static image.
2. **Calendar access.** Explains: why Full Access (Apple has no read-only tier), that data stays on the Mac, no network in this version. Button triggers the system prompt. Denied state shows recovery steps and a button opening System Settings → Privacy & Security → Calendars.
3. **Make it yours.** Calendar checklist (grouped by account), attention-mode picker with live preview cards, and **Send test reminder**.
4. **Finish.** Launch-at-login toggle (with `.requiresApproval` guidance), a note that the app lives in the menu bar, and where the next meeting appears.

## Settings {#settings}

Native `Settings` scene with a tab toolbar. Defaults in bold.

### Calendars

- Accounts and calendars, grouped by source, each with a toggle. **All on** except birthdays and holidays calendars.
- Detection: **Require a Meet / Teams link**, include Zoom and other links, include events without a link (off), include tentative (**on**), include all-day (off), include declined (off).
- Link-opening: **Prefer Teams app when installed**.

### Reminders

- Lead times: checkboxes for 1 / **3** / 5 min, **At start**, plus custom (minutes).
- Attention mode: Gentle / **Focused** / Unmissable (with live preview).
- Snooze durations: **1, 2, 5** (editable), default snooze **2**.
- Repeat while ignored: every **2 min**, up to **3** times (Gentle / Focused). Unmissable persists.
- Catch-up window: **10 min**.
- Sound: off / **on at start**; sound picker.

### Appearance

- Background dim: on/off, strength (default 40 %), applied in Focused/Unmissable.
- Show on: **screen with pointer** / all displays.
- Card position (centre / higher) and size (regular / large).

### Privacy

- Privacy mode: manual toggle shortcut, treat mirrored displays as presenting, optional power-assertion heuristic.
- When presenting: **hide titles**, force Gentle, mute sound.
- Downgrade during Focus (off, shown only if authorisation is available).

### General

- Launch at login, show Dock icon (off), start minimised, menu-bar label style, global shortcut for Join next meeting (optional).
- About and a debug section (only in debug builds).
