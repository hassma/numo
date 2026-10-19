import { defineConfig } from 'vitepress'

// GitHub Pages serves a project site under /<repo>/. Build it with DOCS_BASE=/numo/ pnpm docs:build.
const base = process.env.DOCS_BASE ?? '/'
const repo = 'https://github.com/hassma/numo'

export default defineConfig({
  title: 'numo',
  description:
    'A native macOS menu-bar meeting reminder that is hard to miss and always easy to dismiss. Install guide, product plan and architecture.',
  lang: 'en-US',
  base,
  cleanUrls: true,
  appearance: true,
  lastUpdated: true,

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}favicon.svg` }],
    ['meta', { name: 'theme-color', content: '#3b82f6' }]
  ],

  themeConfig: {
    logo: '/favicon.svg',

    nav: [
      { text: 'Guide', link: '/guide/', activeMatch: '^/guide/' },
      {
        text: 'Plan',
        activeMatch: '^/(overview|product-spec|feasibility|architecture|project-structure|ui-spec|roadmap|risks|testing|decisions)',
        items: [
          { text: 'Overview & MVP', link: '/overview' },
          { text: 'Product specification', link: '/product-spec' },
          { text: 'Architecture', link: '/architecture' },
          { text: 'Roadmap', link: '/roadmap' },
          { text: 'Decisions', link: '/decisions' }
        ]
      },
      { text: 'MVP status', link: '/implementation' }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Get started',
          items: [
            { text: 'Introduction', link: '/guide/' },
            { text: 'Requirements', link: '/guide/requirements' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Signing the app', link: '/guide/signing' }
          ]
        },
        {
          text: 'Use numo',
          items: [
            { text: 'Using numo', link: '/guide/using' },
            { text: 'Troubleshooting', link: '/guide/troubleshooting' }
          ]
        },
        {
          text: 'Contribute',
          items: [{ text: 'Development', link: '/guide/development' }]
        }
      ],
      '/': [
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
      ]
    },

    socialLinks: [{ icon: 'github', link: repo }],
    editLink: {
      pattern: `${repo}/edit/main/docs/:path`,
      text: 'Edit this page on GitHub'
    },
    lastUpdated: { text: 'Last updated' },
    outline: { level: [2, 3] },
    search: { provider: 'local' },
    footer: {
      message: 'The MVP builds on macOS 26; runtime verification on hardware is in progress.',
      copyright: 'numo'
    }
  }
})
