# rsg-bountyhunter

Version 3.5.0. rsg-bountyhunter - hunt wanted outlaws and bring them in dead or alive

**Version 3.5.0** · Dependencies: rsg-core, rsg-inventory, rsg-target, oxmysql · Full reference: [DOCS.md](DOCS.md) Bounty hunting for RSG Framework (RedM). Take a wanted poster from the clerk at any sheriff's office, track the outlaw to their hideout, and bring them in dead or alive. - Clerk NPC at each sheriff's office (rsg-target): **View Bounties** and **Turn In Bounty**

Source: https://github.com/Rexshack-RedM/rsg-bountyhunter

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-bountyhunter']:Name)

**server:** `CancelBounty(ref)`, `IsReputationWanted(citizenid)`, `PostBounty(opts)`

## Net events registered

**server:** `rsg-bountyhunter:server:registerGang`, `rsg-bountyhunter:server:registerTarget`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-bountyhunter:client:endContract`, `rsg-bountyhunter:client:startContract`, `rsg-bountyhunter:client:startPlayerContract`, `rsg-bountyhunter:client:trackArea`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`, `rsg-reputation:server:honorChanged`, `rsg-skills:server:ready`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-bountyhunter:server:abandon`, `rsg-bountyhunter:server:accept`, `rsg-bountyhunter:server:getBoard`, `rsg-bountyhunter:server:turnIn`

## Public (table) functions

**server/webhooks.lua:** `BountyLog.Event(event, src, fields, description)`, `BountyLog.ContractFields(poster, extra)`

## Database tables

`rsg_bountyhunter`
