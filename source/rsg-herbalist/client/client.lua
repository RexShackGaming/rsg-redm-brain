local ResourceName = GetCurrentResourceName()
local RSGCore = exports['rsg-core']:GetCoreObject()

lib.locale()

local function Debug(msg)
    if Config.Debug then
        print('[rsg-herbalist] ' .. msg)
    end
end

----------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------

local function RequestAnimDictWithTimeout(animDict, timeoutMs)
    if HasAnimDictLoaded(animDict) then return true end
    RequestAnimDict(animDict)
    local deadline = GetGameTimer() + timeoutMs
    while not HasAnimDictLoaded(animDict) do
        if GetGameTimer() > deadline then
            Debug('anim dict failed to load: ' .. animDict)
            return false
        end
        Wait(0)
    end
    return true
end

local function AttachHandProp(ped, propName, boneName, offset, rotation)
    local hash = GetHashKey(propName)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then
            Debug('prop model failed to load: ' .. propName)
            return nil
        end
        Wait(0)
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, false, false)
    AttachEntityToEntity(
        prop, ped, GetEntityBoneIndexByName(ped, boneName),
        offset.x or 0.0, offset.y or 0.0, offset.z or 0.0,
        rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function DeleteHandProp(prop)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
end

-- Plays a clip once and blocks until it finishes.
local function PlayAnimClipAndWait(ped, animDict, clip)
    TaskPlayAnim(ped, animDict, clip, 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(50)
    while DoesEntityExist(ped) and IsEntityPlayingAnim(ped, animDict, clip, 3)
        and GetEntityAnimCurrentTime(ped, animDict, clip) < 0.98 do
        Wait(0)
    end
end

local function CreateCraftingCam(ped, camConfig)
    if not camConfig or not camConfig.enabled then return nil end

    local pedCoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam,
        pedCoords.x + forward.x * camConfig.distance,
        pedCoords.y + forward.y * camConfig.distance,
        pedCoords.z + (camConfig.height or 0.55))
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.0, true)
    SetCamFov(cam, camConfig.fov or 40.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, camConfig.transitionMs or 500, true, true)
    return cam
end

local function DestroyCraftingCam(cam, camConfig)
    if not cam then return end
    RenderScriptCams(false, true, camConfig and camConfig.transitionMs or 500, true, true)
    if DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
end

function ProgressOrWait(durationMs, label, showBar)
    if showBar then
        return lib.progressCircle({
            duration = durationMs,
            label = label,
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
        })
    end
    Wait(durationMs)
    return true
end

----------------------------------------------------------------------------
-- Herb nodes
----------------------------------------------------------------------------

local spawnEntries = BuildHerbSpawns()
local suppressed = {}
local nearbyEntries = {}
local isGathering = false

local SCOPE_RANGE_LOAD = Config.ScopeRangeLoad
local SCOPE_RANGE_UNLOAD = Config.ScopeRangeUnload
local PICKUP_RANGE = Config.PickupRange
local NEARBY_RANGE = Config.NearbyRange
local COMPOSITE_LOAD_TIMEOUT_MS = Config.CompositeLoadTimeoutMs

