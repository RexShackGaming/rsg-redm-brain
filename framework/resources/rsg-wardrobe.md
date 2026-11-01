# rsg-wardrobe

Version 3.0.0. rsg-wardrobe

Toggle individual clothing items on/off via chat commands for RSG Framework (RedM). - [rsg-core](https://github.com/Rexshack-RedM/rsg-core) - [rsg-appearance](https://github.com/Rexshack-RedM/rsg-appearance)

Source: https://github.com/Rexshack-RedM/rsg-wardrobe

**Dependencies:** `rsg-core`, `rsg-character`

## Exports (call as exports['rsg-wardrobe']:Name)

**server:** `DressPlayer(source)`, `RemovePlayerClothing(source)`, `TogglePlayerClothing(source, name)`

**client:** `IsWearing(name)`, `RemoveAllClothing()`, `ToggleClothing(clothingName)`

## Net events registered

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-wardrobe:client:OnOffClothing`, `rsg-wardrobe:client:dress`, `rsg-wardrobe:client:removeAllClothing`

## Event handlers

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-character:client:ApplyClothes`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-wardrobe:server:getPlayerSkin`

## Commands (RSGCore.Commands.Add)

**server:** `/dress`, `/undress`

## Server events it triggers in other resources

**client:** `rsg-weapons:server:RemoveAllObjects`
