local RSGCore = exports['rsg-core']:GetCoreObject()

local npcs, blips = {}, {}
local currentStore = nil
local uiOpen = false

local previewVeh = nil
local previewCam = nil
local previewCamActive = false
local previewRotateDir = nil
local previewZoomDelta = 0.0
local previewToken = 0

local myWagon = nil -- { id, entity, netId, name, model, condition, destroyed }
local spawnOwnedWagon -- defined further down; used by the call (J) feature

-- ===================== HELPERS =====================
local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function applyLivery(veh, livery)
    livery = tonumber(livery)
    if veh and DoesEntityExist(veh) and livery and livery >= 0 then
        Citizen.InvokeNative(0xF89D82A0582E46ED, veh, livery) -- _SET_VEHICLE_LIVERY
    end
end

local function applyTint(veh, tint)
    tint = tonumber(tint)
    if veh and DoesEntityExist(veh) and tint and tint >= -1 then
        Citizen.InvokeNative(0x8268B098F6FCA4E2, veh, math.floor(tint)) -- _SET_VEHICLE_TINT (-1 = default)
    end
end

-- Tint first, then livery. In RDR2 a tint is a full paint scheme: setting it also sets that scheme's own
-- livery (tested: tint 5 on a cart forces livery 2). The chosen livery is applied after a short pause so
-- it replaces the tint's built-in one (tested: tint 5 then livery 7 keeps both).
local paintToken = {} -- per vehicle, so painting several wagons at once doesn't cancel each other
local function applyPaint(veh, livery, tint)
    if not veh or not DoesEntityExist(veh) then return end
    paintToken[veh] = (paintToken[veh] or 0) + 1
    local token = paintToken[veh]
    applyTint(veh, tint)
    applyLivery(veh, livery)
    SetTimeout(150, function()
        if paintToken[veh] ~= token or not DoesEntityExist(veh) then return end
        applyLivery(veh, livery)
    end)
end

-- RedM has no NETWORK_FADE_* natives: fade in with _SET_ENTITY_FADE_IN, fade out by stepping the alpha down
local function fadeInEntity(ent)
    if ent and DoesEntityExist(ent) then
        Citizen.InvokeNative(0x744B9EF44779D9AB, ent)  -- RESET_ENTITY_ALPHA
        Citizen.InvokeNative(0xA91E6CF94404E8C9, ent)  -- _SET_ENTITY_FADE_IN
    end
end

local function fadeOutEntity(ent, ms)
    ms = ms or 700
    local steps = 10
    for i = steps - 1, 0, -1 do
        if not DoesEntityExist(ent) then return end
        Citizen.InvokeNative(0x0DF7692B1D9E7BA7, ent, math.floor(255 * i / steps), false) -- SET_ENTITY_ALPHA
        Wait(math.floor(ms / steps))
    end
end

