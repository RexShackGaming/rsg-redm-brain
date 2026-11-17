# rsg-weaponcomp

Version 3.5.1. rsg-weaponcomp

Weapon customisation for **RSG Framework** (RedM). Players place a portable gunsmith workbench, then use it to swap parts, materials, engravings, tints and wraps on the weapon in their hands, with a live 3D preview. - Portable gunsmith workbench (usable item) placed with the rsg-gizmo placement gizmo, with a cancellable set-up and per-player limits - NUI customisation menu with a live 3D preview o

Source: https://github.com/Rexshack-RedM/rsg-weaponcomp

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-weapons`, `rsg-target`, `rsg-gizmo`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-weaponcomp']:Name)

**server:** `GetWeaponRecord(serial)`

## Net events registered

**server:** `rsg-weaponcomp:server:adminplace`, `rsg-weaponcomp:server:createnewprop`, `rsg-weaponcomp:server:purchase`, `rsg-weaponcomp:server:removegunsiteprops`, `rsg-weaponcomp:server:reset`, `rsg-weaponcomp:server:setaccess`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-weaponcomp:client:ExitCam`, `rsg-weaponcomp:client:InspectionWeapon`, `rsg-weaponcomp:client:adminplace`, `rsg-weaponcomp:client:animationSaved`, `rsg-weaponcomp:client:confirmpackup`, `rsg-weaponcomp:client:createprop`, `rsg-weaponcomp:client:oilWeapon`, `rsg-weaponcomp:client:printlist`, `rsg-weaponcomp:client:reloadWeapon`, `rsg-weaponcomp:client:setupgunzone`, `rsg-weaponcomp:client:updatePropData`

## Event handlers

**client:** `rsg-weaponcomp:client:reloadWeapon`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-weaponcomp:server:countprop`, `rsg-weaponcomp:server:deletePreset`, `rsg-weaponcomp:server:equipScope`, `rsg-weaponcomp:server:getPlayerWeaponComponents`, `rsg-weaponcomp:server:getProps`, `rsg-weaponcomp:server:listPresets`, `rsg-weaponcomp:server:savePreset`, `rsg-weaponcomp:server:setIdentity`, `rsg-weaponcomp:server:unequipScope`, `rsg-weaponcomp:server:useGunOil`, `rsg-weaponcomp:server:useRepairKit`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

**client/maintenance.lua:** `Maintenance.GetHeldWeaponObject(ped)`, `Maintenance.GetDirt(ped)`, `Maintenance.ClearDirt(obj)`, `Maintenance.ClearDegradation(obj)`

**server/discord.lua:** `Discord.Log(channel, src, title, extraFields, description)`, `Discord.Security(src, reason, details)`, `Discord.FormatComponents(comps)`

**shared/utils.lua:** `WeaponComp.IsFactoryCategory(cat)`, `WeaponComp.Priority(cat)`, `WeaponComp.SortedKeys(comps)`, `WeaponComp.ChangePrice(current, new)`, `WeaponComp.SharedCategoryAllowed(cat, weaponName, specific)`

## Database tables

`player_weapons`, `player_weapons_custom`, `player_weapons_presets`
