# Installation

numo is not distributed as a download yet, so you build it from source. Run every command from the repository root, which is the folder containing the `justfile`.

::: tip Short on time?
Xcode 26 installed and active? Then it is just:

```sh
brew install xcodegen just
git clone https://github.com/hassma/numo.git && cd numo
just install && open -a numo
```
:::

## 1. Set up Xcode

1. Install **Xcode 26** from the App Store or [developer.apple.com](https://developer.apple.com/xcode/).
2. Make it the active developer directory, accept the license and install its components:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # adjust the path if your Xcode has another name
   sudo xcodebuild -license accept
   sudo xcodebuild -runFirstLaunch
   ```

3. Check it: `xcodebuild -version` should print `Xcode 26.x`. If you see an error about the Command Line Tools instead, the first command above did not take effect.

## 2. Install XcodeGen and just

```sh
brew install xcodegen just
```

The Xcode project is generated from `Numo/project.yml` and is not committed, so XcodeGen is required. [just](https://just.systems) runs the commands used in this guide; run `just` on its own to list them. Without Homebrew, see the [just](https://just.systems/man/en/packages.html) and [XcodeGen](https://github.com/yonaskolb/XcodeGen#installing) install options.

## 3. Get the code

```sh
git clone https://github.com/hassma/numo.git
cd numo
```

## 4. Check your setup

```sh
just doctor
```

It prints the active developer directory, the Swift and Xcode versions, whether `xcodegen` is found, and whether a [signing certificate](/guide/signing) exists. Every line should look sensible; the notes after `<-` say what to look for. If something is missing, see [Troubleshooting](/guide/troubleshooting).

Optionally run the logic tests. They need no calendar and no screen:

```sh
just test
```

## 5. Build and install

```sh
just install
```

This builds a Release version, signs it ad hoc (no Apple account needed) and copies it to `/Applications/numo.app`. Start it from Launchpad or Finder, or run `open -a numo`.

To keep macOS from asking for calendar access again after every rebuild, install with a local certificate instead. It takes one extra command; see [Signing the app](/guide/signing).

## 6. Grant calendar access

On first launch macOS asks whether numo may access your calendars. Choose **Allow Full Access**. numo only works with full access; macOS has no read-only calendar permission.

numo has no window and no Dock icon. Look for its icon, a calendar or a countdown such as "in 12m", in the **menu bar** at the top right. If you cannot find it, see [Troubleshooting](/guide/troubleshooting#menu-bar-item-missing).

## 7. Check that it works

1. Click the menu-bar icon. The line under *Reminders on* should read *Calendar read HH:MM:SS · N events*. If N is 0, see [Troubleshooting](/guide/troubleshooting#reminders-do-not-appear-or-the-menu-shows-outdated-meetings).
2. Choose **Send test reminder**. The reminder card should appear in the middle of your screen.
3. Open **Settings…** to pick the calendars to watch and turn on **Launch at login**.

## Run without installing

To try numo without copying it to `/Applications`, build and launch it from the `build/` folder:

| Command | What it does |
| --- | --- |
| `just run` | Builds a Debug version with ad-hoc signing and launches it. |
| `just run self` | Same, signed with your [local certificate](/guide/signing). |
| `just run none` | Skips signing. The app runs unsandboxed, which is fine for trying it out. |
| `just stop` | Quits the running app. |
| `just open` | Generates the Xcode project and opens it. Select the **Numo** target → **Signing & Capabilities** → choose your **Team**, then press ⌘R. Best for debugging. |

### Without `just`

```sh
(cd Numo && xcodegen generate)                         # writes Numo/Numo.xcodeproj (git-ignored)
open Numo/Numo.xcodeproj
xcrun swift test --package-path Numo/Packages/NumoCore
xcodebuild -project Numo/Numo.xcodeproj -scheme Numo \
  -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The parentheses keep the `cd` from changing your shell's directory, so the later commands still work.

## Update

```sh
git pull
just install
```

This quits the running numo, replaces `/Applications/numo.app` and leaves your settings alone. If you install with a [local certificate](/guide/signing), add `self`: `just install self`.

## Uninstall

```sh
just uninstall
```

This quits numo and deletes `/Applications/numo.app`. Your settings and reminder history stay on disk. To remove them as well:

```sh
rm -rf ~/Library/Containers/app.numo.Numo              # settings and history of the sandboxed app
rm -rf ~/Library/Application\ Support/numo             # only exists if you ran with `just run none`
defaults delete app.numo.Numo 2>/dev/null              # only exists if you ran with `just run none`
tccutil reset Calendar app.numo.Numo                   # forget the calendar permission
```

If you created the [signing certificate](/guide/signing#remove-the-certificate), `just self-sign-reset` removes it too.
