# rsg-character

Version 3.1.3. rsg-character

Character selection, character creation, clothing stores, wardrobe and spawn selection for **RSG-Core** (RedM). > Server owners and developers: see **[DOCS.md](DOCS.md)** for the full flow, database layout, security model, exports and how to extend the script. - In-world select screen: your characters' peds line up at a configurable location, with the camera framing every slot automatically.

Source: https://github.com/Rexshack-RedM/rsg-character

**Dependencies:** `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-character']:Name)

**client:** `ApplySkin()`, `ApplySkinMultiChar(SkinData, Target, ClothesData)`, `GetBodyComponents()`, `GetBodyCurrentComponentHash(name)`, `GetClothesCache(name)`, `GetClothesComponentId(name)`, `GetClothesCurrentComponentHash(name)`, `GetComponentId(name)`, `GetComponentsMax(name)`, `GetMaxTexturesForModel(category, model, isClothing)`, `IsCothingActive()`, `SetBeard(target, data)`, `SetFaceOverlays(target, data)`, `SetHair(target, data)`

## Net events registered

**server:** `rsg-character:server:DeleteCharacterSlot`, `rsg-character:server:DeleteOutfit`, `rsg-character:server:RequestCharacterSlots`, `rsg-character:server:RequestCreateCharacterSlot`, `rsg-character:server:SaveSkin`, `rsg-character:server:SelectCharacterSlot`, `rsg-character:server:SetPlayerBucket`, `rsg-character:server:saveOutfit`, `rsg-multicharacter:server:createCharacter`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-character:client:ApplyClothes`, `rsg-character:client:ApplySkin`, `rsg-character:client:BeginLogout`, `rsg-character:client:CharSelectFailed`, `rsg-character:client:OpenCharSelect`, `rsg-character:client:OpenCreator`, `rsg-character:client:OpenSpawnSelect`, `rsg-character:client:ReceiveCharacterSlots`, `rsg-character:client:outfits`

## Event handlers

**client:** `rsg-character:client:ApplyClothes`, `rsg-character:client:CameraMoveStart`, `rsg-character:client:CameraMoveStop`, `rsg-character:client:CameraReset`, `rsg-character:client:CharInfoDelete`, `rsg-character:client:CharInfoGenderChange`, `rsg-character:client:CharInfoPlay`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-character:server:LoadClothes`, `rsg-character:server:getAppearance`, `rsg-character:server:getOutfits`, `rsg-character:server:wearOutfit`, `rsg-multicharacter:server:getAppearance`

## Commands (RegisterCommand)

**client:** `/loadskin`

## Server events it triggers in other resources

**client:** `RSGCore:Server:OnPlayerLoaded`, `rsg-multicharacter:server:createCharacter`

## Public (table) functions

**client/ui.lua:** `menu.setElement(index, prop, value)`, `menu.refresh()`, `menu.addNewElement(element)`, `menu.removeElementByIndex(index)`, `menu.close()`, `UI.Open(_type, _resource, _name, menuData, onSelect, onClose, onChange, onRowAction)`, `UI.CloseAll()`, `UI.inputDialog(header, fields)`, `UI.alertDialog(opts)`, `UI.OpenSpawnSelect(opts)`, `UI.ShowCharacterInfo(data)`, `UI.HideCharacterInfo()`, `UI.ShowLoadingScreen(text)`, `UI.HideLoadingScreen()`

**server/sv_appearance.lua:** `RSG.SetPrivateBucket(src)`, `RSG.ResetBucket(src)`, `RSG.OpenCreatorFor(src, data)`, `RSG.LoadSkinForSource(src)`

**server/webhook.lua:** `RSG.SendWebhook(category, embed)`, `RSG.WebhookIdentityFields(_source)`

**shared/functions.lua:** `RSG.IsValidBirthdate(date)`
