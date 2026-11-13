local RSGCore = exports['rsg-core']:GetCoreObject()

local BLIP_STYLE = 1664425300 -- default coords blip style

local npcs = {}         -- every vendor / collector: { id, coords, npcmodel, npccoords, label, event, key, icon, blip }
local spawnedPeds = {}  -- [npc index] = ped
local spawnedCards = {} -- [card point index] = prop
local cardReadyAt = {}  -- [itemName] = GetGameTimer() value at which the card can be collected again
local blips = {}
local fadingOut = {}   -- [entity] = true while an entity fades out before it is deleted
local prompts = {}      -- rsg-core prompt names
local collecting = false
local loggedIn = false

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

-- fades an entity in or out in its own thread so the spawn loop never stalls; `after` runs when done
local function fade(entity, fadeIn, after)
    CreateThread(function()
        if Config.FadeIn then
            local from, to, step = 0, 255, 51
            if not fadeIn then from, to, step = 255, 0, -51 end
            for alpha = from, to, step do
                if not DoesEntityExist(entity) then break end
                SetEntityAlpha(entity, alpha, false)
                Wait(50)
            end
        elseif fadeIn and DoesEntityExist(entity) then
            SetEntityAlpha(entity, 255, false)
        end
        if after then after() end
    end)
end

-- fades an entity out, then deletes it (own thread, so the spawn loop never stalls)
local function fadeOutAndDelete(entity)
    fadingOut[entity] = true
    fade(entity, false, function()
        if DoesEntityExist(entity) then DeleteEntity(entity) end
        fadingOut[entity] = nil
    end)
end

