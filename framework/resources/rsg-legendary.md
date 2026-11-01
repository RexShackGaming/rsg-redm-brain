# rsg-legendary

Version 3.1.0. rsg-legendary - legendary animal hunting

Legendary animal hunting for the RSG Framework (rsg-core 3.0.3). 1. **Buy a map** from the Legendary Trapper (rsg-target). Each legendary shows its price, or how long until it returns if you are on cooldown. 2. **Use the map** from your inventory. The hunting area and the first tracks appear on your map.

Source: https://github.com/Rexshack-RedM/rsg-legendary

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-legendary']:Name)

**server:** `GetTrophies(citizenid)`

## Net events registered

**server:** `rsg-legendary:server:animalSpawned`

**client:** `rsg-legendary:client:endHunt`, `rsg-legendary:client:preview`, `rsg-legendary:client:startHunt`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

**client:** `RSGCore:Client:OnPlayerUnload`

## Commands (RSGCore.Commands.Add)

**server:** `/abandonhunt`, `/accepthunt`, `/invitehunt`, `/legendpreview`

## Database tables

`rsg_legendary_cooldowns`, `rsg_legendary_hunts`, `rsg_legendary_trophies`
