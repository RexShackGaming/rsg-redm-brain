# rsg-mining

Version 3.0.1. rsg-mining - mine lease & NPC worker management

Mine lease and NPC worker management for **RSG-Core (RedM)**. Lease a mine from its foreman, hire a crew of miners, keep them fed, watered, equipped and paid, and collect the ore they dig while you're away. - **Mine leases.** Each mine is leased by one player for a set time, and the holder can extend the lease from the foreman.

Source: https://github.com/Rexshack-RedM/rsg-mining

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Callbacks (lib.callback)

**server:** `rsg-mining:server:addWages`, `rsg-mining:server:buyLease`, `rsg-mining:server:collect`, `rsg-mining:server:deposit`, `rsg-mining:server:fire`, `rsg-mining:server:getMineData`, `rsg-mining:server:hire`, `rsg-mining:server:renewLease`, `rsg-mining:server:withdrawWages`

## Commands (RegisterCommand)

**server:** `/rsgmining_webhooktest`

## Public (table) functions

**server/sv_webhooks.lua:** `Webhook.Log(event, opts)`

## Database tables

`rsg_mining`, `rsg_mining_workers`