local function addBlip(coords, sprite, scale, name)
    local blip = BlipAddForCoords(BLIP_STYLE, coords.x, coords.y, coords.z)
    SetBlipSprite(blip, joaat(sprite), true)
    SetBlipScale(blip, scale)
    SetBlipName(blip, name)
    blips[#blips + 1] = blip
end

local function addPrompt(name, coords, key, label, event, arg)
    exports['rsg-core']:createPrompt(name, vector3(coords.x, coords.y, coords.z), RSGCore.Shared.Keybinds[key], label, {
        type = 'client',
        event = event,
        args = { arg },
    })
    prompts[name] = true
end

local function removePrompt(name)
    if not prompts[name] then return end
    exports['rsg-core']:deletePrompt(name)
    prompts[name] = nil
end

---------------------------------------------------------------------
-- VENDORS AND COLLECTORS
---------------------------------------------------------------------
for _, location in ipairs(Config.Shop.Locations) do
    npcs[#npcs + 1] = {
        id = location.id, coords = location.coords, npcmodel = location.npcmodel, npccoords = location.npccoords,
        label = locale('vendor_title'), event = 'rsg-cards:client:openVendor', key = Config.Shop.Key,
        icon = 'fa-solid fa-store',
        blip = Config.Blip.showblipShop and { sprite = Config.Blip.ShopSprite, scale = Config.Blip.ShopScale },
    }
end

for _, location in ipairs(Config.Trades.Locations) do
    npcs[#npcs + 1] = {
        id = location.id, coords = location.coords, npcmodel = location.npcmodel, npccoords = location.npccoords,
        label = locale('trade_title'), event = 'rsg-cards:client:openTrades', key = Config.Trades.Key,
        icon = 'fa-solid fa-handshake',
        blip = Config.Blip.showblipCollect and { sprite = Config.Blip.CollectSprite, scale = Config.Blip.CollectScale },
    }
end

local function spawnNpc(index)
    local npc = npcs[index]
    local hash = loadModel(npc.npcmodel)
    if not hash then return end

    local c = npc.npccoords
    local ped = CreatePed(hash, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    spawnedPeds[index] = ped

    SetEntityAlpha(ped, 0, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    if Config.EnableTarget then
        exports['rsg-target']:addLocalEntity(ped, {
            {
                name = 'rsg-cards:npc:' .. npc.id,
                icon = npc.icon,
                label = npc.label,
                distance = 3.0,
                onSelect = function()
                    TriggerEvent(npc.event, npc.id)
                end,
            },
        })
    end

    fade(ped, true)
end

local function removeNpc(index, instant)
    local ped = spawnedPeds[index]
    if not ped then return end
    spawnedPeds[index] = nil
    if not DoesEntityExist(ped) then return end
    if Config.EnableTarget then exports['rsg-target']:removeLocalEntity(ped) end
    if instant or not Config.FadeIn then return DeleteEntity(ped) end
    fadeOutAndDelete(ped)
end

-- blips and prompts are created once
CreateThread(function()
    for _, npc in ipairs(npcs) do
        if npc.blip then addBlip(npc.coords, npc.blip.sprite, npc.blip.scale, npc.label) end
        if not Config.EnableTarget then
            addPrompt('rsg-cards:npc:' .. npc.id, npc.coords, npc.key, npc.label, npc.event, npc.id)
        end
    end

    if Config.Blip.showblipCards then
        for _, point in ipairs(Config.CardPoints) do
            addBlip(point.coords, Config.Blip.cardSprite, Config.Blip.cardScale, locale('card_blip'))
        end
    end
end)

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for index, npc in ipairs(npcs) do
            local near = #(playerCoords - npc.coords) < Config.DistanceSpawn
            if near and not spawnedPeds[index] then
                spawnNpc(index)
            elseif not near and spawnedPeds[index] then
                removeNpc(index)
            end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------
-- CARDS IN THE WORLD
---------------------------------------------------------------------
local cardCoords = {} -- [card point index] = vector3, built once so the distance loop doesn't allocate
for index, point in ipairs(Config.CardPoints) do
    cardCoords[index] = vector3(point.coords.x, point.coords.y, point.coords.z)
end

local function isCardReady(item)
    local readyAt = cardReadyAt[item]
    return not readyAt or GetGameTimer() >= readyAt
end

local function removeCard(index, instant)
    local prop = spawnedCards[index]
    if not prop then return end
    spawnedCards[index] = nil
    removePrompt('rsg-cards:card:' .. index)
    if not DoesEntityExist(prop) then return end
    if Config.EnableTarget then exports['rsg-target']:removeLocalEntity(prop) end
    if instant or not Config.FadeIn then return DeleteEntity(prop) end
    fadeOutAndDelete(prop)
end

local function collectCard(index)
    local point = Config.CardPoints[index]
    if collecting or not point or not spawnedCards[index] then return end
    collecting = true

    local done = RSGCore.Functions.ProgressBar({
        duration = Config.Card.PickupTime,
        label = locale('progress_pickup'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    })

    if done then
        local result = RSGCore.Functions.AwaitCallback('rsg-cards:server:pickupCard', 5000, index)
        if result and result.cooldown then
            cardReadyAt[point.item] = GetGameTimer() + math.floor(result.cooldown * 1000)
            removeCard(index, true)
        end
        if result and result.item then
            TriggerEvent('rsg-cards:client:revealCard', result)
        end
    end

    collecting = false
end

AddEventHandler('rsg-cards:client:takecard', function(index)
    collectCard(tonumber(index))
end)

local function spawnCard(index)
    local point = Config.CardPoints[index]
    local info = Cards.Info[point.item]
    local hash = info and loadModel(info.model)
    if not hash then return end

    local c = point.coords
    local prop = CreateObject(hash, c.x, c.y, c.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(prop) then return end
    spawnedCards[index] = prop

    SetEntityHeading(prop, c.w)
    PlaceEntityOnGroundProperly(prop, true)
    FreezeEntityPosition(prop, true)

    if Config.Card.EagleEye.enabled then
        Citizen.InvokeNative(0x543DFE14BE720027, PlayerId(), prop, true)            -- _REGISTER_EAGLE_EYE_FOR_ENTITY
        Citizen.InvokeNative(0x62ED71E133B6C9F1, prop, 255, 255, 0)                 -- EAGLE_EYE_SET_CUSTOM_ENTITY_TINT
        Citizen.InvokeNative(0x907B16B3834C69E2, prop, Config.Card.EagleEye.distance) -- _EAGLE_EYE_SET_CUSTOM_DISTANCE
    end

    if Config.EnableTarget then
        exports['rsg-target']:addLocalEntity(prop, {
            {
                name = 'rsg-cards:card:' .. index,
                icon = 'fa-solid fa-hand',
                label = locale('pickup_label'),
                distance = Config.Card.PickupDistance,
                onSelect = function()
                    collectCard(index)
                end,
            },
        })
    else
        addPrompt('rsg-cards:card:' .. index, c, Config.Card.Key, locale('pickup_label'), 'rsg-cards:client:takecard', index)
    end

    SetEntityAlpha(prop, 0, false)
    fade(prop, true)
end

local function refreshCooldowns()
    local remaining = RSGCore.Functions.AwaitCallback('rsg-cards:server:getPickups', 10000)
    cardReadyAt = {}
    for item, seconds in pairs(remaining or {}) do
        cardReadyAt[item] = GetGameTimer() + math.floor(seconds * 1000)
    end
    loggedIn = true
end

CreateThread(function()
    local lastHeartbeat = 0
    while true do
        local sleep = 1000
        if loggedIn then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local closest = math.huge

            for index, point in ipairs(Config.CardPoints) do
                local distance = #(playerCoords - cardCoords[index])
                local ready = isCardReady(point.item)
                if ready and distance < closest then closest = distance end

                if distance < Config.DistanceSpawn and ready and not spawnedCards[index] then
                    spawnCard(index)
                elseif spawnedCards[index] and (distance >= Config.DistanceSpawn or not ready) then
                    removeCard(index)
                end
            end

            -- Eagle Eye hint: a heartbeat that speeds up as the player gets closer to a card
            local eagleEye = Config.Card.EagleEye
            if eagleEye.enabled and closest < eagleEye.distance
                and Citizen.InvokeNative(0x45AB66D02B601FA7, PlayerId()) then -- _IS_SECONDARY_SPECIAL_ABILITY_ACTIVE (Eagle Eye)
                sleep = 250
                local interval = 500 + math.floor(2000 * (closest / eagleEye.distance))
                if GetGameTimer() - lastHeartbeat >= interval then
                    lastHeartbeat = GetGameTimer()
                    PlaySoundFrontend(eagleEye.soundName, eagleEye.soundRef, true, 0)
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- PLAYER LOAD / UNLOAD / RESOURCE STOP
---------------------------------------------------------------------
local function clearCards()
    for index in pairs(spawnedCards) do removeCard(index, true) end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    refreshCooldowns()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    loggedIn = false
    cardReadyAt = {}
    clearCards()
end)

-- resource (re)started while the player is already in game
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then refreshCooldowns() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearCards()
    for index in pairs(spawnedPeds) do removeNpc(index, true) end
    for entity in pairs(fadingOut) do if DoesEntityExist(entity) then DeleteEntity(entity) end end
    for name in pairs(prompts) do removePrompt(name) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
