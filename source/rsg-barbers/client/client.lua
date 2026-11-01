local RSGCore = exports['rsg-core']:GetCoreObject()
local RESOURCE = GetCurrentResourceName()

local CreatorCache = {}
local current = nil      -- active barber location
local cam = nil
local textureId = -1
local busy = false

local function notify(title, description, ntype)
    RSGCore.Functions.Notify({ title = title, description = description, type = ntype, duration = 5000 })
end

local function genderKey(ped)
    return IsPedMale(ped or PlayerPedId()) and 'male' or 'female'
end

---------------------------------------------------------------------
-- ped variation helpers
---------------------------------------------------------------------
local function UpdatePedVariation(ped)
    Citizen.InvokeNative(0x704C908E9C405136, ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    local timeout = GetGameTimer() + 2000
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and GetGameTimer() < timeout do Wait(0) end
end

local function SetComponent(ped, hash)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, false, true, true)
    UpdatePedVariation(ped)
end

local CATEGORY_HASH = { hair = 0x864B03AE, beard = 0xF8016BCA }

local function LoadHairCategory(ped, category)
    local sel = CreatorCache[category]
    if type(sel) ~= 'table' then return end
    local hash = Barber.ResolveHash(genderKey(ped), category, sel.model, sel.texture)
    if hash and hash ~= 0 then
        SetComponent(ped, hash)
    elseif hash == 0 then
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, CATEGORY_HASH[category], 0)
        UpdatePedVariation(ped)
    end
end

local function GetMaxTextures(category, model)
    local list = hairs_list[genderKey()][category]
    local entry = list[(model and model > 0) and model or 1]
    return entry and #entry or 1
end

---------------------------------------------------------------------
-- overlays
---------------------------------------------------------------------
local function ChangeOverlay(name, visibility, tx_id, tx_color_type, palette_id, c1, c2, var, opacity)
    for _, v in pairs(overlay_all_layers) do
        if v.name == name then
            v.visibility = visibility
            if visibility ~= 0 then
                v.tx_normal, v.tx_material, v.tx_color_type, v.tx_opacity, v.tx_unk = 0, 0, tx_color_type, 1.0, 0
                if tx_color_type == 0 then
                    v.palette = color_palettes[palette_id] and color_palettes[palette_id][1] or color_palettes[1][1]
                    v.palette_color_primary, v.palette_color_secondary, v.palette_color_tertiary = c1, c2, 0
                end
                if name == 'shadows' or name == 'eyeliners' or name == 'lipsticks' then
                    v.var = var
                    v.tx_id = overlays_info[name][1].id
                else
                    v.var = 0
                    v.tx_id = (overlays_info[name][tx_id] or overlays_info[name][1]).id
                end
                v.opacity = opacity
            end
        end
    end
end

local function ApplyOverlays(ped)
    local settings = texture_types[genderKey(ped)]
    if textureId ~= -1 then
        Citizen.InvokeNative(0xB63B9178D0F58D82, textureId)
        Citizen.InvokeNative(0x6BEFAA907B076859, textureId)
    end
    textureId = Citizen.InvokeNative(0xC5E7204F322E49EB, settings.albedo, settings.normal, settings.material)
    for _, v in pairs(overlay_all_layers) do
        if v.visibility ~= 0 then
            local id = Citizen.InvokeNative(0x86BB5FF45F193A02, textureId, v.tx_id, v.tx_normal, v.tx_material, v.tx_color_type, v.tx_opacity, v.tx_unk)
            if v.tx_color_type == 0 then
                Citizen.InvokeNative(0x1ED8588524AC9BE1, textureId, id, v.palette)
                Citizen.InvokeNative(0x2DF59FFE6FFD6044, textureId, id, v.palette_color_primary, v.palette_color_secondary, v.palette_color_tertiary)
            end
            Citizen.InvokeNative(0x3329AAE2882FC8E4, textureId, id, v.var)
            Citizen.InvokeNative(0x6C76BC24F8BB709A, textureId, id, v.opacity)
        end
    end
    local timeout = GetGameTimer() + 3000
    while not Citizen.InvokeNative(0x31DC8D3F216D8509, textureId) and GetGameTimer() < timeout do Wait(0) end
    Citizen.InvokeNative(0x92DAABA2C1C10B0E, textureId)
    Citizen.InvokeNative(0x8472A1789478F82F, textureId)
    Citizen.InvokeNative(0x0B46E25761519058, ped, `heads`, textureId)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
end

local function n(key) return tonumber(CreatorCache[key]) end

