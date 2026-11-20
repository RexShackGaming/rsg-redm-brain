# rsg-gangs

Version 3.4.0. Gang System for RSG Framework

Player-run gangs ("outfits") for the RSG Framework: ranks and permissions, a shared bank, a chuck wagon that acts as the gang base, deployable camp equipment, crafting stations and an upgradable strongbox stash. Version 3.1.1. Full reference: [DOCS.md](DOCS.md). - rsg-core

Source: https://github.com/Rexshack-RedM/rsg-gangs

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `rsg-wellpump`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-gangs']:Name)

**server:** `AddGangBank(gangName, amount, reason)`, `GetGangBank(gangName)`, `GetGangData(gangName)`, `GetGangMembers(gangName)`, `GetGangOnlineSources(gangName)`, `GetGangTag(src)`, `GetPlayerGang(citizenid)`, `HasGangPermission(citizenid, permission)`, `IsGangLeader(citizenid)`, `RemoveGangBank(gangName, amount, reason)`

## Net events registered

**server:** `rsg-gangs:server:abandonTerritory`, `rsg-gangs:server:acceptInvite`, `rsg-gangs:server:claimTerritory`, `rsg-gangs:server:craftItem`, `rsg-gangs:server:createGang`, `rsg-gangs:server:declineInvite`, `rsg-gangs:server:demoteMember`, `rsg-gangs:server:deployEquipment`, `rsg-gangs:server:depositMoney`, `rsg-gangs:server:disbandGang`, `rsg-gangs:server:drinkWater`, `rsg-gangs:server:equipmentPlaced`, `rsg-gangs:server:equipmentPlacementCancelled`, `rsg-gangs:server:equipmentSpawned`, `rsg-gangs:server:fillBucket`, `rsg-gangs:server:gangVehicleSpotFailed`, `rsg-gangs:server:gangVehicleSpotFound`, `rsg-gangs:server:gangWagonMoved`, `rsg-gangs:server:gangWagonSpawned`, `rsg-gangs:server:invitePlayer`, `rsg-gangs:server:kickMember`, `rsg-gangs:server:leaveGang`, `rsg-gangs:server:openGangStash`, `rsg-gangs:server:packEquipment`, `rsg-gangs:server:postBounty`, `rsg-gangs:server:promoteMember`, `rsg-gangs:server:renameGang`, `rsg-gangs:server:requestEquipmentRegistry`, `rsg-gangs:server:requestLeaderboard`, `rsg-gangs:server:requestLogs`, `rsg-gangs:server:requestState`, `rsg-gangs:server:requestTerritories`, `rsg-gangs:server:requestWagonRegistry`, `rsg-gangs:server:resetWagon`, `rsg-gangs:server:setBlips`, `rsg-gangs:server:setColor`, `rsg-gangs:server:setTag`, `rsg-gangs:server:startRaid`, `rsg-gangs:server:transferLeadership`, `rsg-gangs:server:upgradeGangStash`, `rsg-gangs:server:wagonHeartbeat`, `rsg-gangs:server:withdrawMoney`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-gangs:client:adminTeleport`, `rsg-gangs:client:closeMenu`, `rsg-gangs:client:despawnGangWagon`, `rsg-gangs:client:equipmentRegistered`, `rsg-gangs:client:equipmentRegistrySync`, `rsg-gangs:client:equipmentUnregistered`, `rsg-gangs:client:findGangVehicleSpot`, `rsg-gangs:client:leaderboard`, `rsg-gangs:client:logs`, `rsg-gangs:client:memberBlips`, `rsg-gangs:client:openAdmin`, `rsg-gangs:client:openCraftMenu`, `rsg-gangs:client:openMenu`, `rsg-gangs:client:requestAccept`, `rsg-gangs:client:requestDecline`, `rsg-gangs:client:setState`, `rsg-gangs:client:spawnEquipmentAt`, `rsg-gangs:client:spawnGangWagonAt`, `rsg-gangs:client:startEquipmentPlacement`, `rsg-gangs:client:territories`, `rsg-gangs:client:wagonRegistered`, `rsg-gangs:client:wagonRegistrySync`, `rsg-gangs:client:wagonUnregistered`

## Event handlers

**server:** `RSGCore:Server:OnPlayerKilled`, `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`, `rsg-bountyhunter:server:posterClosed`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-gangs:server:admin`, `rsg-gangs:server:bountyTargets`

## Commands (RSGCore.Commands.Add)

**server:** `/addgangmember`, `/creategangadmin`, `/disbandgangadmin`, `/gangaccept`, `/gangdecline`, `/setgangwagon`

## Public (table) functions

**client/main.lua:** `RSGGangsClient.Notify(description, nType)`, `RSGGangsClient.SetFocus(enable)`, `RSGGangsClient.OpenFocusOnly()`, `RSGGangsClient.RequestState()`

**client/vehicle.lua:** `RSGGangsClient.LoadModel(modelHash)`, `RSGGangsClient.GetValidNetworkId(entity, maxWaitMs)`, `RSGGangsClient.AddEntityTarget(entity, options)`, `RSGGangsClient.RemoveEntityTarget(entity)`

**server/features.lua:** `RSGGangs.TerritoryPayload(gang)`, `RSGGangs.OnGangDestroyed(gang)`, `RSGGangs.UpkeepPayload(gang)`, `RSGGangs.BountyPayload(gang)`, `RSGGangs.ClearRivals(name)`, `RSGGangs.RivalPayload(gang)`, `RSGGangs.Webhook(gang, actor, action, parts)`, `RSGGangs.OnGangDestroyed(gang)`, `RSGGangs.TerritoryPayload(gang)`, `RSGGangs.AdminTerritories()`, `RSGGangs.AdminSetTerritory(id, gangName)`

## Database tables

`rsg_gang_bounties`, `rsg_gang_equipment`, `rsg_gang_logs`, `rsg_gang_members`, `rsg_gang_rivals`, `rsg_gang_territories`, `rsg_gangs`
