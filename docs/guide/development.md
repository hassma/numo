# Development

Run `just` from the repository root, or any folder inside it, to list every command.

## Commands

| Command | What it does |
| --- | --- |
| `just doctor` | Check that the tools are installed. |
| `just test` | Run the `NumoCore` logic tests. |
| `just build` | Compile the app without signing. A compile check; do not run this output. |
| `just run [adhoc\|self\|none]` / `just stop` | Build, launch and quit a Debug app. |
| `just open` | Generate the Xcode project and open it. |
| `just install [adhoc\|self\|none]` / `just uninstall` | Install to or remove from `/Applications`. |
| `just self-sign-setup` / `self-sign` / `self-sign-verify` / `self-sign-reset` | Manage the local signing certificate. See [Signing the app](/guide/signing). |
| `just docs-install` / `docs-dev` / `docs-build` | Install, serve (`http://localhost:5173`) and build these docs. |
| `just clean` | Remove generated files. |

## Tests

The logic that decides when to remind lives in `NumoCore`, a Foundation-only Swift package, and is covered by Swift Testing tests with a manual clock.

```sh
just test
```

CI runs the same tests on macOS and on Linux (`swift:6.0`), and builds these docs. New scheduling behaviour needs a test using the manual clock in `Tests/NumoCoreTests/TestSupport.swift`.

## Repository layout

```
.
├── justfile                    developer commands (run `just` to list them)
├── Numo/
│   ├── project.yml             XcodeGen spec for the macOS app
│   ├── App/                    @main, composition root, Info.plist, entitlements
│   ├── Services/               EventKit provider, system events, login item, settings store
│   ├── Coordination/           menu-bar state, reminder coordinator
│   ├── Windowing/              the floating NSPanel and the dimming windows
│   ├── Features/               reminder card, menu bar, settings
│   ├── DesignSystem/           shared views and helpers
│   └── Packages/NumoCore/      pure logic and its tests (swift test)
├── docs/                       these docs (VitePress)
└── .github/workflows/ci.yml    logic tests on macOS and Linux, docs build
```

More detail: [Project structure](/project-structure) and [System architecture](/architecture).

## Working on the docs

The docs are a [VitePress 2](https://vitepress.dev) site in `docs/`, managed with pnpm (not npm). VitePress 2 is still a pre-release, so the version is pinned in `package.json`.

```sh
just docs-install
just docs-dev       # http://localhost:5173
just docs-build     # static site in docs/.vitepress/dist
```

It needs Node `^20.19` or `>=22.12`. The build fails on dead links, so a renamed page shows up straight away.

To publish on GitHub Pages, build with the project path as base:

```sh
DOCS_BASE=/numo/ pnpm docs:build
```

## Conventions

- Swift 6 with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`). Keep `NumoCore` free of AppKit, SwiftUI and EventKit.
- No new entitlement or permission without a documented reason. The MVP deliberately has no network entitlement.
- Use `just` for anything a contributor would run; keep the README and these docs in step with the `justfile`.
