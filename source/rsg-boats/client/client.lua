local RSGCore = exports['rsg-core']:GetCoreObject()

local Yards = {}       -- [id] = { id, name, coords = vector4, dock = { x, y, z, w, r } }
local Npcs, Blips = {}, {}
local activeBoat = nil
local uiOpen = false
local shopYard = nil   -- yard id the shop is open at
local storePrompt = nil
local storing = false
local offerCb = nil    -- pending transfer offer answer
placingBoat = false    -- set by placer.lua
local OpenShop, OpenAdmin -- defined below, used by the NPC target / placer

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
function BoatsLoadModel(model, timeout)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return nil end
        Wait(10)
    end
    return hash
end

-- all locale strings for the NUI (ui_* keys), sent with every open so the UI follows the server language
function BoatsUiLocales()
    local ui = {}
    for k, v in pairs(locale() or {}) do
        if k:sub(1, 3) == 'ui_' then ui[k] = v end
    end
    return ui
end

local function setUi(state, payload)
    uiOpen = state
    SetNuiFocus(state, state)
    if payload then SendNUIMessage(payload) end
    if not state then SendNUIMessage({ action = 'close' }) end
end

function BoatsNotify(msg, ntype)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = msg, type = ntype or 'inform', duration = 5000 })
end
local notify = BoatsNotify

local function await(name, ...)
    return RSGCore.Functions.AwaitCallback(name, nil, ...)
end

---------------------------------------------------------------------
-- yard NPCs + blips
---------------------------------------------------------------------
local function removeNpc(id)
    local npc = Npcs[id]
    if npc and DoesEntityExist(npc) then
        exports['rsg-target']:removeLocalEntity(npc, 'rsg_boats_shop')
        DeleteEntity(npc)
    end
    Npcs[id] = nil
end

