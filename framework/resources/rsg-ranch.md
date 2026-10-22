# rsg-ranch

Version 3.1.0. rsg-ranch

A complete livestock ranching system for **RedM** servers running the **RSG Framework**. Buy a ranch, hire staff, raise cattle, pigs, sheep and chickens, keep them fed and watered, breed them, collect their produce, and sell or slaughter them for profit, all managed from an in-game ranch menu. - Six purchasable ranches out of the box (Macfarlane, Emerald, Pronghorn, Downes, Hill Haven, Hanging Dog

Source: https://github.com/Rexshack-RedM/rsg-ranch

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-multijob`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-ranch']:Name)

**server:** `CreateAnimalId()`, `addAnimalToRanch(ranchid, model, gender, pos_x, pos_y, pos_z, pos_w)`, `getAnimalData(animalid)`, `getPlayerRanchId(playerId)`, `getRanchAnimalCount(ranchid)`, `getRanchAnimals(ranchid)`, `getRanchStatistics(ranchid)`, `getStaffCount(ranchid)`, `isPlayerRanchStaff(playerId)`, `removeAnimalFromRanch(animalid)`, `updateAnimalStats(animalid, stats)`

**client:** `GetAnimalDataCache()`, `GetAnimalEntityById(animalId)`, `GetNearestFeedTrough(coords, ranchid)`, `GetNearestWaterTrough(coords, ranchid)`, `IsPropPlacementActive()`, `StartPropPlacement(propmodel, opts)`, `canInteractWithAnimal(animalid)`, `getAllBuyPointLocations()`, `getAllRanchLocations()`, `getAllSalePointLocations()`, `getAnimalProductInfo(animalModel)`, `getBreedingConfig(animalModel)`, `getLocalPlayerRanchId()`, `getNearestRanch()`, `getNearestWaterSource()`, `getPlayerJobGrade()`, `getRanchLocation(ranchid)`, `hasPermission(permissionName)`, `isLocalPlayerRanchStaff()`, `isNearRanch(maxDistance)`

## Net events registered

**server:** `rsg-ranch:server:buyAnimal`, `rsg-ranch:server:buyChicken`, `rsg-ranch:server:collectEggs`, `rsg-ranch:server:collectProduct`, `rsg-ranch:server:collectSupplyOrder`, `rsg-ranch:server:confirmMoveFeedTrough`, `rsg-ranch:server:confirmMoveWaterTrough`, `rsg-ranch:server:deleteChickenCoop`, `rsg-ranch:server:deleteFeedTrough`, `rsg-ranch:server:deleteWaterTrough`, `rsg-ranch:server:demoteEmployee`, `rsg-ranch:server:feedChickenCoop`, `rsg-ranch:server:fireEmployee`, `rsg-ranch:server:hireEmployee`, `rsg-ranch:server:openranchstorage`, `rsg-ranch:server:placeChickenCoop`, `rsg-ranch:server:placeFeedTrough`, `rsg-ranch:server:placeSupplyOrder`, `rsg-ranch:server:placeWaterTrough`, `rsg-ranch:server:promoteEmployee`, `rsg-ranch:server:purchaseRanch`, `rsg-ranch:server:purchaseranchstorage`, `rsg-ranch:server:refillFeedTrough`, `rsg-ranch:server:refillWaterTrough`, `rsg-ranch:server:refreshAnimals`, `rsg-ranch:server:refreshChickenCoops`, `rsg-ranch:server:refreshFeedTroughs`, `rsg-ranch:server:refreshWaterTroughs`, `rsg-ranch:server:registerAnimalNetworkId`, `rsg-ranch:server:renameranchstorage`, `rsg-ranch:server:reportDespawn`, `rsg-ranch:server:requestAnimalSpawn`, `rsg-ranch:server:requestMoveFeedTrough`, `rsg-ranch:server:requestMoveWaterTrough`, `rsg-ranch:server:saveAnimalPosition`, `rsg-ranch:server:sellAllAnimals`, `rsg-ranch:server:sellAnimal`, `rsg-ranch:server:sellAtRanch`, `rsg-ranch:server:sellRanch`, `rsg-ranch:server:sendAnimalToFeed`, `rsg-ranch:server:sendAnimalToWater`, `rsg-ranch:server:setstorageaccess`, `rsg-ranch:server:slaughterAtRanch`, `rsg-ranch:server:startBreeding`, `rsg-ranch:server:transferRanchOwnership`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-ranch:client:actionsmenu`, `rsg-ranch:client:animalfollow`, `rsg-ranch:client:animalmenu`, `rsg-ranch:client:animalsendfeed`, `rsg-ranch:client:animalsendwater`, `rsg-ranch:client:applyRanchSettings`, `rsg-ranch:client:checkProducts`, `rsg-ranch:client:clearAnimalSelection`, `rsg-ranch:client:collectProduct`, `rsg-ranch:client:confirmBreeding`, `rsg-ranch:client:findBreedingPartner`, `rsg-ranch:client:moveFeedTrough`, `rsg-ranch:client:moveWaterTrough`, `rsg-ranch:client:openAdmin`, `rsg-ranch:client:openHerdingMenu`, `rsg-ranch:client:openSaleMenu`, `rsg-ranch:client:openmanagermenu`, `rsg-ranch:client:openpurchasemenu`, `rsg-ranch:client:openranch`, `rsg-ranch:client:openranchhandmenu`, `rsg-ranch:client:opentraineemenu`, `rsg-ranch:client:placePump`, `rsg-ranch:client:refreshAnimalsBatch`, `rsg-ranch:client:refreshSingleAnimal`, `rsg-ranch:client:removeAnimal`, `rsg-ranch:client:removeChickenCoop`, `rsg-ranch:client:removeFeedTrough`, `rsg-ranch:client:removeWaterTrough`, `rsg-ranch:client:setAnimalTransporting`, `rsg-ranch:client:showIndividualSelectionMenu`, `rsg-ranch:client:showTypeMenu`, `rsg-ranch:client:spawnAnimalDenied`, `rsg-ranch:client:spawnAnimalGranted`, `rsg-ranch:client:spawnAnimals`, `rsg-ranch:client:spawnChickenCoop`, `rsg-ranch:client:spawnChickenCoops`, `rsg-ranch:client:spawnFeedTrough`, `rsg-ranch:client:spawnFeedTroughs`, `rsg-ranch:client:spawnWaterTrough`, `rsg-ranch:client:spawnWaterTroughs`, `rsg-ranch:client:startChickenCoopPlacement`, `rsg-ranch:client:startDistanceHerding`, `rsg-ranch:client:startFeedTroughMove`, `rsg-ranch:client:startFeedTroughPlacement`, `rsg-ranch:client:startSelectedHerding`, `rsg-ranch:client:startTypeHerding`, `rsg-ranch:client:startWaterTroughMove`, `rsg-ranch:client:startWaterTroughPlacement`, `rsg-ranch:client:stopHerding`, `rsg-ranch:client:syncPumps`, `rsg-ranch:client:toggleAnimalSelection`, `rsg-ranch:client:updateChickenCoop`, `rsg-ranch:client:updateFeedTroughUses`, `rsg-ranch:client:updateWaterTroughUses`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-ranch:server:countanimals`, `rsg-ranch:server:getAnimalOverview`, `rsg-ranch:server:getAnimalProductionStatus`, `rsg-ranch:server:getAvailableAnimalsForBreeding`, `rsg-ranch:server:getBreedingStatus`, `rsg-ranch:server:getChickenCoopStatus`, `rsg-ranch:server:getNearbyAnimalsForSale`, `rsg-ranch:server:getNearbyPlayers`, `rsg-ranch:server:getPregnancyProgress`, `rsg-ranch:server:getRanchMarket`, `rsg-ranch:server:getRanchSellQuote`, `rsg-ranch:server:getStaffList`, `rsg-ranch:server:getSupplyOrders`, `rsg-ranch:server:getranchowner`, `rsg-ranch:server:getranchstorages`

## Callbacks (lib.callback)

**server:** `rsg-ranch:admin:action`, `rsg-ranch:admin:createRanch`, `rsg-ranch:admin:getOverview`, `rsg-ranch:admin:getRanch`, `rsg-ranch:admin:searchPlayers`, `rsg-ranch:server:fillBucket`, `rsg-ranch:server:getPumps`, `rsg-ranch:server:getRanchSettings`, `rsg-ranch:server:packPump`, `rsg-ranch:server:placePump`, `rsg-ranch:server:pumpPrecheck`

**client:** `rsg-ranch:client:requestConsent`

## Commands (RegisterCommand)

**client:** `/cleanupranchanimals`, `/herd`, `/herdclear`, `/herdselectstatus`, `/testproduction`, `/validatemenu`

## Public (table) functions

**client/menu.lua:** `Menu.registerContext(def)`, `Menu.showContext(id)`, `Menu.hideContext(onExit)`, `Menu.getOpenContextMenu()`, `Menu.alertDialog(opts)`, `Menu.closeAlert()`

**client/modules/animals.lua:** `SpawnManager:Initialize()`, `SpawnManager:CheckSpawnRequests()`, `SpawnManager:IsValidAnimalData(data)`, `SpawnManager:RequestSpawn(animalId, animalData)`, `SpawnManager:SpawnAnimal(animalId, animalData, networkId, isCreator)`, `SpawnManager:CreateAnimalEntity(animalData, networkId)`, `SpawnManager:ConfigureAnimalEntity(entity, animalData)`, `SpawnManager:CreateOrUpdateAnimalBlip(animalId)`, `SpawnManager:RemoveAnimalBlip(animalId)`, `SpawnManager:SetupAnimalInteraction(entity, animalData)`, `SpawnManager:SetupAnimalWandering(animalId, entity, animalData)`, `SpawnManager:StartWanderManager()`, `SpawnManager:UpdateAnimalWander(animalId)`, `SpawnManager:StartAnimalWander(animalId, wanderState)`, `SpawnManager:StopAnimalWander(animalId, wanderState)`, `SpawnManager:PauseAnimalWander(animalId)`, `SpawnManager:ResumeAnimalWander(animalId)`, `SpawnManager:DespawnAnimal(animalId)`, `SpawnManager:GetPendingCount()`, `SpawnManager:GetEntityById(animalId)`, `SpawnManager:RemoveAnimal(animalId)`, `SpawnManager:ClearAll()`, `SpawnManager:CleanupOrphanedEntities()`

**server/server.lua:** `SpawnController:Initialize()`, `SpawnController:CanPlayerSpawn(playerId, animalId)`, `SpawnController:RegisterSpawn(playerId, animalId, animalData, networkId)`, `SpawnController:CleanupStaleData()`, `SpawnController:ClearPlayerSpawns(playerId)`

## Database tables

`below`, `rsg_ranch_animals`, `rsg_ranch_chickencoops`, `rsg_ranch_custom`, `rsg_ranch_feedtroughs`, `rsg_ranch_orders`, `rsg_ranch_owners`, `rsg_ranch_settings`, `rsg_ranch_storages`, `rsg_ranch_watertroughs`
