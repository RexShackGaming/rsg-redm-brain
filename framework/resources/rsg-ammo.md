# rsg-ammo

Version 3.0.1. rsg-ammo

**Persistent ammunition system for RedM using the RSG Framework.** Players refill their weapons by using ammo boxes and arrows from their inventory, and every ammo type is saved to the database per character, so ammo carries over between sessions and restarts. - 📦 **Ammo boxes** for revolver, pistol, repeater, rifle, shotgun, elephant rifle and varmint ammo, including express, explosive, high velo

Source: https://github.com/Rexshack-RedM/rsg-ammo

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `ox_lib`

## Exports (call as exports['rsg-ammo']:Name)

**client:** `GetAmmoTypes()`

## Net events registered

**server:** `rsg-ammo:server:cancelOpen`, `rsg-ammo:server:openAmmoBox`, `rsg-ammo:server:updateDb`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-ammo:client:AddAmmo`, `rsg-ammo:client:openAmmoBox`

## Callbacks (lib.callback)

**server:** `rsg-ammo:server:initializeDb`

**client:** `rsg-ammo:client:CanAddAmmo`

## Database tables

`player_ammo`
