# rsg-playertrade

Version 3.0.0. rsg-playertrade - secure two-way player trading

**Version:** 3.0.0 · **Requires:** `rsg-core`, `rsg-inventory` 3.6.0 or newer, `rsg-target` · **ox_lib:** not required Secure two-way trading of items and cash between players. Technical details: [DOCS.md](DOCS.md). - Side-by-side trade window: your items, your offer and their offer

Source: https://github.com/Rexshack-RedM/rsg-playertrade

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-playertrade']:Name)

**server:** `IsTrading(src)`

## Net events registered

**server:** `rsg-playertrade:server:cancel`, `rsg-playertrade:server:confirm`, `rsg-playertrade:server:ready`, `rsg-playertrade:server:request`, `rsg-playertrade:server:setCash`, `rsg-playertrade:server:setItem`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-playertrade:client:close`, `rsg-playertrade:client:open`, `rsg-playertrade:client:update`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`
