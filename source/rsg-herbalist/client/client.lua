local ResourceName = GetCurrentResourceName()
local RSGCore = exports['rsg-core']:GetCoreObject()

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
        return RSGCore.Functions.ProgressCircle({
            duration = durationMs,
            label = label,
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, mount = true, combat = true },
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
local lastPromptId = nil

local SCOPE_RANGE_LOAD = Config.ScopeRangeLoad
local SCOPE_RANGE_UNLOAD = Config.ScopeRangeUnload
-- squared ranges: the scope loop compares these instead of taking a square root per node
local LOAD_SQ = SCOPE_RANGE_LOAD * SCOPE_RANGE_LOAD
local UNLOAD_SQ = SCOPE_RANGE_UNLOAD * SCOPE_RANGE_UNLOAD
local NEARBY_SQ = Config.NearbyRange * Config.NearbyRange
local PICKUP_RANGE = Config.PickupRange
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
        local px, py, pz = playerPos.x, playerPos.y, playerPos.z
        local newNearby = {}
        for id = 1, #spawnEntries do
            local entry = spawnEntries[id]
            if not suppressed[id] then
                local c = entry.coord
                local dx, dy = px - c.x, py - c.y
                local d2 = dx * dx + dy * dy
                -- cheap flat-distance reject first; only near nodes pay for the 3D check
                if d2 <= UNLOAD_SQ then
                    local dz = pz - c.z
                    d2 = d2 + dz * dz
                    if entry.entity then
                        if d2 >= UNLOAD_SQ then
                            UnloadEntry(entry)
                        elseif d2 <= NEARBY_SQ then
                            newNearby[#newNearby + 1] = entry
                        end
                    elseif d2 <= LOAD_SQ then
                        LoadEntry(entry)
                    end
                elseif entry.entity then
                    UnloadEntry(entry)
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
    Debug(('pickup pressed, gathering node id=%d plant=%s'):format(entry.id, tostring(entry.plant)))

    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_GATHER_HERBS', 0, true)
    local completed = ProgressOrWait(Config.GatherDurationMs, locale('gathering_herb'), Config.GatherProgressBarEnabled)
    ClearPedTasks(ped)

    -- With the progress bar off the wait can't be cancelled, so check the player is
    -- still at the plant (the server enforces the same range and would drop it silently).
    if completed and (IsPedDeadOrDying(ped, true)
        or #(GetEntityCoords(ped) - entry.coord) > Config.ScopeRangeGather - 0.1) then
        completed = false
        if not IsPedDeadOrDying(ped, true) then
            RSGCore.Functions.Notify({
                title = locale('gather_moved_away_title'),
                description = locale('gather_moved_away_description'),
                type = 'warning',
                duration = 4000,
            })
        end
    end

    Debug(('gather finished id=%d completed=%s suppressed=%s'):format(entry.id, tostring(completed), tostring(suppressed[entry.id])))
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
                if lastPromptId ~= entry.id then
                    lastPromptId = entry.id
                    Debug(('node in pickup range id=%d plant=%s'):format(entry.id, tostring(entry.plant)))
                end
                DisplayCompositePickupThisFrame(entry.entity)
                if IsPickupControlPressed() and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
                    and not IsPedDeadOrDying(ped, true) then
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

local uiOpen = false
local activeBuyer = nil -- coords of the buyer whose sell menu is open
local isCrafting = false
local activeCraftCam, activeDrinkProp = nil, nil -- tracked so onResourceStop can clean up mid-action

local function BuildTonicPayload(level)
    local list = {}
    for _, tonic in ipairs(Config.Tonics) do
      if HerbalistRecipeValid(tonic, RSGCore.Shared.Items) then
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
        list[#list + 1] = {
            id = tonic.id,
            category = tonic.category or 'tonic',
            label = HerbalistRecipeLabel(tonic),
            outputLabel = outputDef and outputDef.label or tonic.output.item,
            description = tonic.description and locale(tonic.description) or '',
            image = tonic.image or (outputDef and outputDef.image) or (tonic.output.item .. '.png'),
            durationMs = tonic.durationMs,
            minLevel = tonic.minLevel or 1,
            locked = level ~= nil and level < (tonic.minLevel or 1),
            outputAmount = tonic.output.amount,
            ingredients = ingredients,
        }
      end
    end
    return list
end

-- All focus changes go through here so push-to-talk keeps working while the UI is open.
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game, so block all controls except push-to-talk while focused.
CreateThread(function()
    while true do
        if uiOpen and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            local list = Config.PushToTalkControls
            if list then
                for i = 1, #list do
                    EnableControlAction(0, list[i], true)
                    EnableControlAction(1, list[i], true)
                    EnableControlAction(2, list[i], true)
                end
            end
        else
            Wait(250)
        end
    end
end)

local function CloseTonicMenu()
    if not uiOpen then return end
    uiOpen = false
    activeBuyer = nil
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function OpenTonicMenu(level)
    if uiOpen or isCrafting then return end
    level = tonumber(level)
    local tier = GetTonicTier(level)
    uiOpen = true
    applyNuiFocus(true)
    SendNUIMessage({
        action = 'open',
        tonics = BuildTonicPayload(level),
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
            requires = locale('ui_requires_level'),
            tabTonic = locale('ui_tab_tonic'),
            tabDrying = locale('ui_tab_drying'),
            tabTea = locale('ui_tab_tea'),
            quality = tier and locale('ui_quality', locale(tier.label)) or '',
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
    activeCraftCam = craftCam
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
    activeCraftCam = nil
    isCrafting = false

    TriggerServerEvent(completed and 'rsg-herbalist:server:finishCraft' or 'rsg-herbalist:server:cancelCraft')
end)

----------------------------------------------------------------------------
-- Field guide (/herbguide): data comes from the server callback, display only
----------------------------------------------------------------------------

local function OpenFieldGuide()
    if not Config.FieldGuide.Enabled or uiOpen or isCrafting then return end
    RSGCore.Functions.TriggerCallback('rsg-herbalist:server:getGuide', function(data)
        if not data or uiOpen then return end
        local entries, foundCount = {}, 0
        for _, name in ipairs(data.items or {}) do
            local def = RSGCore.Shared.Items[name]
            local count = tonumber(data.found and data.found[name]) or 0
            if count > 0 then foundCount = foundCount + 1 end
            entries[#entries + 1] = {
                label = def and def.label or name,
                image = def and def.image or (name .. '.png'),
                count = count,
            }
        end
        table.sort(entries, function(a, b) return a.label < b.label end)
        uiOpen = true
        applyNuiFocus(true)
        SendNUIMessage({
            action = 'openGuide',
            entries = entries,
            imagePath = Config.InventoryImagePath,
            locale = {
                title = locale('guide_title'),
                subtitle = locale('guide_progress', foundCount, #entries),
                close = locale('ui_close'),
                gathered = locale('guide_gathered'),
                unknown = locale('guide_unknown'),
            },
        })
    end)
end

if Config.FieldGuide.Enabled then
    RegisterCommand(Config.FieldGuide.Command, OpenFieldGuide, false)
end

----------------------------------------------------------------------------
-- Herb buyer NPC (spawned from the server's buyer list, sells via the NUI)
----------------------------------------------------------------------------

local buyers, buyerPeds = {}, {}

local function LoadPedModel(model)
    if HasModelLoaded(model) then return true end
    if not IsModelValid(model) then return false end
    RequestModel(model, false)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

local function BuildBuyerRows(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        local def = RSGCore.Shared.Items[r.name]
        local tier = r.tier and GetTonicTierByKey(r.tier)
        out[#out + 1] = {
            slot = r.slot,
            label = def and def.label or r.name,
            image = def and def.image or (r.name .. '.png'),
            tier = tier and locale(tier.label) or '',
            amount = r.amount,
            unit = r.unit,
        }
    end
    return out
end

local function OpenBuyer(i)
    local b = buyers[i]
    if not b or uiOpen or isCrafting then return end
    RSGCore.Functions.TriggerCallback('rsg-herbalist:server:getBuyerStock', function(rows)
        if not rows or uiOpen then return end
        activeBuyer = vector3(b.x, b.y, b.z)
        uiOpen = true
        applyNuiFocus(true)
        SendNUIMessage({
            action = 'openBuyer',
            rows = BuildBuyerRows(rows),
            imagePath = Config.InventoryImagePath,
            locale = {
                title = locale('buyer_title'),
                subtitle = locale('buyer_subtitle'),
                close = locale('ui_close'),
                owned = locale('buyer_owned'),
                each = locale('buyer_each'),
                sellOne = locale('buyer_sell_one'),
                sellAll = locale('buyer_sell_all'),
                empty = locale('buyer_empty'),
            },
        })
    end)
end

RegisterNetEvent('rsg-herbalist:client:BuyerStock', function(rows)
    if uiOpen and activeBuyer then
        SendNUIMessage({ action = 'buyerStock', rows = BuildBuyerRows(rows) })
    end
end)

RegisterNUICallback('sell', function(data, cb)
    if activeBuyer and type(data) == 'table' and tonumber(data.slot) and tonumber(data.amount) then
        TriggerServerEvent('rsg-herbalist:server:sell', tonumber(data.slot), tonumber(data.amount))
    end
    cb('ok')
end)

local function BuyerOptionName(i) return 'rsg_herbalist_buyer_' .. i end

local function SpawnBuyer(i)
    local b, bc = buyers[i], Config.Buyer
    if not b or buyerPeds[i] or not LoadPedModel(bc.Model) then return end
    local ped = CreatePed(bc.Model, b.x, b.y, b.z - 1.0, b.w, false, false, false, false)
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(ped) do
        if GetGameTimer() > deadline then return end
        Wait(10)
    end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = BuyerOptionName(i),
            icon = 'fa-solid fa-hand-holding-dollar',
            label = locale('buyer_target'),
            distance = bc.TargetDistance,
            onSelect = function() OpenBuyer(i) end,
        },
    })
    buyerPeds[i] = ped
end

local function DespawnBuyer(i)
    local ped = buyerPeds[i]
    if ped and DoesEntityExist(ped) then
        exports['rsg-target']:removeLocalEntity(ped, { BuyerOptionName(i) })
        DeleteEntity(ped)
    end
    buyerPeds[i] = nil
end

local function DespawnAllBuyers()
    for i in pairs(buyerPeds) do DespawnBuyer(i) end
end

RegisterNetEvent('rsg-herbalist:client:SetBuyers', function(list)
    DespawnAllBuyers()
    buyers = type(list) == 'table' and list or {}
end)

if Config.Buyer and Config.Buyer.Enabled then
    CreateThread(function()
        TriggerServerEvent('rsg-herbalist:server:requestBuyers')
        local bc = Config.Buyer
        while true do
            local pos = GetEntityCoords(PlayerPedId())
            local nearest = math.huge
            for i, b in ipairs(buyers) do
                local dist = #(pos - vector3(b.x, b.y, b.z))
                if dist < nearest then nearest = dist end
                if dist < bc.SpawnDistance and not buyerPeds[i] then
                    SpawnBuyer(i)
                elseif dist >= bc.SpawnDistance and buyerPeds[i] then
                    DespawnBuyer(i)
                end
            end
            if not next(buyerPeds) and HasModelLoaded(bc.Model) then SetModelAsNoLongerNeeded(bc.Model) end
            if activeBuyer and #(pos - activeBuyer) > bc.MaxUseDistance then CloseTonicMenu() end
            Wait(nearest > bc.SpawnDistance * 3 and 3000 or 1000)
        end
    end)
end

----------------------------------------------------------------------------
-- Tonic consumption
----------------------------------------------------------------------------

RegisterNetEvent('rsg-herbalist:client:ApplyTonicEffect', function(itemName, boost)
    local effect = Config.TonicEffects[itemName]
    if not effect then return end
    boost = tonumber(boost) or 1.0

    local ped = PlayerPedId()
    local attr = Config.TonicAttributeIndex or {}
    local drinkAnim = Config.TonicDrinkAnim

    if drinkAnim and drinkAnim.enabled and drinkAnim.clips and #drinkAnim.clips > 0
        and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
        and RequestAnimDictWithTimeout(drinkAnim.dict, drinkAnim.animDictLoadTimeoutMs or 5000) then
        local prop = drinkAnim.prop and AttachHandProp(ped, drinkAnim.prop, drinkAnim.propBone or 'PH_R_HAND',
            drinkAnim.propOffset or {}, drinkAnim.propRotation or {})
        activeDrinkProp = prop
        for _, clip in ipairs(drinkAnim.clips) do
            TaskPlayAnim(ped, drinkAnim.dict, clip.anim, 8.0, -8.0, clip.duration or -1, 31, 0, false, false, false)
            Wait(clip.duration or 500)
        end
        ClearPedTasks(ped)
        RemoveAnimDict(drinkAnim.dict)
        DeleteHandProp(prop)
        activeDrinkProp = nil
    end

    if effect.healthBoost and attr.health then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, ped, attr.health, math.min(1.0, effect.healthBoost * boost), true)
    end
    if effect.staminaBoost and attr.stamina then
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, ped, attr.stamina, math.min(1.0, effect.staminaBoost * boost), true)
    end
    if effect.thirstBoost then
        TriggerEvent('hud:client:UpdateThirst', math.max(0, math.min(100, (LocalPlayer.state.thirst or 0) + effect.thirstBoost * boost)))
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if ResourceName ~= resourceName then return end
    for i = 1, #spawnEntries do
        UnloadEntry(spawnEntries[i])
    end
    CloseTonicMenu()
    DespawnAllBuyers()
    if activeCraftCam then DestroyCraftingCam(activeCraftCam, Config.TonicCraftCamera) end
    DeleteHandProp(activeDrinkProp)
    if isCrafting or isGathering then ClearPedTasks(PlayerPedId()) end
end)
