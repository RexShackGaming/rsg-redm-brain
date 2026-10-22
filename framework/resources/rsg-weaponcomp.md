# rsg-weaponcomp

Version 3.0.0. rsg-weaponcomp

Weapon customisation for **RSG Framework** (RedM). Players place a portable gunsmith workbench, then use it to swap parts, materials, engravings, tints and wraps on the weapon in their hands, with a live 3D preview. - Portable gunsmith workbench (usable item) with placement preview, rotation and per-player limits - NUI customisation menu with live 3D preview and camera controls (zoom, random angle

Source: https://github.com/Rexshack-RedM/rsg-weaponcomp

**Dependencies:** `rsg-core`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-weaponcomp:server:createnewprop`, `rsg-weaponcomp:server:inspectkitConsume`, `rsg-weaponcomp:server:purchase`, `rsg-weaponcomp:server:removegunsiteprops`, `rsg-weaponcomp:server:reset`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-weaponcomp:client:ExitCam`, `rsg-weaponcomp:client:InspectionWeapon`, `rsg-weaponcomp:client:animationSaved`, `rsg-weaponcomp:client:confirmpackup`, `rsg-weaponcomp:client:createprop`, `rsg-weaponcomp:client:equipScope`, `rsg-weaponcomp:client:reloadWeapon`, `rsg-weaponcomp:client:setupgunzone`, `rsg-weaponcomp:client:unequipScope`, `rsg-weaponcomp:client:updatePropData`

## Event handlers

**client:** `rsg-weaponcomp:client:InspectionWeapon`, `rsg-weaponcomp:client:reloadWeapon`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-weaponcomp:server:countprop`, `rsg-weaponcomp:server:equipScope`, `rsg-weaponcomp:server:getPlayerWeaponComponents`, `rsg-weaponcomp:server:getProps`, `rsg-weaponcomp:server:unequipScope`

## Server events it triggers in other resources

**client:** `rsg-weapons:server:repairweapon`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`

## Database tables

`player_weapons`, `player_weapons_custom`
