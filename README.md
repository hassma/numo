# numo

Your little helper to finally get into the meeting.

## Planning docs

The product and technical plan for **Meeting Nudge** (working name), a native macOS 26 (Swift 6, SwiftUI, Liquid Glass) menu-bar app that makes it hard to accidentally miss a meeting, lives in `docs/` as a [VitePress](https://vitepress.dev) site. No application code exists yet; implementation starts after the plan is approved (see `docs/decisions.md`).

```sh
npm install
npm run docs:dev      # http://localhost:5173
npm run docs:build    # static site in docs/.vitepress/dist
npm run docs:preview
```

When publishing to GitHub Pages, set `base` in `docs/.vitepress/config.mts` to `'/numo/'`.
