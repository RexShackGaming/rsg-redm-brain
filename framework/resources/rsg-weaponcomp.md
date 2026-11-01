# rsg-weaponcomp

Version 3.2.1. rsg-weaponcomp

Weapon customisation for **RSG Framework** (RedM). Players place a portable gunsmith workbench, then use it to swap parts, materials, engravings, tints and wraps on the weapon in their hands, with a live 3D preview. - Portable gunsmith workbench (usable item) with a placement preview, rotation, range indicator, cancellable set-up and per-player limits - NUI customisation menu with a live 3D previe

Source: https://github.com/Rexshack-RedM/rsg-weaponcomp

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-weaponcomp:server:createnewprop`, `rsg-weaponcomp:server:purchase`, `rsg-weaponcomp:server:removegunsiteprops`, `rsg-weaponcomp:server:reset`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-weaponcomp:client:ExitCam`, `rsg-weaponcomp:client:InspectionWeapon`, `rsg-weaponcomp:client:animationSaved`, `rsg-weaponcomp:client:confirmpackup`, `rsg-weaponcomp:client:createprop`, `rsg-weaponcomp:client:reloadWeapon`, `rsg-weaponcomp:client:setupgunzone`, `rsg-weaponcomp:client:updatePropData`

## Event handlers

**client:** `rsg-weaponcomp:client:reloadWeapon`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-weaponcomp:server:countprop`, `rsg-weaponcomp:server:equipScope`, `rsg-weaponcomp:server:getPlayerWeaponComponents`, `rsg-weaponcomp:server:getProps`, `rsg-weaponcomp:server:unequipScope`, `rsg-weaponcomp:server:useRepairKit`

## Server events it triggers in other resources

**client:** `rsg-weapons:server:repairweapon`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

**server/discord.lua:** `Discord.Log(channel, src, title, extraFields, description)`, `Discord.Security(src, reason, details)`, `Discord.FormatComponents(comps)`

**shared/utils.lua:** `WeaponComp.IsFactoryCategory(cat)`, `WeaponComp.Priority(cat)`, `WeaponComp.SortedKeys(comps)`, `WeaponComp.ChangePrice(current, new)`

## Database tables

`player_weapons`, `player_weapons_custom`
