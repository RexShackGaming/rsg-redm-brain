# rsg-animations

Version 3.0.1. rsg-animations

**Emote & animation menu for RedM (RSG Core).** > A Vue.js animation menu that lets players play gestures, dances, emotes and scenarios, and save their favourites per character. - **rsg-core** – framework, player data, callbacks, notifications & locales

Source: https://github.com/Rexshack-RedM/rsg-animations

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-animations']:Name)

**client:** `PlayAnimation(animationName, bodyOption)`, `StopAnimation()`

## Net events registered

**server:** `rsg-animations:server:Favorite`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-animations:client:syncFavorite`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-animations:server:getFavorites`

## Database tables

`favorites_animations`
