---
layout: home

hero:
  name: numo
  text: A reminder you can't accidentally miss.
  tagline: A native macOS 26 menu-bar app with a Liquid Glass overlay that interrupts deep focus, and always lets you join, snooze or dismiss.
  actions:
    - theme: brand
      text: Read the overview
      link: /overview
    - theme: alt
      text: Decisions to approve
      link: /decisions
    - theme: alt
      text: Roadmap
      link: /roadmap

features:
  - icon: 🪟
    title: Disruptive by design, never a trap
    details: A floating, non-activating NSPanel that can sit above full-screen Spaces. Three attention modes, and always an explicit way out.
  - icon: 📅
    title: EventKit first
    details: Reads the Google, Microsoft 365 and iCloud accounts you already added to macOS. Direct OAuth is a later, optional phase.
  - icon: 🔗
    title: Finds the join link
    details: Extracts Google Meet and Microsoft Teams links from the event URL, location and notes, and opens the right app.
  - icon: 🔋
    title: Quiet when idle
    details: One sleeping task armed for the next reminder. Re-armed on wake, clock, time-zone and calendar changes. No polling loops.
---

## What is in this site

| Section | Contents |
| --- | --- |
| [Overview & MVP](/overview) | Requirements analysis, key findings, the simplest reliable MVP |
| [Decisions](/decisions) | Open choices that need your approval before any code is generated |
| [A · Product spec](/product-spec) | Features, attention modes, flows |
| [B · Feasibility](/feasibility) | What macOS actually allows, and what still needs a hardware spike |
| [C · Architecture](/architecture) | Components, data flow, concurrency model, reminder state machine |
| [D · Project structure](/project-structure) | Xcode project and local Swift package layout |
| [E · UI / UX spec](/ui-spec) | Overlay, menu-bar popover, onboarding, settings |
| [F · Roadmap](/roadmap) | Phases, milestones, acceptance criteria |
| [G · Risks & edge cases](/risks) | Failure modes and mitigations |
| [H · Testing](/testing) | Unit, integration and manual QA matrices |
| [MVP status](/implementation) | What is built, how to build it, what to verify first |

::: warning Status
The plan is approved to build and the Phase 1 MVP is written (see [MVP status](/implementation)). It was written in a Linux sandbox and **builds on macOS 26 / Xcode 26**, but its runtime behaviour and tests are still being verified on hardware. API names come from Apple's documented frameworks and public sources; items that need confirmation on real hardware are marked 🔬 and scheduled as [Phase 0 spikes](/roadmap#phase-0-feasibility-spikes).
:::
