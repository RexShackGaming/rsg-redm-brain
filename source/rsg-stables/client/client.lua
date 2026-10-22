local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local stablePeds = {}
local stableBlips = {}
local activeHorse = nil -- { entity = int, dbId = int, maxhealth = int, snapshot = table, hunger = num, thirst = num }
local horseBlip = nil
local pendingHorse = nil -- horse that is 'out' in the DB but has no entity (fled, or restored after relog); whistle recalls it
local recallPendingHorse
local NuiStatsDialog
local CARE_COOLDOWN = 60000 -- ms; mirrors server.lua's CARE_COOLDOWN (client-side cooldown is UX only, server enforces the real limit)
local HORSE_TARGETS = { 'rsg_stables_feed', 'rsg_stables_water', 'rsg_stables_brush', 'rsg_stables_stats', 'rsg_stables_store', 'rsg_stables_flee', 'rsg_stables_inventory' }

local function healthPctOf(entity)
    return math.floor((GetEntityHealth(entity) / math.max(1, GetEntityMaxHealth(entity))) * 100)
end

local function staminaPctOf(entity, default)
    return math.floor(tonumber(Citizen.InvokeNative(0x36731AC041289BB1, entity, 1)) or default or 0) -- _GET_ATTRIBUTE_CORE_VALUE (stamina)
end

-- ===================== UTIL =====================

local function loadModel(model)
    local hash
    if type(model) == 'string' then
        hash = tonumber(model) or joaat(model)
    else
        hash = model
    end
    if not IsModelValid(hash) then
        print(('[rsg-stables] WARNING: invalid model "%s" (hash %s) — check the spelling in config.lua'):format(tostring(model), tostring(hash)))
        return nil
    end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(50)
        timeout = timeout + 50
    end
    if not HasModelLoaded(hash) then
        print(('[rsg-stables] WARNING: model "%s" did not stream in within 5s'):format(tostring(model)))
        return nil
    end
    return hash
end

-- ===================== TACK =====================
local function applyTackItem(entity, itemHash)
    itemHash = tonumber(itemHash)
    if not itemHash or itemHash == 0 then return end
    Citizen.InvokeNative(0xD3A7B003ED343FD9, entity, itemHash, true, true, true)
end

local function applyTackTable(entity, tack)
    if not tack then return end
    for _, category in ipairs(Config.TackCategories) do
        local hash = tack[category.key]
        if hash then applyTackItem(entity, hash) end
    end
end

local function decodeTack(raw)
    if not raw or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then return t end
    return {}
end

local tackItemIndex = {}
for categoryKey, items in pairs(Config.TackItems) do
    tackItemIndex[categoryKey] = {}
    for _, item in ipairs(items) do
        tackItemIndex[categoryKey][tostring(item.hash)] = item
    end
end

local function getTackItem(categoryKey, hash)
    local byHash = tackItemIndex[categoryKey]
    if not byHash then return nil end
    return byHash[tostring(hash)]
end

local function tackItemLabel(categoryKey, hash)
    if not hash or hash == 0 then return locale('none') end
    local item = getTackItem(categoryKey, hash)
    return item and item.label or locale('none')
end

-- blip function
local function AddLocationBlip(x, y, z, sprite, color, scale, label)
    local blip = BlipAddForCoords(1664425300, x, y, z)
    SetBlipSprite(blip, joaat(sprite), true)
    SetBlipScale(blip, scale)
    BlipAddModifier(blip, joaat(color))
    SetBlipName(blip, label)
    return blip
end

local function fmtTimeLeft(msLeft)
    if msLeft <= 0 then return locale('time_ready') end
    local mins = math.ceil(msLeft / 60000)
    if mins >= 60 then
        return locale('time_hours_minutes', mins // 60, mins % 60)
    end
    return locale('time_minutes', mins)
end

-- ===================== HORSE SPAWN / DESPAWN =====================

local function despawnActiveHorseEntity()
    if activeHorse and activeHorse.entity and DoesEntityExist(activeHorse.entity) then
        pcall(function()
            exports.ox_target:removeLocalEntity(activeHorse.entity, HORSE_TARGETS)
        end)
        DeleteEntity(activeHorse.entity)
    end
    if horseBlip and DoesBlipExist(horseBlip) then
        RemoveBlip(horseBlip)
    end
    horseBlip = nil
    activeHorse = nil
end

local whistleToken = 0
local HORSE_NOSE_OFFSET = 1.3 -- approx distance from a horse's centre to its nose

-- Walk/run the horse to a spot in front of the player, stop there and face the player
local function sendHorseToPlayer(entity, playerPed)
    whistleToken = whistleToken + 1
    local token = whistleToken
    local stopDist = (Config.WhistleStopDistance or 1.0) + HORSE_NOSE_OFFSET

    local function targetPoint()
        local pc = GetEntityCoords(playerPed)
        local fwd = GetEntityForwardVector(playerPed)
        return vector3(pc.x + fwd.x * stopDist, pc.y + fwd.y * stopDist, pc.z)
    end

    CreateThread(function()
        local target = targetPoint()
        ClearPedTasks(entity)
        TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, 2.5, 0, false, 786603, 0xbf800000)

        local walking = false
        local deadline = GetGameTimer() + 60000
        while token == whistleToken and DoesEntityExist(entity) and not IsEntityDead(entity) and GetGameTimer() < deadline do
            Wait(100)
            if GetMount(playerPed) == entity then return end

            local horsePos = GetEntityCoords(entity)
            local dist = #(horsePos.xy - target.xy)

            -- re-target if the player moved, and drop to a walk for the final approach
            local newTarget = targetPoint()
            local moved = #(newTarget.xy - target.xy) > 1.0
            local wantWalk = dist < 6.0
            if moved or (wantWalk and not walking) then
                target = newTarget
                walking = wantWalk
                TaskGoToCoordAnyMeans(entity, target.x, target.y, target.z, walking and 1.0 or 2.5, 0, false, 786603, 0xbf800000)
            end

            if dist <= 0.6 then
                ClearPedTasks(entity)
                TaskTurnPedToFaceEntity(entity, playerPed, 1500)
                return
            end
        end
    end)
end

local function whistleActiveHorse()
    if not (activeHorse and activeHorse.entity and DoesEntityExist(activeHorse.entity)) then return end
    if IsEntityDead(activeHorse.entity) then return end

    local entity = activeHorse.entity
    local playerPed = PlayerPedId()

    if GetMount(playerPed) == entity then return end

    local playerCoords = GetEntityCoords(playerPed)
    local horseCoords = GetEntityCoords(entity)
    local distance = #(playerCoords - horseCoords)

    -- too far away: move it close to the player first, then it walks the last few metres
    if distance > Config.WhistleTeleportDistance then
        local heading = GetEntityHeading(playerPed)
        local rad = math.rad(-heading)
        local x = playerCoords.x + 5.0 * math.sin(rad)
        local y = playerCoords.y + 5.0 * math.cos(rad)
        SetEntityCoords(entity, x, y, playerCoords.z, false, false, false, true)
        SetEntityHeading(entity, heading + 180.0)
    end
    sendHorseToPlayer(entity, playerPed)
end

local function whistlePressed()
    return IsControlJustPressed(0, `INPUT_WHISTLE`) or IsDisabledControlJustPressed(0, `INPUT_WHISTLE`)
end

local function pollWhistle()
    if not whistlePressed() then return end
    if IsPedDeadOrDying(cache.ped, true) then return end

    -- script-spawned horses don't trigger the game's own whistle, so play it ourselves
    if Config.WhistleAnim ~= false and not IsPedInAnyVehicle(cache.ped, false) then
        TaskWhistleAnim(cache.ped, joaat(Config.WhistleAnim or 'WHISTLEHORSESHORT'), joaat('UNSPECIFIED'))
    end

    -- activeHorse is set but the game removed the entity (culled, cleaned up, etc.):
    -- fall back to a recall so the whistle still brings the horse back
    if activeHorse and not (activeHorse.entity and DoesEntityExist(activeHorse.entity)) then
        local snapshot = activeHorse.snapshot
        if snapshot then
            snapshot.hunger = activeHorse.hunger or snapshot.hunger
            snapshot.thirst = activeHorse.thirst or snapshot.thirst
            snapshot.bonding = activeHorse.bonding or snapshot.bonding
        end
        if horseBlip and DoesBlipExist(horseBlip) then RemoveBlip(horseBlip) end
        horseBlip = nil
        activeHorse = nil
        if snapshot then pendingHorse = snapshot end
    end

    if activeHorse then
        whistleActiveHorse()
    elseif pendingHorse and recallPendingHorse then
        recallPendingHorse()
    end
end

-- ===================== PREVIEW HORSE =====================

local previewPed = nil
local previewCam = nil
local previewCamActive = false
local previewRotateDir = nil
local previewZoomDelta = 0.0
local previewRadius = 3.5
local PREVIEW_RADIUS_MIN = 1.5
local PREVIEW_RADIUS_MAX = 7.0

RegisterNUICallback('rotateCam', function(data, cb)
    previewRotateDir = data and data.dir or nil
    cb('ok')
end)

RegisterNUICallback('zoomCam', function(data, cb)
    local dir = data and data.dir or 0
    previewZoomDelta = previewZoomDelta + (dir * 0.35)
    cb('ok')
end)

local function applyOutfit(entity, outfitNum)
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, entity, outfitNum, true)
end

local function initAndApplyOutfit(entity, outfitNum)
    Citizen.InvokeNative(0x45EEE61580806D63, entity)
    Wait(150)
    if DoesEntityExist(entity) then
        applyOutfit(entity, outfitNum)
    end
end

local function destroyPreviewCam()
    previewCamActive = false
    previewRotateDir = nil
    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        if DoesCamExist(previewCam) then DestroyCam(previewCam, false) end
        previewCam = nil
    end
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
    end
end

local function despawnPreviewHorse()
    destroyPreviewCam()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

local function startPreviewCam(entity)
    local coords = GetEntityCoords(entity)

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 500, true, true)
    FreezeEntityPosition(PlayerPedId(), true)
    previewCamActive = true
    previewRotateDir = nil
    previewZoomDelta = 0.0
    previewRadius = 3.5

    CreateThread(function()
        local angle = 0.0
        local height = 1.3
        local rotateSpeed = 60.0 -- degrees per second while holding a rotate control

        while previewCamActive and previewCam and DoesCamExist(previewCam) do
            local frameTime = GetFrameTime()
            local delta = rotateSpeed * frameTime

            if previewRotateDir == 'left' then
                angle = angle - delta
            elseif previewRotateDir == 'right' then
                angle = angle + delta
            end
            angle = angle % 360.0

            if previewZoomDelta ~= 0.0 then
                previewRadius = math.max(PREVIEW_RADIUS_MIN, math.min(PREVIEW_RADIUS_MAX, previewRadius + previewZoomDelta))
                previewZoomDelta = 0.0
            end

            local rad = math.rad(angle)
            local camX = coords.x + math.cos(rad) * previewRadius
            local camY = coords.y + math.sin(rad) * previewRadius
            local camZ = coords.z + height

            SetCamCoord(previewCam, camX, camY, camZ)
            PointCamAtCoord(previewCam, coords.x, coords.y, coords.z + 0.7)

            Wait(0)
        end
    end)
end

local function spawnPreviewPed(model, previewCoords, outfitNum, tack, coat)
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    previewPed = nil

    if not (previewCoords and previewCoords.x and previewCoords.y and previewCoords.z) then
        print('[rsg-stables] WARNING: spawnPreviewPed called with missing/malformed previewCoords — check stable.previewCoords in shared/config.lua')
        lib.notify({ description = locale('preview_load_failed'), type = 'error' })
        return nil
    end

    local hash = loadModel(model)
    if not hash then
        lib.notify({ description = locale('preview_load_failed'), type = 'error' })
        return nil
    end

    local entity = CreatePed(hash, previewCoords.x, previewCoords.y, previewCoords.z, previewCoords.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(hash)

    if not DoesEntityExist(entity) then
        lib.notify({ description = locale('preview_spawn_failed'), type = 'error' })
        return nil
    end

    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetEntityCollision(entity, false, false)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetPedCanBeTargetted(entity, false)
    TaskStartScenarioInPlace(entity, 'WORLD_HORSE_IDLE_GRAZE', 0, true)

    previewPed = entity
    initAndApplyOutfit(entity, outfitNum or 0)
    applyTackTable(entity, tack)
    if coat then HorseCoat.Apply(entity, coat) end

    return entity
end

local function spawnPreviewHorse(model, previewCoords, outfitNum, tack, coat)
    despawnPreviewHorse()
    local entity = spawnPreviewPed(model, previewCoords, outfitNum, tack, coat)
    if entity then
        startPreviewCam(entity)
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        if previewPed then
            local ped = PlayerPedId()
            if not DoesEntityExist(previewPed)
                or #(GetEntityCoords(ped) - GetEntityCoords(previewPed)) > 10.0 then
                despawnPreviewHorse()
            end
        end
    end
end)

