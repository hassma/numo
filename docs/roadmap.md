# F · Implementation roadmap

Reliability first: a working MVP before polish, and a feasibility spike before any commitment.

Effort is relative (S ≈ days, M ≈ 1–2 weeks, L ≈ 2–3 weeks of one developer), not a calendar promise.

## Phase 0 · Feasibility spikes {#phase-0-feasibility-spikes}

**Effort S.** Throwaway code on a real Mac running macOS 26. Output is a findings page added to these docs.

| Spike | Question | Pass criterion |
| --- | --- | --- |
| S1 · Panel over full-screen | Does the recipe in [feasibility](/feasibility#always-on-top-reminder-window) show above a full-screen app on Space 2 without switching Spaces or stealing typing focus? Which window level keeps the menu bar and Dock usable? | Verified on a laptop display + external display, with Safari full-screen and a full-screen video |
| S2 · Glass in a panel | Does `glassEffect` + `GlassEffectContainer` render correctly in a transparent borderless `NSPanel` hosted by `NSHostingView`? | Looks right over light, dark and busy backgrounds; Reduce Transparency respected |
| S3 · EventKit link survey | For each of your account types (Google, M365, iCloud), where do Meet/Teams links land (`url` / `location` / `notes`)? Are cancelled events returned? How stale can a new invite be? | A table of results; go/no-go for EventKit-only |
| S4 · Menu bar host | Does `MenuBarExtra(.window)` give a live label and good glass? Can we open Settings reliably from an accessory app? | Live label updates; Settings opens in front on first try |
| S5 · Teams deep link | Does `msteams://` open the right meeting for both `/l/meetup-join/` and `/meet/` links, and is detection of the app reliable? | Works with Teams installed; clean fallback without it |

**Exit:** decisions 1, 4 and 8 in [Decisions](/decisions) confirmed or revised.

## Phase 1 · MVP: it reliably reminds me

**Effort M.**

Scope:

- Xcode project, `NudgeCore` package, strict concurrency, accessory app.
- EventKit provider, authorisation flow (bare-bones), calendar enable/disable.
- Link detector with fixtures; filter; planner; ledger; engine with sleep/wake/clock recovery.
- Focused overlay (panel, glass card, ring, Join/Snooze/Dismiss), single meeting.
- Menu-bar popover: next meeting, countdown, today, quick join.
- Minimal settings: calendars, lead times, snooze, launch at login.
- "Send test reminder".

**Acceptance criteria**

1. Events created in Apple, Google and Microsoft accounts appear in the popover within the account's sync latency.
2. A reminder appears at each chosen offset **once**, across relaunch, sleep/wake and calendar edits.
3. Join opens the right Meet/Teams link and removes the overlay; Snooze re-shows after the chosen interval; Dismiss never re-shows that meeting.
4. Cancelled and declined meetings never alert; a moved meeting alerts at its new time only.
5. Idle CPU is 0.0 % in Activity Monitor over 10 minutes; resident memory under 40 MB.
6. All `NudgeCore` unit tests pass, including DST and manual-clock scenarios.
7. No network entitlement; app launches with Calendar permission denied and shows the recovery state.

## Phase 2 · The full experience

**Effort L.**

- Gentle and Unmissable modes; escalation stages; optional dim windows; sound.
- Multi-meeting stack; per-screen placement and display-change handling.
- Onboarding flow; complete settings window; pause; Dock-icon toggle; start-minimised.
- Full accessibility behaviour (Reduce Motion/Transparency, VoiceOver, keyboard).
- Join-success morph and polished spring motion.

**Acceptance criteria**

1. All three modes match the [UI spec](/ui-spec) in light and dark appearance.
2. Unmissable persists until an explicit action or meeting end, and menu bar, Dock, Cmd-Tab and Force Quit stay usable while it is up.
3. Overlay appears correctly over a full-screen app, on both displays of a two-display setup, and after a display is unplugged mid-reminder.
4. With Reduce Motion on, no spring, pulse or scale animation runs.
5. Fresh-install onboarding completes in under 90 seconds and ends with a successful test reminder.
6. VoiceOver can complete Join, Snooze and Dismiss without a mouse.

## Phase 3 · Hardening and distribution

**Effort M.**

- Privacy mode (manual, mirroring, optional heuristic); Focus downgrade if feasible.
- `UserNotifications` time-sensitive fallback for the next meetings, cancelled when the overlay appears.
- Instruments pass (energy, memory, wakeups), long-run soak test.
- Localisation scaffolding (String Catalogs), crash-safe ledger recovery.
- Developer ID signing, notarisation, release automation, update path.

**Acceptance criteria**

1. 48-hour soak test with sleep/wake cycles: zero missed and zero duplicate reminders in the log.
2. Killing the app before a meeting still produces a system notification at the right time.
3. Privacy mode hides titles in a mirrored-display scenario.
4. Notarised build installs and runs on a clean macOS 26 machine.

## Phase 4 · Direct calendar APIs (optional)

**Effort L.** Start only if S3 or daily use shows EventKit gaps (missing Meet links, slow sync).

- `GoogleCalendarProvider` and `GraphCalendarProvider` behind `CalendarProviding`.
- OAuth 2.0 + PKCE via `ASWebAuthenticationSession`, Keychain refresh tokens, least-privilege read-only scopes.
- Incremental sync (`syncToken`, delta query) on a slow poll; aggregate and dedupe with EventKit.
- Network entitlement added, privacy copy updated, sign-out wipes tokens.

**Acceptance criteria**

1. Conference links come from structured API fields, not text parsing.
2. Tokens exist only in Keychain; sign-out removes them.
3. Network traffic is limited to the two API hosts and idle when no account is connected.

## Dependencies between phases

```
Phase 0 ──▶ Phase 1 ──▶ Phase 2 ──▶ Phase 3
                │                      ▲
                └──────▶ Phase 4 ──────┘   (optional; only if justified by Phase 0/1)
```

## Definition of done (every phase)

- Builds with Swift 6 strict concurrency and zero warnings.
- New logic covered by unit tests; new UI covered by a manual QA row in the [testing matrix](/testing).
- No new permission or entitlement without a documented reason.
- Docs updated.