local function spawnNpc(y)
    if Npcs[y.id] and DoesEntityExist(Npcs[y.id]) then return end
    local c = y.coords
    local hash = BoatsLoadModel(Config.Yard.npcModel)
    if not hash then return end
    local npc = CreatePed(hash, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetRandomOutfitVariation(npc, true)
    SetEntityCanBeDamaged(npc, false)
    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetModelAsNoLongerNeeded(hash)
    Npcs[y.id] = npc

    exports['rsg-target']:addLocalEntity(npc, {
        {
            name = 'rsg_boats_shop',
            label = locale('target_label'),
            icon = 'fa-solid fa-anchor',
            distance = Config.Yard.targetDistance,
            onSelect = function() OpenShop(y.id) end,
        }
    })
end

local function clearYards()
    for id in pairs(Npcs) do removeNpc(id) end
    for _, b in pairs(Blips) do RemoveBlip(b) end
    Blips = {}
end

local function setYards(list)
    clearYards()
    Yards = {}
    for _, y in ipairs(list or {}) do
        y.coords = vector4(y.coords.x, y.coords.y, y.coords.z, y.coords.w or 0.0)
        Yards[y.id] = y
        if Config.Yard.blip.enabled then
            local b = BlipAddForCoords(Config.Yard.blip.style, y.coords.x, y.coords.y, y.coords.z)
            SetBlipSprite(b, Config.Yard.blip.sprite, true)
            SetBlipScale(b, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, b, y.name) -- _SET_BLIP_NAME
            Blips[y.id] = b
        end
    end
end

RegisterNetEvent('rsg-boats:client:yards', setYards)

CreateThread(function()
    setYards(await('rsg-boats:server:getYards'))
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        local nearest = math.huge
        for id, y in pairs(Yards) do
            local dist = #(pc - y.coords.xyz)
            if dist < nearest then nearest = dist end
            if dist < Config.Yard.npcSpawnDistance then spawnNpc(y) else removeNpc(id) end
        end
        Wait(nearest < Config.Yard.npcSpawnDistance + 40.0 and 1000 or 3000)
    end
end)

---------------------------------------------------------------------
-- shop
---------------------------------------------------------------------
OpenShop = function(yardId)
    if uiOpen then return end
    local data = await('rsg-boats:server:getShopData', yardId)
    if not data then return end
    shopYard = yardId
    data.hasActive = data.hasActive or (activeBoat ~= nil and DoesEntityExist(activeBoat))
    setUi(true, { action = 'openShop', data = data, title = locale('shop_title'), subtitle = data.name, locales = BoatsUiLocales() })
end

local function refreshShop()
    local data = await('rsg-boats:server:getShopData', shopYard)
    if data then SendNUIMessage({ action = 'updateShop', data = data }) end
end

local function launchBoat(info)
    local hash = BoatsLoadModel(info.model)
    if not hash then
        TriggerServerEvent('rsg-boats:server:launchFailed')
        return notify(locale('spawn_failed'), 'error')
    end
    local s = info.spawn
    local veh = CreateVehicle(hash, s.x, s.y, s.z, s.w, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then
        TriggerServerEvent('rsg-boats:server:launchFailed')
        return notify(locale('spawn_failed'), 'error')
    end
    SetEntityAsMissionEntity(veh, true, true)
    activeBoat = veh
    if Config.Storage.enabled then
        exports['rsg-target']:addLocalEntity(veh, {
            {
                name = 'rsg_boats_storage',
                label = locale('storage_target'),
                icon = 'fa-solid fa-box-open',
                distance = Config.Storage.distance,
                onSelect = function()
                    if DoesEntityExist(veh) then
                        await('rsg-boats:server:openStorage', NetworkGetNetworkIdFromEntity(veh))
                    end
                end,
            }
        })
    end
    -- wait until the boat is registered on the network, otherwise the netId is 0
    local t = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < t do
        NetworkRegisterEntityAsNetworked(veh)
        Wait(10)
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdExistsOnAllMachines(netId, true)
    TriggerServerEvent('rsg-boats:server:launched', netId)
    if Config.Debug then print(('[rsg-boats] launched boat entity %s netId %s'):format(veh, netId)) end
    if Config.WarpIntoBoat then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
    notify(locale('launched', info.label), 'success')
end

---------------------------------------------------------------------
-- dock store prompt (works at every yard's dock)
---------------------------------------------------------------------
local function createStorePrompt()
    if storePrompt then return end
    storePrompt = PromptRegisterBegin()
    PromptSetControlAction(storePrompt, Config.Dock.promptKey)
    PromptSetText(storePrompt, CreateVarString(10, 'LITERAL_STRING', locale('prompt_store')))
    PromptSetEnabled(storePrompt, false)
    PromptSetVisible(storePrompt, false)
    PromptSetHoldMode(storePrompt, Config.Dock.holdTime)
    -- ePromptPriority (data/rdr3-native-enums)
    Citizen.InvokeNative(0xCA24F528D0D16289, storePrompt, 2) -- _UI_PROMPT_SET_PRIORITY: PP_High
    PromptRegisterEnd(storePrompt)
end

local promptShown = false
local function showStorePrompt(state)
    if promptShown == state or not storePrompt then return end
    promptShown = state
    PromptSetEnabled(storePrompt, state)
    PromptSetVisible(storePrompt, state)
end

local function returnToDock(d)
    if not d or not d.x then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
    SetEntityCoords(ped, d.x, d.y, d.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, d.w or 0.0)
    Wait(500)
end

-- after a successful store: remove the target option and, if the server couldn't delete
-- the boat (e.g. it was never linked to a net id), delete our own copy so nothing is left floating
local function clearActiveBoat()
    if activeBoat and DoesEntityExist(activeBoat) then
        exports['rsg-target']:removeLocalEntity(activeBoat, 'rsg_boats_storage')
        SetEntityAsMissionEntity(activeBoat, true, true)
        DeleteEntity(activeBoat)
    end
    activeBoat = nil
end

local function storeAtDock(yardId)
    if storing then return end
    storing = true
    -- fade first so the player never sees themselves drop into the water when the boat is removed
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    local result = await('rsg-boats:server:store', yardId, true)
    if result then
        clearActiveBoat()
        returnToDock(result)
    end
    DoScreenFadeIn(500)
    storing = false
end

CreateThread(function()
    createStorePrompt()
    local lastDebug = 0
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local boat = activeBoat and DoesEntityExist(activeBoat) and activeBoat or nil

        local showing = false
        if boat then
            local bc = GetEntityCoords(boat)
            for id, y in pairs(Yards) do
                local d = y.dock
                local dist = #(vector2(bc.x, bc.y) - vector2(d.x, d.y)) -- 2D: water is lower than the dock
                if dist < Config.Dock.markerRange then
                    sleep = 0
                    if Config.Dock.showMarker then
                        -- 0x94FDAE17 = cylinder marker (femga markers)
                        Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, d.x, d.y, bc.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            d.r * 2.0, d.r * 2.0, 1.5, 255, 255, 255, 50, false, false, 2, false, nil, nil, false)
                    end
                    if Config.Debug and GetGameTimer() - lastDebug > 2000 then
                        lastDebug = GetGameTimer()
                        print(('[rsg-boats] yard %s dist %.1f / r %.1f | inBoat %s'):format(id, dist, d.r, tostring(veh == boat)))
                    end
                    if not showing and dist <= d.r and veh == boat and not storing then
                        showing = true
                        showStorePrompt(true)
                        if PromptHasHoldModeCompleted(storePrompt) then
                            showStorePrompt(false)
                            storeAtDock(id)
                            Wait(500)
                            break
                        end
                    end
                end
            end
        elseif activeBoat then
            -- boat sank or despawned: forget it (the shop's Store button clears it on the server)
            exports['rsg-target']:removeLocalEntity(activeBoat, 'rsg_boats_storage')
            activeBoat = nil
        end
        if not showing then showStorePrompt(false) end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- show boat storage in the inventory's right panel while sitting in your boat
---------------------------------------------------------------------
RegisterNetEvent('rsg-inventory:client:open', function(_, other)
    if not Config.Storage.enabled or not Config.Storage.showInBoat then return end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if Config.Debug then
        print(('[rsg-boats] inventory open | other %s | activeBoat %s | in vehicle %s'):format(
            other and other.id or 'nil', tostring(activeBoat), tostring(veh)))
    end
    if other and other.id ~= 'newdrop' then return end -- already showing a stash/drop (incl. ours)
    if veh == 0 or not IsThisModelABoat(GetEntityModel(veh)) then return end
    -- server checks this is really the player's launched boat
    TriggerServerEvent('rsg-boats:server:inBoatInventory', NetworkGetNetworkIdFromEntity(veh))
end)

---------------------------------------------------------------------
-- shop NUI
---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    if offerCb then answerOffer(false) end
    setUi(false)
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    local ok = await('rsg-boats:server:buy', shopYard, data.model)
    cb(ok and true or false)
    if ok then refreshShop() end
end)

RegisterNUICallback('launch', function(data, cb)
    local info = await('rsg-boats:server:launch', shopYard, data.id)
    cb(info and true or false)
    if info then
        setUi(false)
        launchBoat(info)
    end
end)

RegisterNUICallback('store', function(_, cb)
    local ok = await('rsg-boats:server:store', shopYard, false)
    if ok then clearActiveBoat() end
    cb(ok and true or false)
    if ok then refreshShop() end
end)

RegisterNUICallback('transfer', function(data, cb)
    local ok = RSGCore.Functions.AwaitCallback('rsg-boats:server:transfer', (Config.Transfer.acceptTimeout + 10) * 1000, shopYard, data.id, data.target)
    cb(ok and true or false)
    if ok then refreshShop() end
end)

-- someone offers us a boat: answered in our own NUI (no ox_lib dialog)
local function answerOffer(accepted)
    if not offerCb then return end
    local cb = offerCb
    offerCb = nil
    SendNUIMessage({ action = 'offerClose' })
    if not uiOpen then SetNuiFocus(false, false) end
    cb(accepted == true)
end

RSGCore.Functions.CreateClientCallback('rsg-boats:client:transferOffer', function(cb, fromName, label, yardName)
    if offerCb or placingBoat then return cb(false) end
    offerCb = cb
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'offer', locales = BoatsUiLocales(),
        title = locale('transfer_offer_title'),
        text = locale('transfer_offer_text', fromName, label, yardName),
        accept = locale('transfer_accept'), decline = locale('transfer_decline'),
        timeout = Config.Transfer.acceptTimeout,
    })
    local mine = cb
    SetTimeout(Config.Transfer.acceptTimeout * 1000, function()
        if offerCb == mine then answerOffer(false) end
    end)
end)

RegisterNUICallback('offerAnswer', function(data, cb)
    cb('ok')
    answerOffer(data.accepted == true)
end)

RegisterNUICallback('sell', function(data, cb)
    local ok = await('rsg-boats:server:sell', shopYard, data.id)
    cb(ok and true or false)
    if ok then refreshShop() end
end)

---------------------------------------------------------------------
-- admin panel
---------------------------------------------------------------------
OpenAdmin = function()
    local data = await('rsg-boats:server:getAdminData')
    if not data then return notify(locale('no_permission'), 'error') end
    setUi(true, { action = 'openAdmin', data = data, locales = BoatsUiLocales() })
end

RegisterNetEvent('rsg-boats:client:openAdmin', OpenAdmin)

RegisterNUICallback('adminSave', function(data, cb)
    -- validate the model exists in the game files and is a vehicle before saving
    local model = type(data.model) == 'string' and data.model or ''
    local hash = joaat(model)
    if model == '' or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        notify(locale('admin_bad_model', model), 'error')
        return cb(false)
    end
    cb(await('rsg-boats:server:saveModel', data) or false)
end)

RegisterNUICallback('adminDelete', function(data, cb)
    cb(await('rsg-boats:server:deleteModel', data.model) or false)
end)

RegisterNUICallback('yardCreate', function(data, cb)
    cb(await('rsg-boats:server:createYard', data.name) or false)
end)

RegisterNUICallback('yardRename', function(data, cb)
    cb(await('rsg-boats:server:renameYard', data.id, data.name) or false)
end)

RegisterNUICallback('yardMove', function(data, cb)
    cb(await('rsg-boats:server:moveYard', data.id) or false)
end)

RegisterNUICallback('yardModels', function(data, cb)
    cb(await('rsg-boats:server:setYardModels', data.id, data.all == true, data.models) or false)
end)

RegisterNUICallback('yardDelete', function(data, cb)
    cb(await('rsg-boats:server:deleteYard', data.id) or false)
end)

RegisterNUICallback('adminDock', function(data, cb)
    cb(await('rsg-boats:server:saveDock', false,
        { yard = data.id, r = tonumber(data.r), usePed = data.usePed == true }) or false)
end)

RegisterNUICallback('adminPlace', function(data, cb)
    cb('ok')
    setUi(false)
    StartBoatPlacer(data.model or 'rowboat', data.id)
end)

-- called by placer.lua when finished
function BoatsReopenAdmin() OpenAdmin() end

---------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearYards()
    if activeBoat and DoesEntityExist(activeBoat) then DeleteEntity(activeBoat) end
    if storePrompt then PromptDelete(storePrompt) end
    if uiOpen or offerCb then SetNuiFocus(false, false) end
end)
