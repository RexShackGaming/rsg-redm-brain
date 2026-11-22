# rsg-factory

Version 3.1.0. rsg-factory

**Version 3.1.0** · Requires: `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` · Optional: `rsg-telegram`, `rsg-society` Admin-built factories for the RSG Framework. An admin stands where the factory NPC should be, runs `/createfactory`, and then defines production lines in an NUI: which items go in, which items come out, and how long it takes. Players buy a factory at its NPC and become its o

Source: https://github.com/Rexshack-RedM/rsg-factory

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-factory:client:openAdmin`, `rsg-factory:client:sync`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-factory:server:deleteFactory`, `rsg-factory:server:findPlayers`, `rsg-factory:server:getFactories`, `rsg-factory:server:getFactory`, `rsg-factory:server:getItems`, `rsg-factory:server:saveFactory`

## Commands (RSGCore.Commands.Add)

**server:** `/acceptfactory`

## Public (table) functions

**server/sv_society.lua:** `FactorySociety.Account(f)`, `FactorySociety.Balance(f)`, `FactorySociety.Credit(f, amount, reason)`, `FactorySociety.Debit(f, amount, reason)`, `FactorySociety.Open(f)`, `FactorySociety.ClearPeople(f)`, `FactorySociety.OwnerSet(f, cid)`, `FactorySociety.OwnerChange(f, oldCid, newCid)`, `FactorySociety.StaffAdd(f, cid)`, `FactorySociety.StaffRemove(f, cid)`, `FactorySociety.Rename(f)`, `FactorySociety.Close(f, Owner)`, `FactorySociety.Backfill(factories)`

## Database tables

`rsg_factories`, `rsg_factory_queue`
