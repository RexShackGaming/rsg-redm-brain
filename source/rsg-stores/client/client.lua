local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local SELL_PCT = Config.SellPricePercentage or 0.80
local FEE_PCT  = math.floor((1 - SELL_PCT) * 100 + 0.5)
local CLOSE_DIST = (Config.TargetDistance or 2.5) + 2.0

local customBlips, activeBlips = {}, {}   -- activeBlips keyed by blip DB id
local savedNpcs = {}
local spawnedNpcs = {}                    -- npcId -> ped
local spawning = {}                       -- npcId -> true while loading/spawned
local refreshVersion = 0

local currentShop = nil                   -- npc table of the open shop
local uiStringsCache = nil

-- ============================================
-- HELPERS
-- ============================================
local function itemMeta(name)
    local info = RSGCore.Shared.Items[name]
    return info and info.label, info and info.description or '', info and info.image or (name .. '.png'),
        info and (info.category or info.type) or 'misc' -- category from shared items (falls back to type)
end

-- Translate config option lists (labels are locale keys)
local function localizedOptions(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = { label = locale(v.label), value = v.value } end
    return out
end

local function formatShopItems(items)
    local out = {}
    for _, item in ipairs(items or {}) do
        local label, desc, image, category = itemMeta(item.name)
        out[#out + 1] = {
            name = item.name, label = item.label or label or item.name,
            price = item.price, amount = item.amount, description = desc, image = image, category = category,
        }
    end
    return out
end

local function GetPlayerItems()
    local items, data = {}, RSGCore.Functions.GetPlayerData()
    for _, item in pairs(data and data.items or {}) do
        if item and item.amount and item.amount > 0 then
            local label, desc, image, category = itemMeta(item.name)
            items[#items + 1] = { name = item.name, label = label or item.name, amount = item.amount, description = desc, image = image, category = category }
        end
    end
    return items
end

local function GetPlayerMoney()
    local data = RSGCore.Functions.GetPlayerData()
    return data and data.money and data.money.cash or 0
end

-- ui_* and cl_* strings for the NUI (en merged under the active locale). Cached after first build.
local function GetUiStrings()
    if uiStringsCache then return uiStringsCache.code, uiStringsCache.strings end
    local code = GetConvar('ox:locale', 'en')
    local function load(lang)
        local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
        local ok, decoded = pcall(json.decode, raw or '')
        return ok and type(decoded) == 'table' and decoded or {}
    end
    local merged = load('en')
    if code ~= 'en' then for k, v in pairs(load(code)) do merged[k] = v end end
    local out = {}
    for k, v in pairs(merged) do
        if type(v) == 'string' and (k:sub(1, 3) == 'ui_' or k:sub(1, 3) == 'cl_') then out[k] = v end
    end
    uiStringsCache = { code = code, strings = out }
    return code, out
end

-- Ground height under a point. Player/entity coords sit ~1m above the feet,
-- so we probe from slightly above and fall back to z - 1.0 if no ground is found.
local function groundZ(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if found and math.abs(gz - z) <= 3.0 then return gz end
    return z - 1.0
end

local function pushPlayerState()
    SendNUIMessage({ action = 'updateMoney', money = GetPlayerMoney() })
    SendNUIMessage({ action = 'updatePlayerItems', items = GetPlayerItems() })
end

-- ============================================
-- SHOP OPEN / CLOSE
-- ============================================
local function CloseCustomShop()
    if not currentShop then return end
    currentShop = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeShop' })
end

local function OpenCustomShop(npcData)
    if currentShop or not npcData.shop then return end
    currentShop = npcData
    SetNuiFocus(true, true)

    local code, strings = GetUiStrings()
    SendNUIMessage({
        action         = 'openShop',
        shopName       = npcData.shop.name,
        shopLabel      = npcData.shop.label,
        shopType       = npcData.shop.type,
        items          = formatShopItems(npcData.shop.items),
        playerItems    = GetPlayerItems(),
        playerMoney    = GetPlayerMoney(),
        sellPercentage = SELL_PCT,
        feePercent     = FEE_PCT,
        maxStock       = (Config.SellAddsStock ~= false) and (tonumber(Config.MaxShopStock) or 0) or 0,
        locale         = code,
        uiStrings      = strings,
    })
    -- cached stock may be stale: ask server for live numbers
    TriggerServerEvent('rsg-stores:server:requestShopStock', npcData.id)

    -- auto-close if the player walks off or dies
    CreateThread(function()
        local shopCoords = vector3(npcData.x, npcData.y, npcData.z)
        while currentShop == npcData do
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - shopCoords) > CLOSE_DIST then
                CloseCustomShop()
                break
            end
            Wait(500)
        end
    end)
end

-- ============================================
-- NUI CALLBACKS (shop identity always comes from Lua, never from NUI)
-- ============================================
RegisterNUICallback('closeShop', function(_, cb)
    CloseCustomShop()
    cb('ok')
end)

RegisterNUICallback('notify', function(data, cb)
    lib.notify({ title = data.title or '', description = data.description or '', type = data.type or 'inform', duration = 5000 })
    cb('ok')
end)

RegisterNUICallback('processTransaction', function(data, cb)
    cb('ok')
    if not currentShop or not data or data.mode ~= 'sell' then return end
    TriggerServerEvent('rsg-stores:server:sellItem', currentShop.id, data.itemName, tonumber(data.quantity))
end)

RegisterNUICallback('purchaseCart', function(data, cb)
    cb('ok')
    if not currentShop or not data or type(data.items) ~= 'table' or #data.items == 0 then return end
    TriggerServerEvent('rsg-stores:server:purchaseCart', currentShop.id, data.items)
end)

RegisterNUICallback('refreshShop', function(_, cb)
    cb('ok')
    if not currentShop then return end
    pushPlayerState()
    TriggerServerEvent('rsg-stores:server:requestShopStock', currentShop.id)
end)

-- ============================================
-- SERVER RESPONSES
-- ============================================
RegisterNetEvent('rsg-stores:client:transactionResult', function(success, message, newMoney, updatedShopItems)
    if not currentShop then return end
    SendNUIMessage({
        action             = 'transactionResult',
        success            = success,
        message            = message,
        newMoney           = newMoney,
        updatedPlayerItems = GetPlayerItems(),
        updatedShopItems   = updatedShopItems and formatShopItems(updatedShopItems) or nil,
    })
end)

RegisterNetEvent('rsg-stores:client:purchaseSuccess', function(message, newMoney, updatedShopItems)
    if not currentShop then return end
    SendNUIMessage({ action = 'updateMoney', money = newMoney or GetPlayerMoney() })
    SendNUIMessage({ action = 'updatePlayerItems', items = GetPlayerItems() })
    if updatedShopItems then SendNUIMessage({ action = 'updateItems', items = formatShopItems(updatedShopItems) }) end
    SendNUIMessage({ action = 'purchaseSuccess', message = message })
end)

RegisterNetEvent('rsg-stores:client:purchaseFailed', function(message, newMoney)
    if not currentShop then return end
    SendNUIMessage({ action = 'updateMoney', money = newMoney or GetPlayerMoney() })
    SendNUIMessage({ action = 'purchaseFailed', message = message })
end)

RegisterNetEvent('rsg-stores:client:shopStock', function(shopItems)
    if not currentShop or not shopItems then return end
    SendNUIMessage({ action = 'updateItems', items = formatShopItems(shopItems) })
end)

-- Trailing debounce: the last change within the window is always pushed.
local pendingSync = false
RegisterNetEvent('RSGCore:Player:SetPlayerData', function()
    if not currentShop or pendingSync then return end
    pendingSync = true
    SetTimeout(300, function()
        pendingSync = false
        if currentShop then pushPlayerState() end
    end)
end)

-- ============================================
-- NPC SPAWN / DESPAWN
-- ============================================
local function removeTarget(ped)
    pcall(function() exports.ox_target:removeLocalEntity(ped) end)
end

local function DespawnNPC(npcId, instant)
    local ped = spawnedNpcs[npcId]
    spawnedNpcs[npcId], spawning[npcId] = nil, nil
    if not ped or not DoesEntityExist(ped) then return end
    removeTarget(ped)
    if instant or not Config.FadeIn then
        DeleteEntity(ped)
        return
    end
    CreateThread(function() -- fade without blocking the distance loop
        for a = 204, 0, -51 do
            if not DoesEntityExist(ped) then return end
            SetEntityAlpha(ped, a, false)
            Wait(50)
        end
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end)
end

local function SpawnNPC(npcData)
    local id, version = npcData.id, refreshVersion
    if spawning[id] then return end
    spawning[id] = true

    local model = joaat(npcData.model)
    if not IsModelValid(model) then
        print(('[rsg-stores] invalid model for NPC %s: %s'):format(id, npcData.model))
        return -- leave spawning[id] set so we don't retry every tick
    end
    if not pcall(lib.requestModel, model, 5000) then spawning[id] = nil return end -- throws on timeout
    if version ~= refreshVersion then SetModelAsNoLongerNeeded(model) spawning[id] = nil return end

    -- Snap to ground (also fixes NPCs saved before feet-level coords were stored)
    local found, gz = GetGroundZFor_3dCoord(npcData.x, npcData.y, npcData.z + 1.0, false)
    local z = (found and math.abs(gz - npcData.z) <= 3.0) and gz or npcData.z
    local ped = CreatePed(model, npcData.x, npcData.y, z, npcData.h, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then spawning[id] = nil return end
    Citizen.InvokeNative(0x9587913B9E772D29, ped, true) -- PlaceEntityOnGroundProperly

    if Config.FadeIn then SetEntityAlpha(ped, 0, false) end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, joaat(Config.DefaultScenario), 0, true)
    spawnedNpcs[id] = ped

    if npcData.shop then
        pcall(function()
            exports.ox_target:addLocalEntity(ped, {{
                name     = 'rsg_shop_' .. id,
                icon     = 'fa-solid fa-shopping-cart',
                label    = locale('cl_trade_with'):format(npcData.shop.label),
                distance = Config.TargetDistance,
                onSelect = function() OpenCustomShop(npcData) end,
            }})
        end)
    end

    if Config.FadeIn then
        CreateThread(function()
            for a = 51, 255, 51 do
                Wait(50)
                if not DoesEntityExist(ped) then return end
                SetEntityAlpha(ped, a, false)
            end
            ResetEntityAlpha(ped)
        end)
    end
end

local function RemoveAllNPCs()
    for id in pairs(spawnedNpcs) do DespawnNPC(id, true) end
    spawning = {}
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for _, npc in ipairs(savedNpcs) do
            local near = #(coords - vector3(npc.x, npc.y, npc.z)) < Config.DistanceSpawn
            if near and not spawning[npc.id] then
                SpawnNPC(npc)
            elseif not near and spawning[npc.id] then
                DespawnNPC(npc.id)
            end
        end
        Wait(1000)
    end
end)


-- ============================================
-- ADMIN PANEL STATE
-- ============================================
local adminOpen = false
local hiddenBlips = {}      -- blipId -> true (local-only visibility toggle)
local itemCatalog = nil     -- cached shared item list for the NUI picker

local function hiddenList()
    local out = {}
    for id in pairs(hiddenBlips) do out[#out + 1] = id end
    return out
end

local function pushAdminData()
    if not adminOpen then return end
    SendNUIMessage({ action = 'adminData', npcs = savedNpcs, blips = customBlips, hidden = hiddenList() })
end

RegisterNetEvent('rsg-blipmenu:client:refreshNPCs', function(npcs)
    refreshVersion = refreshVersion + 1
    if currentShop then CloseCustomShop() end
    RemoveAllNPCs()
    savedNpcs = npcs or {}
    pushAdminData()
end)

-- ============================================
-- BLIPS
-- ============================================
local function createBlip(data)
    local blip = N_0x554d9d53f696d002(1664425300, data.x, data.y, data.z)
    SetBlipSprite(blip, data.sprite, true)
    SetBlipScale(blip, 0.2)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, data.name) -- SetBlipName
    if data.color then BlipAddModifier(blip, joaat(data.color)) end
    return blip
end

local function clearBlips()
    for _, blip in pairs(activeBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    activeBlips = {}
end

RegisterNetEvent('rsg-blipmenu:client:refreshBlips', function(blips)
    clearBlips()
    customBlips = blips or {}
    for _, data in ipairs(customBlips) do
        if not hiddenBlips[data.id] then activeBlips[data.id] = createBlip(data) end
    end
    pushAdminData()
end)

-- ============================================
-- ADMIN PANEL (NUI)
-- ============================================
local function findNpcById(id)
    for _, npc in ipairs(savedNpcs) do
        if npc.id == id then return npc end
    end
end

local function findBlip(id)
    for _, b in ipairs(customBlips) do
        if b.id == id then return b end
    end
end

local function findBlipByNpcId(npcId)
    for _, b in ipairs(customBlips) do
        if b.associatedNpcId == npcId then return b end
    end
end

local function adminNotify(title, desc, nType)
    lib.notify({ title = title, description = desc, type = nType or 'success', duration = 5000 })
end

local function myPosition()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = groundZ(c.x, c.y, c.z), h = GetEntityHeading(ped) }
end

local function getItemCatalog()
    if itemCatalog then return itemCatalog end
    itemCatalog = {}
    for name, data in pairs(RSGCore.Shared.Items) do
        itemCatalog[#itemCatalog + 1] = { name = name, label = data.label or name, image = data.image or (name .. '.png') }
    end
    table.sort(itemCatalog, function(a, b) return a.label < b.label end)
    return itemCatalog
end

local function CloseAdmin()
    if not adminOpen then return end
    adminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAdmin' })
end

-- Server presets -> NUI options ({ id, label, value }); seeded labels are locale keys.
local function presetOptions(list)
    local out = {}
    for i, p in ipairs(list or {}) do out[i] = { id = p.id, label = locale(p.label), value = p.value } end
    return out
end

local function presetPayload(presets)
    return { models = presetOptions(presets.model), blipTypes = presetOptions(presets.blip) }
end

local function OpenAdmin()
    if adminOpen or currentShop then return end
    local presets = lib.callback.await('rsg-stores:server:getPresets', false)
        or { model = Config.NpcModels, blip = Config.BlipTypes }
    local opts = presetPayload(presets)
    adminOpen = true
    SetNuiFocus(true, true)
    local code, strings = GetUiStrings()
    SendNUIMessage({
        action    = 'openAdmin',
        npcs      = savedNpcs,
        blips     = customBlips,
        hidden    = hiddenList(),
        items     = getItemCatalog(),
        models    = opts.models,
        blipTypes = opts.blipTypes,
        colors    = localizedOptions(Config.BlipColors),
        locale    = code,
        uiStrings = strings,
    })
end

RegisterCommand('npcshops', function()
    if not lib.callback.await('rsg-blipmenu:server:hasAdminPerm', false) then
        return adminNotify(locale('t_access_denied'), locale('cl_access_denied'), 'error')
    end
    OpenAdmin()
end, false)

RegisterNUICallback('adminClose', function(_, cb)
    CloseAdmin()
    cb('ok')
end)

RegisterNUICallback('adminGetPosition', function(_, cb)
    cb(myPosition())
end)

-- Create or update an NPC (optionally creating a linked blip for new shops).
RegisterNUICallback('adminSaveNpc', function(data, cb)
    if not adminOpen or type(data) ~= 'table' or type(data.npc) ~= 'table' then return cb({ ok = false }) end
    local npc, id = data.npc, tonumber(data.id)

    if id then
        TriggerServerEvent('rsg-blipmenu:server:updateNPC', id, npc) -- server also moves linked blips
        adminNotify(locale('t_updated'), locale('cl_updated'):format(npc.name or ''))
        return cb({ ok = true, id = id })
    end

    local newId = lib.callback.await('rsg-blipmenu:server:saveNPC', false, npc)
    if not newId then
        adminNotify(locale('t_error'), locale('sv_update_fail'), 'error')
        return cb({ ok = false })
    end
    if type(data.blip) == 'table' and npc.shop then
        TriggerServerEvent('rsg-blipmenu:server:saveBlip', {
            name = data.blip.name ~= '' and data.blip.name or npc.shop.label,
            sprite = tonumber(data.blip.sprite), color = data.blip.color,
            x = npc.x, y = npc.y, z = npc.z, associatedNpcId = newId,
        })
    end
    adminNotify(locale('t_npc_saved'), locale('cl_npc_saved'):format(npc.name or ''))
    cb({ ok = true, id = newId })
end)

RegisterNUICallback('adminDeleteNpc', function(data, cb)
    cb('ok')
    local npc = adminOpen and findNpcById(tonumber(data and data.id))
    if not npc then return end
    TriggerServerEvent('rsg-blipmenu:server:deleteNPC', npc.id) -- server removes linked blips too
    adminNotify(locale('t_deleted'), locale('cl_npc_deleted'):format(npc.name or npc.model), 'error')
end)

RegisterNUICallback('adminDuplicateNpc', function(data, cb)
    local src = adminOpen and findNpcById(tonumber(data and data.id))
    if not src then return cb({ ok = false }) end
    local copy = lib.table.deepclone(src)
    local pos = myPosition()
    copy.id, copy.x, copy.y, copy.z, copy.h = nil, pos.x, pos.y, pos.z, pos.h
    local newId = lib.callback.await('rsg-blipmenu:server:saveNPC', false, copy)
    if not newId then return cb({ ok = false }) end
    local blip = findBlipByNpcId(src.id)
    if blip then
        TriggerServerEvent('rsg-blipmenu:server:saveBlip', {
            name = blip.name, sprite = blip.sprite, color = blip.color,
            x = copy.x, y = copy.y, z = copy.z, associatedNpcId = newId,
        })
    end
    adminNotify(locale('t_duplicated'), locale('cl_npc_duplicated'):format(src.name or src.model))
    cb({ ok = true, id = newId })
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    cb('ok')
    local x, y, z = tonumber(data and data.x), tonumber(data and data.y), tonumber(data and data.z)
    if not adminOpen or not x or not y or not z then return end
    SetEntityCoords(PlayerPedId(), x, y, z, false, false, false, false)
    adminNotify(locale('t_teleported'), locale('cl_teleported'):format(data.label or ''))
end)

RegisterNUICallback('adminSaveBlip', function(data, cb)
    cb('ok')
    if not adminOpen or type(data) ~= 'table' or type(data.blip) ~= 'table' then return end
    local id = tonumber(data.id)
    if id then
        TriggerServerEvent('rsg-blipmenu:server:updateBlip', id, data.blip)
        adminNotify(locale('t_updated'), locale('cl_updated'):format(data.blip.name or ''))
    else
        TriggerServerEvent('rsg-blipmenu:server:saveBlip', data.blip)
        adminNotify(locale('t_blip_created'), locale('cl_blip_added'):format(data.blip.name or ''))
    end
end)

RegisterNUICallback('adminDeleteBlip', function(data, cb)
    cb('ok')
    local blip = adminOpen and findBlip(tonumber(data and data.id))
    if not blip then return end
    hiddenBlips[blip.id] = nil
    TriggerServerEvent('rsg-blipmenu:server:deleteBlip', blip.id)
    adminNotify(locale('t_deleted'), locale('cl_blip_deleted'):format(blip.name), 'error')
end)

RegisterNUICallback('adminDuplicateBlip', function(data, cb)
    cb('ok')
    local blip = adminOpen and findBlip(tonumber(data and data.id))
    if not blip then return end
    local pos = myPosition()
    TriggerServerEvent('rsg-blipmenu:server:saveBlip', { name = blip.name, sprite = blip.sprite, color = blip.color, x = pos.x, y = pos.y, z = pos.z })
    adminNotify(locale('t_duplicated'), locale('cl_blip_duplicated'):format(blip.name))
end)

RegisterNUICallback('adminToggleBlip', function(data, cb)
    local blip = adminOpen and findBlip(tonumber(data and data.id))
    if not blip then return cb({ ok = false }) end
    if hiddenBlips[blip.id] then
        hiddenBlips[blip.id] = nil
        activeBlips[blip.id] = createBlip(blip)
    else
        hiddenBlips[blip.id] = true
        if activeBlips[blip.id] and DoesBlipExist(activeBlips[blip.id]) then RemoveBlip(activeBlips[blip.id]) end
        activeBlips[blip.id] = nil
    end
    cb({ ok = true, hidden = hiddenBlips[blip.id] == true })
end)

-- Presets: admin-managed NPC model / blip type dropdown options (persisted server-side)
local function presetResult(res, cb, okTitle, okMsg)
    if not res or not res.ok then
        adminNotify(locale('t_error'), locale(res and res.err or 'sv_update_fail'), 'error')
        return cb({ ok = false })
    end
    adminNotify(okTitle, okMsg, 'success')
    local p = presetPayload(res.presets)
    cb({ ok = true, models = p.models, blipTypes = p.blipTypes })
end

RegisterNUICallback('adminSavePreset', function(data, cb)
    if not adminOpen or type(data) ~= 'table' or type(data.preset) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('rsg-stores:server:savePreset', false, tonumber(data.id), data.preset)
    presetResult(res, cb, locale('t_preset_saved'), locale('cl_preset_saved'):format(data.preset.label or data.preset.value or ''))
end)

RegisterNUICallback('adminDeletePreset', function(data, cb)
    if not adminOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('rsg-stores:server:deletePreset', false, tonumber(data.id))
    presetResult(res, cb, locale('t_deleted'), locale('cl_preset_deleted'):format(data.label or ''))
end)

-- ============================================
-- LIFECYCLE
-- ============================================
local function requestData()
    TriggerServerEvent('rsg-blipmenu:server:requestBlips')
    TriggerServerEvent('rsg-blipmenu:server:requestNPCs')
end

AddEventHandler('RSGCore:Client:OnPlayerLoaded', requestData)

CreateThread(function() -- resource (re)start while already in-game
    if LocalPlayer.state.isLoggedIn then requestData() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if currentShop or adminOpen then SetNuiFocus(false, false) end
    clearBlips()
    RemoveAllNPCs()
end)
