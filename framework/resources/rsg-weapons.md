# rsg-weapons

Version 3.1.0. rsg-weapons

**Weapon handling for RSG Framework: dual wield, serial-based equipping, weapon wear, repairs, saved loadouts and damage tuning.** rsg-weapons controls what happens when a player uses a weapon from their inventory. Every gun is tracked by its **serial number**, so two of the same model behave as two separate weapons with their own wear and repair state. All item and quality changes happen **on the

Source: https://github.com/Rexshack-RedM/rsg-weapons

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `oxmysql`

## Exports (call as exports['rsg-weapons']:Name)

**client:** `CheckWeaponSerial()`, `EquippedWeapons()`, `GetUsedWeapons()`, `RemoveWeaponFromPeds(weaponName, serial)`, `UsedWeapons(serial)`, `weaponInHands()`

## Net events registered

**server:** `rsg-weapons:requestToggle`, `rsg-weapons:server:cancelRepair`, `rsg-weapons:server:degradeWeapon`, `rsg-weapons:server:finishRepair`, `rsg-weapons:server:saveEquippedKnife`, `rsg-weapons:server:saveEquippedWeapon`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-weapons:client:UseEquipment`, `rsg-weapons:client:UseThrownWeapon`, `rsg-weapons:client:UseWeapon`, `rsg-weapons:client:brokenweapon`, `rsg-weapons:client:repairweapon`, `rsg-weapons:toggle`

## Callbacks (lib.callback)

**server:** `rsg-weapons:server:consumeItem`, `rsg-weapons:server:getEquipped`, `rsg-weapons:server:startRepair`

## Commands (RegisterCommand)

**client:** `/infinityammo`

## Server events it triggers in other resources

**client:** `rsg-weaponcomp:server:check_comps`, `rsg-weaponcomp:server:removeComponents`

## Public (table) functions

**client/dataview.lua:** `DataView.ArrayBuffer(length)`, `DataView.Wrap(blob)`, `DataView:Buffer()`, `DataView:ByteLength()`, `DataView:ByteOffset()`, `DataView:SubView(offset)`
