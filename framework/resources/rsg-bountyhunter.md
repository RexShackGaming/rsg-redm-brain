# rsg-bountyhunter

Version 3.0.0. rsg-bountyhunter - hunt wanted outlaws and bring them in dead or alive

Bounty hunting for RSG Framework (RedM). Take a wanted poster from the clerk at any sheriff's office, track the outlaw to their hideout, and bring them in dead or alive. - Clerk NPC at each sheriff's office (ox_target): **View Bounties** and **Turn In Bounty** - NUI wanted board in the RSG leather & gold style: tiered posters (Petty / Wanted / Notorious) with random names, crimes and rewards

Source: https://github.com/Rexshack-RedM/rsg-bountyhunter

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-bountyhunter:server:registerTarget`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-bountyhunter:client:endContract`, `rsg-bountyhunter:client:startContract`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`

## Callbacks (lib.callback)

**server:** `rsg-bountyhunter:server:abandon`, `rsg-bountyhunter:server:accept`, `rsg-bountyhunter:server:getBoard`, `rsg-bountyhunter:server:turnIn`

## Public (table) functions

**server/webhooks.lua:** `BountyLog.Event(event, src, fields, description)`, `BountyLog.ContractFields(poster, extra)`

## Database tables

`rsg_bountyhunter`