-- cargo + lantern propsets, applied the way Rockstar's scripts do it (decompiled av_wagon_music.c, ambush_odr_*.c):
-- _REQUEST_PROP_SET -> wait for _HAS_PROP_SET_LOADED -> _ADD_PROP_SET_FOR_VEHICLE (the vehicle's own cargo slot).
-- The "additional" propset native (0x75F90E4051CC084C) is never used by Rockstar and is the likely cause of the screen judder while driving.
local function loadPropset(hash)
    if Citizen.InvokeNative(0x48A88FC684C55FDC, hash) then return true end -- _HAS_PROP_SET_LOADED
    Citizen.InvokeNative(0xF3DE57A46D5585E9, hash)                       -- _REQUEST_PROP_SET
    local timeout = GetGameTimer() + 5000
    while not Citizen.InvokeNative(0x48A88FC684C55FDC, hash) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

local propToken = {}
local function applyProps(veh, propset, lantern, tarp)
    if not veh or not DoesEntityExist(veh) then return end
    propToken[veh] = (propToken[veh] or 0) + 1
    local token = propToken[veh]
    CreateThread(function()
        local pHash = (type(propset) == 'string' and propset ~= '') and joaat(propset) or nil
        local lHash = (type(lantern) == 'string' and lantern ~= '') and joaat(lantern) or nil
        if pHash then loadPropset(pHash) end
        if lHash then loadPropset(lHash) end
        if propToken[veh] ~= token or not DoesEntityExist(veh) then return end -- a newer change came in
        Citizen.InvokeNative(0x3BCF32FF37EA9F1D, veh)                          -- _REMOVE_VEHICLE_PROP_SETS
        if pHash then Citizen.InvokeNative(0xD80FAF919A2E56EA, veh, pHash) end -- _ADD_PROP_SET_FOR_VEHICLE
        Citizen.InvokeNative(0xE31C0CB1C3186D40, veh)                          -- _REMOVE_VEHICLE_LIGHT_PROP_SETS
        if lHash then Citizen.InvokeNative(0xC0F0417A90402742, veh, lHash) end -- _ADD_LIGHT_PROP_SET_TO_VEHICLE
        if tarp then
            Wait(250)
            Citizen.InvokeNative(0x31F343383F19C987, veh, tarp + 0.0, true) -- _SET_BATCH_TARP_HEIGHT (hunting cart load)
        end
    end)
end

local function applyLook(veh, look)
    if type(look) ~= 'table' then return end
    applyPaint(veh, look.livery, look.tint)
    applyProps(veh, look.propset, look.lantern, look.tarp)
end

local function notify(desc, ntype)
    RSGCore.Functions.Notify({ title = locale('cl_title'), description = desc, type = ntype or 'inform' })
end

local UI_KEYS = {
    'ui_subtitle', 'ui_for_sale', 'ui_my_wagons', 'ui_close', 'ui_buy', 'ui_price', 'ui_capacity',
    'ui_slots', 'ui_seats', 'ui_rotate', 'ui_zoom', 'ui_controls_hint', 'ui_name_wagon', 'ui_name_placeholder',
    'ui_cancel', 'ui_confirm', 'ui_take_out', 'ui_sell', 'ui_rename', 'ui_condition', 'ui_stored_at',
    'ui_out', 'ui_no_owned', 'ui_sell_confirm', 'ui_trade_in', 'ui_all',
    'ui_return_wagon', 'ui_kg', 'ui_search', 'ui_back', 'ui_livery', 'ui_no_liveries', 'ui_colour', 'ui_colour_default', 'ui_colour_n',
    'ui_customise', 'ui_cargo', 'ui_lanterns', 'ui_none', 'ui_save', 'ui_repair',
    'cat_carts', 'cat_buggies', 'cat_wagons', 'cat_coaches', 'cat_heavy',
    'tier_1', 'tier_2', 'tier_3', 'tier_4',
    'cond_damaged', 'cond_poor', 'cond_average', 'cond_quality', 'cond_exceptional',
}

local function uiStrings()
    local t = {}
    for _, k in ipairs(UI_KEYS) do t[k] = locale(k) end
    return t
end

local function catalogue(storeKey)
    local list = {}
    for model, w in pairs(Config.Wagons) do
        local allowed = true
        if w.stores then
            allowed = false
            for _, s in ipairs(w.stores) do if s == storeKey then allowed = true break end end
        end
        if allowed then
            list[#list + 1] = {
                model = model, label = w.label, category = w.category, price = w.price,
                weight = w.weight, slots = w.slots, seats = w.seats or 2, tier = w.tier or 1,
                description = w.description or '',
                liveries = (Config.Liveries and Config.Liveries[model]) or {},
                tints = (Config.Tints and Config.Tints[model]) or 0,
            }
        end
    end
    table.sort(list, function(a, b) return a.price < b.price end)
    return list
end

-- ===================== PREVIEW =====================
local function destroyPreviewCam()
    previewCamActive = false
    previewRotateDir = nil
    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        if DoesCamExist(previewCam) then DestroyCam(previewCam, false) end
        previewCam = nil
    end
    FreezeEntityPosition(PlayerPedId(), false)
end

local function deletePreviewVehicle()
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
    end
    previewVeh = nil
end

local function endPreview()
    previewToken = previewToken + 1
    destroyPreviewCam()
    deletePreviewVehicle()
end

local function startPreviewCam(coords, heading)
    if previewCam and DoesCamExist(previewCam) then return end
    local P = Config.Preview
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 500, true, true)
    FreezeEntityPosition(PlayerPedId(), true)
    previewCamActive = true
    previewZoomDelta = 0.0

    CreateThread(function()
        local angle = (heading or 0.0) + 35.0  -- start on a three-quarter view
        local radius = P.radius
        while previewCamActive and previewCam and DoesCamExist(previewCam) do
            local ft = GetFrameTime()
            if previewRotateDir == 'left' then
                angle = angle - P.rotateSpeed * ft
            elseif previewRotateDir == 'right' then
                angle = angle + P.rotateSpeed * ft
            elseif P.autoRotate and P.autoRotate > 0 then
                angle = angle + P.autoRotate * ft
            end
            angle = angle % 360.0
            if previewZoomDelta ~= 0.0 then
                radius = math.max(P.radiusMin, math.min(P.radiusMax, radius + previewZoomDelta))
                previewZoomDelta = 0.0
            end
            local rad = math.rad(angle)
            SetCamCoord(previewCam, coords.x + math.cos(rad) * radius, coords.y + math.sin(rad) * radius, coords.z + P.height)
            PointCamAtCoord(previewCam, coords.x, coords.y, coords.z + P.lookAtHeight)
            Wait(0)
        end
    end)
end