local function LoadOverlays(ped)
    local d = CreatorCache
    if n('eyebrows_t') and n('eyebrows_op') then
        ChangeOverlay('eyebrows', 1, n('eyebrows_t'), 0, n('eyebrows_id') or 1, n('eyebrows_c1') or 0, 0, 0, n('eyebrows_op') / 100)
    else
        ChangeOverlay('eyebrows', 1, 1, 0, 10, 0, 0, 0, 1.0)
    end
    for _, name in ipairs({ 'scars', 'ageing', 'freckles', 'moles', 'spots' }) do
        if n(name .. '_t') and n(name .. '_op') then
            ChangeOverlay(name, 1, n(name .. '_t'), 1, 0, 0, 0, 0, n(name .. '_op') / 100)
        end
    end
    if n('eyeliners_t') and n('eyeliners_op') then
        ChangeOverlay('eyeliners', 1, 1, 0, n('eyeliners_id') or 1, n('eyeliners_c1') or 0, 0, n('eyeliners_t'), n('eyeliners_op') / 100)
    end
    if n('shadows_t') and n('shadows_op') then
        ChangeOverlay('shadows', 1, 1, 0, n('shadows_id') or 1, n('shadows_c1') or 0, 0, n('shadows_t'), n('shadows_op') / 100)
    end
    if n('lipsticks_t') and n('lipsticks_op') then
        ChangeOverlay('lipsticks', 1, 1, 0, n('lipsticks_id') or 1, n('lipsticks_c1') or 0, n('lipsticks_c2') or 0, n('lipsticks_t'), n('lipsticks_op') / 100)
    end
    if n('blush_t') and n('blush_op') then
        ChangeOverlay('blush', 1, n('blush_t'), 0, n('blush_id') or 1, n('blush_c1') or 0, 0, 0, n('blush_op') / 100)
    end
    if d.beardstabble_t ~= nil and n('beardstabble_op') then
        ChangeOverlay('beardstabble', 1, 1, 0, 10, 0, 0, 0, n('beardstabble_op') / 100)
    end
    ApplyOverlays(ped)
end

---------------------------------------------------------------------
-- session
---------------------------------------------------------------------
local function SeedCache(skin)
    CreatorCache = {}
    for k, v in pairs(skin) do
        if type(v) ~= 'table' then CreatorCache[k] = tonumber(v) or v end
    end
    local gender = genderKey()
    for _, cat in ipairs({ 'hair', 'beard' }) do
        local m, t = Barber.FindModel(gender, cat, Barber.StoredHash(gender, cat, skin[cat]))
        CreatorCache[cat] = { model = m, texture = t }
    end
    for _, layer in pairs(overlay_all_layers) do layer.visibility = 0 end
end

local function CloseBarber(reloadSkin)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if cam then
        RenderScriptCams(false, true, 1000, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, true)
        cam = nil
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    current = nil

    if reloadSkin then
        Wait(1000)
        local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, ped, Citizen.ResultAsFloat())
        local stamina = maxStamina > 0 and (Citizen.InvokeNative(0x775A1CA7893AA8B5, ped, Citizen.ResultAsFloat()) / maxStamina * 100) or 100
        exports['rsg-character']:ApplySkin() -- reverts preview / applies saved style, keeps health
        Citizen.InvokeNative(0xC3D4B754C0E86B9E, PlayerPedId(), stamina)
    end
    if textureId ~= -1 then
        Citizen.InvokeNative(0x6BEFAA907B076859, textureId)
        textureId = -1
    end
    CreatorCache = {}
    busy = false
end

