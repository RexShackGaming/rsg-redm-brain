# rsg-legendary

Version 3.0.0. rsg-legendary - legendary animal hunting

Legendary animal hunting for the RSG Framework (rsg-core 3.0.3). 1. **Buy a map** from the Legendary Trapper (ox_target). Each legendary shows its price, or how long until it returns if you are on cooldown. 2. **Use the map** from your inventory. The hunting area and the first tracks appear on your map.

Source: https://github.com/Rexshack-RedM/rsg-legendary

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-legendary:server:animalSpawned`

**client:** `rsg-legendary:client:endHunt`, `rsg-legendary:client:preview`, `rsg-legendary:client:startHunt`

## Event handlers

**client:** `RSGCore:Client:OnPlayerUnload`

## Callbacks (lib.callback)

**server:** `rsg-legendary:server:buyMap`, `rsg-legendary:server:getMenu`, `rsg-legendary:server:inspectClue`, `rsg-legendary:server:sell`, `rsg-legendary:server:skin`

## Commands (RSGCore.Commands.Add)

**server:** `/abandonhunt`, `/legendpreview`

## Database tables

`rsg_legendary_cooldowns`
