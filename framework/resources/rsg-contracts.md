# rsg-contracts

Version 3.0.0. rsg-contracts - player written contracts with held payment

Written contracts between players, with the payment held by the server. Needs `rsg-core`, `rsg-inventory`, `rsg-target` and `oxmysql`. `rsg-reputation` is optional. See [DOCS.md](DOCS.md) for technical details.

Source: https://github.com/Rexshack-RedM/rsg-contracts

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-contracts:client:paper`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-contracts:server:action`, `rsg-contracts:server:getItems`, `rsg-contracts:server:getPaper`, `rsg-contracts:server:getState`

## Public (table) functions

**server/server.lua:** `Actions.create(src, Player, data)`, `Actions.sign(src, Player, data, c)`, `Actions.decline(_, Player, _, c)`, `Actions.deliver(src, Player, _, c)`, `Actions.finish(_, Player, _, c)`, `Actions.approve(_, Player, _, c)`, `Actions.dispute(_, Player, _, c)`, `Actions.giveup(_, Player, _, c)`, `Actions.cancel(_, Player, _, c)`, `Actions.rule(_, Player, data, c)`, `Actions.collect(src, Player)`

## Database tables

`rsg_contract_claims`, `rsg_contracts`