local function showPreview(model, livery, tint)
    if not currentStore or not Config.Wagons[model] then return end
    previewToken = previewToken + 1
    local token = previewToken
    local p = Config.Stores[currentStore].preview

    local hash = loadModel(model)
    if not hash or token ~= previewToken then
        if not hash then notify(locale('cl_preview_failed'), 'error') end
        return
    end

    deletePreviewVehicle()
    -- local (non-networked) preview vehicle; last arg false = auto-create draft animals
    local veh = CreateVehicle(hash, p.x, p.y, p.z, p.w, false, false, not Config.Preview.draftAnimals, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then notify(locale('cl_preview_failed'), 'error') return end
    if token ~= previewToken then DeleteEntity(veh) return end

    PlaceEntityOnGroundProperly(veh, true)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    applyPaint(veh, livery, tint)
    previewVeh = veh

    startPreviewCam(vector3(p.x, p.y, p.z), p.w)
end

-- ===================== NUI =====================
local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    endPreview()
end

local opening = false
local function openShop(storeKey)
    if uiOpen or opening or not Config.Stores[storeKey] then return end
    opening = true
    currentStore = storeKey
    local owned = RSGCore.Functions.AwaitCallback('rsg-wagons:server:getOwned', 5000) or {}
    opening = false
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        store = { key = storeKey, label = Config.Stores[storeKey].label },
        categories = Config.Categories,
        wagons = catalogue(storeKey),
        owned = owned,
        maxWagons = Config.MaxWagons,
        nameMax = Config.NameMaxLength,
        hasActive = myWagon ~= nil,
        strings = uiStrings(),
    })
end

RegisterNUICallback('close', function(_, cb) closeUI() cb('ok') end)

RegisterNUICallback('preview', function(data, cb)
    cb('ok')
    if data and type(data.model) == 'string' then showPreview(data.model, data.livery, data.tint) end
end)

-- change the livery on the current preview wagon without respawning it
RegisterNUICallback('previewLivery', function(data, cb)
    cb('ok')
    if data then applyPaint(previewVeh, data.livery, data.tint) end
end)

RegisterNUICallback('clearPreview', function(_, cb) endPreview() cb('ok') end)

RegisterNUICallback('rotateCam', function(data, cb)
    local dir = data and data.dir
    previewRotateDir = (dir == 'left' or dir == 'right') and dir or nil
    cb('ok')
end)

RegisterNUICallback('zoomCam', function(data, cb)
    local dir = tonumber(data and data.dir) or 0
    previewZoomDelta = previewZoomDelta + (dir > 0 and 1.0 or dir < 0 and -1.0 or 0.0)
    cb('ok')
end)

RegisterNUICallback('buy', function(data, cb)
    local ok, owned = RSGCore.Functions.AwaitCallback('rsg-wagons:server:buy', 8000, currentStore, data.model, data.name, data.livery, data.tint)
    cb({ ok = ok == true, owned = owned })
end)

RegisterNUICallback('yardRepair', function(data, cb)
    local ok, owned = RSGCore.Functions.AwaitCallback('rsg-wagons:server:yardRepair', 8000, currentStore, data.id)
    cb({ ok = ok == true, owned = owned })
end)

RegisterNUICallback('rename', function(data, cb)
    local ok, owned = RSGCore.Functions.AwaitCallback('rsg-wagons:server:rename', 5000, data.id, data.name)
    cb({ ok = ok == true, owned = owned })
end)

RegisterNUICallback('sell', function(data, cb)
    local ok, owned = RSGCore.Functions.AwaitCallback('rsg-wagons:server:sell', 8000, currentStore, data.id)
    if ok == nil then notify(locale('cl_no_response'), 'error') end -- callback timed out (server error?)
    cb({ ok = ok == true, owned = owned })
end)

local function wagonCondition()
    if myWagon and myWagon.destroyed then return 10 end
    if not myWagon then return 100 end
    if not myWagon.entity or myWagon.entity == 0 or not DoesEntityExist(myWagon.entity) then return myWagon.condition or 100 end
    local max = GetEntityMaxHealth(myWagon.entity)
    if not max or max <= 0 then return 100 end
    return math.floor(GetEntityHealth(myWagon.entity) / max * 100)
end

-- ===== map blip for the wagon that is out =====
local wagonBlip = nil

local function removeWagonBlip()
    if wagonBlip and DoesBlipExist(wagonBlip) then RemoveBlip(wagonBlip) end
    wagonBlip = nil
end

local function addWagonBlip(veh, name)
    removeWagonBlip()
    local cfg = Config.WagonBlip
    if not cfg or not cfg.enabled or not veh or not DoesEntityExist(veh) then return end
    wagonBlip = BlipAddForEntity(joaat(cfg.style or 'BLIP_STYLE_PLAYER_COACH'), veh)
    if cfg.sprite then SetBlipSprite(wagonBlip, joaat(cfg.sprite), true) end
    Citizen.InvokeNative(0x9CB1A1623062F402, wagonBlip, name or locale('cl_title')) -- SetBlipName
end

local function clearMyWagon()
    removeWagonBlip()
    if myWagon and myWagon.entity and DoesEntityExist(myWagon.entity) then
        exports['rsg-target']:removeLocalEntity(myWagon.entity)
    end
    myWagon = nil
end

RegisterNUICallback('store', function(_, cb)
    local ok, owned = RSGCore.Functions.AwaitCallback('rsg-wagons:server:store', 8000, currentStore, wagonCondition())
    if ok then clearMyWagon() end
    cb({ ok = ok == true, owned = owned, hasActive = myWagon ~= nil })
end)

