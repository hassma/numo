# numo

Your little helper to finally get into the meeting.

## What is here

- `docs/`: the product and technical plan for **numo**, a native macOS 26 (Swift 6, SwiftUI, Liquid Glass) menu-bar app that makes it hard to accidentally miss a meeting. It is a [VitePress](https://vitepress.dev) site.
- `Numo/`: the Phase 1 MVP. A Foundation-only logic package (`Numo/Packages/NumoCore`) and the macOS app. **Written but not yet compiled**; see `docs/implementation.md` for how to build it and what to verify first.

## Docs

```sh
pnpm install
pnpm docs:dev      # http://localhost:5173
pnpm docs:build    # static site in docs/.vitepress/dist
pnpm docs:preview
```

When publishing to GitHub Pages, set `base` in `docs/.vitepress/config.mts` to `'/numo/'`.

## App

Needs macOS 26 and Xcode 26.

```sh
brew install xcodegen
cd Numo && xcodegen generate && open Numo.xcodeproj   # set your signing team, then Run
swift test --package-path Numo/Packages/NumoCore      # logic tests
```
