# rsg-wardrobe

Version 3.1.0. rsg-wardrobe

**Version 3.2.0** · RSG Framework (RedM) Take individual clothing items off and put them back on from a wardrobe menu or chat commands, switch between saved outfits, keep your clothes clean and dry, and tip your hat. Works on top of the clothing stored by rsg-character. Full technical documentation: [DOCS.md](DOCS.md)

Source: https://github.com/Rexshack-RedM/rsg-wardrobe

**Dependencies:** `rsg-core`, `rsg-character`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-wardrobe']:Name)

**server:** `DressPlayer(source)`, `RemovePlayerClothing(source)`, `TogglePlayerClothing(source, name)`

**client:** `CleanClothes()`, `GetClothingState()`, `IsWearing(name)`, `OpenWardrobe()`, `RemoveAllClothing()`, `ToggleClothing(clothingName)`

## Net events registered

**server:** `rsg-wardrobe:server:dress`, `rsg-wardrobe:server:toggle`, `rsg-wardrobe:server:undress`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-medic:client:revive`, `rsg-wardrobe:client:OnOffClothing`, `rsg-wardrobe:client:dress`, `rsg-wardrobe:client:openMenu`, `rsg-wardrobe:client:removeAllClothing`

## Event handlers

**client:** `rsg-character:client:ApplyClothes`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-wardrobe:server:deleteOutfit`, `rsg-wardrobe:server:getOutfits`, `rsg-wardrobe:server:getPlayerSkin`, `rsg-wardrobe:server:saveOutfit`, `rsg-wardrobe:server:wearOutfit`

## Commands (RSGCore.Commands.Add)

**server:** `/dress`, `/undress`

## Server events it triggers in other resources

**client:** `rsg-weapons:server:RemoveAllObjects`
