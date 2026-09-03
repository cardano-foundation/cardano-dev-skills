import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
  site: 'https://cardano-foundation.github.io',
  base: '/cardano-dev-skills',
  integrations: [
    starlight({
      title: 'Cardano Dev Skills',
      description: 'Cardano dev knowledge, native in your AI coding agent.',
      social: {
        github: 'https://github.com/cardano-foundation/cardano-dev-skills',
      },
      customCss: ['./src/styles/custom.css'],
      // Both replacements exist for structure CSS cannot add: a stat row in the
      // hero, and a wordmark beside the lockup in the header. SiteTitle imports
      // the logo itself, which is why there is no `logo` key above.
      components: {
        Hero: './src/components/Hero.astro',
        SiteTitle: './src/components/SiteTitle.astro',
      },
      sidebar: [
        { label: 'Getting started', link: '/getting-started/' },
        { label: 'How it works', link: '/how-it-works/' },
        { label: 'Skills', link: '/skills/' },
        { label: 'Sources', link: '/sources/' },
        {
          label: 'Contributing',
          items: [
            { label: 'Overview', link: '/contributing/' },
            { label: 'Scope', link: '/contributing/scope/' },
            { label: 'Add a source', link: '/contributing/add-a-source/' },
            { label: 'Add a skill', link: '/contributing/add-a-skill/' },
            { label: 'Governance', link: '/contributing/governance/' },
          ],
        },
        {
          label: 'About',
          items: [
            { label: 'Why this exists', link: '/about/why/' },
            { label: 'Roadmap', link: '/about/roadmap/' },
          ],
        },
      ],
    }),
  ],
});
