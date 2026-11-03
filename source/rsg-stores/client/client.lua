local RSGCore = exports['rsg-core']:GetCoreObject()

local SELL_PCT = Config.SellPricePercentage or 0.80
local CLOSE_DIST = (Config.TargetDistance or 2.5) + 2.0

local customBlips, activeBlips = {}, {}   -- activeBlips keyed by blip DB id
local savedNpcs = {}
local spawnedNpcs = {}                    -- npcId -> ped
local spawning = {}                       -- npcId -> true while loading/spawned
local refreshVersion = 0

local currentShop = nil                   -- npc table of the open shop
local manageShop = nil                    -- npc table of the owned store being managed
local storeZones = {}                     -- npcId -> rsg-target zone id (player-owned stores)
local storeZoneLabel = {}                 -- npcId -> label the zone was built with
local signProps = {}                      -- npcId -> sign object (false while loading)
local uiStringsCache = nil
local OS = Config.OwnedStores or {}

-- forward declarations (kept local instead of polluting the global scope)
local findNpcById, CreateStoreZone, RemoveAllSigns, RebuildStoreZones, OpenManage, CloseManage, isMyStore

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

-- Display-only job/gang discount (the server works out the real price the same way).
local DISC = Config.Discounts or {}
local function myDiscount(npc)
    if not DISC.Enabled or not npc or npc.kind == 'player' then return 0 end
    local data = RSGCore.Functions.GetPlayerData() or {}
    local d = math.max(tonumber(data.job and DISC.Jobs and DISC.Jobs[data.job.name]) or 0,
        tonumber(data.gang and DISC.Gangs and DISC.Gangs[data.gang.name]) or 0)
    return math.min(math.max(d, 0), tonumber(DISC.MaxDiscount) or 0.5)
end

local function formatShopItems(items, discount)
    local out, d = {}, discount or 0
    for _, item in ipairs(items or {}) do
        local label, desc, image, category = itemMeta(item.name)
        local base = tonumber(item.price) or 0
        out[#out + 1] = {
            name = item.name, label = item.label or label or item.name,
            price = d > 0 and math.floor(base * (1 - d) * 100 + 0.5) / 100 or base, basePrice = base,
            amount = item.amount, description = desc, image = image, category = category,
        }
    end
    return out
end

