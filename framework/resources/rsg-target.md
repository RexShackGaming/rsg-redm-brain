# rsg-target

Version 3.1.0. targeting system for RSG RedM Framework

Targeting system for the RSG Framework (RedM), rebuilt from ox_target into the standard RSG resource layout, with an RSG-style NUI and a nearby-target highlighter. - Hold **Left Alt** (or toggle) to target peds, horses/wagons, objects and zones - **Nearby highlighter** – eyeball icons over everything around you that you can interact with; the eye turns **green** when the target you're aiming at ca

Source: https://github.com/Rexshack-RedM/rsg-target

**Dependencies:** `rsg-core`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-target']:Name)

**client:** `AddBoxZone(name, center, length, width, options, targetoptions)`, `AddCircleZone(name, center, radius, options, targetoptions)`, `AddEntityZone()`, `AddGlobalObject(options)`, `AddGlobalPed(options)`, `AddGlobalPlayer(options)`, `AddGlobalVehicle(options)`, `AddPolyZone(name, points, options, targetoptions)`, `AddTargetBone(_, options)`, `AddTargetEntity(entities, options)`, `AddTargetModel(models, options)`, `RemoveGlobalObject(labels)`, `RemoveGlobalPed(labels)`, `RemoveGlobalPlayer(labels)`, `RemoveGlobalVehicle(labels)`, `RemoveTargetBone()`, `RemoveTargetEntity(entities, labels)`, `RemoveTargetModel(models, labels)`, `RemoveZone(id)`

## Net events registered

**server:** `rsg-target:server:setEntityHasOptions`

**client:** `RSGCore:Client:OnJobUpdate`, `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `rsg-target:client:removeEntity`

## Event handlers

**client:** `rsg-target:client:debug`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-target:server:getJobs`

## Public (table) functions

**client/api.lua:** `api.addPolyZone(data)`, `api.addBoxZone(data)`, `api.addSphereZone(data)`, `api.zoneExists(id)`, `api.removeZone(id, suppressWarning)`, `api.addGlobalPed(options)`, `api.removeGlobalPed(options)`, `api.addGlobalVehicle(options)`, `api.removeGlobalVehicle(options)`, `api.addGlobalObject(options)`, `api.removeGlobalObject(options)`, `api.addGlobalPlayer(options)`, `api.removeGlobalPlayer(options)`, `api.addModel(arr, options)`, `api.removeModel(arr, options)`, `api.addEntity(arr, options)`, `api.removeEntity(arr, options)`, `api.addLocalEntity(arr, options)`, `api.removeLocalEntity(arr, options)`, `options_mt:wipe()`, `options_mt:set(entity, _type, model)`, `api.addGlobalOption(options)`, `api.removeGlobalOption(options)`, `api.getTargetOptions(entity, _type, model)`, `api.disableTargeting(value)`, `api.isActive()`

**client/framework.lua:** `utils.isOnDuty()`, `utils.hasPlayerGotGroup(filter)`

**client/highlight.lua:** `highlight.isEnabled()`, `highlight.scan()`, `highlight.draw(hovered, activeZones)`, `highlight.clear()`, `highlight.setEnabled(value)`

**client/state.lua:** `state.isActive()`, `state.setActive(value)`, `state.isNuiFocused()`, `state.setNuiFocus(value, cursor)`, `state.isDisabled()`, `state.setDisabled(value)`

**client/utils.lua:** `utils.getTexture()`, `utils.getNearbyZones(coords)`, `utils.drawZoneSprites(dict, texture)`, `utils.getItems()`, `utils.hasPlayerGotItems(filter, hasAny)`, `utils.hasPlayerGotGroup(filter)`, `utils.isOnDuty()`, `utils.onCooldown(option)`, `utils.passesFilters(option)`, `utils.warn(msg)`
