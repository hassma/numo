import { defineConfig } from 'vitepress'

// Set base to '/<repo>/' when publishing to GitHub Pages (e.g. '/numo/').
export default defineConfig({
  title: 'numo',
  description:
    'Product & technical plan for a native macOS meeting reminder built with SwiftUI and Liquid Glass.',
  lang: 'en-US',
  cleanUrls: true,
  appearance: true,

  themeConfig: {
    nav: [
      { text: 'Overview', link: '/overview' },
      { text: 'Plan', link: '/product-spec' },
      { text: 'Roadmap', link: '/roadmap' },
      { text: 'MVP status', link: '/implementation' },
      { text: 'Decisions', link: '/decisions' }
    ],

    sidebar: [
      {
        text: 'Start here',
        items: [
          { text: 'Overview & MVP', link: '/overview' },
          { text: 'MVP implementation status', link: '/implementation' },
          { text: 'Decisions', link: '/decisions' }
        ]
      },
      {
        text: 'The plan',
        items: [
          { text: 'A · Product specification', link: '/product-spec' },
          { text: 'B · Technical feasibility', link: '/feasibility' },
          { text: 'C · System architecture', link: '/architecture' },
          { text: 'D · Project structure', link: '/project-structure' },
          { text: 'E · UI / UX specification', link: '/ui-spec' },
          { text: 'F · Implementation roadmap', link: '/roadmap' },
          { text: 'G · Risks & edge cases', link: '/risks' },
          { text: 'H · Testing strategy', link: '/testing' }
        ]
      }
    ],

    outline: { level: [2, 3] },
    search: { provider: 'local' },
    footer: {
      message: 'Plan and MVP status. The MVP code is written but not yet compiled.',
      copyright: 'numo'
    }
  }
})
