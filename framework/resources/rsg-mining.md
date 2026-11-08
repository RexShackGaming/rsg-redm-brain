# rsg-mining

Version 3.0.2. rsg-mining - mine lease & NPC worker management

Mine lease and NPC worker management for **RSG-Core (RedM)**. Lease a mine from its foreman, hire a crew of miners, keep them fed, watered, equipped and paid, and collect the ore they dig while you're away. - **Mine leases.** Each mine is leased by one player for a set time, and the holder can extend the lease from the foreman.

Source: https://github.com/Rexshack-RedM/rsg-mining

**Dependencies:** `rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

Has NUI (`ui_page`).

## Commands (RegisterCommand)

**server:** `/rsgmining_webhooktest`

## Public (table) functions

**server/sv_webhooks.lua:** `Webhook.Log(event, opts)`

## Database tables

`rsg_mining`, `rsg_mining_workers`