-- ===== customise (cargo / lanterns) =====
local customOpen = false

local function propsetList(model)
    return (Config.Propsets and Config.Propsets[model]) or {}, (Config.Lanterns and Config.Lanterns[model]) or {}
end

local function openCustomise()
    if uiOpen or customOpen or not myWagon or not myWagon.entity or not DoesEntityExist(myWagon.entity) then return end
    local props, lanterns = propsetList(myWagon.model)
    if #props == 0 and #lanterns == 0 then return end
    local look = Entity(myWagon.entity).state.rsgWagonLook or {}
    customOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'custom', strings = uiStrings(), name = myWagon.name,
        propsets = props, lanterns = lanterns, propset = look.propset, lantern = look.lantern,
    })
end

local function closeCustomise(revert)
    if not customOpen then return end
    customOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCustom' })
    if revert and myWagon and myWagon.entity and DoesEntityExist(myWagon.entity) then
        applyLook(myWagon.entity, Entity(myWagon.entity).state.rsgWagonLook)
    end
end

RegisterNUICallback('customPreview', function(data, cb)
    cb('ok')
    if customOpen and myWagon and data then
        local look = (myWagon.entity and Entity(myWagon.entity).state.rsgWagonLook) or {}
        applyProps(myWagon.entity, data.propset or (look.tarp and look.propset), data.lantern, look.tarp)
    end
end)

RegisterNUICallback('customSave', function(data, cb)
    local ok = RSGCore.Functions.AwaitCallback('rsg-wagons:server:setLook', 8000, data and data.propset, data and data.lantern)
    cb({ ok = ok == true })
    closeCustomise(not ok)
end)

RegisterNUICallback('customClose', function(_, cb) cb('ok') closeCustomise(true) end)

-- ===== field repair (temporary patch) =====
local repairing = false

local function wagonNeedsPatch()
    if not myWagon then return false end
    if myWagon.destroyed then return true end
    return (myWagon.condition or wagonCondition()) < Config.FieldRepair.condition
end

-- quick client-side check so the player isn't made to work on a repair they can't pay for
-- (the server checks and charges for real)
local function canPayRepair()
    local c = Config.FieldRepair.cost or {}
    if c.type == 'item' then
        if RSGCore.Functions.HasItem(c.item, c.amount or 1) then return true end
        local item = RSGCore.Shared.Items[c.item]
        notify(locale('sv_repair_need_item', c.amount or 1, item and item.label or c.item), 'error')
        return false
    end
    local money = (RSGCore.Functions.GetPlayerData().money or {})[Config.MoneyType] or 0
    if money >= (c.amount or 0) then return true end
    notify(locale('sv_repair_no_money'), 'error')
    return false
end

local function patchMyWagon()
    if repairing or not Config.FieldRepair.enabled then return end
    if not myWagon then return notify(locale('cl_no_wagon_out'), 'error') end
    if not wagonNeedsPatch() then return notify(locale('sv_repair_not_needed', Config.FieldRepair.condition .. '%'), 'inform') end
    if not canPayRepair() then return end
    repairing = true
    local ped = PlayerPedId()
    local veh = myWagon.entity
    local onSite = veh and veh ~= 0 and DoesEntityExist(veh) and not IsEntityDead(veh)
    if onSite then
        if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > Config.UseDistance + 2.0 then
            repairing = false
            return notify(locale('sv_wagon_too_far'), 'error')
        end
        TaskTurnPedToFaceEntity(ped, veh, 1000, 0, 0, 0)
        Wait(1000)
    end
    -- work on it (also for a wreck: you're patching up what's left of it)
    TaskStartScenarioInPlaceHash(ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), Config.FieldRepair.duration, true, 0, GetEntityHeading(ped), false)
    notify(locale('cl_repairing'), 'inform')
    Wait(Config.FieldRepair.duration)
    ClearPedTasks(ped, true, true)

    local ok, newCond, wasWrecked = RSGCore.Functions.AwaitCallback('rsg-wagons:server:fieldRepair', 8000)
    if ok then
        if wasWrecked then
            -- the wreck is cleared server side; the wagon is now "away" and can be called with J
            local id, name, model = myWagon.id, myWagon.name, myWagon.model
            clearMyWagon()
            myWagon = { id = id, entity = 0, netId = 0, name = name, model = model, condition = newCond }
        else
            myWagon.condition = newCond
            if onSite and DoesEntityExist(veh) then
                local max = GetEntityMaxHealth(veh)
                if max and max > 0 then SetEntityHealth(veh, math.max(1, math.floor(max * newCond / 100)), 0) end
            end
        end
    end
    repairing = false
end

-- ===== hunting cart =====
local HC = Config.HuntingCart or {}
local HC_QUALITY = { [0] = 'poor', [1] = 'good', [2] = 'perfect' } -- GetPedQuality, as rsg-hunting
local cartBusy = false

local function isMyHuntCart(entity)
    return HC.enabled and myWagon and entity == myWagon.entity and HC.models[myWagon.model] == true
end

local function cartLoad(entity)
    local look = Entity(entity).state.rsgWagonLook
    return (look and look.cargo) or 0