Debug(('built %d spawn entries'):format(#spawnEntries))

local function RequestAndWaitForComposite(hash)
    if Citizen.InvokeNative(0x5E5D96BE25E9DF68, hash) then return true end
    Citizen.InvokeNative(0x73F0D0327BFA0812, hash)
    local deadline = GetGameTimer() + COMPOSITE_LOAD_TIMEOUT_MS
    while not Citizen.InvokeNative(0x5E5D96BE25E9DF68, hash) do
        if GetGameTimer() > deadline then
            Debug('composite failed to load, hash=' .. tostring(hash))
            return false
        end
        Wait(0)
    end
    return true
end

local function DeleteComposite(composite)
    Citizen.InvokeNative(0x5758B1EE0C3FD4AC, composite, 0)
end

local function DisplayCompositePickupThisFrame(composite)
    Citizen.InvokeNative(0x40D72189F46D2E15, composite, true)
end

-- Each load runs in its own thread so one slow/failed stream can't stall
-- the scope loop for every other node.
local function LoadEntry(entry)
    if entry.entity or entry.loading then return end
    entry.loading = true
    CreateThread(function()
        local hash = GetHashKey(entry.plant)
        if RequestAndWaitForComposite(hash) and not entry.entity and not suppressed[entry.id] then
            local c = entry.coord
            local composite = exports[ResourceName]:NativeCreateComposite(hash, c.x, c.y, c.z, false)
            if composite and composite ~= 0 then
                entry.entity = composite
            else
                Debug('composite creation failed, plant=' .. entry.plant)
            end
        end
        entry.loading = false
    end)
end

local function UnloadEntry(entry)
    if entry.entity then
        DeleteComposite(entry.entity)
        entry.entity = nil
    end
end

RegisterNetEvent('rsg-herbalist:client:SetSuppressed', function(id, suppress, newPlant)
    local entry = spawnEntries[id]
    if not entry then return end
    UnloadEntry(entry)
    if suppress then
        suppressed[id] = true
    else
        suppressed[id] = nil
        if newPlant then entry.plant = newPlant end
        -- the scope loop reloads it on its next tick if the player is in range
    end
end)

-- Full state sync (sent in response to requestSync on resource start).
RegisterNetEvent('rsg-herbalist:client:SyncState', function(suppressedIds, plantOverrides)
    suppressed = {}
    for _, id in ipairs(suppressedIds or {}) do
        suppressed[id] = true
        local entry = spawnEntries[id]
        if entry then UnloadEntry(entry) end
    end
    for _, o in ipairs(plantOverrides or {}) do
        local entry = spawnEntries[o[1]]
        if entry and entry.plant ~= o[2] then
            entry.plant = o[2]
            UnloadEntry(entry)
        end
    end
end)

RegisterNetEvent('rsg-herbalist:client:ForceReload', function(id)
    local entry = spawnEntries[id]
    if entry and entry.entity then
        UnloadEntry(entry)
        LoadEntry(entry)
    end
end)

CreateThread(function()
    TriggerServerEvent('rsg-herbalist:server:requestSync')
end)

-- Scope loop: stream nodes in/out and refresh the nearby list once a second.
CreateThread(function()
    while true do
        local playerPos = GetEntityCoords(PlayerPedId())
        local newNearby = {}
        for id = 1, #spawnEntries do
            local entry = spawnEntries[id]
            if not suppressed[id] then
                local dist = #(playerPos - entry.coord)
                if entry.entity then
                    if dist >= SCOPE_RANGE_UNLOAD then
                        UnloadEntry(entry)
                    elseif dist <= NEARBY_RANGE then
                        newNearby[#newNearby + 1] = entry
                    end
                elseif dist <= SCOPE_RANGE_LOAD then
                    LoadEntry(entry)
                end
            end
        end
        nearbyEntries = newNearby
        Wait(1000)
    end
end)

local function GetClosestPickable(playerPos)
    local closest, closestDist
    for i = 1, #nearbyEntries do
        local entry = nearbyEntries[i]
        if entry.entity and not suppressed[entry.id] then
            local dist = #(playerPos - entry.coord)
            if dist <= PICKUP_RANGE and (not closestDist or dist < closestDist) then
                closest, closestDist = entry, dist
            end
        end
    end
    return closest
end

local function TryGather(entry)
    if isGathering then return end
    isGathering = true

    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GATHER_HERBS', 0, true)
    local completed = ProgressOrWait(Config.GatherDurationMs, locale('gathering_herb'), Config.GatherProgressBarEnabled)
    ClearPedTasks(ped)

    if completed and not suppressed[entry.id] then
        TriggerServerEvent('rsg-herbalist:server:gathered', entry.id)
    end
    isGathering = false
end

-- Interaction loop: only runs per-frame while a node is actually in pickup range.
CreateThread(function()
    while true do
        local sleep = 500
        if not isGathering and #nearbyEntries > 0 then
            local ped = PlayerPedId()
            local entry = GetClosestPickable(GetEntityCoords(ped))
            if entry then
                sleep = 0
                DisplayCompositePickupThisFrame(entry.entity)
                if IsPickupControlPressed() and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
                    TryGather(entry)
                end
            end
        end
        Wait(sleep)
    end
end)

----------------------------------------------------------------------------
-- Tonic crafting UI (presentational only - the server validates everything)
----------------------------------------------------------------------------

local playerData = RSGCore.Functions.GetPlayerData()

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(data)
    playerData = data
end)

local function CountItem(itemName)
    local items = playerData and playerData.items
    if not items then return 0 end
    local total = 0
    for _, item in pairs(items) do
        if item and item.name == itemName then
            total = total + (item.amount or 0)
        end
    end
    return total
end

local craftMenuOpen = false
local isCrafting = false

local function BuildTonicPayload()
    local list = {}
    for i, tonic in ipairs(Config.Tonics) do
        local ingredients = {}
        for _, ingredient in ipairs(tonic.ingredients) do
            local itemDef = RSGCore.Shared.Items[ingredient.item]
            ingredients[#ingredients + 1] = {
                label = itemDef and itemDef.label or ingredient.item,
                image = itemDef and itemDef.image or (ingredient.item .. '.png'),
                required = ingredient.amount,
                have = CountItem(ingredient.item),
            }
        end
        local outputDef = RSGCore.Shared.Items[tonic.output.item]
        list[i] = {
            id = tonic.id,
            label = locale(tonic.label),
            description = tonic.description and locale(tonic.description) or '',
            image = tonic.image or (outputDef and outputDef.image) or (tonic.output.item .. '.png'),
            durationMs = tonic.durationMs,
            outputAmount = tonic.output.amount,
            ingredients = ingredients,
        }
    end
    return list
end

local function CloseTonicMenu()
    if not craftMenuOpen then return end
    craftMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function OpenTonicMenu()
    if craftMenuOpen or isCrafting then return end
    craftMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        tonics = BuildTonicPayload(),
        imagePath = Config.InventoryImagePath,
        locale = {
            title = locale('ui_title'),
            subtitle = locale('ui_subtitle'),
            close = locale('ui_close'),
            yields = locale('ui_yields'),
            craft = locale('ui_craft'),
            empty = locale('ui_empty'),
            seconds = locale('ui_seconds_short'),
            minutes = locale('ui_minutes_short'),
        },
    })
