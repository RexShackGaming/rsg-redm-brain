# rsg-bathing

Version 2.0.0. rsg-bathing

Interactive bathing system for RedM servers using RSG Core. - [rsg-core](https://github.com/Rexshack-RedM/rsg-core) - [ox_lib](https://github.com/Rexshack-RedM/ox_lib)

Source: https://github.com/Rexshack-RedM/rsg-bathing

**Dependencies:** `rsg-core`, `rsg-character`, `rsg-wardrobe`

## Exports (call as exports['rsg-bathing']:Name)

**client:** `IsBathingActive()`

## Net events registered

**client:** `rsg-bathing:client:HideDeluxePrompt`, `rsg-bathing:client:StartBath`, `rsg-bathing:client:StartDeluxeBath`, `rsg-bathing:client:ToggleInvincibility`

## Event handlers

**server:** `rsg-bathing:server:canEnterBath`, `rsg-bathing:server:canEnterDeluxeBath`, `rsg-bathing:server:dressPlayer`, `rsg-bathing:server:setBathAsFree`, `rsg-bathing:server:undressPlayer`

**client:** `rsg-bathing:client:HideDeluxePrompt`, `rsg-bathing:client:StartBath`, `rsg-bathing:client:StartDeluxeBath`, `rsg-bathing:client:ToggleInvincibility`

## Server events it triggers in other resources

**client:** `RSGCore:Server:SetMetaData`