end

local function knownCarcass(ent)
    return ent and ent ~= 0 and DoesEntityExist(ent) and IsEntityAPed(ent) and IsEntityDead(ent)
        and HC.animals[GetEntityModel(ent)] ~= nil
end

-- carcass strapped to the player's horse (same itemset loop as rsg-hunting / Rockstar's shop_butcher.c)
local function horseCarcass()
    if not HC.fromHorse then return 0 end
    local ped = PlayerPedId()
    local horse = Citizen.InvokeNative(0x4C8B59171957BCF7, ped) -- _GET_LAST_MOUNT
    if not horse or horse == 0 or not DoesEntityExist(horse) then return 0 end
    if #(GetEntityCoords(ped) - GetEntityCoords(horse)) > (HC.horseRange or 6.0) then return 0 end
    if not Citizen.InvokeNative(0xA911EE21EDF69DAF, horse) then return 0 end -- IS_PED_CARRYING_SOMETHING
    local found = 0
    local set = Citizen.InvokeNative(0xA1AF16083320065A, true, Citizen.ResultAsInteger()) -- CREATE_ITEMSET
    Citizen.InvokeNative(0xB5ACE8B23A438EC0, horse, set) -- FIND_ALL_ATTACHED_CARRIABLE_ENTITIES
    local size = Citizen.InvokeNative(0x55F2E375AC6018A9, set, Citizen.ResultAsInteger()) -- GET_ITEMSET_SIZE
    for i = 0, size - 1 do
        local item = Citizen.InvokeNative(0x275A2E2C0FAB7612, i, set, Citizen.ResultAsInteger()) -- GET_INDEXED_ITEM_IN_ITEMSET
        local ent = Citizen.InvokeNative(0xEE04C0AFD4EFAF0E, item, Citizen.ResultAsInteger()) -- _GET_ENTITY_FROM_ITEM
        if knownCarcass(ent) then found = ent break end
    end
    Citizen.InvokeNative(0x712BC69F10549B92, set) -- DESTROY_ITEMSET
    return found
end

-- rsg-target calls canInteract every frame while aiming at the cart, and the horse lookup builds an itemset,
-- so the result is cached briefly
local carcassCache, carcassCacheAt = 0, 0
local function carriedCarcass(fresh)
    local now = GetGameTimer()
    if not fresh and now - carcassCacheAt < 500 then return carcassCache end
    local ent = GetFirstEntityPedIsCarrying(PlayerPedId())
    if not knownCarcass(ent) then ent = horseCarcass() end
    carcassCache, carcassCacheAt = ent, now
    return ent
end

local function nearButcherClient(coords)
    for _, b in ipairs(HC.butchers or {}) do
        if #(coords - b.coords) <= (HC.sellRange or 25.0) then return true end
    end
    return false
end

local function stowCarcass()
    if cartBusy or not myWagon then return end
    local carcass = carriedCarcass(true)
    if carcass == 0 then return notify(locale('sv_not_carcass'), 'error') end
    cartBusy = true
    if not NetworkGetEntityIsNetworked(carcass) then
        NetworkRegisterEntityAsNetworked(carcass)
        Wait(200)
    end
    local netId = NetworkGetEntityIsNetworked(carcass) and NetworkGetNetworkIdFromEntity(carcass) or 0
    if netId ~= 0 then
        local quality = HC_QUALITY[GetPedQuality(carcass)] or 'poor'
        local ok = RSGCore.Functions.AwaitCallback('rsg-wagons:server:stowCarcass', 8000, netId, quality)
        if ok and DoesEntityExist(carcass) then -- don't leave it in the player's arms
            DetachEntity(carcass, true, true)
            NetworkRequestControlOfEntity(carcass)
            SetEntityAsMissionEntity(carcass, true, true)
            DeleteEntity(carcass)
        end
    end
    cartBusy = false
end

local function sellCartLoad()
    if cartBusy or not myWagon then return end
    cartBusy = true
    LocalPlayer.state:set('inv_busy', true, false)
    local done = RSGCore.Functions.ProgressBar({
        duration = HC.sellTime or 8000, position = 'bottom', useWhileDead = false, canCancel = true,
        disable = { move = true, combat = true }, label = locale('cl_selling_load'),
    })
    if done then RSGCore.Functions.AwaitCallback('rsg-wagons:server:sellCargo', 8000) end
    LocalPlayer.state:set('inv_busy', false, false)
    cartBusy = false
end

local busyCall = false

-- send the wagon away (like fleeing a horse): it stays out but leaves the world until called
local function fleeMyWagon()
    if busyCall or not myWagon or myWagon.destroyed then return end
    local veh = myWagon.entity
    if not veh or veh == 0 or not DoesEntityExist(veh) then return notify(locale('cl_wagon_already_away'), 'inform') end
    busyCall = true
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) == veh then
        TaskLeaveVehicle(ped, veh, 0)
        local t = GetGameTimer() + 4000
        while GetVehiclePedIsIn(ped, false) == veh and GetGameTimer() < t do Wait(100) end
    end
    myWagon.condition = wagonCondition()
    fadeOutEntity(veh, 700)
    local ok = RSGCore.Functions.AwaitCallback('rsg-wagons:server:fleeWagon', 8000, myWagon.condition)
    if ok then
        exports['rsg-target']:removeLocalEntity(veh)
        removeWagonBlip()
        myWagon.entity, myWagon.netId = 0, 0
        notify(locale('cl_wagon_sent'), 'inform')
    elseif DoesEntityExist(veh) then
        fadeInEntity(veh)
    end
    busyCall = false
