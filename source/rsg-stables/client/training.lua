-- rsg-stables: horse training (client)
lib.locale()

-- also applies tack stat bonuses (Config.TackBonuses), so it runs if either feature is on
local T = Config.Training or {}
local TB = Config.TackBonuses or {}
local TRAINING = T.enabled == true
if not (TRAINING or TB.enabled) then return end

-- attribute IDs: rsg-redm-brain data/rdr3-native-enums/PedAttribute__AttributeType.md
local STAT_ATTR = { health = 0, stamina = 1, speed = 5, accel = 6 }
if T.stats then for k, v in pairs(T.stats) do STAT_ATTR[k] = v.attribute end end
T.session = T.session or {}
T.riding = T.riding or {}

-- tack lookup: tackItemByHash[category][tostring(hash)] = item
local tackItemByHash = {}
for cat, items in pairs(Config.TackItems or {}) do
    tackItemByHash[cat] = {}
    for _, it in ipairs(items) do tackItemByHash[cat][tostring(it.hash)] = it end
end

local function tackBonuses(rawTack)
    local out = {}
    if not TB.enabled then return out end
    local tack = {}
    if type(rawTack) == 'string' and rawTack ~= '' then
        local ok, t = pcall(json.decode, rawTack)
        if ok and type(t) == 'table' then tack = t end
    elseif type(rawTack) == 'table' then tack = rawTack end
    for cat, hash in pairs(tack) do
        local item = tackItemByHash[cat] and tackItemByHash[cat][tostring(hash)]
        local bonus = (item and item.bonus) or (item and TB.categoryDefaults and TB.categoryDefaults[cat])
        if bonus then
            for stat, v in pairs(bonus) do out[stat] = (out[stat] or 0) + (tonumber(v) or 0) end
        end
    end
    return out
end

-- Natives: rsg-redm-brain natives/db/ATTRIBUTE.md
local GET_ATTRIBUTE_BONUS_RANK = 0x0EFA71F4B4330E04
local SET_ATTRIBUTE_BONUS_RANK = 0x920F9488BD115EFB

local horse = nil      -- { entity, id, baseBonus = { [attr] = rank }, training }
local nuiOpen = false
local activeToken = nil

-- bonus rank = breed's own bonus + tack + training
local function applyTraining()
    if not (horse and DoesEntityExist(horse.entity)) then return end
    for key, attr in pairs(STAT_ATTR) do
        local s = horse.training and horse.training.stats[key]
        local lvl = s and s.level or 0
        local base = horse.baseBonus[attr] or 0
        local tack = horse.tackBonus[key] or 0
        Citizen.InvokeNative(SET_ATTRIBUTE_BONUS_RANK, horse.entity, attr, base + tack + lvl * (T.bonusPerLevel or 1))
    end
end

local function refresh()
    if not horse or not TRAINING then return end
    local data = lib.callback.await('rsg-stables:server:getTraining', false)
    if data and horse and data.horseId == horse.id then
        horse.training = data
        applyTraining()
    end
    return data
end

local function nearStable()
    local coords = GetEntityCoords(cache.ped)
    for _, stable in ipairs(Config.Stables) do
        for _, p in ipairs({ stable.pedCoords, stable.storeCoords, stable.previewCoords }) do
            if p and #(coords - vector3(p.x, p.y, p.z)) <= T.session.stableDistance then return true end
        end
    end
    return false
end

local function closeTraining()
    nuiOpen = false
    if activeToken then -- session paid but never finished: settle it so the server frees it
        local tk = activeToken
        CreateThread(function() lib.callback.await('rsg-stables:server:finishTraining', false, tk, 0) end)
    end
    activeToken = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'trainingClose' })
    if horse and DoesEntityExist(horse.entity) then ClearPedTasks(horse.entity) end
end

local function trainingStrings()
    local s = {}
    for _, k in ipairs({ 'training_title', 'training_health', 'training_stamina', 'training_speed', 'training_accel', 'training_courage',
        'training_level', 'training_maxed', 'training_train_btn', 'training_hint', 'training_round',
        'training_hit', 'training_miss', 'training_cooldown_ui', 'ui_close' }) do
        s[k] = locale(k)
    end
    return s
end

local function openTraining()
    if not horse or not DoesEntityExist(horse.entity) then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return
    end
    if GetMount(cache.ped) == horse.entity then
        lib.notify({ description = locale('training_dismount'), type = 'error' })
        return
    end
    local data = refresh()
    if not data then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return
    end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'trainingOpen', data = data, order = T.statOrder, strings = trainingStrings() })
