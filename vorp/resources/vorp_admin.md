# vorp_admin

Version 2.6. VORP admin menu

- Built in database permissions - Permissions for all actions - Administration tools

Source: https://github.com/VORPCORE/vorp_admin

Has NUI (`ui_page`).

## Net events registered

**server:** `vorp:teleportWayPoint`, `vorp_admin:BanOffline`, `vorp_admin:BanPlayer`, `vorp_admin:Bring`, `vorp_admin:ClearAllItems`, `vorp_admin:ClearCurrency`, `vorp_admin:GodMode`, `vorp_admin:GoldenCores`, `vorp_admin:HealSelf`, `vorp_admin:InfiAmmo`, `vorp_admin:NoClip`, `vorp_admin:ReviveSelf`, `vorp_admin:ServerDrainPlayerStamHandler`, `vorp_admin:ServerHandcuffPlayerHandler`, `vorp_admin:ServerTempHighPlayerHandler`, `vorp_admin:ServerTrollInvisibleHandler`, `vorp_admin:ServerTrollKillPlayerHandler`, `vorp_admin:ServerTrollLightningStrikePlayerHandler`, `vorp_admin:ServerTrollRagdollPlayerHandler`, `vorp_admin:ServerTrollSetPlayerOnFireHandler`, `vorp_admin:ServerTrollTPToHeavenHandler`, `vorp_admin:TeleportPlayerBack`, `vorp_admin:TpToPlayer`, `vorp_admin:Unban`, `vorp_admin:Whitelist`, `vorp_admin:Whitelistoffline`, `vorp_admin:alertstaff`, `vorp_admin:announce`, `vorp_admin:checkInventory`, `vorp_admin:freeze`, `vorp_admin:getStaffInfo`, `vorp_admin:givePlayer`, `vorp_admin:heal`, `vorp_admin:kick`, `vorp_admin:requeststaff`, `vorp_admin:respawnPlayer`, `vorp_admin:revive`, `vorp_admin:sendAdminBack`, `vorp_admin:setGroup`, `vorp_admin:setJob`, `vorp_admin:spawnHorse`, `vorp_admin:spawnWagon`, `vorp_admin:spectate`, `vorp_admin:tptocoords`

**client:** `vorp_admin:Bring`, `vorp_admin:ClientDrainPlayerStamHandler`, `vorp_admin:ClientHandcuffPlayerHandler`, `vorp_admin:ClientTempHighPlayerHandler`, `vorp_admin:ClientTrollInvisbleHandler`, `vorp_admin:ClientTrollKillPlayerHandler`, `vorp_admin:ClientTrollLightningStrikePlayerHandler`, `vorp_admin:ClientTrollRagdollPlayerHandler`, `vorp_admin:ClientTrollSetPlayerOnFireHandler`, `vorp_admin:ClientTrollTPToHeavenHandler`, `vorp_admin:Freezeplayer`, `vorp_admin:SendPlayers`, `vorp_admin:TeleportPlayerBack`, `vorp_admin:getplayerInventory`, `vorp_admin:gotoPlayer`, `vorp_admin:respawn`, `vorp_admin:sendAdminBack`, `vorp_admin:spectatePlayer`

## Event handlers

**server:** `vorp:SelectedCharacter`, `vorp_admin:logs`

## Callbacks (VORP Core.Callback.Register)

**server:** `vorp_admin:Callback:getplayersinfo`, `vorp_admin:CanOpenStaffMenu`

## Server events it triggers in other resources

**client:** `vorp:teleportWayPoint`