end

-- find a road spot near the player (not right on top of them); fall back to beside the player
local function callSpot()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    for n = 1, 6 do
        local found, pos, heading = GetNthClosestVehicleNodeWithHeading(p.x, p.y, p.z, n, 1, 3.0, 0)
        if found and pos then
            local d = #(p - pos)
            if d >= 6.0 and d <= Config.CallRoadDistance then return vector4(pos.x, pos.y, pos.z, heading or 0.0) end
        end
    end
    local f = GetOffsetFromEntityInWorldCoords(ped, 0.0, 8.0, 0.0)
    return vector4(f.x, f.y, f.z, GetEntityHeading(ped) + 90.0)
end

-- call the wagon to you (J), like whistling a horse
local function callMyWagon()
    if busyCall or uiOpen or customOpen then return end
    if not myWagon then return notify(locale('cl_no_wagon_out'), 'error') end
    if myWagon.destroyed then return notify(locale('cl_wagon_destroyed'), 'error') end
    local veh = myWagon.entity
    if veh and veh ~= 0 and DoesEntityExist(veh)
        and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) <= Config.CallNearDistance then
        return notify(locale('cl_wagon_nearby'), 'inform')
    end
    busyCall = true
    local ok, info = RSGCore.Functions.AwaitCallback('rsg-wagons:server:callWagon', 8000)
    if ok and info then
        if veh and veh ~= 0 then exports['rsg-target']:removeLocalEntity(veh) end
        if spawnOwnedWagon(info, callSpot(), true) then
            notify(locale('cl_wagon_arrived', info.name), 'success')
        end
    end
    busyCall = false
end

local storing = false
local function storeMyWagon()
    if storing or not myWagon then return end
    storing = true
    local ok = RSGCore.Functions.AwaitCallback('rsg-wagons:server:storeNearest', 8000, wagonCondition())
    if ok then clearMyWagon() end
    storing = false
end

local function addWagonTarget(veh)
    exports['rsg-target']:addLocalEntity(veh, {
        {
            name = 'rsg_wagons_storage',
            icon = 'fa-solid fa-box-open',
            label = locale('cl_open_storage'),
            distance = Config.UseDistance,
            canInteract = function(entity) return myWagon and entity == myWagon.entity end,
            onSelect = function()
                if myWagon then TriggerServerEvent('rsg-wagons:server:openStorage', myWagon.netId) end
            end,
        },
        {
            name = 'rsg_wagons_store',
            icon = 'fa-solid fa-warehouse',
            label = locale('cl_store_wagon'),
            distance = Config.UseDistance,
            canInteract = function(entity) return myWagon and entity == myWagon.entity end,
            onSelect = function() storeMyWagon() end,
        },
        {
            name = 'rsg_wagons_flee',
            icon = 'fa-solid fa-person-walking-arrow-right',
            label = locale('cl_send_away'),
            distance = Config.UseDistance,
            canInteract = function(entity) return myWagon and entity == myWagon.entity end,
            onSelect = function() CreateThread(fleeMyWagon) end,
        },
        {
            name = 'rsg_wagons_customise',
            icon = 'fa-solid fa-boxes-stacked',
            label = locale('cl_customise'),
            distance = Config.UseDistance,
            canInteract = function(entity)
                if not myWagon or entity ~= myWagon.entity then return false end
                local props, lanterns = propsetList(myWagon.model)
                return #props > 0 or #lanterns > 0
            end,
            onSelect = function() openCustomise() end,
        },
        {
            name = 'rsg_wagons_stow',
            icon = 'fa-solid fa-paw',
            label = locale('cl_stow_carcass'),
            distance = Config.UseDistance,
            canInteract = function(entity)
                return isMyHuntCart(entity) and not cartBusy and cartLoad(entity) < (HC.capacity or 20) and carriedCarcass() ~= 0
            end,
            onSelect = function() CreateThread(stowCarcass) end,
        },
        {
            name = 'rsg_wagons_sell_load',
            icon = 'fa-solid fa-sack-dollar',
            label = locale('cl_sell_load'),
            distance = Config.UseDistance,
            canInteract = function(entity)
                return isMyHuntCart(entity) and not cartBusy and cartLoad(entity) > 0 and nearButcherClient(GetEntityCoords(entity))
            end,
            onSelect = function() CreateThread(sellCartLoad) end,
        },
        {
            name = 'rsg_wagons_patch',
            icon = 'fa-solid fa-hammer',
            label = locale('cl_patch_wagon'),
            distance = Config.UseDistance,
            canInteract = function(entity)
                return Config.FieldRepair.enabled and myWagon and entity == myWagon.entity and not repairing and wagonNeedsPatch()
            end,
            onSelect = function() CreateThread(patchMyWagon) end,
        },
    })
