# rsg-poison

Version 3.0.0. Poison script for RSG Framework

A poison / antidote system for **RSG-Core** RedM servers. Players can be poisoned by poison ammo (throwing knives, arrows) or venomous snake bites, take ongoing health drain until cured, and are cured with a consumable `tonic_antidote` item. Poison state persists across logout, disconnect, and server restarts, and every meaningful event can be logged to Discord. - **Poison sources** — poison-tippe

Source: https://github.com/Rexshack-RedM/rsg-poison

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `/assetpacks`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-poison']:Name)

**server:** `SendPoisonLog(eventName, data)`

## Net events registered

**server:** `rsg-poison:server:setPoisoned`

**client:** `rsg-poison:client:resumePoison`, `rsg-poison:client:useAntidote`

## Event handlers

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`

## Callbacks (lib.callback)

**server:** `rsg-poison:server:getPoisonState`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
