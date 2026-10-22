# rsg-weapons

Version 2.1.10. rsg-weapons

**Weapon handling, degradation & repair for RSG Framework.** > Degradation over time, damage modifiers, repair workflow with a usable repair kit, and an admin `/infinityammo` toggle. > Includes an ammo type map for bows, thrown weapons and firearms.

Source: https://github.com/Rexshack-RedM/rsg-weapons

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

## Exports (call as exports['rsg-weapons']:Name)

**client:** `CheckWeaponSerial()`, `EquippedWeapons()`, `GetUsedWeapons()`, `RemoveWeaponFromPeds(weaponName, serial)`, `UsedWeapons(serial)`, `weaponInHands()`

## Net events registered

**server:** `rsg-weapons:requestToggle`, `rsg-weapons:server:degradeWeapon`, `rsg-weapons:server:repairweapon`, `rsg-weapons:server:saveEquippedKnife`, `rsg-weapons:server:saveEquippedWeapon`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-weapons:client:UseEquipment`, `rsg-weapons:client:UseThrownWeapon`, `rsg-weapons:client:UseWeapon`, `rsg-weapons:client:brokenweapon`, `rsg-weapons:client:repairbrokenweapon`, `rsg-weapons:client:repairweapon`, `rsg-weapons:toggle`

## Event handlers

**server:** `rsg-weapons:server:removeitem`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-weapons:server:getEquippedKnives`, `rsg-weapons:server:getEquippedWeapons`, `rsg-weapons:server:getWeaponBySerial`, `rsg-weapons:server:getweaponinfo`

## Callbacks (lib.callback)

**server:** `rsg-weapons:server:getweaponinfo`

## Usable items

**server:** `weapon_repair_kit`

## Commands (RegisterCommand)

**client:** `/infinityammo`

## Server events it triggers in other resources

**client:** `rsg-weaponcomp:server:check_comps`, `rsg-weaponcomp:server:removeComponents`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