end

exports('GetHorseBonusInfo', function()
    if not horse then return nil end
    return { tack = horse.tackBonus, training = horse.training }
end)

AddEventHandler('rsg-stables:client:openTraining', function()
    if TRAINING and T.session.enabled then openTraining() end
end)

-- ===================== SPAWN HOOK (fired from client.lua spawnHorse) =====================
AddEventHandler('rsg-stables:client:horseSpawned', function(entity, horseRow)
    horse = { entity = entity, id = horseRow.id, baseBonus = {}, tackBonus = tackBonuses(horseRow.tack), training = nil }
    for _, attr in pairs(STAT_ATTR) do
        horse.baseBonus[attr] = Citizen.InvokeNative(GET_ATTRIBUTE_BONUS_RANK, entity, attr, Citizen.ResultAsInteger()) or 0
    end
    if (T.courageFromBonding or 0) > 0 and STAT_ATTR.courage then
        local fromBond = math.floor((tonumber(horseRow.bonding) or 0) / T.courageFromBonding)
        horse.tackBonus.courage = (horse.tackBonus.courage or 0) + fromBond
    end
    applyTraining()
    CreateThread(refresh)

    if TRAINING and T.session.enabled then
        exports.ox_target:addLocalEntity(entity, {
            {
                name = 'rsg_stables_train',
                icon = 'fas fa-horse-head',
                label = locale('target_train'),
                distance = 2.5,
                canInteract = function() return GetMount(cache.ped) ~= entity and nearStable() end,
                onSelect = openTraining,
            },
        })
    end
end)

RegisterNetEvent('rsg-stables:client:trainingUpdate', function(horseId, data)
    if horse and horse.id == horseId then
        data.horseId = horseId
        horse.training = data
        applyTraining()
    end
end)

-- ===================== RIDE TICKS =====================
if TRAINING and T.riding.enabled then
    CreateThread(function()
        while true do
            Wait(T.riding.interval * 1000)
            if horse and DoesEntityExist(horse.entity) and GetMount(cache.ped) == horse.entity then
                TriggerServerEvent('rsg-stables:server:trainingRideTick')
            end
        end
    end)
end

-- ===================== NUI =====================
RegisterNUICallback('trainingStart', function(data, cb)
    if not (horse and DoesEntityExist(horse.entity)) then cb({ ok = false }) return end
    local ok, res = lib.callback.await('rsg-stables:server:startTraining', false, data.stat, NetworkGetNetworkIdFromEntity(horse.entity))
    if not ok then
        lib.notify({ description = res, type = 'error' })
        cb({ ok = false })
        return
    end
    activeToken = res.token
    TaskStandStill(horse.entity, -1)
    TaskTurnPedToFaceEntity(cache.ped, horse.entity, 2000)
    cb({ ok = true, rounds = res.rounds, roundMs = res.roundMs })
end)

RegisterNUICallback('trainingFinish', function(data, cb)
    local token = activeToken
    activeToken = nil
    if horse and DoesEntityExist(horse.entity) then ClearPedTasks(horse.entity) end
    if not token then cb({ ok = false }) return end
    local ok, res = lib.callback.await('rsg-stables:server:finishTraining', false, token, data.hits)
    if not ok then
        if res then lib.notify({ description = res, type = 'error' }) end
        cb({ ok = false })
        return
    end
    if horse then
        res.training.horseId = horse.id
        horse.training = res.training
        applyTraining()
    end
    lib.notify({ title = locale('training_title'), description = locale('training_complete', res.gain, locale('training_' .. res.stat)), type = 'success' })
    local fresh = refresh()
    cb({ ok = true, data = fresh })
end)

RegisterNUICallback('trainingClose', function(_, cb)
    -- closing mid-session still completes it (with the rounds hit so far reported by the NUI)
    closeTraining()
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if nuiOpen then SetNuiFocus(false, false) end
    if horse and DoesEntityExist(horse.entity) then
        pcall(function() exports.ox_target:removeLocalEntity(horse.entity, 'rsg_stables_train') end)
        for _, attr in pairs(STAT_ATTR) do
            Citizen.InvokeNative(SET_ATTRIBUTE_BONUS_RANK, horse.entity, attr, horse.baseBonus[attr] or 0)
        end
    end
end)