---------------------------------------------------------------------
-- NUI data
---------------------------------------------------------------------
local function HairFields()
    local fields = {}
    local cats = IsPedMale(PlayerPedId()) and { 'hair', 'beard' } or { 'hair' }
    for _, cat in ipairs(cats) do
        local sel = CreatorCache[cat]
        local has = sel.model > 0
        fields[#fields + 1] = { key = cat .. ':model', label = locale(cat .. '_style'), kind = 'style',
            min = 0, max = #hairs_list[genderKey()][cat], value = sel.model }
        fields[#fields + 1] = { key = cat .. ':texture', label = locale(cat .. '_color'), kind = 'color',
            min = has and 1 or 0, max = has and GetMaxTextures(cat, sel.model) or 0, value = has and sel.texture or 0 }
    end
    return fields
end

local function MakeupFields()
    local fields = {}
    local male = IsPedMale(PlayerPedId())
    for _, def in ipairs(Config.Makeup) do
        if male or not def.maleOnly then
            local v = n(def.key) or def.default
            fields[#fields + 1] = { key = def.key, label = locale(def.label), kind = def.label == 'opacity' and 'percent' or 'number',
                min = def.min, max = def.max, step = def.hop or 1, value = math.max(def.min, math.min(def.max, v)) }
        end
    end
    return fields
end

local function UiStrings()
    local keys = { 'barber_title', 'menu_hair_beard', 'menu_makeup', 'none', 'style_n', 'color_n',
        'ui_cancel', 'ui_pay', 'ui_price', 'ui_hint', 'ui_saving' }
    local t = {}
    for _, k in ipairs(keys) do t[k] = locale(k) end
    return t
end

local MAKEUP = {}
for _, def in ipairs(Config.Makeup) do MAKEUP[def.key] = def end

RegisterNUICallback('change', function(data, cb)
    if not current or type(data) ~= 'table' then return cb({}) end
    local value = math.tointeger(tonumber(data.value))
    if not value then return cb({}) end
    local ped = PlayerPedId()
    local cat, part = tostring(data.key):match('^(%a+):(%a+)$')

    if cat and CreatorCache[cat] and (cat == 'hair' or (cat == 'beard' and IsPedMale(ped))) then
        local sel = CreatorCache[cat]
        if part == 'model' then
            local max = #hairs_list[genderKey()][cat]
            if value < 0 or value > max or value == sel.model then return cb({}) end
            sel.model, sel.texture = value, 1
            LoadHairCategory(ped, cat)
            local has = value > 0
            return cb({ update = { key = cat .. ':texture', min = has and 1 or 0, max = has and GetMaxTextures(cat, value) or 0, value = has and 1 or 0 } })
        elseif part == 'texture' then
            if sel.model == 0 or value < 1 or value > GetMaxTextures(cat, sel.model) then return cb({}) end
            sel.texture = value
            LoadHairCategory(ped, cat)
        end
        return cb({})
    end

    local def = MAKEUP[data.key]
    if def and value >= def.min and value <= def.max and (IsPedMale(ped) or not def.maleOnly) then
        CreatorCache[def.key] = value
        LoadOverlays(ped)
    end
    cb({})
end)

local REASONS = {
    no_money   = function(r) notify(locale('no_money_title'), locale('no_money', r.price or Config.BarberCost), 'error') end,
    no_changes = function() notify(locale('barber_title'), locale('no_changes'), 'inform') end,
    too_far    = function() notify(locale('barber_title'), locale('too_far'), 'error') end,
    busy       = function() notify(locale('barber_title'), locale('busy'), 'warning') end,
}
local KEEP_OPEN = { no_money = true, no_changes = true, busy = true }

RegisterNUICallback('save', function(_, cb)
    if not current then return cb({ ok = false }) end
    local payload = { hair = CreatorCache.hair }
    if IsPedMale(PlayerPedId()) then payload.beard = CreatorCache.beard end
    for _, def in ipairs(Config.Makeup) do payload[def.key] = CreatorCache[def.key] end

    local result = RSGCore.Functions.AwaitCallback('rsg-barbers:server:purchase', 10000, current.barberid, payload)
    if result and result.ok then
        cb({ ok = true })
        return CloseBarber(true)
    end
    local handler = REASONS[result and result.reason]
    if handler then handler(result) else notify(locale('barber_title'), locale('error'), 'error') end
    local keep = result and KEEP_OPEN[result.reason] or false
    cb({ ok = false, keepOpen = keep })
    if not keep then CloseBarber(true) end
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    if current then CloseBarber(true) end
end)

---------------------------------------------------------------------
-- open
---------------------------------------------------------------------
RegisterNetEvent('rsg-barbers:client:open', function(barberid)
    if busy then return end
    local loc = Barber.GetLocation(barberid)
    local ped = PlayerPedId()
    if not loc or IsEntityDead(ped) or IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end
    if #(GetEntityCoords(ped) - loc.coords) > 2.5 then return notify(locale('barber_title'), locale('too_far'), 'error') end
    busy = true

    local data = RSGCore.Functions.AwaitCallback('rsg-character:server:getAppearance', 10000)
    if not data or not data.skin then
        busy = false
        return notify(locale('barber_title'), locale('error'), 'error')
    end
    SeedCache(data.skin)
    current = loc

    ClearPedTasks(ped)
    Citizen.InvokeNative(0x4D1F61FC34AF3CD1, ped, `PROP_PLAYER_BARBER_SEAT`, loc.seat.x, loc.seat.y, loc.seat.z, loc.seat.w, 0, false, true) -- TaskStartScenarioAtPosition
    FreezeEntityPosition(ped, true)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, loc.camPos.x, loc.camPos.y, loc.camPos.z)
    SetCamRot(cam, loc.camRot.x, loc.camRot.y, loc.camRot.z, 2)
    SetCamFov(cam, GetGameplayCamFov())
    RenderScriptCams(true, true, 2000, true, true)

    SendNUIMessage({
        action = 'open',
        strings = UiStrings(),
        shop = loc.name,
        price = Barber.GetPrice(loc),
        align = Config.MenuAlign,
        tabs = {
            { id = 'hair', label = locale('menu_hair_beard'), fields = HairFields() },
            { id = 'makeup', label = locale('menu_makeup'), fields = MakeupFields() },
        },
    })
    SetNuiFocus(true, true)

    CreateThread(function()
        while current == loc do
            DrawLightWithRange(loc.lighting.x, loc.lighting.y, loc.lighting.z, 255, 255, 255, 2.5, 50.0)
            Wait(0)
        end
    end)
end)

-- legacy event name
AddEventHandler('rsg-barber:client:menu', function(barberid) TriggerEvent('rsg-barbers:client:open', barberid) end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    SetNuiFocus(false, false)
    if not busy then return end
    if cam then RenderScriptCams(false, false, 0, true, true); DestroyCam(cam, true) end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    if textureId ~= -1 then Citizen.InvokeNative(0x6BEFAA907B076859, textureId) end
end)
