# rsg-economy

Version 3.2.0. Regional treasuries, taxes, supply-and-demand prices and town projects for RSG Framework

A regional economy for the RSG Framework: every town has a **treasury**, its own **tax rates** set by its officials, **supply-and-demand prices** that react to what players buy and sell, and **town projects** the treasury can pay for. Taxes flow into the treasuries, and projects and officials' decisions spend them, so money keeps moving instead of piling up. Version 3.2.0 · Requires `rsg-core` and

Source: https://github.com/Rexshack-RedM/rsg-economy

**Dependencies:** `oxmysql`, `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-economy']:Name)

**server:** `ClearMayor(region)`, `DepositTreasury(region, amount, reason, actor)`, `GetCategories()`, `GetMarketMultiplier(item, region)`, `GetMayor(region)`, `GetPressure(item, region)`, `GetRegionAt(coords, maxDistance)`, `GetRegions()`, `GetTaxRate(region, category)`, `GetTreasury(region)`, `HasProject(region, id)`, `IsOfficial(src, region)`, `Quote(src, o)`, `Record(src, q)`, `RecordTrade(item, region, qty, mode)`, `ResetMarket(region, item)`, `SetMayor(region, citizenid)`, `SetTaxRate(region, category, rate, actor)`, `StartElection(region)`, `WithdrawTreasury(region, amount, reason, actor)`

**client:** `HasProject(region, id)`

## Net events registered

**client:** `rsg-economy:client:open`

## Event handlers

**client:** `RSGCore:Client:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-economy:server:getAdmin`, `rsg-economy:server:getElection`, `rsg-economy:server:getLedger`, `rsg-economy:server:getPanel`

## Public (table) functions

**server/automation.lua:** `RSGEcon.SyncProjects()`

**server/database.lua:** `RSGEcon.finite(v)`, `RSGEcon.round2(v)`, `RSGEcon.WaitReady()`, `RSGEcon.MarkTreasury(region)`, `RSGEcon.MarkTax(region, cat)`, `RSGEcon.MarkMarket(region, item)`, `RSGEcon.MarkProject(region, id)`, `RSGEcon.Ledger(region, amount, balanceAfter, kind, reason, actor, awaitIt)`, `RSGEcon.Flush()`, `RSGEcon.SaveTreasuryNow(region)`, `RSGEcon.SaveProjectNow(region, id)`, `RSGEcon.SetMeta(key, value, awaitIt)`, `RSGEcon.Prune()`

**server/economy.lua:** `RSGEcon.GetTaxRate(region, category)`, `RSGEcon.SetTaxRate(region, category, rate, actor)`, `RSGEcon.GetTreasury(region)`, `RSGEcon.DepositTreasury(region, amount, reason, actor, kind, awaitLedger)`, `RSGEcon.WithdrawTreasury(region, amount, reason, actor, kind, awaitLedger)`, `RSGEcon.SetTreasury(region, value, actor)`, `RSGEcon.GetPressure(item, region)`, `RSGEcon.GetMarketMultiplier(item, region)`, `RSGEcon.RecordTrade(item, region, qty, mode)`, `RSGEcon.ResetMarket(region, item)`, `RSGEcon.Quote(src, o)`, `RSGEcon.Record(src, q)`, `RSGEcon.HasProject(region, id)`, `RSGEcon.ActiveEffects(region, etype)`, `RSGEcon.GetProjectDef(id)`, `RSGEcon.GetMayor(region)`, `RSGEcon.IsOfficial(src, region)`, `RSGEcon.GetRegionAt(coords, maxDistance)`

**server/elections.lua:** `RSGEcon.StartElection(region)`, `RSGEcon.AdvanceElection(region)`, `RSGEcon.CancelElection(region)`, `RSGEcon.SetMayor(region, citizenid)`, `RSGEcon.ClearMayor(region)`, `RSGEcon.ElectionRegister(src, region, platform)`, `RSGEcon.ElectionWithdraw(src, region)`, `RSGEcon.ElectionVote(src, region, candidateId)`, `RSGEcon.ElectionView(src, region)`

**server/regions.lua:** `RSGEcon.ApplyRegionRow(r)`, `RSGEcon.AdminList()`, `RSGEcon.AdminSaveRegion(src, data)`, `RSGEcon.AdminDeleteRegion(id)`

## Database tables

`rsg_economy_candidate`, `rsg_economy_election`, `rsg_economy_ledger`, `rsg_economy_market`, `rsg_economy_mayor`, `rsg_economy_meta`, `rsg_economy_project`, `rsg_economy_region`, `rsg_economy_tax`, `rsg_economy_treasury`, `rsg_economy_vote`
