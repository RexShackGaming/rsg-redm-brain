local RSGCore = exports['rsg-core']:GetCoreObject()

local uiMode = nil -- nil | 'pack' | 'reveal' | 'vendor' | 'trade'
local uiLocation = nil -- id of the vendor / collector the UI was opened at
local busy = false
local inspectProp = nil

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function notify(description, notifyType)
    RSGCore.Functions.Notify({ title = locale('title'), description = description, type = notifyType or 'inform', duration = 5000 })
end

local function playSound(name)
    if not Config.Sounds.enabled or not name or GetResourceState('interact-sound') ~= 'started' then return end
    TriggerServerEvent('InteractSound_SV:PlayOnSource', name, Config.Sounds.volume)
end

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

local uiStrings
local function getStrings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for _, key in ipairs({
        'pack_title', 'pack_subtitle', 'pack_hint', 'found_title', 'found_subtitle', 'new_card', 'collection_progress',
        'close', 'tier_basic', 'tier_rare', 'tier_ultra', 'tier_v', 'tier_vmax', 'tier_deck',
        'vendor_title', 'vendor_subtitle', 'vendor_empty', 'vendor_empty_boxes', 'vendor_each', 'vendor_owned', 'sell', 'sell_all', 'buy_supplies',
        'confirm_title', 'confirm_sell_all', 'confirm', 'cancel',
        'sets_title', 'sell_title', 'set_ready', 'make_set', 'set_pill',
        'trade_title', 'trade_subtitle', 'trade_empty', 'trade_button', 'trade_needs', 'trade_refresh', 'trade_completed',
    }) do
        uiStrings[key] = locale(key)
    end
    return uiStrings
end

---------------------------------------------------------------------
-- NUI FOCUS (keeps push-to-talk working while the UI is open)
---------------------------------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

CreateThread(function()
    while true do
        if uiMode and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, control in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, control, true)
                EnableControlAction(1, control, true)
                EnableControlAction(2, control, true)
            end
        else
            Wait(250)
        end
    end
end)

local function openUI(mode, data, locationId)
    uiMode = mode
    uiLocation = locationId
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', mode = mode, data = data, strings = getStrings(), imagePath = Config.ImagePath })
end

local function closeUI()
    if not uiMode then return end
    if uiMode == 'pack' then
        -- the server hands over any cards that were not turned over
        TriggerServerEvent('rsg-cards:server:closePack')
    end
    uiMode = nil
    uiLocation = nil
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

---------------------------------------------------------------------
-- CARD PACKS
---------------------------------------------------------------------
RegisterNetEvent('rsg-cards:client:openPack', function(amount)
    if uiMode then closeUI() end

    RSGCore.Functions.ProgressBar({
        duration = Config.Pack.OpenTime,
        label = locale('progress_open_pack'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, combat = true, mouse = true },
    })

    playSound(Config.Sounds.open)
    openUI('pack', { amount = tonumber(amount) or Config.Pack.Cards })
end)

RegisterNUICallback('flip', function(body, cb)
    if uiMode ~= 'pack' then return cb(false) end
    local result = RSGCore.Functions.AwaitCallback('rsg-cards:server:flipCard', 5000, tonumber(body.index))
    if result then playSound(Config.Sounds.flip) end
    cb(result or false)
end)

-- a single card found in the world (already given by the server)
AddEventHandler('rsg-cards:client:revealCard', function(card)
    if uiMode then closeUI() end
    playSound(Config.Sounds.flip)
    openUI('reveal', { card = card })
end)

---------------------------------------------------------------------
-- CARD VENDOR
---------------------------------------------------------------------
AddEventHandler('rsg-cards:client:openVendor', function(shopId)
    if uiMode or busy then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-cards:server:getVendor', 5000, shopId)
    if not data or uiMode then return end
    openUI('vendor', data, shopId)
end)

RegisterNUICallback('sell', function(body, cb)
    if uiMode ~= 'vendor' then return cb(false) end
    cb(RSGCore.Functions.AwaitCallback('rsg-cards:server:sell', 5000, uiLocation, body.name, tonumber(body.amount)) or false)
end)