-- ===================== HORSE CARE / STORE (ox_target prompts on the active horse) =====================
local lastFeedAt, lastBrushAt, lastWaterAt = 0, 0, 0
local function bumpHorseNeed(key, amount, defaultValue)
    if not activeHorse then return end
    local current = activeHorse[key] or defaultValue or 100
    activeHorse[key] = math.max(0, math.min(100, current + amount))
end

local function pushBondingToNative(horse)
    if not (horse and DoesEntityExist(horse) and activeHorse) then return end
    Citizen.InvokeNative(0x5DA12E025D47D4E5, horse, 7, math.floor(activeHorse.bonding or 0))
end

local function feedActiveHorse(preferredItem)
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then return end
    if IsEntityDead(activeHorse.entity) then
        lib.notify({ description = locale('horse_is_dead'), type = 'error' })
        return
    end
    local now = GetGameTimer()
    if now - lastFeedAt < CARE_COOLDOWN then
        lib.notify({ description = locale('not_hungry'), type = 'inform' })
        return
    end

    local ok, result = lib.callback.await('rsg-stables:server:feedHorse', false, preferredItem)
    if not ok then
        lib.notify({ description = result or locale('no_feed'), type = 'error' })
        return
    end
    lastFeedAt = now

    local horse = activeHorse.entity
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, horse, 800)
    Wait(800)
    TaskAnimalInteraction(ped, horse, -224471938, 0, 0) -- hand-feed animation

    SetTimeout(2000, function()
        if not DoesEntityExist(horse) then return end

        -- health/stamina restored are percentage points (0-100 scale), added to current and
        -- capped at 100 — not an instant full refill like the old flat behaviour.
        local maxHp = GetEntityMaxHealth(horse)
        local healthPct = (GetEntityHealth(horse) / math.max(1, maxHp)) * 100
        local newHealthPct = math.min(100, healthPct + (result.health or 0))
        SetEntityHealth(horse, math.max(1, math.floor((newHealthPct / 100) * maxHp)))

        local staminaPct = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, horse, 1)) or 0
        local newStaminaPct = math.min(100, staminaPct + (result.stamina or 0))
        Citizen.InvokeNative(0x675680D089BFA21F, horse, newStaminaPct) -- RESTORE_PED_STAMINA

        if activeHorse then
            if result.hunger then activeHorse.hunger = result.hunger end
            if Config.HorseBonding.enabled and result.bonding then
                activeHorse.bonding = result.bonding
                pushBondingToNative(horse)
            end
        end

        lib.notify({ description = locale('horse_enjoyed', result.label or locale('feed_generic')), type = 'success' })
    end)
end

-- ===================== HORSE STIMULANT =====================
local stimulant = { entity = nil, endsAt = 0 }

local function applyStimulantFortify(horse, cfg)
    Citizen.InvokeNative(0x675680D089BFA21F, horse, 100.0)                          -- RESTORE_PED_STAMINA (full refill)
    Citizen.InvokeNative(0xC6258F41D86676E0, horse, 1, 100)                         -- _SET_ATTRIBUTE_CORE_VALUE (stamina core)
    Citizen.InvokeNative(0x4AF5A4C7B9157D14, horse, 1, cfg.fortifyAmount, true)     -- _ENABLE_ATTRIBUTE_CORE_OVERPOWER (gold core)
    Citizen.InvokeNative(0xF6A7C08DF2E28B28, horse, 1, cfg.fortifyAmount, true)     -- _ENABLE_ATTRIBUTE_OVERPOWER (gold bar)
end

local function stimulantActive()
    return stimulant.entity ~= nil
        and activeHorse ~= nil
        and activeHorse.entity == stimulant.entity
        and DoesEntityExist(stimulant.entity)
        and not IsEntityDead(stimulant.entity)
        and GetGameTimer() < stimulant.endsAt
end

local function startStimulantLoop(horse, durationSec)
    local cfg = Config.HorseStimulant
    local alreadyRunning = stimulant.entity ~= nil
    stimulant.entity = horse
    stimulant.endsAt = GetGameTimer() + durationSec * 1000
    applyStimulantFortify(horse, cfg)
    if alreadyRunning then return end

    -- stamina top-up + fortify refresh (every 5s)
    CreateThread(function()
        local warned = false
        while stimulantActive() do
            local h = stimulant.entity
            local stam = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, h, 1)) or 0
            if stam < cfg.staminaFloor then
                Citizen.InvokeNative(0xC6258F41D86676E0, h, 1, cfg.staminaFloor) -- keep core topped up
            end
            Citizen.InvokeNative(0x675680D089BFA21F, h, 100.0)                  -- keep bar topped up
            if not warned and stimulant.endsAt - GetGameTimer() <= 60000 then
                warned = true
                lib.notify({ description = locale('stimulant_wearing_off'), type = 'inform' })
            end
            Wait(5000)
        end
        local expiredNaturally = stimulant.entity and GetGameTimer() >= stimulant.endsAt
        stimulant.entity, stimulant.endsAt = nil, 0
        if expiredNaturally then
            lib.notify({ description = locale('stimulant_worn_off'), type = 'inform' })
        end
    end)

    -- speed boost while mounted (move-rate override is per-frame)
    if (cfg.speedMultiplier or 1.0) > 1.0 then
        CreateThread(function()
            while stimulantActive() do
                local h = stimulant.entity
                if GetMount(cache.ped) == h then
                    SetPedMoveRateOverride(h, cfg.speedMultiplier + 0.0)
                    Wait(0)
                else
                    Wait(500)
                end
            end
        end)
    end
end

RegisterNetEvent('rsg-stables:client:useStimulant', function()
    local cfg = Config.HorseStimulant
    if not (cfg and cfg.enabled) then return end
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return
    end
    local horse = activeHorse.entity
    if IsEntityDead(horse) then
        lib.notify({ description = locale('horse_is_dead'), type = 'error' })
        return
    end
    local mounted = GetMount(cache.ped) == horse
    if not mounted and #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) > cfg.useDistance then
        lib.notify({ description = locale('must_be_near_horse'), type = 'error' })
        return
    end

    local ok, result = lib.callback.await('rsg-stables:server:useStimulant', false)
    if not ok then
        lib.notify({ description = result or locale('stimulant_failed'), type = 'error' })
        return
    end

    TaskAnimalInteraction(cache.ped, horse, -1355254781, GetHashKey('p_cs_syringe01x'), 0)
    Wait(3000)

    if not DoesEntityExist(horse) then return end

    startStimulantLoop(horse, result.duration)
    lib.notify({ description = locale('stimulant_active', math.floor(result.duration / 60)), type = 'success' })
end)

local function waterActiveHorse()
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then return end
    if IsEntityDead(activeHorse.entity) then
        lib.notify({ description = locale('horse_is_dead'), type = 'error' })
        return
    end
    local now = GetGameTimer()
    if now - lastWaterAt < CARE_COOLDOWN then
        lib.notify({ description = locale('not_thirsty'), type = 'inform' })
        return
    end

    local ok, result = lib.callback.await('rsg-stables:server:waterHorse', false)
    if not ok then
        lib.notify({ description = result or locale('no_water'), type = 'error' })
        return
    end
    lastWaterAt = now

    local horse = activeHorse.entity
    TaskAnimalInteraction(PlayerPedId(), horse, -224471938, 0, 0)

    SetTimeout(2000, function()
        if not DoesEntityExist(horse) then return end

        local staminaPct = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, horse, 1)) or 0
        local newStaminaPct = math.min(100, staminaPct + (result.stamina or 0))
        Citizen.InvokeNative(0x675680D089BFA21F, horse, newStaminaPct) -- RESTORE_PED_STAMINA

        -- Same as feedActiveHorse: thirst/bonding are the server's authoritative session values.
        if activeHorse then
            if result.thirst then activeHorse.thirst = result.thirst end
            if Config.HorseBonding.enabled and result.bonding then
                activeHorse.bonding = result.bonding
                pushBondingToNative(horse)
            end
        end

        lib.notify({ description = locale('horse_drank', result.label or locale('water_generic')), type = 'success' })
    end)
end

local function brushActiveHorse()
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then return end
    if IsEntityDead(activeHorse.entity) then
        lib.notify({ description = locale('horse_is_dead'), type = 'error' })
        return
    end
    local now = GetGameTimer()
    if now - lastBrushAt < CARE_COOLDOWN then
        lib.notify({ description = locale('already_clean'), type = 'inform' })
        return
    end

    local ok, result = lib.callback.await('rsg-stables:server:brushHorse', false)
    if not ok then
        lib.notify({ description = result or locale('already_clean'), type = 'inform' })
        return
    end
    lastBrushAt = now

    local horse = activeHorse.entity
    TaskAnimalInteraction(PlayerPedId(), horse, 554992710, `P_BRUSHHORSE02X`, 0)

    SetTimeout(4000, function()
        if not DoesEntityExist(horse) then return end
        ClearPedEnvDirt(horse)
        ClearPedDamageDecalByZone(horse, 10, 'ALL')
        ClearPedBloodDamage(horse)
        Citizen.InvokeNative(0x5DA12E025D47D4E5, horse, 16, 0)

        if activeHorse and Config.HorseBonding.enabled and result.bonding then
            activeHorse.bonding = result.bonding
            pushBondingToNative(horse)
        end

        lib.notify({ description = locale('brushed'), type = 'success' })
    end)
end

-- Inventory-use checks shared by the feed items and the brush: horse out, dismounted, close by
local function canCareFromInventory(dismountKey, tooFarKey)
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return false
    end
    if GetMount(cache.ped) == activeHorse.entity then
        lib.notify({ description = locale(dismountKey), type = 'error' })
        return false
    end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(activeHorse.entity)) > (Config.HorseBrushDistance or 3.0) then
        lib.notify({ description = locale(tooFarKey), type = 'error' })
        return false
    end
    return true
end

-- Using a feed item (horse_apple, horse_carrot, ...) from the inventory
RegisterNetEvent('rsg-stables:client:useFeed', function(item)
    if canCareFromInventory('feed_dismount', 'feed_too_far') then feedActiveHorse(item) end
end)

-- Using the horse_brush item from the inventory
RegisterNetEvent('rsg-stables:client:useBrush', function()
    if canCareFromInventory('brush_dismount', 'brush_too_far') then brushActiveHorse() end
end)

local function showActiveHorseStats()
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return
    end

    local horse = activeHorse.entity
    local healthPct = healthPctOf(horse)
    local stamina = staminaPctOf(horse, 0)

    local hunger = math.floor(activeHorse.hunger or 100)
    local thirst = math.floor(activeHorse.thirst or 100)
    local bonding = math.floor(activeHorse.bonding or 0)
    local dirtiness = math.floor(math.max(0, math.min(100, tonumber(Citizen.InvokeNative(0xA4C8E23E29040DE0, horse, 16)) or 0)))
    local cleanliness = 100 - dirtiness

    NuiStatsDialog(locale('horse_stats'), {
        { label = locale('stat_health'),      value = healthPct },
        { label = locale('stat_stamina'),     value = stamina },
        { label = locale('stat_hunger'),      value = hunger },
        { label = locale('stat_thirst'),      value = thirst },
        { label = locale('stat_bonding'),     value = bonding },
        { label = locale('stat_cleanliness'), value = cleanliness },
    })
