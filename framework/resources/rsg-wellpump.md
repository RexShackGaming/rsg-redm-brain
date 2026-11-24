# rsg-wellpump

Version 3.1.0. Well pumps for RSG Framework: place, fill buckets, pack up, and shared bucket API

Well pumps for the **RSG Framework** (rsg-core 3). Players place a pump, fill empty buckets with water and pack the pump up again. The same resource owns the **water bucket**: a filled `fullbucket` carries a number of uses, and other scripts (farming, ranch, gangs) call rsg-wellpump instead of carrying their own bucket code. Full developer reference: [DOCS.md](DOCS.md) **Version:** 1.1.0

Source: https://github.com/Rexshack-RedM/rsg-wellpump

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`

## Exports (call as exports['rsg-wellpump']:Name)

**server:** `CommitBucketUse(src, ticket)`, `DrawWater(id, amount)`, `Drink(src)`, `FillBucket(src)`, `GetBucketUses(info)`, `GetFillTime()`, `GetMaxUses()`, `GetNearestPump(coords, maxDistance)`, `GetPump(id)`, `GetPumpWater(id)`, `GetPumps()`, `IsNearPump(src, distance)`, `RefundBucketUse(src, ticket)`, `TakeBucketUse(src)`, `UseBucket(src)`

**client:** `PlayDrink()`, `PlayFill()`

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-wellpump:client:place`, `rsg-wellpump:client:sync`, `rsg-wellpump:client:thirst`

## Event handlers

**server:** `rsg-wellpump:internal:pumpRemoved`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-wellpump:server:drink`, `rsg-wellpump:server:fill`, `rsg-wellpump:server:getPumps`, `rsg-wellpump:server:pack`, `rsg-wellpump:server:placePump`, `rsg-wellpump:server:precheck`

## Database tables

`rsg_wellpump_migrations`, `rsg_wellpumps`