end

-- Only opened by the server after the mortarpestle item is used and the job lock passes.
RegisterNetEvent('rsg-herbalist:client:OpenTonicCrafting', OpenTonicMenu)

RegisterNUICallback('close', function(_, cb)
    CloseTonicMenu()
    cb('ok')
end)

RegisterNUICallback('craftTonic', function(data, cb)
    CloseTonicMenu()
    if not isCrafting and type(data) == 'table' and type(data.id) == 'string' then
        TriggerServerEvent('rsg-herbalist:server:requestCraft', data.id)
    end
    cb('ok')
end)

RegisterNetEvent('rsg-herbalist:client:StartCraftProgress', function(durationMs)
    if isCrafting then return end
    isCrafting = true

    local ped = PlayerPedId()
    local anim = Config.TonicCraftAnim
    local camConfig = Config.TonicCraftCamera
    local craftCam = CreateCraftingCam(ped, camConfig)
    local animDone = false

    if anim and anim.enabled and anim.clips and #anim.clips > 0
        and RequestAnimDictWithTimeout(anim.dict, anim.animDictLoadTimeoutMs or 5000) then
        CreateThread(function()
            for _, clip in ipairs(anim.clips) do
                if animDone then break end
                PlayAnimClipAndWait(ped, anim.dict, clip)
            end
            RemoveAnimDict(anim.dict)
        end)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end

    local completed = ProgressOrWait(durationMs, locale('crafting_tonic'), Config.TonicCraftProgressBarEnabled)

    animDone = true
    ClearPedTasks(ped)
    DestroyCraftingCam(craftCam, camConfig)
    isCrafting = false

    TriggerServerEvent(completed and 'rsg-herbalist:server:finishCraft' or 'rsg-herbalist:server:cancelCraft')
end)

----------------------------------------------------------------------------
-- Tonic consumption
----------------------------------------------------------------------------

RegisterNetEvent('rsg-herbalist:client:ApplyTonicEffect', function(itemName)
    local effect = Config.TonicEffects[itemName]
    if not effect then return end

    local ped = PlayerPedId()
    local attr = Config.TonicAttributeIndex or {}
    local drinkAnim = Config.TonicDrinkAnim

    if drinkAnim and drinkAnim.enabled and drinkAnim.clips and #drinkAnim.clips > 0
        and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
        and RequestAnimDictWithTimeout(drinkAnim.dict, drinkAnim.animDictLoadTimeoutMs or 5000) then
        local prop = drinkAnim.prop and AttachHandProp(ped, drinkAnim.prop, drinkAnim.propBone or 'PH_R_HAND',
            drinkAnim.propOffset or {}, drinkAnim.propRotation or {})
        for _, clip in ipairs(drinkAnim.clips) do
            TaskPlayAnim(ped, drinkAnim.dict, clip.anim, 8.0, -8.0, clip.duration or -1, 31, 0, false, false, false)
            Wait(clip.duration or 500)
        end
        ClearPedTasks(ped)
        RemoveAnimDict(drinkAnim.dict)
        DeleteHandProp(prop)
    end

    if effect.healthBoost and attr.health then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, ped, attr.health, effect.healthBoost, true)
    end
    if effect.staminaBoost and attr.stamina then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, ped, attr.stamina, effect.staminaBoost, true)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if ResourceName ~= resourceName then return end
    for i = 1, #spawnEntries do
        UnloadEntry(spawnEntries[i])
    end
    CloseTonicMenu()
end)
