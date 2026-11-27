# rsg-animations

Version 3.2.1. rsg-animations

**Emote & animation menu for RedM (RSG Core).** · v3.2.1 · [Full docs](DOCS.md) > A Vue.js animation menu that lets players play gestures, dances, emotes and scenarios, and save their favourites per character. - **rsg-core** – framework, player data, callbacks, notifications & locales

Source: https://github.com/Rexshack-RedM/rsg-animations

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-animations']:Name)

**client:** `PlayAnimation(animationName, bodyOption)`, `StopAnimation()`

## Net events registered

**server:** `rsg-animations:server:Favorite`, `rsg-animations:server:invite`, `rsg-animations:server:respond`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-animations:client:invited`, `rsg-animations:client:syncFavorite`, `rsg-animations:client:together`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

**client:** `rsg-animations:client:radialOpen`, `rsg-animations:client:radialSlot`, `rsg-animations:client:radialStop`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-animations:server:getFavorites`

## Public (table) functions

**client/extras.lua:** `RSGAnims.OnPlay(animation)`, `RSGAnims.OnStop()`, `RSGAnims.MenuData()`

**client/together.lua:** `RSGAnims.HasInvite()`

## Database tables

`favorites_animations`
