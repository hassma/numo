# Requirements

| Requirement | Version | Needed for | Notes |
| --- | --- | --- | --- |
| macOS | 26 (Tahoe) or later | building and running | The UI uses Liquid Glass APIs that do not exist earlier. |
| Xcode | 26, the full app | building | The Command Line Tools alone are **not** enough: `xcodebuild` is missing from them. |
| [Homebrew](https://brew.sh) | any recent | installing XcodeGen and just | Or install both another way. |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | any recent | generating the Xcode project | `brew install xcodegen` |
| [just](https://just.systems) | any recent | running the project's commands | `brew install just` |
| Git | any recent | getting the code | Included with Xcode. |
| Calendar accounts | added in System Settings → Internet Accounts | having something to remind you about | iCloud, Google, Microsoft 365/Exchange, CalDAV. |
| Calendar permission | **Full** Calendar Access | running | macOS has no read-only calendar permission. Events never leave your Mac. |
| Apple Developer account | not required | nothing | `just run` and `just install` sign ad hoc, or with a free local certificate ([self-signing](/guide/signing)). You only need a team to distribute the app or to run it from Xcode with your own signing. |
| Node `^20.19` or `>=22.12`, and [pnpm](https://pnpm.io) | optional | the docs site only | Not needed to build or run the app. |

## Why these requirements

**macOS 26.** numo uses Liquid Glass for its card and buttons. Those APIs do not exist on macOS 15 or earlier, and a fallback for every glass surface was judged not worth it for a personal utility ([decision 2](/decisions)).

**Full Xcode.** The app is built with `xcodebuild`, which ships only with Xcode. The Command Line Tools provide `git` and some compilers but not `xcodebuild`.

**XcodeGen.** The Xcode project is generated from `Numo/project.yml` and is deliberately not committed: a hand-edited `.pbxproj` is fragile and unreviewable.

**Full Calendar Access.** Since macOS 14, reading events requires the *Full Access* permission; there is no read-only tier. numo requests nothing else: it has no network entitlement and sends nothing anywhere.

## Check what you have

```sh
sw_vers -productVersion          # 26.0 or later
xcodebuild -version              # Xcode 26.x
brew --version
```

After [cloning the repository](/guide/installation#_3-get-the-code), `just doctor` prints the state of everything numo needs in one go.
