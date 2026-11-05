---
layout: page
title: Team
# Meta property
head:
  - - meta
    - property: og:type
      content: website
  - - meta
    - property: og:title
      content: Feather Team
  - - meta
    - property: og:description
      content: Unlock Boundless Possibilities with Feather Framework
  - - meta
    - property: og:image
      content: https://avatars.githubusercontent.com/u/140788019?s=200&v=4
  - - meta
    - name: title
      content: Feather Team
  - - meta
    - name: twitter:card
      content: https://avatars.githubusercontent.com/u/140788019?s=200&v=4
  - - link
    - rel: icon
      type: image/png
      href: logo.png
---

<script setup>
import {
  VPTeamPage,
  VPTeamPageTitle,
  VPTeamMembers,
  VPTeamPageSection
} from 'vitepress/theme'

const developers = [
    {
        avatar: 'https://avatars.githubusercontent.com/u/10902965?v=4',
        name: 'Bytesizd',
        title: 'Lead Developer/Founder',
        links: [
          { icon: 'github', link: 'https://github.com/andrewr3k' },
          { icon: 'youtube', link: 'https://www.youtube.com/channel/UCmuccaVOwak0R3m0q9dyodA' },
          { icon: 'twitch', link: 'https://www.twitch.tv/bytesizd' }
        ]
    },
    {
        avatar: 'https://avatars.githubusercontent.com/u/47730893?s=96&v=4',
        name: 'SavSin',
        title: 'Developer',
        links: [
          { icon: 'github', link: 'https://github.com/DavFount' }
        ]
    },
    {
        avatar: 'https://avatars.githubusercontent.com/u/37031311?s=96&v=4',
        name: 'Apollyon',
        title: 'Developer',
        links: [
          { icon: 'github', link: 'https://github.com/JusCampin' }
        ]
    },
    {
        avatar: 'https://avatars.githubusercontent.com/u/2729972?v=4&size=64',
        name: 'iseeyoucopy',
        title: 'Developer',
        links: [
          { icon: 'github', link: 'https://github.com/iseeyoucopy' }
        ]
    },
]

const staff = [
    {
        avatar: 'https://cdn.discordapp.com/avatars/1011606164489904209/c28b4baa853642c3fe2b82c3414b8298.webp?size=128',
        name: 'Charlie',
        title: 'Staff',
        links: [
        ]
    }
]

const retired = [
    {
        avatar: 'https://avatars.githubusercontent.com/u/119366047?v=4',
        name: 'Jake2k4',
        title: 'Developer/Project Manager',
        links: [
          { icon: 'github', link: 'https://github.com/jakeyboi1' },
          { icon: 'youtube', link: 'https://youtube.com/@Jake2k4-id9ym' }
        ]
    },
    {
        avatar: 'https://avatars.githubusercontent.com/u/82676805?v=4',
        name: 'Jannings',
        title: 'Developer',
        links: [
          { icon: 'github', link: 'https://github.com/BurntJannings' }
        ]
    },
    {
        avatar: 'https://avatars.githubusercontent.com/u/9192488?v=4',
        name: 'Elzetia',
        title: 'Staff',
        links: [
          { icon: 'github', link: 'https://github.com/elzetia' }
        ]
    },
    {
        avatar: 'https://avatars.githubusercontent.com/u/92045818?v=4',
        name: 'Fistsoffury',
        title: 'Staff',
        links: [
          { icon: 'github', link: 'https://github.com/Fistsofury' }
        ]
    },
]
</script>

<VPTeamPage>
  <VPTeamPageTitle>
    <template #title>Our Team</template>
    <template #lead></template>
  </VPTeamPageTitle>
  <VPTeamPageSection>
    <template #title>Developers</template>
    <template #lead></template>
    <template #members>
     <VPTeamMembers size="medium" :members="developers" />
    </template>
  </VPTeamPageSection>
  <VPTeamPageSection>
    <template #title>Staff</template>
    <template #lead></template>
    <template #members>
      <VPTeamMembers size="medium" :members="staff" />
    </template>
  </VPTeamPageSection>
  <VPTeamPageSection>
    <template #title>Retired</template>
    <template #lead></template>
    <template #members>
      <VPTeamMembers size="medium" :members="retired" />
    </template>
  </VPTeamPageSection>
</VPTeamPage>
