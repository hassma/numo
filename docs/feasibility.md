# B · Technical feasibility

Everything here uses public APIs only. Items marked 🔬 are scheduled as [Phase 0 spikes](/roadmap#phase-0-feasibility-spikes) because they can only be confirmed on a Mac.

## Calendar access

### EventKit as the primary source ✅

- Accounts added in **System Settings → Internet Accounts** (iCloud, Google, Microsoft 365/Exchange, CalDAV) appear as `EKSource`s with `EKCalendar`s. One integration covers all three providers and multiple accounts.
- Authorisation: `EKEventStore.requestFullAccessToEvents()` (macOS 14+). Info.plist key `NSCalendarsFullAccessUsageDescription`. Sandbox entitlement `com.apple.security.personal-information.calendars`.
- ⚠️ **There is no read-only permission.** Apple offers *write-only* and *full* access; reading requires full access. The onboarding copy must state this plainly and that nothing leaves the Mac.
- Change detection: `Notification.Name.EKEventStoreChanged` (event-driven; no polling). Re-query the window on each (debounced).
- Fetching: `predicateForEvents(withStart:end:calendars:)` + `events(matching:)`. This call is synchronous and can be slow, so run it inside an actor, never on the main thread.
- `EKEventStore` and `EKEvent` are not `Sendable`. Confine the store to an actor and convert events to immutable `Sendable` snapshots immediately.
- Useful fields: `calendarItemExternalIdentifier`, `occurrenceDate`, `startDate`, `endDate`, `isAllDay`, `status` (`.canceled`), `url`, `location`, `notes`, `attendees` (`isCurrentUser`, `participantStatus`), `hasRecurrenceRules`, `timeZone`.
- Declined detection: `attendees?.first { $0.isCurrentUser }?.participantStatus == .declined`.
- Sync freshness: EventKit shows what the system's calendar daemon has synced. Call `refreshSourcesIfNecessary()` on wake and shortly before lead times. A brand-new invite can still lag by minutes for some account types.

### Meeting links in EventKit 🔬

Google and Exchange store the join link in different places, and what survives into EventKit is not documented:

- Teams invites normally embed the link in the body (`notes`) and set `location` to "Microsoft Teams Meeting".
- Google's structured `conferenceData` lives in the Calendar API. Whether the Meet link reaches EventKit via `url`, `location` or `notes` for a Google account added to macOS must be checked with real events.

**Spike:** dump `url`, `location`, `notes` for a sample Meet and Teams event on each account type. If Meet links are missing, that is the trigger for [Phase 4 (direct API)](#direct-google-and-microsoft-apis-optional).

### Direct Google and Microsoft APIs (optional) {#direct-google-and-microsoft-apis-optional}

Only if the spike shows gaps. Proposed architecture:

| Concern | Google Calendar API | Microsoft Graph |
| --- | --- | --- |
| Auth | OAuth 2.0 authorisation code + **PKCE** via `ASWebAuthenticationSession`, loopback or reversed-client-ID redirect | OAuth 2.0 / OIDC + PKCE via `ASWebAuthenticationSession` (hand-rolled, or MSAL if we accept a dependency) |
| Scope | `calendar.events.readonly` (read-only) | `Calendars.Read`, `offline_access` |
| Fetch | `events.list` with `singleEvents=true`, `timeMin/timeMax`; link from `hangoutLink` / `conferenceData.entryPoints` | `/me/calendarView?startDateTime&endDateTime`; link from `onlineMeeting.joinUrl` |
| Change feed | `syncToken` incremental sync, polled every ~5 min (push needs a public HTTPS endpoint, not available to a desktop app) | `/me/calendarView/delta`, polled |
| Token storage | Keychain generic password items, `kSecAttrAccessibleAfterFirstUnlock`, refresh token only | same |
| Entitlement | `com.apple.security.network.client` | same |

Caveats: Google OAuth clients in *Testing* status expire refresh tokens after 7 days, and sensitive scopes require verification for broad distribution. Work Microsoft tenants may require admin consent. This is why it is optional and last.

## Always-on-top reminder window

### Recipe ✅/🔬

An accessory app (`LSUIElement = YES`, activation policy `.accessory`) showing a borderless `NSPanel`:

```swift
final class ReminderPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating                       // or .floating + 1 above the dim window
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                       // the glass shape draws its own depth
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
    }
    override var canBecomeKey: Bool { true }    // so buttons and keyboard shortcuts work once clicked
    override var canBecomeMain: Bool { false }
}
```

Why each piece matters (community-verified; not spelled out in Apple's documentation 🔬):

| Piece | Reason |
| --- | --- |
| `.accessory` policy | Regular foreground apps are not layered over other apps' full-screen Spaces; accessory utilities are. |
| `.nonactivatingPanel` | Showing the panel does not activate our app, so the full-screen app does not leave its Space and your typing stays in your current app. |
| `.canJoinAllSpaces` + `.fullScreenAuxiliary` | Lets the panel appear on every Space, including full-screen ones. (`.canJoinAllSpaces` and `.moveToActiveSpace` are mutually exclusive.) |
| Level `.floating` or higher | Lower levels can be hidden behind full-screen windows. |

⚠️ **Deliberate limits** (matching "without trapping the user"):

- No `CGShieldingWindowLevel()` / screen-saver levels. They would cover the menu bar, Dock and system UI.
- Keep the dim window and card below the menu bar and Dock so Cmd-Tab, Force Quit, Mission Control and menu-bar items always work. 🔬 Confirm the exact level ordering on hardware.
- The panel is non-activating, so **Return does not "Join" while you type in another app**. Keyboard shortcuts work only after the panel is clicked, or via an optional Carbon `RegisterEventHotKey` global shortcut (public API, no Accessibility permission needed).
- A normal app cannot interrupt the secure login/lock screen; reminders missed while locked become late reminders after unlock.

### Dimming ✅

One borderless, click-passive `NSWindow` per `NSScreen`, black at ~35–45 % alpha, one level below the card. Rebuild on `NSApplication.didChangeScreenParametersNotification`.

### Multiple displays ✅

Show the card on the screen containing the mouse pointer (`NSEvent.mouseLocation`), with an option for "all displays". The dim covers all displays.

## Liquid Glass ✅ (exact signatures 🔬)

macOS 26 provides native glass in SwiftUI and AppKit. Planned usage:

- `glassEffect(_:in:)` with `.regular` (optionally `.tint(_:)`, `.interactive()`) on the card.
- `GlassEffectContainer(spacing:)` around groups of glass shapes. Glass cannot sample other glass, so one container per surface.
- `.buttonStyle(.glassProminent)` for Join, `.buttonStyle(.glass)` for secondary actions.
- `glassEffectID(_:in:)` + `@Namespace` for the morph when Join succeeds.
- Apply `glassEffect` after layout and padding modifiers.
- Use system materials for secondary content; do not fake glass with static translucent fills.
- Honour `accessibilityReduceTransparency`, `accessibilityReduceMotion`, `accessibilityDifferentiateWithoutColor` and increased contrast.

🔬 **Spike:** confirm glass renders correctly when hosted in a transparent borderless `NSPanel` via `NSHostingView`, including over bright and dark backgrounds, and that vibrancy is correct without activating the app.

## Menu bar 🔬

`MenuBarExtra { … }.menuBarExtraStyle(.window)` hosts SwiftUI content in a window-style popover. Known limitation: no public API to programmatically open or close it. We only need user-initiated opening, so that is acceptable. If the spike shows a blocker (for example live label updates or focus issues), fall back to `NSStatusItem` plus a custom panel.

Opening Settings from an accessory app is awkward: the `Settings` scene needs the app temporarily activated (`NSApp.activate()` and sometimes switching to `.regular` while the window is open). Build a small `SettingsOpener` helper and test it early.

## Launch at login ✅

`SMAppService.mainApp.register()` / `unregister()`. Status can be `.requiresApproval`; then offer `SMAppService.openSystemSettingsLoginItems()`.

## Scheduling and time ✅

- Compute the next fire `Date`, sleep with `Task.sleep(until:clock: .continuous)`. `ContinuousClock` keeps counting during system sleep.
- Monotonic clocks do not notice manual clock or time-zone edits, so re-plan on: `NSWorkspace.didWakeNotification`, `.NSSystemClockDidChange`, `.NSSystemTimeZoneDidChange`, `.NSCalendarDayChanged`, `EKEventStoreChanged`, and a 5-minute heartbeat.
- A UI countdown ticks (1 Hz) only while the overlay is visible, via `TimelineView`.

## Focus and Do Not Disturb

- ⚠️ macOS has no public API to read *which* Focus is active. `INFocusStatusCenter` can report a single "is focused" boolean after the user authorises it, with entitlement and privacy implications 🔬.
- Our overlay is a window, not a notification, so Focus does not suppress it. That is the point of the app.
- Plan: setting "Downgrade to Gentle while a Focus is on", off by default, implemented only if the authorisation flow is reasonable.

## Screen sharing and presentations

- ⚠️ No public API says "the user is sharing the screen".
- `NSWindow.sharingType = .none` asks the system to exclude the window from capture, but its behaviour with ScreenCaptureKit-based capture is not clearly documented. Treat it as best-effort 🔬 ([forum report](https://developer.apple.com/forums/thread/808016)).
- Plan: a **Privacy mode** setting with three triggers: manual "I'm presenting" toggle in the menu bar, display mirroring detected via `CGDisplayIsInMirrorSet`, and an optional heuristic using display-sleep power assertions held by other processes (`IOPMCopyAssertionsByProcess`). When active: hide the meeting title ("Meeting starting"), use Gentle, no sound. Documented as heuristic, never as a guarantee.

## Opening meeting links ✅/🔬

- `NSWorkspace.shared.open(url)` works in the sandbox.
- Teams desktop: rewrite `https://teams.microsoft.com/l/meetup-join/…` to `msteams://teams.microsoft.com/l/meetup-join/…` when `NSWorkspace.urlForApplication(toOpen: URL(string: "msteams://")!)` returns an app; otherwise open the https URL. 🔬 Verify the scheme with new-style `/meet/` links; fall back to https if the app rejects it.
- Google Meet opens in the default browser. We cannot choose a browser profile or account; `?authuser=` can be appended if the account email is known from the event.

## Distribution

Hardened Runtime + App Sandbox + notarisation (Developer ID). Entitlements for MVP: sandbox and calendars only. No network entitlement means the MVP provably makes no network requests.

## Feasibility summary

| Area | Status |
| --- | --- |
| EventKit multi-account read | ✅ |
| Meet link present in EventKit for Google | 🔬 spike |
| Floating panel over normal windows | ✅ |
| Panel over full-screen Spaces | 🔬 spike |
| Native Liquid Glass inside `NSPanel` | 🔬 spike |
| Sleep/wake/clock recovery | ✅ |
| Launch at login | ✅ |
| Focus detection | ⚠️ limited |
| Screen-share detection | ⚠️ heuristic only |
| Waking a sleeping Mac | ⚠️ out of scope |
