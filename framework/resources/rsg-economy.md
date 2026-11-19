# rsg-economy

Version 3.1.0. Regional treasuries, taxes, supply-and-demand prices and town projects for RSG Framework

A regional economy for the RSG Framework: every town has a **treasury**, its own **tax rates** set by its officials, **supply-and-demand prices** that react to what players buy and sell, and **town projects** the treasury can pay for. Taxes flow into the treasuries, and projects and officials' decisions spend them, so money keeps moving instead of piling up. Version 3.1.0 · Requires `rsg-core` and

Source: https://github.com/Rexshack-RedM/rsg-economy

**Dependencies:** `oxmysql`, `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-economy']:Name)

**server:** `DepositTreasury(region, amount, reason, actor)`, `GetCategories()`, `GetMarketMultiplier(item, region)`, `GetPressure(item, region)`, `GetRegionAt(coords, maxDistance)`, `GetRegions()`, `GetTaxRate(region, category)`, `GetTreasury(region)`, `HasProject(region, id)`, `IsOfficial(src, region)`, `Quote(src, o)`, `Record(src, q)`, `RecordTrade(item, region, qty, mode)`, `ResetMarket(region, item)`, `SetTaxRate(region, category, rate, actor)`, `WithdrawTreasury(region, amount, reason, actor)`

## Net events registered

**client:** `rsg-economy:client:open`

## Event handlers

**client:** `RSGCore:Client:OnPlayerUnload`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-economy:server:getLedger`, `rsg-economy:server:getPanel`

## Public (table) functions

**server/database.lua:** `RSGEcon.WaitReady()`, `RSGEcon.MarkTreasury(region)`, `RSGEcon.MarkTax(region, cat)`, `RSGEcon.MarkMarket(region, item)`, `RSGEcon.MarkProject(region, id)`, `RSGEcon.Ledger(region, amount, balanceAfter, kind, reason, actor, awaitIt)`, `RSGEcon.Flush(awaitIt)`, `RSGEcon.SaveTreasuryNow(region)`, `RSGEcon.SaveProjectNow(region, id)`, `RSGEcon.Prune()`

**server/economy.lua:** `RSGEcon.GetTaxRate(region, category)`, `RSGEcon.SetTaxRate(region, category, rate, actor)`, `RSGEcon.GetTreasury(region)`, `RSGEcon.DepositTreasury(region, amount, reason, actor, kind, awaitLedger)`, `RSGEcon.WithdrawTreasury(region, amount, reason, actor, kind, awaitLedger)`, `RSGEcon.SetTreasury(region, value, actor)`, `RSGEcon.GetPressure(item, region)`, `RSGEcon.GetMarketMultiplier(item, region)`, `RSGEcon.RecordTrade(item, region, qty, mode)`, `RSGEcon.ResetMarket(region, item)`, `RSGEcon.Quote(src, o)`, `RSGEcon.Record(src, q)`, `RSGEcon.HasProject(region, id)`, `RSGEcon.GetProjectDef(id)`, `RSGEcon.IsOfficial(src, region)`

## Database tables

`rsg_economy_ledger`, `rsg_economy_market`, `rsg_economy_project`, `rsg_economy_tax`, `rsg_economy_treasury`
