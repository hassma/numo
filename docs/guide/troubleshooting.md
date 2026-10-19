# Troubleshooting

Run `just doctor` first. It prints the state of the toolchain and the signing certificate and usually points at the problem.

## Build and setup

### `swift: bad interpreter: /opt/homebrew/opt/python@3.11/bin/python3.11: no such file`

The `swift` first on your `PATH` is a stale Homebrew script, not Xcode's compiler. Use `just test` (it calls `xcrun swift`), or run `xcrun swift …` directly. To fix it for good, run `which -a swift` and `ls -l /opt/homebrew/bin/swift`, then `brew reinstall` or `brew uninstall` the formula it points to.

### `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' …`

Only the Command Line Tools are active. Follow [Set up Xcode](/guide/installation#_1-set-up-xcode). `just build`, `just test` and `just install` detect this and say so.

### `chdir error … Numo/Numo/Packages/NumoCore`

A command that expects the repository root was run from inside `Numo/`. Run `cd ..` back to the root, or use `just`, which works from any folder in the repository.

### `xcodegen: command not found`

`brew install xcodegen`

### `just: command not found`

`brew install just`. Without it, use the [plain commands](/guide/installation#without-just).

### Xcode: "Signing requires a development team"

Pick your team under Signing & Capabilities, or use `just run` / `just install`, which sign ad hoc and need no team.

### `no 'numo Local Signing' certificate in the login keychain`

You asked for `self` signing before creating the certificate. Run `just self-sign-setup`, then try again. See [Signing the app](/guide/signing).

## Running

### No calendar prompt appears, or access was denied

Open System Settings → Privacy & Security → Calendars → Full Calendar Access and enable numo. To get the prompt again, reset the permission and relaunch:

```sh
tccutil reset Calendar app.numo.Numo
```

### macOS asks for calendar access again after every rebuild

An ad-hoc signature changes with each build, so macOS sees a new app. Use [self-signing](/guide/signing) to give numo a stable identity.

### Reminders do not appear, or the menu shows outdated meetings

Open numo's menu. The line under *Reminders on* says when the calendar was last read and how many events came back. Click **Refresh** to force a read.

| What you see | Meaning and fix |
| --- | --- |
| `0 events` | macOS is not sharing the calendar. Check that Calendar.app shows the event and that Full Calendar Access is on for numo. |
| A number above 0 but an empty list | Every event was filtered out. By default only events with a Meet, Teams or Zoom link are shown; check the event options and the ticked calendars in Settings → Calendars. |
| No "Calendar read" line | numo has not read the calendar yet, usually because the permission is missing. |

For details, stream numo's log while you click **Refresh**:

```sh
log stream --predicate 'subsystem == "app.numo.Numo"' --info
```

It prints how many events were read, how many are usable and how many have a meeting link.

### numo shows no meetings

Add your accounts in System Settings → Internet Accounts. Google calendars need the account added there, not only in a browser. Then check they are ticked in numo's Settings → Calendars.

### Menu-bar item missing {#menu-bar-item-missing}

The notch or a crowded menu bar can hide it. Quit other menu-bar apps, or hold ⌘ and drag icons to make room.

### A Dock icon appears

numo is a menu-bar app (`LSUIElement`), but that setting only applies on a clean launch. If you started it from Xcode and still see a Dock icon, quit and open the installed app instead.

### The screen is dimmed and I want out

Click **Snooze** or **Dismiss** on the card. If the card does not respond, click the numo icon in the menu bar and choose **Quit**, or press ⌥⌘⎋ (Force Quit). The dimming also ends by itself after 10 minutes. Switch the style back under Settings → Reminders.

### macOS says the app "can't be opened"

Right-click `/Applications/numo.app` (or `build/Build/Products/Debug/numo.app`) and choose **Open**. An app built on your own Mac is normally not quarantined, so this should not happen. If it does, run `just self-sign-verify` to check the signature.

## Still stuck?

Open an issue at [github.com/hassma/numo/issues](https://github.com/hassma/numo/issues) with the output of `just doctor`, your macOS and Xcode versions, and the relevant lines of the log command above.
