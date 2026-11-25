# rsg-drugs

Version 3.4.0. rsg-drugs

Drug production for RSG Framework (cannabis lab: drying, processing, packing bags & bricks with hired crew), corner selling to NPCs with a haggle system, plus a built-in player & NPC addiction system with rehab. `rsg-core` (3.0.3+), `rsg-inventory`, `rsg-target`, `oxmysql`. Optional: `rsg-consume` (alcohol), `rsg-hud` (stress relief), `rsg-weapons` (re-equip after rehab), `rsg-farming` (weed seeds

Source: https://github.com/Rexshack-RedM/rsg-drugs

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-drugs']:Name)

**server:** `AddUse(src, key, amount)`, `AddXP(src, amount, reason)`, `DiscordLog(category, title, src, fields, description)`, `GetAddiction(src)`, `GetXP(src)`, `IsCornerSelling(src)`, `IsInRehab(src)`, `ResetXP(src)`, `ReturnRehabItems(src)`, `StopCorner(src)`

**client:** `NpcSoldWeedBag(ped, hooked)`

## Net events registered

**server:** `rsg-drugs:server:checkIn`, `rsg-drugs:server:closed`, `rsg-drugs:server:cornerStop`, `rsg-drugs:server:cornerWalk`, `rsg-drugs:server:npcRehab`, `rsg-drugs:server:raid`, `rsg-prison:server:startSentence`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Client:SetDuty`, `RSGCore:Player:SetPlayerData`, `rsg-drugs:client:cornerDealEnd`, `rsg-drugs:client:cornerState`, `rsg-drugs:client:disarm`, `rsg-drugs:client:openUI`, `rsg-drugs:client:raidAlert`, `rsg-drugs:client:reequip`, `rsg-drugs:client:refresh`, `rsg-drugs:client:sellAlert`, `rsg-drugs:client:teleport`, `rsg-drugs:client:useSubstance`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`, `entityRemoved`, `rsg-consume:server:consumed`, `rsg-skills:server:ready`

**client:** `rsg-drugs:client:exportOpen`, `rsg-drugs:client:npcBought`, `rsg-drugs:client:npcSoldWeedBag`, `rsg-drugs:client:open`

## Commands (RSGCore.Commands.Add)

**server:** `/addiction`, `/clearaddiction`, `/rehab`, `/setaddiction`

## Public (table) functions

**server/addiction.lua:** `DrugsNpc.FromNet(src, netId, maxDist)`, `DrugsNpc.Status(netId)`, `DrugsNpc.Refused(netId)`, `DrugsNpc.IsAmbient(ent)`, `DrugsNpc.Sold(Player, ent, netId, canHook)`

**server/board.lua:** `DrugsBoard.Record(Player, units, earned, potency)`, `DrugsBoard.Top(cid, n)`

**server/integrations.lua:** `DrugsSkills.Register()`, `DrugsSkills.AddXP(src, amount, reason)`, `DrugsSkills.Reset(src)`, `DrugsSkills.Perk(src, perk)`, `DrugsEcon.Region(src)`, `DrugsEcon.Multiplier(src, item)`, `DrugsEcon.Record(src, item, qty)`, `DrugsRep.Apply(src, key)`, `DrugsRep.Hostile(src)`

**server/server.lua:** `DrugsHeat.Add(cid, amount)`

**server/xp.lua:** `DrugsXP.Info(Player)`, `DrugsXP.Add(src, amount, reason)`, `DrugsXP.CanPackBricks(Player)`, `DrugsXP.BrickLevelLabel()`, `DrugsXP.Reset(src)`

## Database tables

`rsg_drugs_labs`, `rsg_drugs_state`
