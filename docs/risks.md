# G · Risks & edge cases

## Technical risks

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R1 | Panel does not appear over some full-screen apps, or exits the Space | Medium | High | Phase 0 spike S1; accessory policy + non-activating panel; fall back to a standard notification (Phase 3) if a specific case is impossible; document known exceptions |
| R2 | Meet links for Google accounts missing from EventKit | Medium | High | Spike S3; parse every text field; if still missing, Phase 4 direct API for Google only |
| R3 | EventKit sync lag means a freshly created invite reminds late or not at all | Medium | Medium | `refreshSourcesIfNecessary()` on wake and before lead times; 5-min heartbeat replan; document account-side latency |
| R4 | Liquid Glass API shape changes between macOS 26 point releases | Low | Medium | Wrap in `DesignSystem/GlassSurface`; one place to change; test on the oldest and newest 26.x |
| R5 | `MenuBarExtra` limitations (no programmatic open, focus quirks) | Medium | Low | Spike S4; `NSStatusItem` fallback behind the same view |
| R6 | Settings window does not come to front from an accessory app | High | Low | `SettingsOpener` helper that activates the app and temporarily uses `.regular` policy; tested early |
| R7 | Unmissable mode feels like a trap or collides with system UI | Low | High | Levels below menu bar/Dock; always-visible Snooze/Dismiss; Esc = Snooze; ends at meeting end; "Pause reminders" always in the menu bar |
| R8 | Screen-share detection is unreliable | High | Medium | Present as a *heuristic* with a manual toggle; never claim a guarantee |
| R9 | `sharingType = .none` does not hide the window from modern capture | Medium | Medium | Treat as best-effort; privacy mode hides *content* (title) instead of relying on window exclusion |
| R10 | Ledger corruption or schema drift causes duplicates or silence | Low | High | Versioned JSON, atomic writes, reset-on-corrupt with a log entry, duplicate-prevention test in soak run |
| R11 | Teams `msteams://` handling differs by link type | Medium | Low | Spike S5; always fall back to the https URL |
| R12 | Calendar permission revoked while running | Low | High | Re-check authorisation on activate, wake and every replan; visible warning state in the menu bar |
| R13 | Reminder shown while the screen is locked or asleep and never seen | Medium | High | `presented` is non-terminal; repeat rule re-shows after wake/unlock; catch-up policy |

## Edge cases and decisions

### Time

| Case | Behaviour |
| --- | --- |
| Mac sleeps through a lead reminder | On wake, replan: show **one** late reminder ("Started 4 min ago") if within the catch-up window; otherwise expire silently |
| Mac asleep at meeting start and still asleep | Cannot be fixed without privileged wake APIs. Documented non-goal |
| Time-zone change (travel) | `NSSystemTimeZoneDidChange` → re-query and replan. Absolute `Date`s don't change; floating events (no zone) shift to the new local time and are re-planned |
| Manual clock change | `NSSystemClockDidChange` → replan; ledger prevents re-alerting meetings already handled, including those that "return to the future" |
| DST transitions | All maths on absolute `Date`s; local display via `Calendar` with the current zone. Tests around 2026-10-25 (EU), 2026-11-01 (US) and 2027 spring transitions |
| Midnight rollover | `NSCalendarDayChanged` → refresh "Today" list |
| Meeting already running at launch | Reminder if within catch-up window and no ledger entry; otherwise just listed |

### Events

| Case | Behaviour |
| --- | --- |
| Recurring series | Identity = external ID + `occurrenceDate`; each occurrence alerts once; editing a single instance doesn't re-alert siblings |
| One occurrence moved | New `startAt` → new `ReminderKey`; old pending reminders cancelled |
| Cancelled | Pending reminders removed; visible overlay switches to "Meeting cancelled" and closes |
| Declined / tentative | Declined skipped; tentative follows setting (default remind) |
| Two meetings at the same time | One card, main meeting plus compact stack; each has its own Join |
| Back-to-back meetings | Each alerts independently; second card appears when its time arrives, replacing the first only if the first has been acted on |
| Same meeting in two calendars | Fingerprint dedupe (link, else title+start+end) |
| No link | Skipped by default; if enabled, card has Snooze/Dismiss only (and an **Open in Calendar** action) |
| Several links in notes | Prefer known providers (Meet/Teams) over dial-in or doc links; first match by priority url → location → notes |
| Teams link inside Outlook Safe Links | Unwrap `url=` query parameter before classification |
| HTML in notes | Strip tags, decode entities before link detection |
| All-day events | Skipped by default |
| Very long titles | 2 lines then truncate; full title in tooltip |
| Private or "busy" events | Title may be "Busy"; show it as provided |

### System

| Case | Behaviour |
| --- | --- |
| Permission revoked / denied | Menu-bar warning state; reminders paused; recovery card with System Settings deep link |
| Network offline | No impact in MVP (EventKit is local). In Phase 4 the provider reports staleness and the UI shows "last synced" |
| App relaunch / crash | Ledger restores snoozes and fired reminders; catch-up policy runs |
| Display added/removed while visible | Observe `didChangeScreenParametersNotification`; move the card to a remaining screen; rebuild dims |
| Full-screen apps, Stage Manager, multiple Spaces | `.canJoinAllSpaces` + `.fullScreenAuxiliary`; matrix in [testing](/testing) |
| Fast user switching | Don't present while this user session is inactive (`NSWorkspace.sessionDidResignActiveNotification`) |
| Screen locked | Cannot draw over the lock screen. Re-present after unlock if the meeting is still in the catch-up window |
| Join link fails to open | Show a non-modal error with **Copy link** |
| User in another call when the next starts | Snooze/Dismiss are one click; the app cannot know about calls |
| Notarisation or sandbox blocks a capability | All planned features work in the sandbox; verify in Phase 1 with the sandboxed build |

## Open questions to resolve in Phase 0

1. Which window level exactly keeps the menu bar usable above full-screen apps?
2. What do Google, Exchange and iCloud events expose in `url`, `location`, `notes`?
3. Does `INFocusStatusCenter` provide enough value to justify its authorisation prompt?
