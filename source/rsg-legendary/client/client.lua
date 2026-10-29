local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local trappers = {}    -- [i] = { ped, blip }
local uiOpen = false
local cluePrompt = nil -- native 'Inspect tracks' prompt (registered once)
local hunt = nil       -- { animal, label, total, found, clue, spawn, zoneBlip, clueBlip, clueZone, ped, pedBlip, dead, deadAt, skinTarget }
local skinning = false
local previewPed, previewToken = nil, 0

local LOOT_COMPLETE = 1376140891   -- EVENT_LOOT_COMPLETE (rdr3_discoveries/AI/EVENTS), same as rsg-hunting

---------------------------------
-- Natives (hashes from rsg-redm-brain natives/db/INDEX.tsv)
---------------------------------
local function setOutfitPreset(ped, preset) Citizen.InvokeNative(0xFFA1594703ED27CA, ped, preset, false) end          -- _SET_PED_OUTFIT_PRESET
local function blipForCoords(style, v) return Citizen.InvokeNative(0x554D9D53F696D002, style, v.x, v.y, v.z or 0.0) end -- BLIP_ADD_FOR_COORDS
local function blipForRadius(style, v, r) return Citizen.InvokeNative(0x45F13B7E0A15C880, style, v.x, v.y, 0.0, r) end  -- BLIP_ADD_FOR_RADIUS
local function blipForEntity(style, ent) return Citizen.InvokeNative(0x23F74C2FDA6E7C61, style, ent) end               -- BLIP_ADD_FOR_ENTITY
local function nameBlip(blip, text) Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', text)) end -- _SET_BLIP_NAME
local function carriedEntity(ped) return Citizen.InvokeNative(0xD806CD2A4F2C2996, ped) end                              -- _GET_FIRST_ENTITY_PED_IS_CARRYING

local function notify(desc, ntype)
    lib.notify({ title = locale('title'), description = desc, type = ntype or 'inform' })
end

local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

-- probe from just above the player so tree canopies / unloaded terrain far away don't give a bad height
local function groundZ(x, y, fromZ)
    local start = fromZ and (fromZ + 50.0) or 1000.0
    local ok, z = GetGroundZFor_3dCoord(x, y, start, false)
    if ok and z ~= 0.0 then return z end
    if fromZ then return fromZ end
end

local function crouchProgress(duration, label)
    local me = cache.ped
    TaskStartScenarioInPlaceHash(me, Config.ClueScenario, duration, true, 0, -1.0, false)
    local ok = lib.progressBar({ duration = duration, label = label, canCancel = true, disable = { move = true, combat = true } })
    ClearPedTasks(me)
    return ok
end

---------------------------------
-- NUI
---------------------------------
local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function refreshUI()
    local data = lib.callback.await('rsg-legendary:server:getMenu', false)
    if data then SendNUIMessage({ action = 'refresh', data = data }) else closeUI() end
end

local function openTrapper()
    local data = lib.callback.await('rsg-legendary:server:getMenu', false)
    if not data then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data, locale = {
        title = locale('ui_title'), subtitle = locale('ui_subtitle'), maps = locale('ui_maps'), sell = locale('ui_sell'),
        sellall = locale('ui_sellall'), cooldown = locale('ui_cooldown'), nothing = locale('ui_nothing'), cash = locale('ui_cash'),
        each = locale('ui_each'), needxp = locale('ui_needxp'), xp = locale('ui_xp'),
    } })
end

RegisterNUICallback('close', function(_, cb) closeUI() cb('ok') end)

RegisterNUICallback('buy', function(body, cb)
    lib.callback.await('rsg-legendary:server:buyMap', false, body.key)
    refreshUI()
    cb('ok')
end)

RegisterNUICallback('sell', function(body, cb)
    lib.callback.await('rsg-legendary:server:sell', false, body.item)
    refreshUI()
    cb('ok')
end)