RegisterNUICallback('sellAll', function(_, cb)
    if uiMode ~= 'vendor' then return cb(false) end
    cb(RSGCore.Functions.AwaitCallback('rsg-cards:server:sellAll', 5000, uiLocation) or false)
end)

RegisterNUICallback('makeSet', function(body, cb)
    if uiMode ~= 'vendor' then return cb(false) end
    cb(RSGCore.Functions.AwaitCallback('rsg-cards:server:makeSet', 5000, uiLocation, body.id) or false)
end)

RegisterNUICallback('buy', function(_, cb)
    local shopId = uiLocation
    local isVendor = uiMode == 'vendor'
    closeUI()
    if isVendor then TriggerServerEvent('rsg-cards:server:openShop', shopId) end
    cb('ok')
end)

---------------------------------------------------------------------
-- CARD COLLECTOR (trades)
---------------------------------------------------------------------
AddEventHandler('rsg-cards:client:openTrades', function(locationId)
    if uiMode or busy then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-cards:server:getTrades', 5000, locationId)
    if not data or uiMode then return end
    openUI('trade', data, locationId)
end)

RegisterNUICallback('trade', function(body, cb)
    if uiMode ~= 'trade' then return cb(false) end
    cb(RSGCore.Functions.AwaitCallback('rsg-cards:server:trade', 5000, uiLocation, body.id) or false)
end)

---------------------------------------------------------------------
-- CARD STORAGE BOX
---------------------------------------------------------------------
local watchingBox = false

-- tell the server when the inventory closes so it can check what was left in the box
RegisterNetEvent('rsg-cards:client:boxOpened', function()
    if watchingBox then return end
    watchingBox = true
    Wait(1000)
    while exports['rsg-inventory']:IsOpen() do Wait(500) end
    watchingBox = false
    TriggerServerEvent('rsg-cards:server:boxClosed')
end)

---------------------------------------------------------------------
-- INSPECT A CARD (used from the inventory)
---------------------------------------------------------------------
local function deleteInspectProp()
    if inspectProp and DoesEntityExist(inspectProp) then DeleteEntity(inspectProp) end
    inspectProp = nil
end

RegisterNetEvent('rsg-cards:client:inspectCard', function(card)
    local info = Cards.Info[card]
    if not info or info.deck or busy or uiMode then return end

    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then
        return notify(locale('inspect_dismount'), 'error')
    end

    local hash = loadModel(info.model)
    if not hash then return end

    busy = true
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local coords = GetEntityCoords(ped)
    inspectProp = CreateObject(hash, coords.x, coords.y, coords.z, false, true, false, false, true)
    SetModelAsNoLongerNeeded(hash)

    -- lets the player turn the card over
    Citizen.InvokeNative(0xCB9401F918CB0F75, ped, 'GENERIC_DOCUMENT_FLIP_AVAILABLE', true, -1) -- _SET_PED_BLACKBOARD_BOOL

    -- interaction states from rdr3_discoveries tasks/TASK_ITEM_INTERACTION
    local state = info.landscape and joaat('CIGARETTE_CARD_W10-7_H6-5_SINGLE_INTRO') or joaat('CIGARETTE_CARD_W6-5_H10-7_SINGLE_INTRO')
    TaskItemInteraction_2(ped, joaat(card), inspectProp, joaat('PrimaryItem'), state, 1, 0, -1.0)

    -- hold the card until the player puts it away or the time runs out
    local deadline = GetGameTimer() + Config.Card.InspectTime
    Wait(1500)
    while GetGameTimer() < deadline and IsPedRunningTaskItemInteraction(ped) do
        Wait(250)
    end

    if IsPedRunningTaskItemInteraction(ped) then ClearPedTasks(ped) end
    deleteInspectProp()
    busy = false
end)

---------------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeUI()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if uiMode then applyNuiFocus(false) end
    if inspectProp then
        ClearPedTasks(PlayerPedId())
        deleteInspectProp()
    end
end)