end

local function findNearestStoreableStable(coords)
    local nearestStable, nearestDist = nil, Config.StoreDistance
    for _, stable in ipairs(Config.Stables) do
        local distStore = #(coords - vector3(stable.storeCoords.x, stable.storeCoords.y, stable.storeCoords.z))
        local distPed = #(coords - vector3(stable.pedCoords.x, stable.pedCoords.y, stable.pedCoords.z))
        local dist = math.min(distStore, distPed)
        if dist <= nearestDist then
            nearestStable = stable
            nearestDist = dist
        end
    end
    return nearestStable
end

local function storeActiveHorse()
    if not activeHorse then
        lib.notify({ description = locale('no_active_horse'), type = 'error' })
        return
    end
    if not DoesEntityExist(activeHorse.entity) then
        despawnActiveHorseEntity()
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local nearestStable = findNearestStoreableStable(coords)

    if not nearestStable then
        lib.notify({ description = locale('not_close_to_stable'), type = 'error' })
        return
    end

    local ok, err = lib.callback.await('rsg-stables:server:storeHorse', false, activeHorse.dbId, healthPctOf(activeHorse.entity), staminaPctOf(activeHorse.entity, 100))
    if ok then
        lib.notify({ description = locale('store_success'), type = 'success' })
        despawnActiveHorseEntity()
    else
        lib.notify({ description = err or locale('store_fail'), type = 'error' })
    end
end

local isHorseFleeing = false

local function fleeActiveHorse()
    if not Config.HorseFlee.enabled then return end
    if isHorseFleeing then return end
    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then return end
    if IsEntityDead(activeHorse.entity) then
        lib.notify({ description = locale('horse_is_dead'), type = 'error' })
        return
    end

    isHorseFleeing = true

    local horse = activeHorse
    local horsePed = horse.entity
    local snapshot = horse.snapshot

    pcall(function()
        exports.ox_target:removeLocalEntity(horsePed, HORSE_TARGETS)
    end)
    if activeHorse and activeHorse.entity == horsePed then
        activeHorse = nil
    end

    if horseBlip and DoesBlipExist(horseBlip) then
        RemoveBlip(horseBlip)
    end
    horseBlip = nil

    lib.notify({ description = locale('horse_flees'), type = 'inform' })
    TaskAnimalFlee(horsePed, cache.ped, -1)

    CreateThread(function()
        Wait(Config.HorseFlee.fleeDelay or 10000)

        if DoesEntityExist(horsePed) then
            local healthPct = healthPctOf(horsePed)

            local stored = Config.HorseFlee.storeOnFlee
                and lib.callback.await('rsg-stables:server:fleeStoreHorse', false, horse.dbId, healthPct, staminaPctOf(horsePed, 100))
            if stored then
                pendingHorse = nil
            elseif snapshot then
                local fc = GetEntityCoords(horsePed)
                local fh = GetEntityHeading(horsePed)
                TriggerServerEvent('rsg-stables:server:saveHorsePosition', horse.dbId, fc.x, fc.y, fc.z, fh, healthPct)
                pendingHorse = snapshot
                pendingHorse.pos_x, pendingHorse.pos_y, pendingHorse.pos_z, pendingHorse.pos_h = fc.x, fc.y, fc.z, fh
                pendingHorse.health = healthPct
                pendingHorse.hunger = horse.hunger or 100
                pendingHorse.thirst = horse.thirst or 100
                pendingHorse.bonding = horse.bonding or 0
            end

            SetEntityAsMissionEntity(horsePed, true, true)
            DeleteEntity(horsePed)
        end

        isHorseFleeing = false
    end)
end

CreateThread(function()
    while true do
        if activeHorse or pendingHorse then
            Wait(0)

            pollWhistle()

            -- hide the native horse Brush / Feed prompts (use the ox_target options instead)
            if Config.HideNativeBrushFeed and activeHorse then
                DisableControlAction(0, `INPUT_INTERACT_HORSE_BRUSH`, true)
                DisableControlAction(0, `INPUT_INTERACT_HORSE_FEED`, true)
            end

            -- native Horse Cargo prompt (B) opens the horse's rsg-inventory stash instead
            if Config.HorseInventory.enabled and Config.HorseInventory.nativeCargoPrompt and activeHorse and DoesEntityExist(activeHorse.entity)
                and not IsNuiFocused() then
                local ped = cache.ped
                if not IsPedOnMount(ped) and #(GetEntityCoords(ped) - GetEntityCoords(activeHorse.entity)) < 3.0
                    and IsControlJustReleased(0, 0x5966D52A) then -- INPUT_OPEN_SATCHEL_HORSE_MENU
                    TriggerServerEvent('rsg-stables:server:openHorseInventory', activeHorse.dbId, NetworkGetNetworkIdFromEntity(activeHorse.entity))
                end
            end

            if activeHorse and DoesEntityExist(activeHorse.entity) then
                local numEvents = GetNumberOfEvents(0)
                if numEvents > 0 then
                    for i = 0, numEvents - 1 do
                        if GetEventAtIndex(0, i) == `EVENT_PLAYER_PROMPT_TRIGGERED` then
                            local eventData = DataView.ArrayBuffer(80)
                            for a = 0, 9 do
                                eventData:SetInt32(8 * a, 0)
                            end
                            local ok = Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, i, eventData:Buffer(), 10)
                            if ok and eventData:GetInt32(0) == 33 and activeHorse and activeHorse.entity == eventData:GetInt32(16) then
                                fleeActiveHorse()
                            end
                        end
                    end
                end
            end
        else
            Wait(400)
        end
    end
end)

local function spawnHorse(horse, coords)
    despawnActiveHorseEntity() -- never leave a previous horse entity orphaned
    local player = PlayerId()
    local hash = loadModel(horse.model)
    if not hash then
        lib.notify({ description = locale('model_load_failed'), type = 'error' })
        return
    end

    local horsePed = CreatePed(hash, coords.x, coords.y, coords.z, coords.w, true, false, 0, 0)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(horsePed) then
        lib.notify({ description = locale('model_load_failed'), type = 'error' })
        return
    end
    initAndApplyOutfit(horsePed, math.floor(tonumber(horse.outfit) or 0))
    applyTackTable(horsePed, decodeTack(horse.tack))
    if horse.coat and horse.coat ~= '' then HorseCoat.Apply(horsePed, horse.coat) end
    SetEntityAsMissionEntity(horsePed, true, true)
    SetBlockingOfNonTemporaryEvents(horsePed, true)
    SetPedCanBeTargetted(horsePed, false)
    Citizen.InvokeNative(0xD2CB0FB0FDCB473D, player, horsePed) -- SetPedAsSaddleHorseForPlayer
    Citizen.InvokeNative(0xB8B6430EAD2D2437, horsePed, `PLAYER_HORSE`) -- SetPedPersonality

    local horseFlags = {
        [6] = true,
        [113] = false,
        [136] = false,
        [208] = true,
        [209] = true,
        [211] = true,
        [277] = true,
        [297] = true,
        [300] = false,
        [301] = false,
        [312] = false,
        [319] = true,
        [400] = true,
        [412] = false,
        [419] = false,
        [438] = false,
        [439] = false,
        [440] = false,
        [561] = true
    }
    for flag, val in pairs(horseFlags) do
        Citizen.InvokeNative(0x1913FE4CBF41C463, horsePed, flag, val); -- SetPedConfigFlag (kind of sets defaultbehavior)
    end

    local horseTunings = { 24, 25, 48 }
    for _, flag in ipairs(horseTunings) do
        Citizen.InvokeNative(0x1913FE4CBF41C463, horsePed, flag, false); -- SetHorseTuning
    end

    horseBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, horsePed) -- BlipAddForEntity
    Citizen.InvokeNative(0x9CB1A1623062F402, horseBlip, horse.name) -- SetBlipName
    Citizen.InvokeNative(0xFE26E4609B1C3772, horsePed, "HorseCompanion", true) -- DecorSetBool
    Citizen.InvokeNative(0xA691C10054275290, cache.ped, horsePed, 0) -- unknown
    Citizen.InvokeNative(0x931B241409216C1F, cache.ped, horsePed, false) -- SetPedOwnsAnimal
    Citizen.InvokeNative(0xED1C764997A86D5A, cache.ped, horsePed) -- unknown
    Citizen.InvokeNative(0xDF93973251FB2CA5, player, true) -- SetPlayerMountStateActive
    if not Config.AllowTwoPlayersRide then
        Citizen.InvokeNative(0xe6d4e435b56d5bd0, player, horsePed) -- SetPlayerOwnsMount
    end
    Citizen.InvokeNative(0xAEB97D84CDF3C00B, horsePed, false) -- SetAnimalIsWild
    Citizen.InvokeNative(0xA691C10054275290, horsePed, player, 431)
    Citizen.InvokeNative(0x6734F0A6A52C371C, player, 431)
    Citizen.InvokeNative(0x024EC9B649111915, horsePed, true)
    Citizen.InvokeNative(0xEB8886E1065654CD, horsePed, 10, "ALL", 0)
    SetEntityCanBeDamaged(horsePed, true)
    SetPedNameDebug(horsePed, horse.name)
    SetPedPromptName(horsePed, horse.name)
    Citizen.InvokeNative(0xCC97B29285B1DC3B, horsePed, 1) -- SetAnimalMood

    local retrieveHealthPct = math.max(0, math.min(100, tonumber(horse.health) or 100))
    SetEntityHealth(horsePed, math.max(1, math.floor((retrieveHealthPct / 100) * GetEntityMaxHealth(horsePed))))
    SetPedConfigFlag(horsePed, 5, true) -- disable frozen physics after cutscene guard

    lastFeedAt, lastBrushAt, lastWaterAt = 0, 0, 0

    local targetOk, targetErr = pcall(function()
        exports.ox_target:addLocalEntity(horsePed, {
            {
                name = 'rsg_stables_feed',
                icon = 'fas fa-wheat-awn',
                label = locale('target_feed'),
                distance = 2.5,
                onSelect = function() feedActiveHorse() end,
            },
            {
                name = 'rsg_stables_water',
                icon = 'fas fa-glass-water',
                label = locale('target_water'),
                distance = 2.5,
                canInteract = function() return Config.HorseNeeds.enabled end,
                onSelect = waterActiveHorse,
            },
            {
                name = 'rsg_stables_brush',
                icon = 'fas fa-brush',
                label = locale('target_brush'),
                distance = 2.5,
                onSelect = brushActiveHorse,
            },
            {
                name = 'rsg_stables_stats',
                icon = 'fas fa-chart-simple',
                label = locale('horse_stats'),
                distance = 2.5,
                onSelect = showActiveHorseStats,
            },
            {
                name = 'rsg_stables_store',
                icon = 'fas fa-warehouse',
                label = locale('target_store'),
                distance = 2.5,
                canInteract = function(entity)
                    return findNearestStoreableStable(GetEntityCoords(entity)) ~= nil
                end,
                onSelect = storeActiveHorse,
            },
            {
                name = 'rsg_stables_flee',
                icon = 'fas fa-person-running',
                label = locale('target_flee'),
                distance = 2.5,
                canInteract = function() return Config.HorseFlee.enabled end,
                onSelect = fleeActiveHorse,
            },
            {
                name = 'rsg_stables_inventory',
                icon = 'fas fa-box-open',
                label = locale('target_inventory'),
                distance = Config.HorseInventory.distance or 2.5,
                canInteract = function() return Config.HorseInventory.enabled end,
                onSelect = function()
                    if not (activeHorse and DoesEntityExist(activeHorse.entity)) then return end
                    TriggerServerEvent('rsg-stables:server:openHorseInventory', activeHorse.dbId, NetworkGetNetworkIdFromEntity(activeHorse.entity))
                end,
            },
        })
    end)
    if not targetOk then
        print(('[rsg-stables] WARNING: failed to register ox_target options on the active horse: %s'):format(tostring(targetErr)))
    end

    activeHorse = {
        entity = horsePed,
        dbId = horse.id,
        snapshot = horse,
        hunger = math.max(0, math.min(100, tonumber(horse.hunger) or 100)),
        thirst = math.max(0, math.min(100, tonumber(horse.thirst) or 100)),
        bonding = math.max(0, math.min(100, tonumber(horse.bonding) or 0)),
        ageDays = tonumber(horse.age_days) or 0,
    }
    pushBondingToNative(horsePed)
    pendingHorse = nil