---------------------------------
-- Trapper NPCs (blips always, peds only when nearby)
---------------------------------
local function spawnTrapper(i, t)
    if not loadModel(t.model) then return end
    local ped = CreatePed(t.model, t.coords.x, t.coords.y, t.coords.z - 1.0, t.coords.w, false, false, false, false)
    SetModelAsNoLongerNeeded(t.model)
    SetRandomOutfitVariation(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    exports.ox_target:addLocalEntity(ped, {
        { name = 'rsg_legendary_trapper', icon = 'fa-solid fa-paw', label = locale('target_trapper'),
          distance = Config.TrapperInteractDistance, onSelect = openTrapper },
    })
    trappers[i].ped = ped
end

local function despawnTrapper(i)
    local ped = trappers[i].ped
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped)
        DeleteEntity(ped)
    end
    trappers[i].ped = nil
end

CreateThread(function()
    for i, t in ipairs(Config.Trappers) do
        trappers[i] = {}
        if t.blip and t.blip.enabled then
            local blip = blipForCoords(`BLIP_STYLE_SHOP`, t.coords)
            SetBlipSprite(blip, t.blip.sprite, true)
            nameBlip(blip, t.blip.name)
            trappers[i].blip = blip
        end
    end
    while true do
        local pos = GetEntityCoords(cache.ped)
        for i, t in ipairs(Config.Trappers) do
            local near = #(pos - t.coords.xyz) < Config.TrapperSpawnDistance
            if near and not trappers[i].ped then spawnTrapper(i, t)
            elseif not near and trappers[i].ped then despawnTrapper(i) end
        end
        Wait(2000)
    end
end)

---------------------------------
-- Hunt
---------------------------------
local function clearClue()
    if hunt.clueBlip then RemoveBlip(hunt.clueBlip) hunt.clueBlip = nil end
    if Config.RouteToClue then ClearGpsMultiRoute() end
    hunt.clueZone, hunt.clueZ = nil, nil   -- stops the clue prompt thread
    if cluePrompt then PromptSetEnabled(cluePrompt, false) PromptSetVisible(cluePrompt, false) end
end

local function endHunt()
    if not hunt then return end
    clearClue()
    if hunt.zoneBlip then RemoveBlip(hunt.zoneBlip) end
    if hunt.pedBlip then RemoveBlip(hunt.pedBlip) end
    if hunt.ped and DoesEntityExist(hunt.ped) then
        if hunt.skinTarget then exports.ox_target:removeLocalEntity(hunt.ped) end
        DeleteEntity(hunt.ped)
    end
    hunt = nil
end

