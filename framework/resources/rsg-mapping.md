# rsg-mapping

Version 3.1.0. Mapping tool for RSG Framework

**Version 3.1.0** · Requires rsg-core and oxmysql · Full developer reference: [DOCS.md](DOCS.md) An in-game IMAP finder and mapping tool for the **RSG Framework** (RedM). Admins can browse the IMAPs (map data files) around them, turn them on or off, give them friendly names and save their state. Saved changes sync to every player. The resource also ships with a curated set of default IMAP removals

Source: https://github.com/Rexshack-RedM/rsg-mapping

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-mapping']:Name)

**client:** `GetNearbyImaps(radius)`

## Net events registered

**server:** `rsg-mapping:server:setLabel`, `rsg-mapping:server:setState`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-mapping:client:syncAll`, `rsg-mapping:client:update`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-mapping:server:canUse`, `rsg-mapping:server:getSaved`

## Database tables

`rsg_imaps`
