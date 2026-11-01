# rsg-trapdoors

Version 2.0.0. rsg-trapdoors

Synced, animated trapdoors for **RSG-Core (RedM)** with an optional 4-digit passcode lock, a themed keypad UI, Discord webhook logging and full multi-language support. - **Server-synced trapdoors** – open/close state is held by the server and pushed to every client through `GlobalState`, so every player sees the same thing, including players who stream in later. - **Smooth animation** – time-based

Source: https://github.com/Rexshack-RedM/rsg-trapdoors

**Dependencies:** `rsg-core`, `oxmysql`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-trapdoors']:Name)

**server:** `Log(event, src, data)`

## Net events registered

**server:** `rsg-trapdoors:server:close`

## Callbacks (lib.callback)

**server:** `rsg-trapdoors:server:changeCode`, `rsg-trapdoors:server:open`, `rsg-trapdoors:server:setCode`

## Public (table) functions

**server/database.lua:** `TrapdoorDB.Install()`

## Database tables

`rsg_trapdoors`