end

-- spawn the player's owned wagon at coords (vector4) and register it with the server
spawnOwnedWagon = function(info, c, fadeIn)
    local hash = loadModel(info.model)
    if not hash then
        TriggerServerEvent('rsg-wagons:server:spawnFailed', info.id)
        notify(locale('cl_spawn_failed'), 'error')
        return false
    end
    local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    applyPaint(veh, info.livery, info.tint)
    local timeout = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < timeout do Wait(10) end
    if not DoesEntityExist(veh) then
        TriggerServerEvent('rsg-wagons:server:spawnFailed', info.id)
        notify(locale('cl_spawn_failed'), 'error')
        return false
    end

    PlaceEntityOnGroundProperly(veh, true)
    SetEntityAsMissionEntity(veh, true, true)
    local max = GetEntityMaxHealth(veh)
    if max and max > 0 and info.condition and info.condition < 100 then
        SetEntityHealth(veh, math.max(1, math.floor(max * info.condition / 100)), 0)
    end
    if fadeIn then fadeInEntity(veh) end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdExistsOnAllMachines(netId, true)
    myWagon = { id = info.id, entity = veh, netId = netId, name = info.name, model = info.model, condition = info.condition }
    addWagonTarget(veh)
    addWagonBlip(veh, info.name)
    TriggerServerEvent('rsg-wagons:server:registerSpawned', info.id, netId)
    return true
end

RegisterNUICallback('takeOut', function(data, cb)
    local ok, info = RSGCore.Functions.AwaitCallback('rsg-wagons:server:takeOut', 8000, currentStore, data.id)
    cb({ ok = ok == true })
    if not ok then return end
    closeUI()
    if spawnOwnedWagon(info, info.coords, false) then
        notify(locale('cl_wagon_ready', info.name), 'success')
    end
end)

-- ===================== NPCS / TARGETS / BLIPS =====================
local function spawnNpc(key, store)
    local hash = loadModel(store.npcModel)
    if not hash then return end
    local n = store.npc
    local ped = CreatePed(hash, n.x, n.y, n.z - 1.0, n.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    npcs[key] = ped

    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'rsg_wagons_shop_' .. key,
            icon = 'fa-solid fa-horse-head',
            label = locale('cl_browse'),
            distance = Config.InteractDistance,
            onSelect = function() openShop(key) end,
        },
    })
end

