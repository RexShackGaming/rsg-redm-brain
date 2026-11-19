# rsg-reputation

Version 3.0.0. Honor and regional standing (fame and infamy) for RSG Framework

Honor and regional standing for the RSG Framework. Every character has one **honor** score (how honorable they are overall) and a **standing** in each state and town (how that place sees them, from infamy to fame). Other scripts report what players do, and read the result to change prices, lawman reactions and access. Version 3.0.0 · Requires `rsg-core` and `oxmysql` · No ox_lib, no target and no 

Source: https://github.com/Rexshack-RedM/rsg-reputation

**Dependencies:** `oxmysql`, `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-reputation']:Name)

**server:** `AddHonor(src, amount, reason, quiet)`, `AddStanding(src, region, amount, reason, quiet, noSpill)`, `ApplyAction(src, action, region)`, `GetHonor(src)`, `GetHonorByCitizenId(cid)`, `GetHonorTier(src)`, `GetPriceModifier(src, region)`, `GetRegions()`, `GetStanding(src, region)`, `GetStandingTier(src, region)`, `HasHonor(src, min)`, `HasStanding(src, region, min)`, `IsHostile(src, region)`, `ResetReputation(src)`, `SetHonor(src, value, reason, quiet)`, `SetStanding(src, region, value, reason, quiet)`

**client:** `GetHonor()`, `GetHonorTier()`, `GetPriceModifier(region)`, `GetStanding(region)`, `GetStandingTier(region)`, `IsHostile(region)`

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-reputation:client:open`, `rsg-reputation:client:sync`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`

**client:** `RSGCore:Client:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-reputation:server:getReputation`, `rsg-reputation:server:requestSync`

## Public (table) functions

**server/database.lua:** `RSGRep.WaitReady()`, `RSGRep.ApplyDecay(c)`, `RSGRep.Load(src)`, `RSGRep.Flush(awaitIt, onlyCid)`

**server/reputation.lua:** `RSGRep.SyncClient(src)`, `RSGRep.SetHonor(src, value, reason, quiet)`, `RSGRep.SetStanding(src, region, value, reason, quiet)`, `RSGRep.AddHonor(src, amount, reason, quiet)`, `RSGRep.AddStanding(src, region, amount, reason, quiet, noSpill)`, `RSGRep.ApplyAction(src, action, region)`, `RSGRep.Reset(src)`, `RSGRep.GetHonor(src)`, `RSGRep.GetHonorTier(src)`, `RSGRep.GetStanding(src, region)`, `RSGRep.GetStandingTier(src, region)`, `RSGRep.GetPriceModifier(src, region)`, `RSGRep.IsHostile(src, region)`, `RSGRep.GetHonorByCitizenId(cid)`

## Database tables

`rsg_reputation`, `rsg_reputation_standing`
