# numo

Your little helper to finally get into the meeting.

## Planning docs

The product and technical plan for **numo**, a native macOS 26 (Swift 6, SwiftUI, Liquid Glass) menu-bar app that makes it hard to accidentally miss a meeting, lives in `docs/` as a [VitePress](https://vitepress.dev) site. No application code exists yet; implementation starts after the plan is approved (see `docs/decisions.md`).

```sh
pnpm install
pnpm docs:dev      # http://localhost:5173
pnpm docs:build    # static site in docs/.vitepress/dist
pnpm docs:preview
```

When publishing to GitHub Pages, set `base` in `docs/.vitepress/config.mts` to `'/numo/'`.
