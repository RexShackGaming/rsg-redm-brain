# rsg-drugs

Version 3.3.0. rsg-drugs

Drug production for RSG Framework (cannabis lab: drying, processing, packing bags & bricks with hired crew) plus a built-in player & NPC addiction system with rehab. `rsg-core` (3.0.3+), `rsg-inventory`, `rsg-target`, `oxmysql`. Optional: `rsg-consume` (alcohol), `rsg-hud` (stress relief), `rsg-weapons` (re-equip after rehab), `rsg-farming` (weed seeds). No ox_lib needed. 1. `ensure rsg-drugs` (af

Source: https://github.com/Rexshack-RedM/rsg-drugs

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-drugs']:Name)

**server:** `AddUse(src, key, amount)`, `AddXP(src, amount, reason)`, `DiscordLog(category, title, src, fields, description)`, `GetAddiction(src)`, `GetXP(src)`, `IsInRehab(src)`, `ResetXP(src)`, `ReturnRehabItems(src)`

**client:** `NpcSoldWeedBag(ped, hooked)`

## Net events registered

**server:** `rsg-drugs:server:checkIn`, `rsg-drugs:server:closed`, `rsg-drugs:server:npcRehab`, `rsg-drugs:server:raid`, `rsg-prison:server:startSentence`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Client:SetDuty`, `RSGCore:Player:SetPlayerData`, `rsg-drugs:client:disarm`, `rsg-drugs:client:openUI`, `rsg-drugs:client:raidAlert`, `rsg-drugs:client:reequip`, `rsg-drugs:client:refresh`, `rsg-drugs:client:sellAlert`, `rsg-drugs:client:teleport`, `rsg-drugs:client:useSubstance`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`, `entityRemoved`, `rsg-consume:server:consumed`, `rsg-skills:server:ready`

**client:** `rsg-drugs:client:exportOpen`, `rsg-drugs:client:npcSoldWeedBag`, `rsg-drugs:client:open`

## Commands (RSGCore.Commands.Add)

**server:** `/addiction`, `/clearaddiction`, `/rehab`, `/setaddiction`

## Server events it triggers in other resources

**client:** `hud:server:GainStress`

## Public (table) functions

**server/integrations.lua:** `DrugsSkills.Register()`, `DrugsSkills.AddXP(src, amount, reason)`, `DrugsSkills.Reset(src)`, `DrugsSkills.Perk(src, perk)`, `DrugsEcon.Region(src)`, `DrugsEcon.Multiplier(src, item)`, `DrugsEcon.Record(src, item, qty)`, `DrugsRep.Apply(src, key)`, `DrugsRep.Hostile(src)`

**server/server.lua:** `DrugsHeat.Add(cid, amount)`

**server/xp.lua:** `DrugsXP.Info(Player)`, `DrugsXP.Add(src, amount, reason)`, `DrugsXP.CanPackBricks(Player)`, `DrugsXP.BrickLevelLabel()`, `DrugsXP.Reset(src)`

## Database tables

`rsg_drugs_labs`, `rsg_drugs_state`