-- ============================================
-- SHOPKEEPER SPEECH (RDR3 decompiled shop_general.c: PLAY_PED_AMBIENT_SPEECH_NATIVE,
-- 7 x 8-byte struct: line, voice, variation, params hash, listener, sync, flag)
-- ============================================
local SPEECH = Config.Speech or {}
local lastSpeech = 0
local function speak(ped, line)
    if not SPEECH.Enabled or not line or not ped or not DoesEntityExist(ped) then return end
    local now = GetGameTimer()
    if now - lastSpeech < 1500 then return end
    lastSpeech = now
    pcall(function()
        local str = CreateVarString(10, 'LITERAL_STRING', line)
        local buf = string.pack('<i8i8i8i8i8i8i8', str, 0, 0, joaat(SPEECH.Params or 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR'), 0, 1, 1)
        Citizen.InvokeNative(0x8E04FEDD28D42462, ped, buf) -- PLAY_PED_AMBIENT_SPEECH_NATIVE
    end)
end

-- ============================================
-- OPENING HOURS (in-game clock)
-- ============================================
local HOURS = Config.OpeningHours or {}
local function shopHours(npc)
    if not HOURS.Enabled or not npc.shop then return nil end
    if npc.kind == 'player' and not HOURS.OwnedStores then return nil end
    local o = (HOURS.Shops or {})[npc.shop.name] or HOURS
    return tonumber(o.Open) or 0, tonumber(o.Close) or 24
end

local function isShopOpen(npc)
    local open, close = shopHours(npc)
    if not open then return true end
    local h = GetClockHours()
    if open == close then return true end
    if open < close then return h >= open and h < close end
    return h >= open or h < close -- wraps past midnight
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
    local code = GetConvar('rsg:locale', GetConvar('ox:locale', 'en'))
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
    if currentShop.kind ~= 'player' then speak(spawnedNpcs[currentShop.id], SPEECH.Goodbye) end
    currentShop = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeShop' })
end

local function OpenCustomShop(npcData)
    if currentShop or manageShop or not npcData.shop then return end
    if not isShopOpen(npcData) then
        local open, close = shopHours(npcData)
        return RSGCore.Functions.Notify({ title = npcData.shop.label, description = locale('cl_shop_hours'):format(open, close), type = 'inform', icon = 'fa-solid fa-clock' })
    end
    if npcData.kind == 'player' and (npcData.upkeepOwed or 0) > 0 and not isMyStore(npcData) then
        return RSGCore.Functions.Notify({ title = npcData.shop.label, description = locale('sv_store_upkeep'), type = 'inform' })
    end
    currentShop = npcData
    local disc = myDiscount(npcData)
    currentShop.discount = disc
    if npcData.kind ~= 'player' then speak(spawnedNpcs[npcData.id], SPEECH.Greet) end
    if disc > 0 then
        RSGCore.Functions.Notify({ title = npcData.shop.label, description = locale('cl_discount'):format(math.floor(disc * 100 + 0.5)), type = 'success', icon = 'fa-solid fa-percent' })
    end
    SetNuiFocus(true, true)

    local code, strings = GetUiStrings()
    local pct = npcData.kind == 'player' and (tonumber(OS.BuyBackPercentage) or SELL_PCT) or SELL_PCT
    local maxStock = npcData.kind == 'player' and (tonumber(OS.MaxStock) or 0)
        or ((Config.SellAddsStock ~= false) and (tonumber(Config.MaxShopStock) or 0) or 0)
    SendNUIMessage({
        action         = 'openShop',
        shopName       = npcData.shop.name,
        shopLabel      = npcData.shop.label,
        shopType       = npcData.shop.type,
        items          = formatShopItems(npcData.shop.items, disc),
        playerItems    = GetPlayerItems(),
        playerMoney    = GetPlayerMoney(),
        sellPercentage = pct,
        feePercent     = math.floor((1 - pct) * 100 + 0.5),
        maxStock       = maxStock,
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
    RSGCore.Functions.Notify({ title = data.title or '', description = data.description or '', type = data.type or 'inform', duration = 5000 })
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
        updatedShopItems   = updatedShopItems and formatShopItems(updatedShopItems, currentShop.discount) or nil,
    })
end)

RegisterNetEvent('rsg-stores:client:purchaseSuccess', function(message, newMoney, updatedShopItems)
    if not currentShop then return end
    SendNUIMessage({ action = 'updateMoney', money = newMoney or GetPlayerMoney() })
    SendNUIMessage({ action = 'updatePlayerItems', items = GetPlayerItems() })
    if updatedShopItems then SendNUIMessage({ action = 'updateItems', items = formatShopItems(updatedShopItems, currentShop.discount) }) end
    if currentShop.kind ~= 'player' then speak(spawnedNpcs[currentShop.id], SPEECH.Thanks) end
    SendNUIMessage({ action = 'purchaseSuccess', message = message })
end)

RegisterNetEvent('rsg-stores:client:purchaseFailed', function(message, newMoney)
    if not currentShop then return end
    SendNUIMessage({ action = 'updateMoney', money = newMoney or GetPlayerMoney() })
    SendNUIMessage({ action = 'purchaseFailed', message = message })
end)

RegisterNetEvent('rsg-stores:client:shopStock', function(shopItems)
    if not currentShop or not shopItems then return end
    SendNUIMessage({ action = 'updateItems', items = formatShopItems(shopItems, currentShop.discount) })
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
    pcall(function() exports['rsg-target']:removeLocalEntity(ped) end)
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
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then spawning[id] = nil return end
        Wait(10)
    end
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
            exports['rsg-target']:addLocalEntity(ped, {{
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
            -- owned stores have no ped
            local near = npc.kind ~= 'player' and #(coords - vector3(npc.x, npc.y, npc.z)) < Config.DistanceSpawn
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
-- PLAYER-OWNED STORES (counter zone, no ped)
-- ============================================
local function myCitizenId()
    local data = RSGCore.Functions.GetPlayerData()
    return data and data.citizenid
end

isMyStore = function(npc)
    return npc and npc.owner ~= nil and npc.owner.citizenid == myCitizenId()
end

local function removeStoreZone(id)
    if storeZones[id] then
        pcall(function() exports['rsg-target']:removeZone(storeZones[id]) end)
        storeZones[id] = nil
    end
    local obj = signProps[id]
    if obj and DoesEntityExist(obj) then pcall(function() exports['rsg-target']:removeLocalEntity(obj) end) end
    storeZoneLabel[id] = nil
end

local function storeOptions(npc)
    local id = npc.id
    return {
        {
            name = 'rsg_store_browse_' .. id,
            icon = 'fa-solid fa-shopping-cart',
            label = locale('cl_trade_with'):format(npc.shop.label),
            distance = Config.TargetDistance,
            canInteract = function() local n = findNpcById(id) return n and n.owner ~= nil end,
            onSelect = function() local n = findNpcById(id) if n then OpenCustomShop(n) end end,
        },
        {
            name = 'rsg_store_closed_' .. id,
            icon = 'fa-solid fa-store-slash',
            label = locale('cl_store_closed'):format(npc.shop.label),
            distance = Config.TargetDistance,
            canInteract = function() local n = findNpcById(id) return n and n.owner == nil end,
            onSelect = function() RSGCore.Functions.Notify({ title = npc.shop.label, description = locale('sv_store_closed'), type = 'inform' }) end,
        },
        {
            name = 'rsg_store_manage_' .. id,
            icon = 'fa-solid fa-key',
            label = locale('cl_manage_store'),
            distance = Config.TargetDistance,
            canInteract = function() return isMyStore(findNpcById(id)) end,
            onSelect = function()
                local n = findNpcById(id)
                if n then CreateThread(function() OpenManage(n) end) end -- AwaitCallback needs a thread
            end,
        },
    }
end

-- (Re)create the target for one owned store: a sphere zone, or the sign prop if it has one.
CreateStoreZone = function(npc)
    removeStoreZone(npc.id)
    if OS.Enabled == false or not npc.shop then return end
    local id = npc.id
    storeZoneLabel[id] = npc.shop.label
    if npc.prop then
        local obj = signProps[id]
        if obj and DoesEntityExist(obj) then exports['rsg-target']:addLocalEntity(obj, storeOptions(npc)) end
        return
    end
    storeZones[id] = exports['rsg-target']:addSphereZone({
        coords = vector3(npc.x, npc.y, npc.z + 1.0),
        radius = tonumber(OS.ZoneRadius) or 1.2,
        options = storeOptions(npc),
    })
end

-- ============================================
-- SHOP SIGN PROPS (stores opened with the shop sign item)
-- ============================================
local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

local function SpawnSign(npc)
    local id = npc.id
    signProps[id] = false -- loading
    local model = joaat(npc.prop)
    if not loadModel(model) then
        print(('[rsg-stores] invalid sign model for store %s: %s'):format(id, npc.prop))
        return -- leave the placeholder so we don't retry every tick
    end
    if signProps[id] ~= false then SetModelAsNoLongerNeeded(model) return end
    local obj = CreateObject(model, npc.x, npc.y, npc.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then signProps[id] = nil return end
    SetEntityHeading(obj, npc.h)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    signProps[id] = obj
    CreateStoreZone(npc) -- attach the target to the sign
end

local function DespawnSign(id)
    local obj = signProps[id]
    signProps[id], storeZoneLabel[id] = nil, nil
    if obj and DoesEntityExist(obj) then
        pcall(function() exports['rsg-target']:removeLocalEntity(obj) end)
        DeleteEntity(obj)
    end
end

RemoveAllSigns = function()
    for id in pairs(signProps) do DespawnSign(id) end
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for _, npc in ipairs(savedNpcs) do
            if npc.prop then
                local near = #(coords - vector3(npc.x, npc.y, npc.z)) < Config.DistanceSpawn
                if near and signProps[npc.id] == nil then SpawnSign(npc)
                elseif not near and signProps[npc.id] ~= nil then DespawnSign(npc.id) end
            end
        end
        Wait(1000)
    end
end)

-- ============================================
-- SHOP SIGN PLACEMENT (using the item)
-- ============================================
local SIGN = Config.ShopSign or {}
local placing = nil -- { obj, rot, dist }

local function updateGhost()
    if not placing then return end
    local ped = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, placing.dist, 0.0)
    local z = groundZ(c.x, c.y, c.z)
    placing.pos = vector3(c.x, c.y, z)
    placing.h = (GetEntityHeading(ped) + 180.0 + placing.rot) % 360.0 -- faces the player by default
    SetEntityCoords(placing.obj, c.x, c.y, z, false, false, false, false)
    SetEntityHeading(placing.obj, placing.h)
    PlaceObjectOnGroundProperly(placing.obj)
end

local function stopPlacing()
    if not placing then return end
    if DoesEntityExist(placing.obj) then DeleteEntity(placing.obj) end
    placing = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSign' })
    SendNUIMessage({ action = 'signHelp', show = false })
end

-- Positioning keys (hashes from rdr3_discoveries Controls/README.md)
local SIGN_KEYS = {
    left   = 0xA65EBAB4, -- INPUT_FRONTEND_LEFT   (Arrow Left)
    right  = 0xDEB34313, -- INPUT_FRONTEND_RIGHT  (Arrow Right)
    up     = 0x6319DB71, -- INPUT_FRONTEND_UP     (Arrow Up)
    down   = 0x05CA7C52, -- INPUT_FRONTEND_DOWN   (Arrow Down)
    accept = 0xC7B5340A, -- INPUT_FRONTEND_ACCEPT (Enter)
    cancel = 0x156F7119, -- INPUT_FRONTEND_CANCEL (Backspace / Esc)
}
local ROT_SPEED, MOVE_SPEED = 90.0, 1.0 -- degrees / metres per second while held

-- Step 2: sign is fixed, the player names the store (NUI focus).
local function openSignDetails()
    placing.mode = 'details'
    SendNUIMessage({ action = 'signHelp', show = false })
    local data = RSGCore.Functions.GetPlayerData()
    local first = data and data.charinfo and data.charinfo.firstname or ''
    local code, strings = GetUiStrings()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSign',
        label = placing.label or (first ~= '' and locale('cl_default_store_name'):format(first) or ''),
        type = placing.type or SIGN.DefaultType or 'buy',
        locale = code, uiStrings = strings,
    })
end

-- Step 1: the sign follows the player; arrows rotate / move it, Enter confirms.
local function startPositioning()
    placing.mode = 'position'
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSign' })
    local code, strings = GetUiStrings()
    SendNUIMessage({ action = 'signHelp', show = true, locale = code, uiStrings = strings })
    CreateThread(function()
        while placing and placing.mode == 'position' do
            for _, c in pairs(SIGN_KEYS) do DisableControlAction(0, c, true) end
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then stopPlacing() break end
            local dt = GetFrameTime()
            if IsDisabledControlPressed(0, SIGN_KEYS.left)  then placing.rot = placing.rot + ROT_SPEED * dt end
            if IsDisabledControlPressed(0, SIGN_KEYS.right) then placing.rot = placing.rot - ROT_SPEED * dt end
            if IsDisabledControlPressed(0, SIGN_KEYS.up)    then placing.dist = math.min(3.0, placing.dist + MOVE_SPEED * dt) end
            if IsDisabledControlPressed(0, SIGN_KEYS.down)  then placing.dist = math.max(0.75, placing.dist - MOVE_SPEED * dt) end
            updateGhost()
            if IsDisabledControlJustPressed(0, SIGN_KEYS.accept) then
                openSignDetails()
            elseif IsDisabledControlJustPressed(0, SIGN_KEYS.cancel) then
                stopPlacing()
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('rsg-stores:client:startSignPlacement', function()
    if placing or currentShop or manageShop or IsPedInAnyVehicle(PlayerPedId(), false) then return end
    local model = joaat(SIGN.Model or 'p_chalksign_buysell01x')
    if not loadModel(model) then return end
    local obj = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return end
    SetEntityAlpha(obj, 170, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    placing = { obj = obj, rot = 0.0, dist = tonumber(SIGN.PlaceDistance) or 1.5 }
    updateGhost()
    startPositioning()
end)

-- From the details panel: go back to positioning (keeps what was typed).
RegisterNUICallback('signReposition', function(data, cb)
    cb('ok')
    if not placing then return end
    if type(data) == 'table' then placing.label, placing.type = data.label, data.type end
    startPositioning()
end)

RegisterNUICallback('signCancel', function(_, cb)
    stopPlacing()
    cb('ok')
end)

RegisterNUICallback('signConfirm', function(data, cb)
    if not placing or placing.mode ~= 'details' or type(data) ~= 'table' then return cb({ ok = false }) end
    local p, h = placing.pos, placing.h -- fixed while the details panel is open
    local res = RSGCore.Functions.AwaitCallback('rsg-stores:server:placeSign', 8000,
        { x = p.x, y = p.y, z = p.z, h = h, label = data.label, type = data.type })
    if not res or not res.ok then
        RSGCore.Functions.Notify({ title = locale('ui_sign_title'), description = locale((res and res.err) or 'sv_try_again'):format(tonumber(SIGN.MaxPerPlayer) or 1), type = 'error' })
        return cb({ ok = false })
    end
    stopPlacing()
    RSGCore.Functions.Notify({ title = locale('ui_sign_title'), description = res.msg, type = 'success' })
    cb({ ok = true })
end)

RebuildStoreZones = function()
    for id in pairs(storeZones) do removeStoreZone(id) end
    for _, npc in ipairs(savedNpcs) do
        if npc.kind == 'player' then CreateStoreZone(npc) end
    end
end

-- Inventory items an owner could put on the shelf (server re-checks everything).
local function stockablePlayerItems()
    local black = {}
    for _, n in ipairs(OS.BlacklistItems or {}) do black[n] = true end
    local out = {}
    for _, it in ipairs(GetPlayerItems()) do
        local shared = RSGCore.Shared.Items[it.name]
        if shared and not black[it.name] and not shared.unique and shared.type ~= 'weapon' then
            out[#out + 1] = it
        end
    end
    return out
end

CloseManage = function()
    if not manageShop then return end
    manageShop = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeManage' })
end

local function managePayload(state)
    state.items = formatShopItems(state.items)
    state.playerItems = stockablePlayerItems()
    for _, w in ipairs(state.wholesale or {}) do
        local _, _, image = itemMeta(w.name)
        w.image = image
    end
    state.playerMoney = GetPlayerMoney()
    return state
end

OpenManage = function(npc)
    if currentShop or manageShop then return end
    local state = RSGCore.Functions.AwaitCallback('rsg-stores:server:ownerGetState', 5000, npc.id)
    if not state or not state.ok then
        return RSGCore.Functions.Notify({ title = npc.shop.label, description = locale(state and state.err or 'sv_shop_notfound'), type = 'error' })
    end
    manageShop = npc
    SetNuiFocus(true, true)
    local code, strings = GetUiStrings()
    local payload = managePayload(state)
    payload.action, payload.locale, payload.uiStrings = 'openManage', code, strings
    SendNUIMessage(payload)

    CreateThread(function()
        local c = vector3(npc.x, npc.y, npc.z)
        while manageShop == npc do
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - c) > CLOSE_DIST then CloseManage() break end
            Wait(500)
        end
    end)
end

RegisterNUICallback('manageClose', function(_, cb)
    CloseManage()
    cb('ok')
end)

-- op -> server callback + which args to forward (store id always comes from Lua)
local MANAGE_OPS = {
    state    = { 'rsg-stores:server:ownerGetState',      function(d) return end },
    stock    = { 'rsg-stores:server:ownerAddStock',      function(d) return d.item, tonumber(d.qty), d.price ~= nil and tonumber(d.price) or nil end },
    take     = { 'rsg-stores:server:ownerTakeStock',     function(d) return d.item, tonumber(d.qty) end },
    price    = { 'rsg-stores:server:ownerSetPrice',      function(d) return d.item, tonumber(d.price) end },
    remove   = { 'rsg-stores:server:ownerRemoveListing', function(d) return d.item end },
    withdraw = { 'rsg-stores:server:ownerWithdraw',      function(d) return tonumber(d.amount) end },
    settings = { 'rsg-stores:server:ownerSetSettings',   function(d) return d.label, d.type end },
    packup   = { 'rsg-stores:server:ownerPackUp',        function(d) return end },
    wholesale = { 'rsg-stores:server:ownerWholesale',    function(d) return d.item, tonumber(d.qty), d.price ~= nil and tonumber(d.price) or nil end },
    upkeep   = { 'rsg-stores:server:ownerPayUpkeep',     function(d) return end },
}

RegisterNUICallback('manageAction', function(data, cb)
    local op = type(data) == 'table' and MANAGE_OPS[data.op]
    if not manageShop or not op then return cb({ ok = false }) end
    local res = RSGCore.Functions.AwaitCallback(op[1], 8000, manageShop.id, op[2](data))
    if not res or not res.ok then
        RSGCore.Functions.Notify({ title = manageShop.shop.label, description = locale(res and res.err or 'sv_try_again'), type = 'error' })
        return cb({ ok = false })
    end
    if res.msg then RSGCore.Functions.Notify({ title = res.label, description = res.msg, type = 'success' }) end
    if res.closed then CloseManage() return cb({ ok = true, closed = true }) end
    Wait(150) -- let the inventory sync land before listing it
    cb(managePayload(res))
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
    if manageShop then CloseManage() end
    RemoveAllNPCs()
    RemoveAllSigns()
    savedNpcs = npcs or {}
    RebuildStoreZones()
    pushAdminData()
end)

-- Light per-store update for owned stores (stock, prices, label, owner). No respawns.
RegisterNetEvent('rsg-stores:client:updateShop', function(npcId, shop, owner, upkeepOwed)
    local npc = findNpcById(npcId)
    if not npc then return end
    npc.shop, npc.owner, npc.upkeepOwed = shop, owner, upkeepOwed   -- mutate in place: currentShop/manageShop share this table
    -- zone labels show the shop sign, so only rebuild when it changes
    if npc.kind == 'player' and storeZoneLabel[npc.id] ~= (shop and shop.label) then CreateStoreZone(npc) end
    if currentShop == npc and shop then
        SendNUIMessage({ action = 'updateItems', items = formatShopItems(shop.items, currentShop.discount) })
    end
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
findNpcById = function(id)
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
    RSGCore.Functions.Notify({ title = title, description = desc, type = nType or 'success', duration = 5000 })
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
    if adminOpen or currentShop or manageShop then return end
    local presets = RSGCore.Functions.AwaitCallback('rsg-stores:server:getPresets', nil)
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

RegisterCommand('createshop', function()
    if not RSGCore.Functions.AwaitCallback('rsg-blipmenu:server:hasAdminPerm', nil) then
        return adminNotify(locale('t_access_denied'), locale('cl_access_denied'), 'error')
    end
    OpenAdmin()
end, false)

RegisterNUICallback('adminClose', function(_, cb)
    CloseAdmin()
    cb('ok')
end)

RegisterNUICallback('adminGetPlayers', function(_, cb)
    if not adminOpen then return cb({}) end
    cb(RSGCore.Functions.AwaitCallback('rsg-stores:server:getOnlinePlayers', 5000) or {})
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

    local newId = RSGCore.Functions.AwaitCallback('rsg-blipmenu:server:saveNPC', nil, npc)
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
    local copy = json.decode(json.encode(src))
    copy.owner = nil -- a duplicated owned store starts empty and unowned
    local pos = myPosition()
    copy.id, copy.x, copy.y, copy.z, copy.h = nil, pos.x, pos.y, pos.z, pos.h
    local newId = RSGCore.Functions.AwaitCallback('rsg-blipmenu:server:saveNPC', nil, copy)
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

RegisterNUICallback('adminEvictOwner', function(data, cb)
    cb('ok')
    local npc = adminOpen and findNpcById(tonumber(data and data.id))
    if not npc then return end
    TriggerServerEvent('rsg-blipmenu:server:evictOwner', npc.id, data.force == true)
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
    local res = RSGCore.Functions.AwaitCallback('rsg-stores:server:savePreset', nil, tonumber(data.id), data.preset)
    presetResult(res, cb, locale('t_preset_saved'), locale('cl_preset_saved'):format(data.preset.label or data.preset.value or ''))
end)

RegisterNUICallback('adminDeletePreset', function(data, cb)
    if not adminOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = RSGCore.Functions.AwaitCallback('rsg-stores:server:deletePreset', nil, tonumber(data.id))
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
    if currentShop or adminOpen or manageShop or placing then SetNuiFocus(false, false) end
    for id in pairs(storeZones) do removeStoreZone(id) end
    RemoveAllSigns()
    if placing then stopPlacing() end
    clearBlips()
    RemoveAllNPCs()
end)
