# Decisions

Each row has a recommended default. The MVP was built on these defaults; where it deviates, [MVP status](/implementation#deviations-from-the-plan) says so. Open a change here before changing a default in code.

| # | Decision | Recommended default | Alternatives and trade-off |
| --- | --- | --- | --- |
| 1 | **Calendar source for MVP** | EventKit only | Direct Google/Graph APIs give structured conference data and faster sync, but add OAuth, Keychain, network entitlement, and (for Google) app verification. Deferred to optional Phase 4. |
| 2 | **Minimum macOS** | macOS 26 only | Supporting 15 means writing a material-based fallback for every glass surface. Doubles UI test surface for little gain on a personal utility. |
| 3 | **Distribution** | Developer ID + notarization, App Sandbox on | Mac App Store adds review risk for an "intentionally disruptive" overlay. Sandbox is compatible with everything planned here. |
| 4 | **Menu-bar host** | SwiftUI `MenuBarExtra` with `.window` style | `NSStatusItem` + custom panel gives programmatic open/close and finer control, at more AppKit code. Chosen only if the Phase 0 spike shows a blocker. |
| 5 | **Attention-mode semantics** | Selected mode applies to the *at-start* reminder. Earlier lead reminders are one step gentler (Unmissable → Focused, Focused → Gentle, Gentle → Gentle). | Per-offset mode matrix is more flexible but a heavier settings UI. |
| 6 | **Default reminder timing** | 3 minutes before + at start | Any combination of 1 / 3 / 5 / 0 / custom is supported. |
| 7 | **Events without a join link** | Not reminded by default; toggle "Also remind for events without a link" (shows *Dismiss / Snooze* only) | Reminding for everything is noisy (focus blocks, birthdays, reminders). |
| 8 | **Zoom and other providers** | Detect and label Zoom as a cheap extra (one host rule). Not promised in the brief. | Meet + Teams only keeps scope tight. |
| 9 | **Esc key in Unmissable mode** | Esc = Snooze (default snooze). Never silently dismisses. | Esc = Dismiss is faster but easier to hit by accident. |
| 10 | **Background dim default** | Off in Focused, on in Unmissable (both user-editable) | Always off is gentler; always on is stronger. |
| 11 | **Focus / DND** | Overlay ignores Focus by default (that is its purpose). Opt-in "Downgrade to Gentle while a Focus is active" where `INFocusStatusCenter` allows. | Honouring Focus by default would defeat the app. |
| 12 | **Notification fallback** | Phase 3: schedule a time-sensitive `UserNotifications` backup for the next meetings, cancelled when the overlay shows | Skipping it means a crashed app misses meetings silently. |
| 13 | **Bundle ID / signing team** | Placeholder `app.numo.Numo`; you provide the real team ID | Needed only when generating the Xcode project. |

## Inputs needed for Phase 0

- Which calendar accounts you actually use (Google / M365 / iCloud, and whether Google is added to macOS or only in a browser). This decides how much the EventKit spike matters.
- A Mac running macOS 26 with Xcode 26 for building. I can write the code from this Linux sandbox but cannot compile or run it here.
