local RSGCore = exports['rsg-core']:GetCoreObject()

local factories = {} -- [id] = { id, name, ped_model, x, y, z, h }
local spawned = {}   -- [id] = ped
local isAdmin = false
local uiOpen, uiFocus = false, false
local currentId = nil
local opening = false

local UI_KEYS = {
    'ui_recipes', 'ui_inputs', 'ui_outputs', 'ui_time', 'ui_batches', 'ui_produce', 'ui_queue',
    'ui_collect', 'ui_ready', 'ui_no_recipes', 'ui_no_queue', 'ui_close', 'ui_admin_title',
    'ui_factory_name', 'ui_ped_model', 'ui_add_recipe', 'ui_recipe_name', 'ui_seconds',
    'ui_job_lock', 'ui_add_item', 'ui_save', 'ui_delete', 'ui_confirm_delete', 'ui_remove',
    'ui_search_item', 'ui_amount', 'ui_cancel', 'ui_confirm', 'ui_seconds_short', 'ui_next_line', 'ui_no_next', 'ui_stage',
    'ui_owner', 'ui_for_sale', 'ui_price', 'ui_buy', 'ui_buy_confirm', 'ui_not_owned', 'ui_fuel', 'ui_water',
    'ui_supplies', 'ui_add', 'ui_fuel_batch', 'ui_water_batch', 'ui_units_each', 'ui_needs', 'ui_sale_price',
    'ui_owner_stocks',
    'ui_tab_production', 'ui_tab_owner', 'ui_earnings', 'ui_withdraw', 'ui_fee', 'ui_access', 'ui_access_public', 'ui_access_trusted', 'ui_access_owner', 'ui_staffed', 'ui_paused', 'ui_on', 'ui_off', 'ui_player_search', 'ui_no_players', 'ui_online', 'ui_offline', 'ui_upgrades', 'ui_upgrade_tank', 'ui_upgrade_speed', 'ui_level', 'ui_max', 'ui_upgrade', 'ui_cost', 'ui_condition', 'ui_working', 'ui_broken', 'ui_repair', 'ui_sell', 'ui_sell_confirm', 'ui_transfer', 'ui_transfer_confirm', 'ui_apply', 'ui_settings',
    -- notification texts reused in the UI to say why production is blocked
    'no_access', 'paused', 'broken', 'not_staffed',
}

---------------------------------------------------------------------
-- NUI focus (keeps push-to-talk working)
---------------------------------------------------------------------
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

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    uiFocus = false
    currentId = nil
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function strings()
    local t = {}
    for i = 1, #UI_KEYS do t[UI_KEYS[i]] = locale(UI_KEYS[i]) end
    return t
end

---------------------------------------------------------------------
-- Opening the UI
---------------------------------------------------------------------
local function fetchFactory(id)
    return RSGCore.Functions.AwaitCallback('rsg-factory:server:getFactory', 10000, id)
end

local function openUi(id, mode)
    if uiOpen or opening then return end
    opening = true
    local data = fetchFactory(id)
    if not data then opening = false return end

    local items = nil
    if mode == 'admin' then
        if not data.isAdmin then opening = false return end
        items = RSGCore.Functions.AwaitCallback('rsg-factory:server:getItems', 10000)
        if not items then opening = false return end
    end

    currentId = id
    uiOpen = true
    uiFocus = true
    SendNUIMessage({ action = 'open', mode = mode, factory = data, items = items, strings = strings(), imagePath = Config.ImagePath })
    applyNuiFocus(true)
    opening = false
end

RegisterNetEvent('rsg-factory:client:openAdmin', function(id)
    CreateThread(function() openUi(id, 'admin') end)
end)

---------------------------------------------------------------------
-- NUI callbacks (all re-validated on the server)
---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb(true)
end)

RegisterNUICallback('refresh', function(_, cb)
    if not currentId then return cb(false) end
    cb(fetchFactory(currentId) or false)
end)

RegisterNUICallback('start', function(data, cb)
    if not currentId or type(data) ~= 'table' then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:startProduction', 10000, currentId, data.recipe, data.batches)
    cb(ok and true or false)
end)

RegisterNUICallback('collect', function(_, cb)
    if not currentId then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:collect', 10000, currentId)
    cb(ok and true or false)
end)

RegisterNUICallback('buy', function(_, cb)
    if not currentId then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:buyFactory', 10000, currentId)
    cb(ok and true or false)
end)

RegisterNUICallback('supply', function(data, cb)
    if not currentId or type(data) ~= 'table' then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:addSupply', 10000, currentId, data.key, data.amount)
    cb(ok and true or false)
end)