end

local isRecallingHorse = false

local function groundZAt(x, y, zHint)
    for _, probe in ipairs({ zHint + 5.0, zHint + 50.0, 1000.0 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, probe, false)
        if found and gz and gz ~= 0.0 then return gz end
    end
    return zHint
end

recallPendingHorse = function()
    local snapshot = pendingHorse
    if not snapshot or isRecallingHorse then return end
    isRecallingHorse = true
    pendingHorse = nil

    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local cfg = Config.ActiveHorse or {}

    local spawnCoords
    local sx, sy, sz = tonumber(snapshot.pos_x), tonumber(snapshot.pos_y), tonumber(snapshot.pos_z)
    local savedDist = (sx and sy and sz) and #(playerCoords - vector3(sx, sy, sz)) or nil
    if savedDist and savedDist >= (cfg.minSpawnDistance or 25.0) and savedDist <= (cfg.recallMaxDistance or 150.0) then
        -- Horse is still where it was left: spawn it there and let it travel to the player
        spawnCoords = vector4(sx, sy, sz, tonumber(snapshot.pos_h) or 0.0)
    else
        -- Saved position is too close, too far or unknown: bring it in from behind the player
        local dist = math.max(cfg.respawnDistance or 30.0, cfg.minSpawnDistance or 25.0)
        local rad = math.rad(-heading)
        local x = playerCoords.x - dist * math.sin(rad)
        local y = playerCoords.y - dist * math.cos(rad)
        spawnCoords = vector4(x, y, groundZAt(x, y, playerCoords.z), heading)
    end

    spawnHorse(snapshot, spawnCoords)

    if activeHorse and DoesEntityExist(activeHorse.entity) then
        local entity = activeHorse.entity
        sendHorseToPlayer(entity, playerPed)
        lib.notify({ description = locale('horse_coming', snapshot.name or locale('your_horse')), type = 'success' })
    else
        pendingHorse = snapshot -- spawn failed, allow another whistle
        lib.notify({ description = locale('horse_cannot_reach'), type = 'error' })
    end

    isRecallingHorse = false
end

-- ===================== ACTIVE HORSE POSITION SAVING =====================

local lastSavedPos = nil

local function saveActiveHorsePosition(force)
    if not (activeHorse and activeHorse.entity and DoesEntityExist(activeHorse.entity)) then return end
    if IsEntityDead(activeHorse.entity) then return end

    local entity = activeHorse.entity
    local coords = GetEntityCoords(entity)
    local minMove = (Config.ActiveHorse and Config.ActiveHorse.minMoveToSave) or 2.0

    if not force and lastSavedPos and lastSavedPos.id == activeHorse.dbId and #(coords - lastSavedPos.coords) < minMove then
        return
    end

    local heading = GetEntityHeading(entity)
    local healthPct = healthPctOf(entity)

    TriggerServerEvent('rsg-stables:server:saveHorsePosition', activeHorse.dbId, coords.x, coords.y, coords.z, heading, healthPct)
    lastSavedPos = { id = activeHorse.dbId, coords = coords }

    if activeHorse.snapshot then
        local snap = activeHorse.snapshot
        snap.pos_x, snap.pos_y, snap.pos_z, snap.pos_h = coords.x, coords.y, coords.z, heading
        snap.health = healthPct
    end
end

CreateThread(function()
    while true do
        Wait((Config.ActiveHorse and Config.ActiveHorse.saveInterval) or 10000)
        saveActiveHorsePosition(false)
    end
end)

-- ===================== PED / BLIP SETUP =====================

local function setupStables()
    for _, stable in ipairs(Config.Stables) do
        CreateThread(function()
            local hash = loadModel(stable.pedModel)
            if not hash then return end

            local ped = CreatePed(hash, stable.pedCoords.x, stable.pedCoords.y, stable.pedCoords.z -1, stable.pedCoords.w, false, false, 0, 0)
            if not DoesEntityExist(ped) then
                print(('[rsg-stables] WARNING: CreatePed failed for stable "%s" (model %s)'):format(stable.name, tostring(stable.pedModel)))
                return
            end
            SetModelAsNoLongerNeeded(hash)
            Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SET_RANDOM_OUTFIT_VARIATION (not exposed as a Lua global in RedM)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

            stablePeds[stable.name] = ped

            exports.ox_target:addLocalEntity(ped, {
                {
                    name = 'rsg_stables_' .. stable.name,
                    icon = 'fas fa-horse',
                    label = locale('manage_stable', stable.label),
                    onSelect = function()
                        OpenStableMenu(stable)
                    end,
                },
                {
                    name = 'rsg_stables_claim_' .. stable.name,
                    icon = 'fas fa-hat-cowboy',
                    label = locale('claim_wild_horse'),
                    canInteract = function()
                        return Config.WildHorse and Config.WildHorse.enabled and GetBrokenWildHorse() ~= nil
                    end,
                    onSelect = function()
                        ClaimWildHorse(stable)
                    end,
                },
            })

            stableBlips[#stableBlips + 1] = AddLocationBlip(
                stable.pedCoords.x, stable.pedCoords.y, stable.pedCoords.z,
                stable.blip.sprite, stable.blip.color, stable.blip.scale, stable.label
            )
        end)
    end
end

-- ===================== NUI UI CORE =====================
local currentHandlers = {}
local pendingInputSubmit, pendingInputCancel = nil, nil
local pendingAlertClose = nil
local currentTackHandlers = nil
local currentCoatHandlers = nil

-- UI (NUI) strings are sent to the page from locales/*.json (ui_* keys)
local nuiLocaleSent = false
local UI_LOCALE_KEYS = { 'ui_stable', 'ui_back', 'ui_close', 'ui_prev_style', 'ui_next_style', 'ui_tack_hint', 'ui_rotate_zoom_hint', 'ui_total_spend', 'ui_insufficient_funds', 'ui_prev_category', 'ui_next_category', 'ui_review_apply', 'ui_input', 'ui_cancel', 'ui_confirm', 'ui_notice', 'ui_understood', 'ui_horse_stats', 'ui_coat_main', 'ui_coat_markings', 'ui_coat_nose', 'ui_coat_mane', 'ui_coat_tail', 'ui_coat_none', 'ui_coat_default', 'ui_coat_presets', 'ui_coat_apply', 'ui_coat_reset', 'ui_coat_no_change' }

local function SendNuiLocale()
    if nuiLocaleSent then return end
    local strings = {}
    for _, key in ipairs(UI_LOCALE_KEYS) do strings[key] = locale(key) end
    SendNUIMessage({ action = 'setLocale', strings = strings })
    nuiLocaleSent = true
end

local function OpenNUI()
    SendNuiLocale()
    SetNuiFocus(true, true)
end

local function CloseNUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

local function NuiNotify(description, ntype)
    lib.notify({ description = description, type = ntype or 'inform' })
end

local function NuiRender(screen)
    currentHandlers = {}
    currentTackHandlers = nil
    currentCoatHandlers = nil
    local opts = {}
    for i, o in ipairs(screen.options) do
        local id = tostring(i)
        currentHandlers[id] = o.onSelect
        table.insert(opts, {
            id = id,
            title = o.title,
            description = o.description,
            icon = o.icon,
            badge = o.badge,
            disabled = o.disabled or false,
            stats = o.stats,
            variant = o.variant,
        })
    end

    local backId = nil
    if screen.back then
        backId = '__back__'
        currentHandlers[backId] = screen.back
    end

    OpenNUI()
    SendNUIMessage({
        action = 'render',
        screen = {
            title = screen.title,
            subtitle = screen.subtitle,
            hint = screen.hint,
            backId = backId,
            options = opts,
        },
    })
end

local function NuiInput(title, placeholder, onSubmit, onCancel)
    OpenNUI()
    pendingInputSubmit = onSubmit
    pendingInputCancel = onCancel
    SendNUIMessage({ action = 'inputDialog', title = title, placeholder = placeholder, maxLength = 40 })
end

local function NuiAlert(header, content, onClose)
    OpenNUI()
    pendingAlertClose = onClose
    SendNUIMessage({ action = 'alertDialog', header = header, content = content })
end

-- ===================== WILD HORSE CLAIM =====================
-- global so the stable-ped target (defined above) can reach it at runtime
function ClaimWildHorse(stable)
    local horse = GetBrokenWildHorse()
    if not horse then return end
    NuiInput(locale('claim_wild_horse_name'), locale('unnamed_horse'), function(name)
        CloseNUI()
        local netId = NetworkGetNetworkIdFromEntity(horse)
        local ok, result = lib.callback.await('rsg-stables:server:claimWildHorse', false, stable.name, netId, name)
        if ok then
            ForgetBrokenWildHorse()
            if IsPedOnMount(cache.ped) and GetMount(cache.ped) == horse then
                TaskDismountAnimal(cache.ped, 1, 0, 0, 0, 0)
            end
            lib.notify({ description = locale('wild_claimed', result), type = 'success' })
        else
            lib.notify({ description = result or locale('generic_error'), type = 'error' })
        end
    end, function()
        CloseNUI()
    end)
end

NuiStatsDialog = function(header, stats, onClose)
    OpenNUI()
    pendingAlertClose = onClose
    SendNUIMessage({ action = 'statsDialog', header = header, stats = stats })
end

local function NuiTackPicker(data)
    currentHandlers = {}
    OpenNUI()
    SendNUIMessage({
        action = 'tackPicker',
        title = data.title,
        subtitle = data.subtitle,
        categoryIndex = data.categoryIndex,
        categoryCount = data.categoryCount,
        styleLabel = data.styleLabel,
        styleMeta = data.styleMeta,
        styleIndex = data.styleIndex,
        styleCount = data.styleCount,
        isLast = data.isLast,
        costTotal = data.costTotal,
        canAfford = data.canAfford,
    })
end

local function NuiCoatPicker(data)
    currentHandlers = {}
    currentTackHandlers = nil
    OpenNUI()
    SendNUIMessage({
        action = 'coatPicker',
        title = data.title,
        subtitle = data.subtitle,
        coat = data.coat,
        price = data.price,
        canAfford = data.canAfford,
        hasCustom = data.hasCustom,
        presets = data.presets,
    })
end

RegisterNUICallback('coatUpdate', function(data, cb)
    if currentCoatHandlers and currentCoatHandlers.update then currentCoatHandlers.update(data) end
    cb('ok')
end)

RegisterNUICallback('coatAction', function(data, cb)
    cb('ok')
    local fn = currentCoatHandlers and currentCoatHandlers[data.action]
    if fn and (data.action == 'apply' or data.action == 'reset' or data.action == 'cancel') then fn() end
end)

RegisterNUICallback('select', function(data, cb)
    local fn = currentHandlers[data.id]
    if fn then fn() end
    cb('ok')
end)

RegisterNUICallback('tackCycle', function(data, cb)
    if currentTackHandlers and currentTackHandlers.cycle then
        currentTackHandlers.cycle(data.dir)
    end
    cb('ok')
end)

RegisterNUICallback('tackCategoryNav', function(data, cb)
    if currentTackHandlers then
        if data.dir == 'next' and currentTackHandlers.nextCategory then
            currentTackHandlers.nextCategory()
        elseif data.dir == 'prev' and currentTackHandlers.prevCategory then
            currentTackHandlers.prevCategory()
        end
    end
    cb('ok')
end)

RegisterNUICallback('inputSubmit', function(data, cb)
    local fn = pendingInputSubmit
    pendingInputSubmit, pendingInputCancel = nil, nil
    if fn then fn(data.value) end
    cb('ok')
end)

RegisterNUICallback('inputCancel', function(data, cb)
    local fn = pendingInputCancel
    pendingInputSubmit, pendingInputCancel = nil, nil
    if fn then fn() end
    cb('ok')
end)

RegisterNUICallback('alertClose', function(data, cb)
    local fn = pendingAlertClose
    pendingAlertClose = nil
    CloseNUI()
    if fn then fn() end
    cb('ok')
end)

RegisterNUICallback('statsClose', function(data, cb)
    local fn = pendingAlertClose
    pendingAlertClose = nil
    CloseNUI()
    if fn then fn() end
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    CloseNUI()
    despawnPreviewHorse()
    currentTackHandlers = nil
    currentCoatHandlers = nil
    cb('ok')
end)

-- ===================== MENUS =====================

function OpenStableMenu(stable)
    despawnPreviewHorse()

    if activeHorse then
        NuiAlert(stable.label, locale('must_store_first'), CloseNUI)
        return
    end

    if pendingHorse then
        NuiAlert(stable.label, locale('horse_still_out_store', pendingHorse.name or locale('your_horse')), CloseNUI)
        return
    end

    local horses = lib.callback.await('rsg-stables:server:getStableHorses', false, stable.name)
    local breedingJobs = lib.callback.await('rsg-stables:server:getBreedingJobs', false, stable.name)

    local options = {
        {
            title = locale('buy_horse'),
            description = locale('buy_horse_desc'),
            icon = 'dollar',
            onSelect = function()
                OpenBuyMenu(stable)
            end,
        },
    }

    local aliveCount = 0
    for _, horse in ipairs(horses) do
        horse.alive = horse.alive == true or horse.alive == 1
        horse.insured = horse.insured == true or horse.insured == 1
        horse.died_of_age = horse.died_of_age == true or horse.died_of_age == 1
        if horse.alive then aliveCount = aliveCount + 1 end
    end
    if aliveCount >= 2 and Config.Breeding.enabled then
        table.insert(options, {
            title = locale('breed_horses'),
            description = locale('breed_horses_desc'),
            icon = 'heart',
            onSelect = function()
                OpenBreedingMenu(stable, horses)
            end,
        })
    end

    for _, job in ipairs(breedingJobs) do
        local ready = job.ready == true
        table.insert(options, {
            title = ready and locale('collect_foal') or locale('foal_growing', fmtTimeLeft(job.ms_left or 0)),
            description = ready and locale('foal_ready') or locale('foal_still_growing'),
            icon = 'foal',
            disabled = not ready,
            onSelect = function()
                local ok, err = lib.callback.await('rsg-stables:server:collectFoal', false, job.id)
                if ok then
                    NuiNotify(locale('foal_collected'), 'success')
                else
                    NuiNotify(err or locale('foal_collect_failed'), 'error')
                end
                OpenStableMenu(stable)
            end,
        })
    end

    for _, horse in ipairs(horses) do
        local desc, badge
        if horse.alive then
            desc = locale('horse_health_stamina', horse.health, horse.stamina)
            if horse.gender then desc = locale(horse.gender == 'male' and 'gender_stallion' or 'gender_mare') .. ' • ' .. desc end
            if horse.stage then
                local stageText = locale('stage_' .. horse.stage)
                local cfgA = Config.HorseAging
                local left = (cfgA.lifespanDays or 0) - (tonumber(horse.age_days) or 0)
                if horse.stage == 'old' and left <= (cfgA.warnDays or 7) then
                    stageText = stageText .. ' (' .. locale('days_left', math.max(left, 0)) .. ')'
                end
                desc = stageText .. ' • ' .. desc
            end
            badge = nil
        else
            desc = horse.died_of_age and locale('died_of_old_age') or locale('deceased')
            badge = locale('deceased')
        end
        table.insert(options, {
            title = horse.name,
            description = desc,
            icon = 'horse',
            badge = badge,
            onSelect = function()
                OpenHorseMenu(stable, horse)
            end,
        })
    end

    NuiRender({
        title = stable.label,
        subtitle = locale('stable_ledger'),
        options = options,
    })
end

local function getBuyFunds()
    local ok, playerData = pcall(function() return RSGCore.Functions.GetPlayerData() end)
    if ok and playerData and playerData.money then
        return playerData.money[Config.PaymentAccount] or 0
    end
    return 0
end

local function BreedStatBars(breed)
    local max = Config.BreedStatMax or 5
    return {
        { label = locale('stat_health'), value = breed.health, max = max },
        { label = locale('stat_stamina'), value = breed.stamina, max = max },
        { label = locale('stat_speed'), value = breed.speed, max = max },
        { label = locale('stat_accel'), value = breed.acceleration, max = max },
    }
end

-- ============================================================
-- Buy menu filters (class, breed, price, handling)
-- ============================================================
local BuyFilters = { class = nil, breed = nil, price = nil, handling = nil }

local function breedGroupLabel(b)
    -- "American Paint (Grey Overo)" -> "American Paint"
    return (b.label:match('^(.-)%s*%(') or b.label)
end

local function filterValue(b, key)
    if key == 'breed' then return breedGroupLabel(b) end
    return b[key]
end

local function priceBandMatches(band, price)
    if not band then return true end
    return price >= (band.min or 0) and (not band.max or price <= band.max)
end

local function breedMatches(b, skipKey)
    if skipKey ~= 'class' and BuyFilters.class and b.class ~= BuyFilters.class then return false end
    if skipKey ~= 'breed' and BuyFilters.breed and breedGroupLabel(b) ~= BuyFilters.breed then return false end
    if skipKey ~= 'handling' and BuyFilters.handling and b.handling ~= BuyFilters.handling then return false end
    if skipKey ~= 'price' and not priceBandMatches(BuyFilters.price, b.price) then return false end
    return true
end

local function activeFilterCount()
    local n = 0
    for _, v in pairs(BuyFilters) do if v then n = n + 1 end end
    return n
end

local FILTER_LABELS = { class = locale('filter_class'), breed = locale('filter_breed'), price = locale('filter_price'), handling = locale('filter_handling') }

local function filterDisplay(key)
    local v = BuyFilters[key]
    if not v then return locale('filter_any') end
    if key == 'price' then return v.label end
    return v
end

local function OpenFilterValueMenu(stable, key)
    local options = {
        {
            title = locale('filter_any'),
            description = locale('filter_clear_one'),
            icon = 'xmark',
            badge = BuyFilters[key] == nil and '✓' or nil,
            onSelect = function()
                BuyFilters[key] = nil
                OpenBuyFilterMenu(stable)
            end,
        },
    }

    if key == 'price' then
        for _, band in ipairs(Config.BuyPriceBands or {}) do
            local count = 0
            for _, b in ipairs(Config.Breeds) do
                if breedMatches(b, 'price') and priceBandMatches(band, b.price) then count = count + 1 end
            end
            table.insert(options, {
                title = band.label,
                description = locale('horse_count', count),
                icon = 'dollar',
                badge = (BuyFilters.price and BuyFilters.price.label == band.label) and '✓' or nil,
                disabled = count == 0,
                onSelect = function()
                    BuyFilters.price = band
                    OpenBuyFilterMenu(stable)
                end,
            })
        end
    else
        -- Collect distinct values, counting matches against the other active filters
        local counts, order = {}, {}
        for _, b in ipairs(Config.Breeds) do
            local v = filterValue(b, key)
            if v then
                if not counts[v] then counts[v] = 0; table.insert(order, v) end
                if breedMatches(b, key) then counts[v] = counts[v] + 1 end
            end
        end
        table.sort(order)
        for _, v in ipairs(order) do
            table.insert(options, {
                title = v,
                description = locale('horse_count', counts[v]),
                icon = 'horse',
                badge = BuyFilters[key] == v and '✓' or nil,
                disabled = counts[v] == 0,
                onSelect = function()
                    BuyFilters[key] = v
                    OpenBuyFilterMenu(stable)
                end,
            })
        end
    end

    NuiRender({
        title = locale('filter_by', FILTER_LABELS[key]),
        subtitle = stable.label,
        back = function() OpenBuyFilterMenu(stable) end,
        options = options,
    })
end

function OpenBuyFilterMenu(stable)
    local options = {}
    for _, key in ipairs({ 'class', 'breed', 'price', 'handling' }) do
        table.insert(options, {
            title = FILTER_LABELS[key],
            description = locale('filter_current', filterDisplay(key)),
            icon = 'filter',
            variant = BuyFilters[key] and 'filter-active' or 'filter',
            onSelect = function() OpenFilterValueMenu(stable, key) end,
        })
    end
    table.insert(options, {
        title = locale('filter_clear_all'),
        icon = 'xmark',
        disabled = activeFilterCount() == 0,
        onSelect = function()
            BuyFilters = { class = nil, breed = nil, price = nil, handling = nil }
            OpenBuyFilterMenu(stable)
        end,
    })

    NuiRender({
        title = locale('filter_horses'),
        subtitle = stable.label,
        back = function() OpenBuyMenu(stable) end,
        options = options,
    })
end

function OpenBuyMenu(stable)
    despawnPreviewHorse()

    local matches = {}
    for _, breed in ipairs(Config.Breeds) do
        if breedMatches(breed) then table.insert(matches, breed) end
    end

    local nFilters = activeFilterCount()
    local options = {
        {
            title = nFilters > 0 and locale('filters_active', nFilters) or locale('filter_horses'),
            description = nFilters > 0
                and locale('filters_showing', #matches, #Config.Breeds)
                or locale('filter_desc'),
            icon = 'filter',
            badge = nFilters > 0 and tostring(nFilters) or nil,
            variant = nFilters > 0 and 'filter-active' or 'filter',
            onSelect = function() OpenBuyFilterMenu(stable) end,
        },
    }

    if #matches == 0 then
        table.insert(options, {
            title = locale('filter_no_match'),
            description = locale('filter_no_match_desc'),
            icon = 'xmark',
            disabled = true,
        })
    end

    local funds = getBuyFunds()
    for _, breed in ipairs(matches) do
        local affordable = funds >= breed.price
        table.insert(options, {
            title = breed.label,
            description = affordable
                and locale('breed_class_handling', breed.class or breed.breed, breed.handling)
                or locale('breed_cant_afford_short', breed.class or breed.breed, breed.handling, breed.price - funds),
            badge = ('$%.2f'):format(breed.price),
            icon = 'horse',
            variant = not affordable and 'unaffordable' or nil,
            stats = BreedStatBars(breed),
            onSelect = function()
                OpenBreedPreviewMenu(stable, breed)
            end,
        })
    end

    NuiRender({
        title = locale('buy_horse'),
        subtitle = stable.label,
        back = function() OpenStableMenu(stable) end,
        options = options,
    })
end

local function showBreedPreviewContext(stable, breed)
    local options = {}

    if breed.description then
        table.insert(options, {
            title = locale('about_breed'),
            description = breed.description,
            icon = 'horse',
        })
    end

    local funds = getBuyFunds()
    if funds < breed.price then
        table.insert(options, {
            title = locale('cant_afford_horse'),
            description = locale('funds_short', funds, breed.price - funds),
            badge = ('$%.2f'):format(breed.price),
            icon = 'xmark',
            variant = 'unaffordable',
            disabled = true,
            stats = BreedStatBars(breed),
        })
    else
        table.insert(options, {
            title = locale('purchase_horse'),
            description = locale('breed_class_handling', breed.class or breed.breed, breed.handling),
            badge = ('$%.2f'):format(breed.price),
            icon = 'dollar',
            stats = BreedStatBars(breed),
            onSelect = function()
                despawnPreviewHorse()
    
                NuiInput(locale('name_your_horse'), locale('horse_name'), function(value)
                    if not value or value == '' then
                        spawnPreviewHorse(breed.model, stable.previewCoords)
                        showBreedPreviewContext(stable, breed)
                        return
                    end
    
                    local function buy(gender)
                        local ok, result = lib.callback.await('rsg-stables:server:buyHorse', false, stable.name, breed.model, value, 0, gender)
                        if ok then
                            NuiNotify(locale('purchase_success', value), 'success')
                        else
                            NuiNotify(result or locale('purchase_fail'), 'error')
                        end
                        OpenStableMenu(stable)
                    end

                    NuiRender({
                        title = locale('choose_gender'),
                        subtitle = value,
                        back = function()
                            spawnPreviewHorse(breed.model, stable.previewCoords)
                            showBreedPreviewContext(stable, breed)
                        end,
                        options = {
                            { title = locale('gender_stallion'), description = locale('gender_stallion_desc'), icon = 'mars',  onSelect = function() buy('male') end },
                            { title = locale('gender_mare'),     description = locale('gender_mare_desc'),     icon = 'venus', onSelect = function() buy('female') end },
                        },
                    })
                end, function()
                    spawnPreviewHorse(breed.model, stable.previewCoords)
                    showBreedPreviewContext(stable, breed)
                end)
            end,
        })
    end

    NuiRender({
        title = breed.label,
        subtitle = locale('horse_preview'),
        hint = locale('ui_rotate_zoom_hint'),
        back = function()
            despawnPreviewHorse()
            OpenBuyMenu(stable)
        end,
        options = options,
    })
end

function OpenBreedPreviewMenu(stable, breed)
    spawnPreviewHorse(breed.model, stable.previewCoords)
    showBreedPreviewContext(stable, breed)
end

function OpenBreedingMenu(stable, horses)
    local alive = {}
    for _, h in ipairs(horses) do
        if h.alive and h.stage ~= 'young' and h.stage ~= 'old' then table.insert(alive, h) end
    end

    if #alive < 2 then
        NuiNotify(locale('breed_need_two'), 'error')
        return
    end

    local options = {}
    for _, a in ipairs(alive) do
        table.insert(options, {
            title = a.name,
            description = (a.gender and (locale(a.gender == 'male' and 'gender_stallion' or 'gender_mare') .. ' • ') or '') .. locale('select_first_parent'),
            icon = 'horse',
            onSelect = function()
                local options2 = {}
                for _, b in ipairs(alive) do
                    local genderOk = Config.Breeding.requireOppositeGender == false or (a.gender and b.gender and a.gender ~= b.gender)
                    if b.id ~= a.id and genderOk then
                        table.insert(options2, {
                            title = b.name,
                            description = (b.gender and (locale(b.gender == 'male' and 'gender_stallion' or 'gender_mare') .. ' • ') or '') .. locale('select_second_parent'),
                            icon = 'horse',
                            onSelect = function()
                                local ok, err = lib.callback.await('rsg-stables:server:startBreeding', false, stable.name, a.id, b.id)
                                if ok then
                                    NuiNotify(locale('breeding_started'), 'success')
                                else
                                    NuiNotify(err or locale('breeding_failed'), 'error')
                                end
                                OpenStableMenu(stable)
                            end,
                        })
                    end
                end
                if #options2 == 0 then
                    NuiNotify(locale('breed_need_opposite_gender'), 'error')
                    return
                end
                NuiRender({
                    title = locale('choose_second_parent'),
                    subtitle = a.name,
                    back = function() OpenBreedingMenu(stable, horses) end,
                    options = options2,
                })
            end,
        })
    end

    NuiRender({
        title = locale('choose_first_parent'),
        subtitle = locale('breed_horses'),
        back = function() OpenStableMenu(stable) end,
        options = options,
    })
end

-- ===================== TACK MENU =====================
local function buildPreviewTack(baseTack, selections)
    local preview = {}
    for k, v in pairs(baseTack) do preview[k] = v end
    for k, v in pairs(selections) do
        if v == 0 then
            preview[k] = nil
        else
            preview[k] = v
        end
    end
    return preview
end

-- metaped category hashes for each tack slot (used to strip a slot in place)
local TackCategoryHashes = {
    saddle = 0xBAA7E618, blanket = 0x17CEB41A, saddlebags = 0x80451C25, horn = 0x05447332,
    stirrups = 0xDA6DADCA, bedroll = 0xEFB31921, tail = 0xA63CAE10, mane = 0xAA0217AB,
    mask = 0xD3500E5D, mustache = 0x30DEFDDF, holster = 0xAC106B30, bridle = 0x94B2E3AF,
    horseshoe = 0xFACFC3C0,
}
-- slots that fall back to the horse's natural look when emptied; stripping them leaves the horse bald,
-- so clearing one of these re-applies the base outfit instead
local NaturalSlots = { mane = true, tail = true }

local lastPreviewPed, lastPreviewTack = nil, {}

-- swaps only the changed tack slots on the existing preview horse (no despawn / respawn)
local function refreshTackPreview(stable, horse, baseTack, selections)
    if not (previewPed and DoesEntityExist(previewPed)) then return end
    local target = buildPreviewTack(baseTack, selections)

    if lastPreviewPed ~= previewPed then
        -- first change on this preview horse: it was spawned with baseTack
        lastPreviewPed = previewPed
        lastPreviewTack = {}
        for k, v in pairs(baseTack) do lastPreviewTack[k] = v end
    end

    local changed = false
    for _, category in ipairs(Config.TackCategories) do
        local key = category.key
        local want, have = target[key], lastPreviewTack[key]
        if tostring(want) ~= tostring(have) then
            if not want and NaturalSlots[key] then
                -- restore natural mane/tail from the base outfit, then re-apply everything else on top
                initAndApplyOutfit(previewPed, horse.outfit or 0)
                applyTackTable(previewPed, target)
                if horse.coat then HorseCoat.Apply(previewPed, horse.coat) end
                lastPreviewTack = target
                return
            end
            local catHash = TackCategoryHashes[key]
            if catHash then
                Citizen.InvokeNative(0xD710A5007C2AC539, previewPed, catHash, 0) -- REMOVE_TAG_FROM_META_PED
            end
            if want then applyTackItem(previewPed, want) end
            changed = true
        end
    end

    if changed then
        Citizen.InvokeNative(0xCC8CA3E88256E58F, previewPed, false, true, true, true, false) -- UPDATE_PED_VARIATION
    end
    lastPreviewTack = target
end

local function currentPick(baseTack, selections, key)
    local sel = selections[key]
    if sel ~= nil then
        if sel == 0 then return nil end
        return sel
    end
    return baseTack[key]
end

local function calcTackTotal(baseTack, selections)
    local total = 0
    for _, category in ipairs(Config.TackCategories) do
        local pick = currentPick(baseTack, selections, category.key)
        local original = baseTack[category.key]
        if pick and tostring(pick) ~= tostring(original) then
            local item = getTackItem(category.key, pick)
            if item then total = total + (item.price or 0) end
        end
    end
    return total
end

local function showTackReview(stable, horse, baseTack, selections)
    local options = {}
    local total = calcTackTotal(baseTack, selections)

    for catIndex, category in ipairs(Config.TackCategories) do
        local pick = currentPick(baseTack, selections, category.key)
        local original = baseTack[category.key]
        local label = pick and tackItemLabel(category.key, pick) or locale('none')
        local desc
        if tostring(pick) == tostring(original) then
            desc = locale('tack_no_change', label)
        elseif not pick then
            desc = locale('tack_removing')
        else
            local item = getTackItem(category.key, pick)
            local price = item and item.price or 0
            desc = locale('tack_item_price', label, price)
        end
        table.insert(options, {
            title = category.label,
            description = desc,
            icon = 'horse',
            onSelect = function()
                showTackWizardStep(stable, horse, baseTack, selections, catIndex)
            end,
        })
    end

    table.insert(options, {
        title = locale('tack_purchase_total', total),
        description = locale('tack_confirm_desc'),
        icon = 'dollar',
        disabled = total == 0 and next(selections) == nil,
        onSelect = function()
            local ok, result = lib.callback.await('rsg-stables:server:applyHorseTack', false, horse.id, selections)
            if ok then
                NuiNotify(locale('tack_updated', result and result.charged or 0), 'success')
                despawnPreviewHorse()
                OpenStableMenu(stable)
            else
                NuiNotify(result or locale('tack_purchase_failed'), 'error')
            end
        end,
    })

    table.insert(options, {
        title = locale('cancel'),
        description = locale('tack_cancel_desc'),
        icon = 'xmark',
        onSelect = function()
            despawnPreviewHorse()
            OpenStableMenu(stable)
        end,
    })

    NuiRender({
        title = locale('review_tack'),
        subtitle = horse.name,
        back = function() showTackWizardStep(stable, horse, baseTack, selections, #Config.TackCategories) end,
        options = options,
    })
end

function showTackWizardStep(stable, horse, baseTack, selections, index)
    local category = Config.TackCategories[index]
    if not category then
        showTackReview(stable, horse, baseTack, selections)
        return
    end

    local items = Config.TackItems[category.key] or {}
    local required = category.required and #items > 0
    local offset = required and 0 or 1 -- optional categories have "None" at position 1
    local styleCount = #items + offset

    local pick = currentPick(baseTack, selections, category.key)
    local styleIndex = 1
    for i, item in ipairs(items) do
        if tostring(item.hash) == tostring(pick) then
            styleIndex = i + offset
            break
        end
    end

    local function applyCurrentStyle()
        if styleIndex - offset < 1 then
            selections[category.key] = pick and 0 or nil
        else
            local hash = items[styleIndex - offset].hash
            selections[category.key] = (tostring(hash) ~= tostring(baseTack[category.key])) and hash or nil
        end
        refreshTackPreview(stable, horse, baseTack, selections)
    end

    local function sendStyleScreen()
        local label, meta
        if styleIndex - offset < 1 then
            label = locale('none')
            meta = locale('tack_none_equipped', category.label:lower())
        else
            local item = items[styleIndex - offset]
            label = item.label
            meta = ('$%.2f'):format(item.price)
        end
        local total = calcTackTotal(baseTack, selections)
        local funds = getBuyFunds()

        NuiTackPicker({
            title = category.label,
            subtitle = horse.name,
            categoryIndex = index,
            categoryCount = #Config.TackCategories,
            styleLabel = label,
            styleMeta = meta,
            styleIndex = styleIndex,
            styleCount = styleCount,
            isLast = index == #Config.TackCategories,
            costTotal = total,
            canAfford = funds >= total,
        })
    end

    currentTackHandlers = {
        cycle = function(dir)
            if dir == 'left' then
                styleIndex = styleIndex - 1
                if styleIndex < 1 then styleIndex = styleCount end
            else
                styleIndex = styleIndex + 1
                if styleIndex > styleCount then styleIndex = 1 end
            end
            local snd = Config.TackSounds
            if snd and snd.enabled then
                Citizen.InvokeNative(0x67C540AA08E4A6F5, dir == 'left' and snd.left or snd.right, snd.soundset, true, 0) -- PLAY_SOUND_FRONTEND
            end
            applyCurrentStyle()
            sendStyleScreen()
        end,
        nextCategory = function()
            applyCurrentStyle()
            showTackWizardStep(stable, horse, baseTack, selections, index + 1)
        end,
        prevCategory = function()
            applyCurrentStyle()
            if index > 1 then
                showTackWizardStep(stable, horse, baseTack, selections, index - 1)
            else
                despawnPreviewHorse()
                OpenStableMenu(stable)
            end
        end,
    }

    applyCurrentStyle()
    sendStyleScreen()
end

function OpenTackMenu(stable, horse)
    if not Config.Tack.enabled then
        NuiNotify(locale('tack_disabled'), 'error')
        return
    end
    local baseTack = decodeTack(horse.tack)
    local selections = {}
    spawnPreviewHorse(horse.model, stable.previewCoords, horse.outfit, baseTack, horse.coat)
    showTackWizardStep(stable, horse, baseTack, selections, 1)
end

-- ===================== COAT MENU =====================
function OpenCoatMenu(stable, horse)
    if not (Config.Coat and Config.Coat.enabled) then
        NuiNotify(locale('coat_disabled'), 'error')
        return
    end

    -- spawn without the saved coat first so we can read the horse's natural colours
    spawnPreviewHorse(horse.model, stable.previewCoords, horse.outfit, decodeTack(horse.tack))
    local ped = previewPed
    if not (ped and DoesEntityExist(ped)) then return end
    local timeout = GetGameTimer() + 3000
    while DoesEntityExist(ped) and not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and GetGameTimer() < timeout do Wait(50) end

    local natural = HorseCoat.Read(ped)
    local saved = HorseCoat.Normalize(horse.coat)
    if saved then HorseCoat.Apply(ped, saved) end
    local current = saved or natural

    local function back()
        currentCoatHandlers = nil
        despawnPreviewHorse()
        OpenHorseMenu(stable, horse)
    end

    currentCoatHandlers = {
        update = function(data)
            local coat = HorseCoat.Normalize(data)
            if coat and previewPed and DoesEntityExist(previewPed) then
                current = coat
                HorseCoat.ApplyNow(previewPed, current)
            end
        end,
        apply = function()
            local ok, result = lib.callback.await('rsg-stables:server:applyHorseCoat', false, horse.id, current)
            if ok then
                horse.coat = json.encode(result.coat)
                NuiNotify(locale('coat_updated', result.charged or 0), 'success')
                back()
            else
                NuiNotify(result or locale('coat_failed'), 'error')
            end
        end,
        reset = function()
            local ok, result = lib.callback.await('rsg-stables:server:applyHorseCoat', false, horse.id, 'reset')
            if ok then
                horse.coat = nil
                NuiNotify(locale('coat_reset'), 'success')
                back()
            else
                NuiNotify(result or locale('coat_failed'), 'error')
            end
        end,
        cancel = back,
    }

    local price = tonumber(Config.Coat.price) or 0
    NuiCoatPicker({
        title = locale('customize_coat'),
        subtitle = horse.name,
        coat = current,
        price = price,
        canAfford = getBuyFunds() >= price,
        hasCustom = saved ~= nil,
        presets = Config.Coat.presets or {},
    })
end

function OpenHorseMenu(stable, horse)
    local options = {}

    if horse.alive then
        table.insert(options, {
            title = locale('retrieve'),
            description = locale('retrieve_desc'),
            icon = 'retrieve',
            onSelect = function()
                local ok, result = lib.callback.await('rsg-stables:server:retrieveHorse', false, horse.id)
                if not ok then
                    NuiNotify(result or locale('retrieve_failed'), 'error')
                    return
                end
                CloseNUI()
                despawnPreviewHorse()
                spawnHorse(result, stable.previewCoords)
                if activeHorse then
                    saveActiveHorsePosition(true)
                    NuiNotify(locale('horse_retrieved', horse.name), 'success')
                else
                    pendingHorse = result -- spawn failed; horse is out in the DB, let a whistle retry
                end
            end,
        })

        if Config.Tack.enabled then
            table.insert(options, {
                title = locale('customize_tack'),
                description = locale('customize_tack_desc'),
                icon = 'shirt',
                onSelect = function()
                    OpenTackMenu(stable, horse)
                end,
            })
        end

        if Config.Coat and Config.Coat.enabled then
            table.insert(options, {
                title = locale('customize_coat'),
                description = locale('customize_coat_desc', tonumber(Config.Coat.price) or 0),
                icon = 'brush',
                onSelect = function()
                    OpenCoatMenu(stable, horse)
                end,
            })
        end

        table.insert(options, {
            title = locale('rename'),
            description = locale('rename_desc', Config.RenameCost),
            icon = 'pen',
            onSelect = function()
                NuiInput(locale('rename_horse'), locale('new_name'), function(value)
                    if not value or value == '' then
                        OpenHorseMenu(stable, horse)
                        return
                    end
                    local ok, result = lib.callback.await('rsg-stables:server:renameHorse', false, horse.id, value)
                    if ok then
                        NuiNotify(locale('renamed_success', result), 'success')
                    else
                        NuiNotify(result or locale('rename_failed'), 'error')
                    end
                    OpenStableMenu(stable)
                end, function() OpenHorseMenu(stable, horse) end)
            end,
        })

        if not horse.insured then
            table.insert(options, {
                title = locale('insure'),
                description = locale('insure_desc', Config.InsuranceCost),
                icon = 'shield',
                onSelect = function()
                    local ok, err = lib.callback.await('rsg-stables:server:insureHorse', false, horse.id)
                    if ok then
                        NuiNotify(locale('insured_success'), 'success')
                    else
                        NuiNotify(err or locale('insure_failed'), 'error')
                    end
                    OpenStableMenu(stable)
                end,
            })
        end

        table.insert(options, {
            title = locale('transfer'),
            description = locale('transfer_desc'),
            icon = 'route',
            onSelect = function()
                local transferOptions = {}
                for _, s in ipairs(Config.Stables) do
                    if s.name ~= stable.name then
                        table.insert(transferOptions, {
                            title = s.label,
                            description = locale('transfer_here'),
                            icon = 'route',
                            onSelect = function()
                                local ok, err = lib.callback.await('rsg-stables:server:transferHorse', false, horse.id, s.name)
                                if ok then
                                    NuiNotify(locale('transferred_success', horse.name, s.label), 'success')
                                else
                                    NuiNotify(err or locale('transfer_failed'), 'error')
                                end
                                OpenStableMenu(stable)
                            end,
                        })
                    end
                end
                NuiRender({
                    title = locale('transfer_to'),
                    subtitle = horse.name,
                    back = function() OpenHorseMenu(stable, horse) end,
                    options = transferOptions,
                })
            end,
        })

        if Config.HorseGive and Config.HorseGive.enabled then
            table.insert(options, {
                title = locale('give_horse'),
                description = (Config.HorseGive.fee or 0) > 0 and locale('give_horse_desc_fee', Config.HorseGive.fee) or locale('give_horse_desc'),
                icon = 'heart',
                onSelect = function()
                    local players = lib.callback.await('rsg-stables:server:getNearbyPlayers', false) or {}
                    if #players == 0 then
                        NuiNotify(locale('give_no_players'), 'error')
                        return
                    end
                    local playerOptions = {}
                    for _, p in ipairs(players) do
                        table.insert(playerOptions, {
                            title = (p.name ~= '' and p.name) or ('#' .. p.id),
                            description = locale('give_to_this_player'),
                            icon = 'horse',
                            onSelect = function()
                                NuiInput(locale('give_set_price'), locale('give_price_placeholder'), function(value)
                                    local price = 0
                                    if value and value ~= '' then
                                        price = tonumber((tostring(value):gsub('[%$,%s]', '')))
                                        if not price or price < 0 or price ~= math.floor(price) then
                                            NuiNotify(locale('give_price_invalid', Config.HorseGive.maxPrice or 100000), 'error')
                                            OpenHorseMenu(stable, horse)
                                            return
                                        end
                                    end
                                    NuiNotify(locale('give_waiting'), 'inform')
                                    local ok, err = lib.callback.await('rsg-stables:server:giveHorse', false, horse.id, p.id, price)
                                    if ok then
                                        if price > 0 then
                                            NuiNotify(locale('give_sold', horse.name, p.name, price), 'success')
                                        else
                                            NuiNotify(locale('give_success', horse.name, p.name), 'success')
                                        end
                                    else
                                        NuiNotify(err or locale('give_failed'), 'error')
                                    end
                                    OpenStableMenu(stable)
                                end, function()
                                    OpenHorseMenu(stable, horse)
                                end)
                            end,
                        })
                    end
                    NuiRender({
                        title = locale('give_horse'),
                        subtitle = horse.name,
                        back = function() OpenHorseMenu(stable, horse) end,
                        options = playerOptions,
                    })
                end,
            })
        end
    else
        if not horse.died_of_age then
            table.insert(options, {
                title = locale('revive'),
                description = locale('revive_desc', Config.ReviveCost),
                icon = 'medkit',
                onSelect = function()
                    local ok, err = lib.callback.await('rsg-stables:server:reviveHorse', false, horse.id)
                    if ok then
                        NuiNotify(locale('revived_success'), 'success')
                    else
                        NuiNotify(err or locale('revive_failed'), 'error')
                    end
                    OpenStableMenu(stable)
                end,
            })
        end

        table.insert(options, {
            title = locale('release_horse'),
            description = locale('release_horse_desc'),
            icon = 'xmark',
            onSelect = function()
                local ok, err = lib.callback.await('rsg-stables:server:releaseHorse', false, horse.id)
                if ok then
                    NuiNotify(locale('horse_released', horse.name), 'success')
                else
                    NuiNotify(err or locale('release_failed'), 'error')
                end
                OpenStableMenu(stable)
            end,
        })
    end

    NuiRender({
        title = horse.name,
        subtitle = stable.label,
        back = function() OpenStableMenu(stable) end,
        options = options,
    })
end

-- ===================== STORE COMMAND =====================
RegisterCommand('storehorse', storeActiveHorse, false)

-- ===================== HORSE NEEDS (hunger / thirst) =====================
CreateThread(function()
    while true do
        Wait(Config.HorseNeeds.decayInterval or 60000)

        if Config.HorseNeeds.enabled and activeHorse and DoesEntityExist(activeHorse.entity) and not IsEntityDead(activeHorse.entity) then
            bumpHorseNeed('hunger', -(Config.HorseNeeds.hungerDecayPerTick or 0))
            bumpHorseNeed('thirst', -(Config.HorseNeeds.thirstDecayPerTick or 0))

            local hunger = activeHorse.hunger or 100
            local thirst = activeHorse.thirst or 100
            local critical = Config.HorseNeeds.criticalThreshold or 15
            local wellFed = Config.HorseNeeds.wellFedThreshold or 50

            local horse = activeHorse.entity
            local maxHp = GetEntityMaxHealth(horse)
            local healthPct = (GetEntityHealth(horse) / math.max(1, maxHp)) * 100

            if hunger < critical or thirst < critical then
                local newHealthPct = math.max(0, healthPct - (Config.HorseNeeds.healthDrainPerTick or 0))
                SetEntityHealth(horse, math.max(0, math.floor((newHealthPct / 100) * maxHp)))

                if hunger < critical and thirst < critical then
                    lib.notify({ description = locale('starving_dehydrated'), type = 'error' })
                elseif hunger < critical then
                    lib.notify({ description = locale('starving'), type = 'error' })
                else
                    lib.notify({ description = locale('dehydrated'), type = 'error' })
                end
            elseif hunger >= wellFed and thirst >= wellFed and healthPct < 100 then
                local newHealthPct = math.min(100, healthPct + (Config.HorseNeeds.healthRegenPerTick or 0))
                SetEntityHealth(horse, math.max(1, math.floor((newHealthPct / 100) * maxHp)))
            end
        end
    end
end)

-- ===================== NATURAL DRINKING (rivers / lakes / troughs) =====================
local naturalDrinking, lastNaturalDrinkAt = false, 0

local function isHorseNearNaturalWater(horse, cfg)
    local coords = GetEntityCoords(horse)
    local fwd = GetEntityForwardVector(horse)
    -- sample a few points around the horse's head for river/lake water
    for _, dist in ipairs({ 0.0, 1.0, cfg.waterRadius or 2.5 }) do
        local p = coords + fwd * dist
        local zone = Citizen.InvokeNative(0x5BA7A68A346A5A91, p.x, p.y, p.z) -- GET_WATER_MAP_ZONE_AT_COORDS
        if zone and zone ~= 0 and zone ~= false then
            local ok, waterZ = GetWaterHeight(p.x, p.y, p.z + 2.0)
            if ok and math.abs(waterZ - p.z) < 2.5 then return 'water' end
        end
    end
    if IsEntityInWater(horse) then return 'water' end
    for _, model in ipairs(cfg.troughModels or {}) do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, cfg.troughRadius or 2.5, joaat(model), false, false, false)
        if obj and obj ~= 0 then return 'trough', obj end
    end
    return nil
end

local DRINK_ANIMS = {
    water  = { enter = 'amb_creature_mammal@world_horse_drink_ground@stand_enter', base = 'amb_creature_mammal@world_horse_drink_ground@base', exit = 'amb_creature_mammal@world_horse_drink_ground@stand_exit' },
    trough = { enter = 'amb_creature_mammal@prop_horse_drink_trough@stand_enter',  base = 'amb_creature_mammal@prop_horse_drink_trough@base',  exit = 'amb_creature_mammal@prop_horse_drink_trough@stand_exit' },
}

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- Plays enter -> looping drink -> exit directly on the horse (works mounted or not;
-- ambient scenarios are ignored on a ridden/player-owned horse, which is why they didn't show)
local function playHorseDrinkAnim(horse, kind, duration)
    local set = DRINK_ANIMS[kind] or DRINK_ANIMS.water
    if not (loadAnimDict(set.enter) and loadAnimDict(set.base) and loadAnimDict(set.exit)) then
        Wait(duration); return
    end
    FreezeEntityPosition(horse, true)
    TaskPlayAnim(horse, set.enter, 'enter', 2.0, -2.0, -1, 2, 0.0, false, false, false)
    Wait(1500)
    TaskPlayAnim(horse, set.base, 'base', 2.0, -2.0, -1, 1, 0.0, false, false, false)
    Wait(duration)
    if DoesEntityExist(horse) then
        TaskPlayAnim(horse, set.exit, 'exit', 2.0, -2.0, -1, 2, 0.0, false, false, false)
        Wait(1500)
        StopAnimTask(horse, set.exit, 'exit', 1.0)
        FreezeEntityPosition(horse, false)
    end
    RemoveAnimDict(set.enter); RemoveAnimDict(set.base); RemoveAnimDict(set.exit)
end

CreateThread(function()
    local stillSince = nil
    while true do
        local cfg = Config.HorseNaturalDrink
        Wait((cfg and cfg.checkInterval) or 2000)

        if cfg and cfg.enabled and not naturalDrinking and activeHorse and DoesEntityExist(activeHorse.entity)
            and not IsEntityDead(activeHorse.entity)
            and (activeHorse.thirst or 100) <= (cfg.thirstThreshold or 40)
            and GetGameTimer() - lastNaturalDrinkAt >= (cfg.cooldown or 120000) then

            local horse = activeHorse.entity
            local mounted = IsPedOnMount(cache.ped) and GetMount(cache.ped) == horse
            local canDrink = (cfg.allowMounted or not mounted) and GetEntitySpeed(horse) < 0.3
            local waterKind, trough = nil, nil
            if canDrink then waterKind, trough = isHorseNearNaturalWater(horse, cfg) end

            if waterKind then
                stillSince = stillSince or GetGameTimer()
                if GetGameTimer() - stillSince >= (cfg.stillTime or 3000) then
                    stillSince = nil
                    naturalDrinking = true
                    lastNaturalDrinkAt = GetGameTimer()

                    local ok, result = lib.callback.await('rsg-stables:server:naturalDrink', false)
                    if ok and DoesEntityExist(horse) then
                        if trough and DoesEntityExist(trough) then
                            TaskTurnPedToFaceEntity(horse, trough, 1500)
                            Wait(1500)
                        end
                        playHorseDrinkAnim(horse, waterKind, cfg.drinkDuration or 8000)
                        if activeHorse and activeHorse.entity == horse and result and result.thirst then
                            activeHorse.thirst = result.thirst
                        end
                        lib.notify({ description = locale(waterKind == 'trough' and 'horse_drank_trough' or 'horse_drank_river'), type = 'success' })
                    end
                    naturalDrinking = false
                end
            else
                stillSince = nil
            end
        else
            stillSince = nil
        end
    end
end)

-- ===================== NATURAL GRAZING (hay near the player) =====================
local naturalGrazing, lastNaturalGrazeAt = false, 0

local function findHayNearPlayer(cfg)
    local pc = GetEntityCoords(cache.ped)
    local best, bestDist = nil, nil
    for _, model in ipairs(cfg.hayModels or {}) do
        local obj = GetClosestObjectOfType(pc.x, pc.y, pc.z, cfg.searchRadius or 15.0, joaat(model), false, false, false)
        if obj and obj ~= 0 then
            local d = #(GetEntityCoords(obj) - pc)
            if not bestDist or d < bestDist then best, bestDist = obj, d end
        end
    end
    return best
end

CreateThread(function()
    while true do
        local cfg = Config.HorseNaturalGraze
        Wait((cfg and cfg.checkInterval) or 3000)

        if cfg and cfg.enabled and not naturalGrazing and not naturalDrinking and activeHorse
            and DoesEntityExist(activeHorse.entity) and not IsEntityDead(activeHorse.entity)
            and not IsPedOnMount(cache.ped) and not IsPedInAnyVehicle(cache.ped, false)
            and (activeHorse.hunger or 100) <= (cfg.hungerThreshold or 40)
            and GetGameTimer() - lastNaturalGrazeAt >= (cfg.cooldown or 120000) then

            local horse = activeHorse.entity
            local nearPlayer = #(GetEntityCoords(horse) - GetEntityCoords(cache.ped)) <= (cfg.searchRadius or 15.0) * 2
            local hay = nearPlayer and not IsPedRagdoll(horse) and findHayNearPlayer(cfg)
            if hay then
                naturalGrazing = true
                lastNaturalGrazeAt = GetGameTimer()

                -- wander over to the hay
                local hc = GetEntityCoords(hay)
                ClearPedTasks(horse)
                TaskGoToCoordAnyMeans(horse, hc.x, hc.y, hc.z, 1.0, 0, false, 786603, 0xbf800000)
                local deadline = GetGameTimer() + (cfg.walkTimeout or 15000)
                local reached = false
                while GetGameTimer() < deadline and DoesEntityExist(horse) and DoesEntityExist(hay) and not IsPedOnMount(cache.ped) do
                    if #(GetEntityCoords(horse) - hc) <= (cfg.eatDistance or 1.8) + 0.5 then reached = true break end
                    Wait(250)
                end

                if reached and DoesEntityExist(horse) and not IsPedOnMount(cache.ped) then
                    ClearPedTasks(horse)
                    TaskTurnPedToFaceEntity(horse, hay, 1500)
                    Wait(1500)
                    local ok, result = lib.callback.await('rsg-stables:server:naturalGraze', false)
                    if ok and DoesEntityExist(horse) then
                        local anim = cfg.eatAnim or {}
                        if anim.dict and loadAnimDict(anim.dict) then
                            FreezeEntityPosition(horse, true)
                            TaskPlayAnim(horse, anim.dict, anim.clip or 'base', 2.0, -2.0, -1, 1, 0.0, false, false, false)
                            Wait(cfg.eatDuration or 10000)
                            if DoesEntityExist(horse) then
                                StopAnimTask(horse, anim.dict, anim.clip or 'base', 1.0)
                                FreezeEntityPosition(horse, false)
                            end
                            RemoveAnimDict(anim.dict)
                        else
                            Wait(cfg.eatDuration or 10000)
                        end
                        if activeHorse and activeHorse.entity == horse and result and result.hunger then
                            activeHorse.hunger = result.hunger
                        end
                        lib.notify({ description = locale('horse_ate_hay'), type = 'success' })
                    end
                elseif DoesEntityExist(horse) then
                    ClearPedTasks(horse)
                end
                naturalGrazing = false
            end
        end
    end
end)

-- ===================== OLD AGE STAMINA =====================
-- Old horses can't hold a full stamina core: the cap drops linearly from 100% on the first
-- 'old' day to Config.HorseAging.oldMinStamina on the last day of their lifespan.
local function oldAgeStaminaCap(ageDays)
    local cfg = Config.HorseAging
    if not (cfg and cfg.enabled) then return 100 end
    local oldFrom, life = cfg.oldFromDays or 60, cfg.lifespanDays or 90
    if ageDays < oldFrom or life <= oldFrom then return 100 end
    local t = math.min(1.0, (ageDays - oldFrom) / (life - oldFrom))
    return math.floor(100 - t * (100 - (cfg.oldMinStamina or 40)))
end

CreateThread(function()
    while true do
        Wait(2000)
        if activeHorse and DoesEntityExist(activeHorse.entity) and not IsEntityDead(activeHorse.entity) then
            local cap = oldAgeStaminaCap(activeHorse.ageDays or 0)
            if cap < 100 and not stimulantActive() then -- the stimulant deliberately tops the core up; don't fight it
                local core = tonumber(Citizen.InvokeNative(0x36731AC041289BB1, activeHorse.entity, 1)) or 0 -- _GET_ATTRIBUTE_CORE_VALUE (stamina)
                if core > cap then
                    Citizen.InvokeNative(0xC6258F41D86676E0, activeHorse.entity, 1, cap) -- _SET_ATTRIBUTE_CORE_VALUE (stamina)
                end
            end
        end
    end
end)

-- ===================== RECEIVING A HORSE FROM ANOTHER PLAYER =====================
lib.callback.register('rsg-stables:client:confirmHorseGift', function(giverName, horseName, breedLabel, price)
    local timeout = (Config.HorseGive and Config.HorseGive.timeout) or 30000
    local answered = nil
    SetTimeout(timeout, function()
        if answered == nil then lib.closeAlertDialog() end
    end)
    local res = lib.alertDialog({
        header = locale('give_offer_header'),
        content = (price or 0) > 0
            and locale('give_offer_content_price', giverName or '?', horseName or '?', breedLabel or '', price)
            or locale('give_offer_content', giverName or '?', horseName or '?', breedLabel or ''),
        centered = true,
        cancel = true,
        labels = { confirm = locale('give_accept'), cancel = locale('give_decline') },
    })
    answered = res
    return res == 'confirm'
end)

-- ===================== NATURAL DEATH (old age) =====================
RegisterNetEvent('rsg-stables:client:horseDiedOfAge', function(horseId, horseName)
    if activeHorse and activeHorse.dbId == horseId then
        despawnActiveHorseEntity()
    end
    -- a horse that is out but not spawned (fled / after relog) must not be whistled back
    if pendingHorse and pendingHorse.id == horseId then
        pendingHorse = nil
    end
    lib.notify({ description = locale('horse_died_of_age', horseName or locale('your_horse')), type = 'error', duration = 10000 })
end)

-- ===================== DEATH DETECTION =====================

CreateThread(function()
    while true do
        Wait(1000)
        if activeHorse and DoesEntityExist(activeHorse.entity) then
            if IsEntityDead(activeHorse.entity) then
                local dbId = activeHorse.dbId
                local netId = NetworkGetEntityIsNetworked(activeHorse.entity) and NetworkGetNetworkIdFromEntity(activeHorse.entity) or nil
                -- report before despawning so the server can confirm the entity is really dead
                lib.callback.await('rsg-stables:server:horseDied', false, dbId, netId)
                despawnActiveHorseEntity()
            end
        end
    end
end)

-- ===================== INIT =====================

CreateThread(function()
    if not Config.Tack.enabled then return end
    local unverified = 0
    for _, items in pairs(Config.TackItems) do
        for _, item in ipairs(items) do
            if item.verified == false then unverified = unverified + 1 end
        end
    end
    if unverified > 0 then
        print(('[rsg-stables] WARNING: %d tack item(s) in shared/config.lua still use placeholder hashes and will not visually apply. Replace them with verified hashes before shipping tack customization to players.'):format(unverified))
    end
end)

CreateThread(function()
    setupStables()
end)

local hasReconciledHorses = false
local function reconcileHorsesOnceLoaded()
    if hasReconciledHorses then return end
    hasReconciledHorses = true

    local horse = lib.callback.await('rsg-stables:server:restoreActiveHorse', false)
    if horse and not activeHorse then
        pendingHorse = horse
        if not Config.ActiveHorse or Config.ActiveHorse.notifyOnLogin ~= false then
            lib.notify({ description = locale('horse_still_out_login', horse.name or locale('your_horse')), type = 'inform', duration = 7000 })
        end
    end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    reconcileHorsesOnceLoaded()
end)

-- Logging out (e.g. to character select): save where the horse is, remove it locally, keep it "out" in the DB
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    saveActiveHorsePosition(true)
    despawnActiveHorseEntity()
    despawnPreviewHorse()
    CloseNUI()
    pendingHorse = nil
    lastSavedPos = nil
    stimulant.entity, stimulant.endsAt = nil, 0
    hasReconciledHorses = false
end)

CreateThread(function()
    local playerData = RSGCore.Functions.GetPlayerData()
    local timeout = 0
    while (not playerData or not playerData.citizenid) and timeout < 30000 do
        Wait(500)
        timeout = timeout + 500
        playerData = RSGCore.Functions.GetPlayerData()
    end
    if playerData and playerData.citizenid then
        reconcileHorsesOnceLoaded()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    for _, ped in pairs(stablePeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    for _, blip in ipairs(stableBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    CloseNUI()
    saveActiveHorsePosition(true)
    despawnActiveHorseEntity()
    despawnPreviewHorse()
end)
