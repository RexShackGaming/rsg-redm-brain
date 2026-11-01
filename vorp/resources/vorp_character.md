# vorp_character

Version 2.1. A Character creator with also shops built in for vorpcore framework

*** *** Lua version of Vorp character <br>

Source: https://github.com/VORPCORE/vorp_character

## Exports (call as exports['vorp_character']:Name)

**server:** `OpenOutfitsMenu(source)`

**client:** `GetAllPlayerComponents()`, `GetPlayerComponent(category)`

## Net events registered

**server:** `vorpcharacter:setPlayerCompChange`

**client:** `vorp:SelectedCharacter`, `vorp_character:Client:OpenOutfitsMenu`, `vorpcharacter:savenew`, `vorpcharacter:selectCharacter`, `vorpcharacter:spawnUniqueCharacter`, `vorpcharacter:startCharacterCreator`, `vorpcharacter:updateCache`

## Event handlers

**server:** `vorp_CreateNewCharacter`, `vorp_character:server:GoToSelectionMenu`, `vorp_character:server:SpawnUniqueCharacter`

**client:** `vorpcharacter:reloadafterdeath`, `vorpcharacter:savenew`, `vorpcharacter:startCharacterCreator`, `vorpcharacter:stopLoadingScene`, `vorpcharacter:updateCache`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_character:callback:CanPayForSecondChance`, `vorp_character:callback:DeleteOutfit`, `vorp_character:callback:GetOutfits`, `vorp_character:callback:PayForSecondChance`, `vorp_character:callback:PayToShop`, `vorp_character:callback:SetOutfit`, `vorp_characters:getMaxCharacters`

## Commands (RegisterCommand)

**client:** `/bandanaon`, `/dress`, `/ringsL`, `/ringsR`, `/sleeves`, `/sleeves2`, `/tuck`, `/undress`

## Server events it triggers in other resources

**client:** `vorp_CharSelectedCharacter`, `vorpcharacter:deleteCharacter`, `vorpcharacter:reloadedskinlistener`, `vorpcharacter:saveCharacter`, `vorpcharacter:setPlayerCompChange`
