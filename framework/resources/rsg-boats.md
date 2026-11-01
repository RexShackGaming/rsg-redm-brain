# rsg-boats

Version 3.1.0. rsg-boats - multi-yard boat shop with dock storing, per-boat storage, transfers and an NUI admin panel

Boat yards for the RSG Framework. Players buy boats at a yard, launch them, store them at any yard's dock and keep items in each boat's own storage. Admins create and manage every yard in game from an NUI panel. No config editing is needed after install. - **Multiple boat yards**: each has its own NPC (rsg-target), map blip, launch point, dock zone and list of allowed boats. - **Shop** (target the

Source: https://github.com/Rexshack-RedM/rsg-boats

**Dependencies:** `rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-boats:server:inBoatInventory`, `rsg-boats:server:launchFailed`, `rsg-boats:server:launched`

**client:** `rsg-boats:client:openAdmin`, `rsg-boats:client:yards`, `rsg-inventory:client:open`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Commands (RegisterCommand)

**server:** `/boatwebhooktest`

## Database tables

`rsg_boats_models`, `rsg_boats_owned`, `rsg_boats_settings`, `rsg_boats_yards`