RegisterNUICallback('owner', function(data, cb)
    if not currentId or type(data) ~= 'table' then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:ownerAction', 10000, currentId, data.action, data.data)
    cb(ok and true or false)
end)

RegisterNUICallback('findPlayers', function(data, cb)
    if not currentId or type(data) ~= 'table' then return cb({}) end
    local list = RSGCore.Functions.AwaitCallback('rsg-factory:server:findPlayers', 5000, currentId, data.query, data.mode)
    cb(list or {})
end)

RegisterNUICallback('save', function(data, cb)
    if not currentId or type(data) ~= 'table' then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:saveFactory', 10000, currentId, data)
    cb(ok and true or false)
end)

RegisterNUICallback('delete', function(_, cb)
    if not currentId then return cb(false) end
    local ok = RSGCore.Functions.AwaitCallback('rsg-factory:server:deleteFactory', 10000, currentId)
    cb(ok and true or false)
end)

---------------------------------------------------------------------
-- Factory NPCs (spawned only when the player is near)
---------------------------------------------------------------------
local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

local function removeFactoryPed(id)
    local ped = spawned[id]
    if not ped then return end
    exports['rsg-target']:removeLocalEntity(ped)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    spawned[id] = nil
end

local function spawnFactoryPed(f)
    local hash = GetHashKey(f.ped_model)
    if not loadModel(hash) then
        hash = GetHashKey(Config.DefaultPedModel)
        if not loadModel(hash) then return end
    end

    local ped = CreatePed(hash, f.x, f.y, f.z, f.h, false, false, false, false)
    if not ped or ped == 0 then return end

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    SetEntityHeading(ped, f.h)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    local id = f.id
    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'rsg_factory_use',
            icon = 'fa-solid fa-industry',
            label = locale('target_use'),
            distance = Config.InteractDistance,
            onSelect = function() CreateThread(function() openUi(id, 'player') end) end,
        },
        {
            name = 'rsg_factory_manage',
            icon = 'fa-solid fa-gear',
            label = locale('target_manage'),
            distance = Config.InteractDistance,
            canInteract = function() return isAdmin end,
            onSelect = function() CreateThread(function() openUi(id, 'admin') end) end,
        },
    })
    spawned[id] = ped
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, f in pairs(factories) do
            local dist = #(pos - vector3(f.x, f.y, f.z))
            if dist < Config.SpawnDistance and not spawned[id] then
                spawnFactoryPed(f)
            elseif dist > Config.SpawnDistance + 10.0 and spawned[id] then
                removeFactoryPed(id)
            end
        end
        Wait(1000)
    end
end)

-- map blips: green for factories you own, default colour for ones for sale
local blips = {}

local function clearBlips()
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}
end

local function refreshBlips()
    clearBlips()
    local cfg = Config.Blips
    if not cfg.enabled then return end
    for id, f in pairs(factories) do
        if f.status == 'mine' or f.status == 'sale' or cfg.showOwnedByOthers then
            local blip = BlipAddForCoords(1664425300, f.x, f.y, f.z)
            SetBlipSprite(blip, cfg.sprite, true)
            SetBlipScale(blip, cfg.scale)
            SetBlipName(blip, f.status == 'sale' and ('%s (%s)'):format(f.name, locale('ui_for_sale')) or f.name)
            local color = (f.status == 'mine' and cfg.mineColor) or (f.status == 'sale' and cfg.saleColor) or nil
            if color then BlipAddModifier(blip, joaat(color)) end
            blips[id] = blip
        end
    end
end

local function sameSpot(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.z == b.z and a.h == b.h and a.ped_model == b.ped_model
end

-- only NPCs that actually moved, changed model or were removed are respawned
local function applyFactories(list)
    local new = {}
    for i = 1, #list do new[list[i].id] = list[i] end
    for id in pairs(spawned) do
        if not sameSpot(factories[id], new[id]) then removeFactoryPed(id) end
    end
    factories = new
    refreshBlips()
end

RegisterNetEvent('rsg-factory:client:sync', function(list)
    applyFactories(list or {})
    if uiOpen and currentId and not factories[currentId] then closeUi() end
end)

local function loadFactories()
    local res
    for _ = 1, 60 do
        res = RSGCore.Functions.AwaitCallback('rsg-factory:server:getFactories', 10000)
        if res then break end
        Wait(1000) -- server still loading
    end
    if not res then return end
    isAdmin = res.isAdmin
    applyFactories(res.factories)
end

CreateThread(loadFactories)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    CreateThread(loadFactories)
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiFocus then applyNuiFocus(false) end
    for id in pairs(spawned) do removeFactoryPed(id) end
    clearBlips()
end)