CreateThread(function()
    for key, store in pairs(Config.Stores) do
        if Config.Blip.enabled and store.showBlip ~= false then
            local blip = BlipAddForCoords(1664425300, store.npc.x, store.npc.y, store.npc.z)
            SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
            SetBlipScale(blip, Config.Blip.scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, store.label) -- SetBlipName
            blips[#blips + 1] = blip
        end
        spawnNpc(key, store)
    end
end)

-- watch the active wagon: wrecked -> must be returned at a yard; gone from the world -> just "away" (call it with J)
CreateThread(function()
    while true do
        Wait(2000)
        if myWagon and not myWagon.destroyed and myWagon.entity and myWagon.entity ~= 0 then
            if DoesEntityExist(myWagon.entity) and IsEntityDead(myWagon.entity) then
                TriggerServerEvent('rsg-wagons:server:condition', 0, true)
                notify(locale('cl_wagon_destroyed'), 'error')
                if Config.FieldRepair.enabled and Config.FieldRepair.command then notify(locale('cl_patch_hint', Config.FieldRepair.command), 'inform') end
                local id, name, model = myWagon.id, myWagon.name, myWagon.model
                clearMyWagon()
                myWagon = { id = id, entity = 0, netId = 0, name = name, model = model, destroyed = true } -- still "out" server side until stored at a yard
            elseif DoesEntityExist(myWagon.entity) then
                local cond = wagonCondition()
                if cond ~= myWagon.condition then
                    myWagon.condition = cond
                    TriggerServerEvent('rsg-wagons:server:condition', cond, false)
                end
            else
                exports['rsg-target']:removeLocalEntity(myWagon.entity)
                removeWagonBlip()
                myWagon.entity, myWagon.netId = 0, 0
            end
        end
    end
end)

-- dress every player wagon in view the way its owner set it up (state bag 'rsgWagonLook').
-- Propsets/tints aren't synced by the game, so every client applies them itself.
CreateThread(function()
    local applied = {}
    while true do
        Wait(2500)
        local seen = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local look = Entity(veh).state.rsgWagonLook
            if look and not (customOpen and myWagon and veh == myWagon.entity) then
                seen[veh] = true
                local key = ('%s|%s|%s|%s|%s'):format(look.livery, look.tint, look.propset or '', look.lantern or '', look.tarp or '')
                if applied[veh] ~= key then
                    applyLook(veh, look)
                    applied[veh] = key
                end
            end
        end
        for veh in pairs(applied) do
            if not seen[veh] then applied[veh], paintToken[veh], propToken[veh] = nil, nil, nil end
        end
    end
end)

-- call key (J) + commands
CreateThread(function()
    if not Config.CallKey then return end
    while true do
        if myWagon and not uiOpen and not customOpen then
            if IsControlJustReleased(0, Config.CallKey) then CreateThread(callMyWagon) end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
if Config.FieldRepair.enabled and Config.FieldRepair.command then
    RegisterCommand(Config.FieldRepair.command, function() CreateThread(patchMyWagon) end, false)
end
if Config.CallCommand then RegisterCommand(Config.CallCommand, function() CreateThread(callMyWagon) end, false) end
if Config.FleeCommand then RegisterCommand(Config.FleeCommand, function() CreateThread(fleeMyWagon) end, false) end

-- ===================== STORE PROMPT (near a yard) =====================
local storePrompt, storeGroup = nil, GetRandomIntInRange(0, 0xffffff)

local function createStorePrompt()
    storePrompt = Citizen.InvokeNative(0x04F97DE45A519419) -- UiPromptRegisterBegin
    Citizen.InvokeNative(0xB5352B7494A08258, storePrompt, Config.StoreKey) -- UiPromptSetControlAction
    Citizen.InvokeNative(0x5DD02A8318420DD7, storePrompt, VarString(10, 'LITERAL_STRING', locale('cl_store_wagon'))) -- UiPromptSetText
    Citizen.InvokeNative(0x8A0FB4D03A630D21, storePrompt, true) -- UiPromptSetEnabled
    Citizen.InvokeNative(0x71215ACCFDE075EE, storePrompt, true) -- UiPromptSetVisible
    Citizen.InvokeNative(0x94073D5CA3F16B7B, storePrompt, Config.StoreHoldTime) -- UiPromptSetHoldMode
    Citizen.InvokeNative(0x2F11D3A254169EA4, storePrompt, storeGroup, 0) -- UiPromptSetGroup
    Citizen.InvokeNative(0xF7AA2696A22AD8B9, storePrompt) -- UiPromptRegisterEnd
end

local function nearYardWithWagon()
    if not myWagon then return false end
    local pcoords = GetEntityCoords(PlayerPedId())
    local wcoords = (myWagon.entity ~= 0 and DoesEntityExist(myWagon.entity)) and GetEntityCoords(myWagon.entity) or pcoords
    local r = Config.StoreRadius - 2.0 -- small margin under the server check
    for _, store in pairs(Config.Stores) do
        local npc = vector3(store.npc.x, store.npc.y, store.npc.z)
        local prev = vector3(store.preview.x, store.preview.y, store.preview.z)
        if math.min(#(pcoords - npc), #(pcoords - prev)) <= r and math.min(#(wcoords - npc), #(wcoords - prev)) <= r then
            return true
        end
    end
    return false
end

CreateThread(function()
    if not Config.StorePrompt then return end
    createStorePrompt()
    while true do
        local sleep = 500
        if not uiOpen and not storing and nearYardWithWagon() then
            sleep = 0
            Citizen.InvokeNative(0xC65A45D4453C2627, storeGroup, VarString(10, 'LITERAL_STRING', locale('cl_title')), 1, 0, 0, 0) -- UiPromptSetActiveGroupThisFrame
            if Citizen.InvokeNative(0xE0F65F0640EF0617, storePrompt) then -- UiPromptHasHoldModeCompleted
                storeMyWagon()
                Wait(1000)
            end
        end
        Wait(sleep)
    end
end)

-- ===================== CLEANUP =====================
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    endPreview()
    for _, ped in pairs(npcs) do
        if DoesEntityExist(ped) then
            exports['rsg-target']:removeLocalEntity(ped)
            DeleteEntity(ped)
        end
    end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    if storePrompt then Citizen.InvokeNative(0x00EDE88D4D13CF59, storePrompt) end -- UiPromptDelete
    if customOpen then SetNuiFocus(false, false) end
    clearMyWagon()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeUI()
    closeCustomise(true)
    clearMyWagon()
end)

-- ===================== RESTORE AFTER RESTART / RELOG =====================
-- a wagon that was out when the server restarted (or you logged off) is still out: it's "away" until you call it
RegisterNetEvent('rsg-wagons:client:restore', function(info)
    if myWagon or type(info) ~= 'table' then return end
    if info.wrecked then
        myWagon = { id = info.id, entity = 0, netId = 0, name = info.name, model = info.model, destroyed = true }
        notify(locale('cl_wagon_destroyed'), 'error')
        if Config.FieldRepair.enabled and Config.FieldRepair.command then notify(locale('cl_patch_hint', Config.FieldRepair.command), 'inform') end
        return
    end
    myWagon = { id = info.id, entity = 0, netId = 0, name = info.name, model = info.model, condition = info.condition }
    notify(locale('cl_wagon_restored', info.name), 'inform')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('rsg-wagons:server:restore')
end)

-- resource (re)started while already logged in
CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.isLoggedIn then TriggerServerEvent('rsg-wagons:server:restore') end
end)