local function placeClueBlip()
    hunt.clueBlip = blipForCoords(Config.ClueBlipStyle, hunt.clue)
    nameBlip(hunt.clueBlip, locale('blip_clue'))
    if Config.RouteToClue then   -- GPS line to the next tracks (RedM GPS multi-route natives)
        local z = groundZ(hunt.clue.x, hunt.clue.y) or GetEntityCoords(cache.ped).z
        ClearGpsMultiRoute()
        StartGpsMultiRoute(joaat('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(hunt.clue.x, hunt.clue.y, z)
        SetGpsMultiRouteRender(true)
    end
end

local function inspectClue()
    if not hunt or not hunt.clue then return end
    if not crouchProgress(Config.ClueInspectTime, locale('inspecting')) or not hunt then return end

    local res = lib.callback.await('rsg-legendary:server:inspectClue', false)
    if not hunt then return end   -- hunt ended (e.g. expired) while waiting
    if not res then notify(locale('clue_failed'), 'error') return end

    clearClue()
    if res.spawn then
        hunt.clue, hunt.spawn = nil, res.spawn
        notify(locale('trail_complete'), 'warning')
    else
        hunt.clue = res.clue
        placeClueBlip()
        notify(locale('clue_found', res.found, hunt.total), 'inform')
    end
end

local function getCluePrompt()
    if cluePrompt then return cluePrompt end
    cluePrompt = PromptRegisterBegin()
    PromptSetControlAction(cluePrompt, Config.CluePromptKey)
    PromptSetText(cluePrompt, CreateVarString(10, 'LITERAL_STRING', locale('target_clue')))
    PromptSetHoldMode(cluePrompt, Config.CluePromptHold)
    PromptSetEnabled(cluePrompt, false)
    PromptSetVisible(cluePrompt, false)
    PromptRegisterEnd(cluePrompt)
    return cluePrompt
end

-- shows the 'Inspect tracks' prompt while the player stands at the current clue
local function activateClue(z)
    hunt.clueZ = z
    if hunt.clueZone then return end   -- prompt thread already running, it reads the new height
    hunt.clueZone = true
    local prompt = getCluePrompt()
    CreateThread(function()
        local busy = false
        while hunt and hunt.clueZone do
            local sleep = 500
            local clue = vector3(hunt.clue.x, hunt.clue.y, hunt.clueZ)
            local near = not busy and #(GetEntityCoords(cache.ped) - clue) < Config.ClueTargetDistance
                and not IsPedOnMount(cache.ped) and not IsPedInAnyVehicle(cache.ped, false)
            PromptSetEnabled(prompt, near)
            PromptSetVisible(prompt, near)
            if near then
                sleep = 0
                if PromptHasHoldModeCompleted(prompt) then
                    busy = true
                    PromptSetEnabled(prompt, false) PromptSetVisible(prompt, false)
                    inspectClue()   -- clears/replaces the clue, which ends or refreshes this loop
                    busy = false
                end
            end
            Wait(sleep)
        end
        PromptSetEnabled(prompt, false)
        PromptSetVisible(prompt, false)
    end)
end

local function spawnAnimal(z)
    local cfg = Config.Animals[hunt.animal]
    if not loadModel(cfg.model) then notify(locale('spawn_failed'), 'error') return end
    local s = hunt.spawn
    local ped = CreatePed(cfg.model, s.x, s.y, z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(cfg.model)
    if not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, true, true)
    setOutfitPreset(ped, cfg.outfit or 0)

    local maxHp = math.floor(GetEntityMaxHealth(ped) * (cfg.healthMult or 1.0))
    SetEntityMaxHealth(ped, maxHp)
    SetEntityHealth(ped, maxHp, 0)

    if cfg.aggressive then
        SetPedCombatAttributes(ped, 5, true)    -- ALWAYS_FIGHT
        SetPedCombatAttributes(ped, 58, true)   -- DISABLE_FLEE_FROM_COMBAT
        TaskCombatPed(ped, cache.ped, 0, 16)
    else
        TaskWanderInArea(ped, s.x, s.y, z, 40.0, 0, 0, 0)
    end

    hunt.ped = ped
    hunt.pedBlip = blipForEntity(Config.ClueBlipStyle, ped)
    nameBlip(hunt.pedBlip, cfg.label)
    TriggerServerEvent('rsg-legendary:server:animalSpawned', NetworkGetNetworkIdFromEntity(ped))
    notify(locale('animal_appeared', cfg.label), 'warning')
end

-- claim rewards for the carcass (native skin or ox_target fallback)
local function claimSkin()
    if skinning or not hunt or not hunt.ped then return end
    skinning = true
    local ok = lib.callback.await('rsg-legendary:server:skin', false, NetworkGetNetworkIdFromEntity(hunt.ped))
    if ok then
        if hunt then hunt.ped = nil end   -- server deleted the carcass
        endHunt()
        if Config.DeleteCarriedPelt then
            Wait(1000)   -- let the game finish handing over the vanilla pelt
            local carried = carriedEntity(cache.ped)
            if carried and carried ~= 0 then DeleteEntity(carried) end
        end
    end
    skinning = false
end

local function addSkinTarget()
    if not hunt or not hunt.ped or hunt.skinTarget then return end
    hunt.skinTarget = true
    exports.ox_target:addLocalEntity(hunt.ped, {
        { name = 'rsg_legendary_skin', icon = 'fa-solid fa-paw', label = locale('target_skin', Config.Animals[hunt.animal].label),
          distance = 3.0,
          onSelect = function()
              if not skinning and crouchProgress(Config.SkinTime, locale('skinning')) then claimSkin() end
          end },
    })
end

-- watch for the game's own skinning finishing on our carcass (only while one is lying dead)
local function watchNativeSkin()
    CreateThread(function()
        while hunt and hunt.dead and hunt.ped do
            for i = 0, GetNumberOfEvents(0) - 1 do
                if GetEventAtIndex(0, i) == LOOT_COMPLETE then
                    local view = exports[GetCurrentResourceName()]:DataViewNativeGetEventData(0, i, 3)
                    if view['4'] == 1 and view['0'] == cache.ped and hunt and view['2'] == hunt.ped then
                        CreateThread(claimSkin)
                    end
                end
            end
            Wait(0)
        end
    end)
end

local function huntTick()
    local pos = GetEntityCoords(cache.ped).xy

    if hunt.clue then
        local dist = #(pos - hunt.clue)
        if not hunt.clueZone and dist < Config.ClueZoneDistance then
            local z = groundZ(hunt.clue.x, hunt.clue.y, GetEntityCoords(cache.ped).z)
            if z then activateClue(z) end
        elseif hunt.clueZone and dist < 10.0 then
            -- terrain is fully loaded now: rebuild the zone if its height was off
            local z = groundZ(hunt.clue.x, hunt.clue.y, GetEntityCoords(cache.ped).z)
            if z and math.abs(z - hunt.clueZ) > 1.5 then
                activateClue(z)
            end
        end
    elseif hunt.spawn and not hunt.ped then
        if #(pos - hunt.spawn) < Config.ActivateDistance then
            local z = groundZ(hunt.spawn.x, hunt.spawn.y)
            if z then spawnAnimal(z) end
        end
    elseif hunt.ped then
        if not DoesEntityExist(hunt.ped) then
            notify(locale('animal_lost'), 'error')
            hunt.ped = nil   -- respawn it next tick if the player is still nearby
            if hunt.pedBlip then RemoveBlip(hunt.pedBlip) hunt.pedBlip = nil end
            hunt.dead, hunt.skinTarget = nil, nil
        elseif not hunt.dead and IsEntityDead(hunt.ped) then
            hunt.dead, hunt.deadAt = true, GetGameTimer()
            notify(locale('animal_down'), 'success')
            if Config.Animals[hunt.animal].skin == 'target' then addSkinTarget() end
            watchNativeSkin()
        elseif hunt.dead and not hunt.skinTarget and Config.SkinFallbackDelay > 0
            and GetGameTimer() - hunt.deadAt > Config.SkinFallbackDelay * 1000 then
            addSkinTarget()
        end
    end
end

RegisterNetEvent('rsg-legendary:client:startHunt', function(data)
    endHunt()
    hunt = { animal = data.animal, total = data.total, clue = data.clue }
    hunt.zoneBlip = blipForRadius(Config.ZoneBlipStyle, data.zone, data.radius)
    placeClueBlip()
    CreateThread(function()
        while hunt do
            huntTick()
            Wait(1000)
        end
    end)
end)

RegisterNetEvent('rsg-legendary:client:endHunt', endHunt)

---------------------------------
-- Admin preview (/legendpreview)
---------------------------------
RegisterNetEvent('rsg-legendary:client:preview', function(key, preset)
    local cfg = Config.Animals[key]
    if not cfg then return end
    if previewPed and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
    if not loadModel(cfg.model) then return end
    local c = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 5.0, 0.0)
    previewPed = CreatePed(cfg.model, c.x, c.y, c.z, GetEntityHeading(cache.ped) + 180.0, false, false, false, false)
    SetModelAsNoLongerNeeded(cfg.model)
    setOutfitPreset(previewPed, preset)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityInvincible(previewPed, true)
    notify(locale('preview', cfg.label, preset))

    previewToken = previewToken + 1
    local token = previewToken
    SetTimeout(30000, function()
        if token == previewToken and previewPed and DoesEntityExist(previewPed) then
            DeleteEntity(previewPed)
            previewPed = nil
        end
    end)
end)

---------------------------------
-- Cleanup
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    endHunt()
    if cluePrompt then PromptDelete(cluePrompt) cluePrompt = nil end
    for i, t in pairs(trappers) do
        despawnTrapper(i)
        if t.blip then RemoveBlip(t.blip) end
    end
    if previewPed and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    closeUI()
    endHunt()
end)
