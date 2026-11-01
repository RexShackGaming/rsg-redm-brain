local RSGCore = exports['rsg-core']:GetCoreObject()

-- =========================================================
-- State
-- =========================================================
local fishing        = false   -- a bait is on the rod and a cast session is running
local ready          = false   -- bait has been applied to the rod for this session
local currentLure    = nil     -- bait item name for the current session
local hasMinigameOn  = false
local mg             = {}      -- fishing minigame struct (f_0 .. f_27)
local fishWeight     = 0       -- raw (pre-multiplier) weight of the hooked fish
local fishForce      = 0.6
local fishStatus     = 0       -- 0 relaxed, 1 struggling
local nextAttTime    = 0
local horizontalMove = 0
local lureCooldown   = 0
local keptEntity     = nil     -- fish just kept from the minigame; the ground pickup loop must ignore it
local tension        = 0       -- line tension 0..1 (line snaps at 1)
local fishSize       = 0.2     -- 0..1, feeds the FishSize audio variable and tension gain
local lastTensionSent = -1
local nextRumble     = 0

local PTFX_DICT  = 'scr_mg_fishing'        -- rdr3_discoveries/graphics/ptfx/ptfx_assets_non_looped.lua
local PTFX_NAME  = 'scr_mg_fish_struggle'
local PTFX_EVERY = 400                     -- ms between struggle splashes (was every frame)
local lastPtfx   = 0
local nextFlee   = 0

local INPUT_ATTACK   = `INPUT_ATTACK`
local INPUT_AIM      = `INPUT_AIM`
local INPUT_DUCK     = `INPUT_DUCK`
local INPUT_REEL     = `INPUT_GAME_MENU_OPTION`
local INPUT_HOLSTER  = `INPUT_TOGGLE_HOLSTER`
local INPUT_RESET    = 0x8FFC75D6 -- LEFT SHIFT
local INPUT_LOOK_LR  = 0x390948DC

-- model hash -> display name, built once from Config.fishData
local fishNames = {}
for model, data in pairs(Config.fishData) do
    fishNames[joaat(model)] = data[1]
end

-- bait -> set of fish model hashes it attracts
local baitFish = {}
for bait, list in pairs(Config.BaitsPerFish) do
    local set = {}
    for i = 1, #list do set[joaat(list[i])] = true end
    baitFish[bait] = set
end

-- weight band (min, max raw kg before * 0.25) per fish model
local weightBands = {
    small  = { 0.5, 3.0, size = 0.2 },
    medium = { 4.0, 6.0, size = 0.5 },
    large  = { 14.0, 20.0, size = 1.0 },
}
local fishBand = {}
for model, band in pairs({
    A_C_FISHBLUEGIL_01_SM = 'small', A_C_FISHBLUEGIL_01_MS = 'small',
    A_C_FISHBULLHEADCAT_01_MS = 'small', A_C_FISHBULLHEADCAT_01_SM = 'small',
    A_C_FISHCHAINPICKEREL_01_MS = 'small', A_C_FISHCHAINPICKEREL_01_SM = 'small',
    A_C_FISHPERCH_01_MS = 'small', A_C_FISHPERCH_01_SM = 'small',
    A_C_FISHREDFINPICKEREL_01_MS = 'small', A_C_FISHREDFINPICKEREL_01_SM = 'small',
    A_C_FISHROCKBASS_01_MS = 'small', A_C_FISHROCKBASS_01_SM = 'small',
    A_C_FISHLARGEMOUTHBASS_01_MS = 'medium', A_C_FISHLARGEMOUTHBASS_01_LG = 'medium',
    A_C_FISHSMALLMOUTHBASS_01_LG = 'medium', A_C_FISHSMALLMOUTHBASS_01_MS = 'medium',
    A_C_FISHSALMONSOCKEYE_01_MS = 'medium', A_C_FISHSALMONSOCKEYE_01_ML = 'medium', A_C_FISHSALMONSOCKEYE_01_LG = 'medium',
    A_C_FISHRAINBOWTROUT_01_LG = 'medium', A_C_FISHRAINBOWTROUT_01_MS = 'medium',
    A_C_FISHCHANNELCATFISH_01_XL = 'large', A_C_FISHCHANNELCATFISH_01_LG = 'large',
    A_C_FISHLAKESTURGEON_01_LG = 'large', A_C_FISHLONGNOSEGAR_01_LG = 'large',
    A_C_FISHMUSKIE_01_LG = 'large', A_C_FISHNORTHERNPIKE_01_LG = 'large',
}) do
    fishBand[joaat(model)] = weightBands[band]
end

local function notify(desc, ntype)
    RSGCore.Functions.Notify({ title = locale('cl_error'), description = desc, type = ntype or 'error', duration = 5000 })
end

local function holdingRod(ped)
    return GetPedCurrentHeldWeapon(ped) == `WEAPON_FISHINGROD`
end

-- =========================================================
-- Feedback: sound, rumble, music (fishing_core.c, build 1436)
-- =========================================================
local soundsetReady = false

local function prepareSounds()
    if not Config.Sounds.Enabled or soundsetReady then return end
    local timeout = GetGameTimer() + 2000
    while not Citizen.InvokeNative(0xD9130842D7226045, Config.Sounds.Soundset, true) and GetGameTimer() < timeout do -- PREPARE_SOUNDSET
        Wait(50)
    end
    soundsetReady = true
end

local function releaseSounds()
    if not soundsetReady then return end
    Citizen.InvokeNative(0x531A78D6BF27014B, Config.Sounds.Soundset) -- _RELEASE_SOUNDSET
    soundsetReady = false
end

-- play a named sound from Config.Sounds.Names on an entity, with the FishSize variable set
local function playSound(key, entity)
    local cfg = Config.Sounds
    if not cfg.Enabled then return end
    local name = cfg.Names[key]
    if not name or name == '' then return end
    entity = (entity and entity ~= 0 and DoesEntityExist(entity)) and entity or PlayerPedId()
    local id = GetSoundId()
    Citizen.InvokeNative(0xF1C5310FEAA36B48, id, name, entity, cfg.Soundset, false, 0) -- _PLAY_SOUND_FROM_ENTITY_WITH_SET
    Citizen.InvokeNative(0x503703EC1781B7D6, id, 'FishSize', fishSize + 0.0)        -- SET_VARIABLE_ON_SOUND
    SetTimeout(5000, function() ReleaseSoundId(id) end)
end

local function rumble(key)
    local cfg = Config.Rumble
    if not cfg.Enabled then return end
    local r = cfg[key]
    if not r then return end
    Citizen.InvokeNative(0x48B3886C1358D0D5, 0, r[1], r[2]) -- SET_CONTROL_SHAKE (old SET_PAD_SHAKE)
end

local function music(start)
    if not Config.Music.Enabled then return end
    TriggerMusicEvent(start and Config.Music.Start or Config.Music.Stop)
end

local function sendTension(v)
    v = math.floor(v * 50 + 0.5) / 50 -- 2% steps, avoids NUI spam
    if v == lastTensionSent then return end
    lastTensionSent = v
    SendNUIMessage({ action = 'tension', value = v, show = v >= 0 })
end

-- =========================================================
-- Minigame struct helpers (backed by client_js.js)
-- =========================================================
local FLOAT_FIELDS = { [1]=true,[2]=true,[3]=true,[4]=true,[8]=true,[9]=true,[13]=true,[14]=true,[15]=true,[17]=true,
    [20]=true,[21]=true,[22]=true,[23]=true,[24]=true,[25]=true,[26]=true,[27]=true }

local function readMinigame()
    local r = exports['rsg-fishing']:GET_TASK_FISHING_DATA_EXTRA()
    hasMinigameOn = r[1]
    local ints, floats = r[2], r[3]
    for i = 0, 27 do
        local idx = tostring(i * 2)
        mg['f_' .. i] = FLOAT_FIELDS[i] and floats[idx] or ints[idx]
    end
end

local function getF(f) return mg['f_' .. f] end

local function setF(f, v)
    mg['f_' .. f] = v
    if mg.f_0 ~= nil then
        exports['rsg-fishing']:SET_TASK_FISHING_DATA_EXTRA(mg)
    end
end

local function mgState()      return getF(0) end
local function lineDistance() return getF(2) or 0 end
local function fishHandle()   return getF(7) end
local function bobberHandle() return getF(11) end
local function hookHandle()   return getF(12) end
local function setTransition(v) setF(6, v) end
local function setRodWeight(v)  setF(18, v) end

local function setHookedFish(entity)
    setF(7, entity)
    local band = fishBand[GetEntityModel(entity)] or weightBands.small
    local kg = (math.random() * (band[2] - band[1]) + band[1]) * 0.25
    fishWeight = kg / Config.FishWeightMultiplier
    setF(8, fishWeight)
    setRodWeight(2)
    fishSize = band.size or 0.2
    tension = 0
end

local function getNearbyFish(coords, radius)
    local result = {}
    local itemSet = CreateItemset(true)
    local size = Citizen.InvokeNative(0x59B57C4B06531E1E, coords, radius, itemSet, 1, Citizen.ResultAsInteger()) -- _GET_ENTITIES_NEAR_POINT (natives/db/INDEX.tsv)
    for i = 0, size - 1 do
        local entity = GetIndexedItemInItemset(i, itemSet)
        if GetEntityPopulationType(entity) == 6 and not IsPedDeadOrDying(entity, false) then
            result[#result + 1] = entity
        end
    end
    if IsItemsetValid(itemSet) then DestroyItemset(itemSet) end
    return result
end

local function loadPtfx()
    local dict = joaat(PTFX_DICT)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasNamedPtfxAssetLoaded(dict)
end

local function splash(entity)
    local now = GetGameTimer()
    if now - lastPtfx < PTFX_EVERY or not entity or not DoesEntityExist(entity) then return end
    lastPtfx = now
    if not loadPtfx() then return end
    UseParticleFxAsset(PTFX_DICT)
    StartParticleFxNonLoopedAtCoord(PTFX_NAME, GetEntityCoords(entity), 0.0, 0.0, math.random(0, 360) + 0.0, 1.5, false, false, false)
end

local function removeFishLater(entity)
    if not entity or entity == 0 then return end
    SetTimeout(3000, function()
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
        if keptEntity == entity then keptEntity = nil end
    end)
end

local function endSession(ped)
    fishing = false
    SetFishingBait(ped, '', 0, 1)
    tension, lastTensionSent = 0, -1
    SendNUIMessage({ action = 'tension', show = false })
    music(false)
end

-- =========================================================
-- Minigame states
-- =========================================================
local function handleWaiting(ped) -- state 6: line in the water
    if IsControlJustPressed(0, INPUT_RESET) then setTransition(128) end

    local hook = hookHandle()
    if not hook or hook == 0 then return end
    local hookPos = GetEntityCoords(hook)

    if IsControlPressed(0, INPUT_DUCK) then -- reel lure in
        local p = hookPos + (GetEntityCoords(ped) - hookPos) * Config.ReelSpeed
        SetEntityCoords(hook, p.x, p.y, p.z, false, false, false, false)
    end

    setF(14, lineDistance() < 4.0 and 1.0 or 0.4)

    if lureCooldown > GetGameTimer() then return end

    local fishes = getNearbyFish(hookPos, 50.0)
    if #fishes == 0 then return end
    lureCooldown = GetGameTimer() + 1000

    local interested = baitFish[currentLure] or {}
    local bobber = bobberHandle()
    local closest
    for i = 1, #fishes do
        local f = fishes[i]
        local fPos = GetEntityCoords(f)
        if Config.Debug then
            DrawLine(fPos.x, fPos.y, fPos.z, fPos.x, fPos.y, fPos.z + 2.0, 255, 255, 0, 255)
        end
        if #(hookPos - fPos) <= 1.6 then
            closest = f
        elseif interested[GetEntityModel(f)] then
            TaskGoToEntity(f, bobber, 100, 1, 1.0, 2.0, 0)
        end
    end

    if closest and getF(5) == 1 then
        local roll = math.random()
        if roll > 0.9 or roll < 0.2 then -- fish bites
            Citizen.InvokeNative(0xF0FBF193F1F5C0EA, closest)
            SetPedConfigFlag(closest, 17, true)
            Citizen.InvokeNative(0x1F298C7BD30D1240, ped)
            ClearPedTasksImmediately(closest, false, true)
            TaskSetBlockingOfNonTemporaryEvents(closest, true)
            PedFishingrodHookEntity(ped, closest)
            setHookedFish(closest)
            fishForce = 0.6
            setTransition(4)
            playSound('Hooked', closest)
            rumble('Bite')
        end
    end
end

local function handleHooked(ped) -- state 7: fish on the line
    fishWeight = getF(8) or fishWeight
    if IsControlJustPressed(0, INPUT_RESET) then setTransition(11) end

    local fish = fishHandle()

    local lr = GetControlNormal(0, INPUT_LOOK_LR)
    horizontalMove = math.max(0.0, math.min(1.0, horizontalMove - 0.05 * lr))
    setF(22, horizontalMove)

    if lineDistance() < 4.0 then setTransition(12) end
    setF(14, 1.0)

    local now = GetGameTimer()
    if now >= nextAttTime then
        if math.random() < Config.StruggleChance then
            fishForce, fishStatus = 0.6, 1
            nextAttTime = now + math.random(1, 3) * 1000
            playSound('Struggle', fish)
        else
            fishForce, fishStatus = 0, 0
            nextAttTime = now + math.random(2, 5) * 1000
        end
    end

    if fishStatus == 1 then
        if IsControlPressed(0, INPUT_REEL) then
            setRodWeight(4)
            fishForce = fishForce + 0.005
        else
            fishForce = fishForce - 0.005
        end
        if IsControlJustReleased(0, INPUT_REEL) then setRodWeight(2) end

        if fishForce >= 1.0 then
            setTransition(11)
        elseif fishForce < 0.6 then
            fishForce = 0.6
        end
        if now >= nextFlee then -- re-issue flee every 500 ms rather than every frame
            nextFlee = now + 500
            TaskSmartFleeCoord(fish, GetEntityCoords(ped), 40.0, 50, 8, 1077936128)
        end
        splash(fish)
    else
        if IsControlJustPressed(0, INPUT_REEL) then
            setRodWeight(4)
            TaskGoToEntity(fish, ped, Config.Difficulty, 1.0, 1.5, 0.0, 0)
        end
        if IsControlJustReleased(0, INPUT_REEL) then setRodWeight(2) end
    end

    -- line tension: reeling against a struggling fish strains the line, everything else lets it recover
    local snap = Config.LineSnap
    if snap.Enabled then
        local reeling = IsControlPressed(0, INPUT_REEL)
        if fishStatus == 1 and reeling then
            tension = tension + snap.Gain * (0.5 + fishSize)
            if now >= nextRumble then
                nextRumble = now + 300
                rumble('Struggle')
            end
        else
            tension = tension - snap.Recover
        end
        tension = math.max(0.0, math.min(1.0, tension))
        sendTension(tension)
        if tension >= 1.0 then
            playSound('Snap', fish)
            rumble('Snap')
            RSGCore.Functions.Notify({ title = locale('cl_fishing'), description = locale('cl_line_snapped'), type = 'error', duration = 5000 })
            setTransition(8)
            if fish and DoesEntityExist(fish) then
                ClearPedTasksImmediately(fish, false, true)
                TaskSmartFleeCoord(fish, GetEntityCoords(ped), 40.0, 10000, 8, 1077936128)
            end
            endSession(ped)
            return
        end
    end

    local t = getF(6)
    if t ~= 11 and t ~= 12 then
        setF(13, fishForce)
        setF(21, fishForce)
    end

    if IsControlJustPressed(0, INPUT_ATTACK) then setF(23, 0.6) end
    if IsControlJustReleased(0, INPUT_ATTACK) then setF(23, 0.0) end
end

local function handleCaught(ped) -- state 12: fish in hand
    local entity = fishHandle()
    if IsControlJustPressed(0, INPUT_ATTACK) then
        setTransition(32)
        keptEntity = entity
        playSound('Caught', entity)
        rumble('Caught')
        TriggerServerEvent('rsg-fishing:server:catchFish', GetEntityModel(entity), fishWeight)
        endSession(ped)
        removeFishLater(entity)
    elseif IsControlJustPressed(0, INPUT_AIM) then
        setTransition(64)
        endSession(ped)
        removeFishLater(entity)
    elseif getF(5) == 96 and getF(6) == 0 then -- fish got away
        endSession(ped)
        removeFishLater(entity)
    end
end

-- =========================================================
-- Bobber marker (NUI)
-- =========================================================
local bobberMarkerActive = false

local function startBobberMarker()
    local cfg = Config.BobberMarker
    if not cfg or not cfg.Enabled or not cfg.ScreenIcon or bobberMarkerActive then return end
    bobberMarkerActive = true
    CreateThread(function()
        while fishing do
            local state = mgState()
            local wait = 250
            local shown = false
            if state == 6 or state == 7 then
                local bobber = bobberHandle()
                if not bobber or bobber == 0 or not DoesEntityExist(bobber) then bobber = hookHandle() end
                if bobber and bobber ~= 0 and DoesEntityExist(bobber) then
                    local pos = GetEntityCoords(bobber)
                    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z + 0.15)
                    SendNUIMessage({ action = 'bobber', show = onScreen, x = sx, y = sy, hooked = state == 7, size = cfg.ScreenIconSize })
                    shown, wait = true, 0
                end
            end
            if not shown then SendNUIMessage({ action = 'bobber', show = false }) end
            Wait(wait)
        end
        bobberMarkerActive = false
        SendNUIMessage({ action = 'bobber', show = false })
    end)
end

-- =========================================================
-- Use bait
-- =========================================================
RegisterNetEvent('rsg-fishing:client:usebait', function(bait)
    if fishing then
        notify(locale('cl_already_fishing'))
        return
    end
    local ped = PlayerPedId()
    if not holdingRod(ped) then
        notify(locale('cl_you_need_use_your_fishing_rod_first'))
        return
    end

    fishing, ready, currentLure = true, false, bait
    fishWeight, fishStatus, horizontalMove, nextAttTime = 0, 0, 0, 0
    tension, lastTensionSent = 0, -1
    Citizen.InvokeNative(0x1096603B519C905F, 'MMFSH')
    TriggerServerEvent('rsg-fishing:server:removeBaitItem', bait)
    startBobberMarker()
    music(true)

    CreateThread(function()
        prepareSounds()
        local noRodSince
        while fishing do
            ped = PlayerPedId()
            local sleep = 1500

            -- rod holstered / swapped / player died before or during the cast: end the session
            if holdingRod(ped) and not IsPedDeadOrDying(ped, true) then
                noRodSince = nil
            elseif not noRodSince then
                noRodSince = GetGameTimer()
            elseif GetGameTimer() - noRodSince > 2000 then
                endSession(ped)
                break
            end

            readMinigame()
            local state = mgState()

            if state == 1 and not ready then
                ready = true
                if Config.Debug then print('[rsg-fishing] bait: ' .. tostring(currentLure)) end
                TaskSwapFishingBait(ped, currentLure, 0)
                SetFishingBait(ped, currentLure, 0, 1)
            end

            if hasMinigameOn then
                sleep = 0
                if state == 2 then
                    setF(1, math.random(25, 30) + 0.0) -- cast distance
                elseif state == 6 then
                    handleWaiting(ped)
                elseif state == 7 then
                    handleHooked(ped)
                elseif state == 12 then
                    handleCaught(ped)
                end
                if state ~= 7 and lastTensionSent >= 0 then
                    lastTensionSent = -1
                    SendNUIMessage({ action = 'tension', show = false })
                end

                if fishing and IsControlJustPressed(0, INPUT_HOLSTER) then
                    setTransition(8)
                    endSession(ped)
                end
            end
            Wait(sleep)
        end
        currentLure, ready = nil, false
        releaseSounds()
    end)
end)

-- =========================================================
-- Controls HUD (NUI, top-left)
-- =========================================================
local hudKey, hudRows = nil, nil

local controlHashes = {}
for id, c in pairs(Config.ControlInputs) do
    controlHashes[id] = type(c) == 'string' and joaat(c) or c
end

local function baitLabel()
    if not currentLure then return nil end
    local item = RSGCore.Shared.Items[currentLure]
    return (item and item.label) or currentLure
end

local function controlsFor(state, ped)
    local k = Config.ControlKeys
    if not fishing then
        if holdingRod(ped) then
            return locale('cl_no_bait'), 'nobait', {
                { id = 'UseBait', key = k.UseBait, label = locale('cl_use_bait_hint') },
            }
        end
        return nil
    end
    local castRows = {
        { id = 'Prepare', key = k.Prepare, label = locale('cl_prepare_fishing_rod') },
        { id = 'Cast',    key = k.Cast,    label = locale('cl_cast_fishing_rod') },
    }
    if state == 6 then
        return locale('cl_fishing'), nil, {
            { id = 'Hook',      key = k.Hook,      label = locale('cl_hook') },
            { id = 'ResetCast', key = k.ResetCast, label = locale('cl_reset_cast') },
            { id = 'ReelLure',  key = k.ReelLure,  label = locale('cl_reel_lure') },
        }
    elseif state == 7 then
        return locale('cl_get_the_fish'), 'hooked', {
            { id = 'ReelIn',    key = k.ReelIn,    label = locale('cl_reel_in') },
            { id = 'ResetCast', key = k.ResetCast, label = locale('cl_reset_cast') },
        }
    elseif state == 12 then
        local name = fishNames[GetEntityModel(fishHandle() or 0)]
        if not name then return locale('cl_ready_to_fish'), nil, castRows end
        local sub = ('%s: %s  //  %s: %.2fKg'):format(locale('cl_name'), name, locale('cl_weight'), fishWeight * Config.FishWeightMultiplier)
        return sub, 'caught', {
            { id = 'KeepFish',  key = k.KeepFish,  label = locale('cl_keep_fish') },
            { id = 'ThrowFish', key = k.ThrowFish, label = locale('cl_throw_fish') },
        }
    end
    return locale('cl_ready_to_fish'), nil, castRows
end

CreateThread(function()
    SendNUIMessage({ action = 'locale', title = locale('cl_hud_title'), tension = locale('cl_line_tension') })
    while true do
        local ped = PlayerPedId()
        local state = fishing and mgState() or nil
        local title, mode, rows = controlsFor(state, ped)
        local label = fishing and baitLabel()
        local info = label and (locale('cl_bait') .. ': ' .. label) or nil
        local key = title and (tostring(state) .. '|' .. title .. '|' .. tostring(info)) or nil
        if key ~= hudKey then
            hudKey, hudRows = key, rows
            if rows then
                SendNUIMessage({ action = 'controls', show = true, title = title, info = info, mode = mode, rows = rows })
            else
                SendNUIMessage({ action = 'controls', show = false })
            end
        end
        Wait(250)
    end
end)

-- live key-press highlight, only while the HUD is visible
CreateThread(function()
    local last = {}
    while true do
        if hudRows then
            local changed, pressed = false, {}
            for _, r in ipairs(hudRows) do
                local c = controlHashes[r.id]
                local down = c ~= nil and (IsControlPressed(0, c) or IsDisabledControlPressed(0, c))
                pressed[r.id] = down
                if last[r.id] ~= down then changed = true end
            end
            if changed then
                last = pressed
                SendNUIMessage({ action = 'pressed', pressed = pressed })
            end
            Wait(0)
        else
            last = {}
            Wait(250)
        end
    end
end)

-- =========================================================
-- Pick up a fish carried in hand (e.g. picked up off the ground) and store it
-- =========================================================
if Config.GroundPickup then
    local fishModels = {}
    for model in pairs(Config.fishData) do fishModels[joaat(model)] = true end

    CreateThread(function()
        while true do
            Wait(1000)
            local ped = PlayerPedId()
            local holding = GetFirstEntityPedIsCarrying(ped)
            if holding ~= 0 and holding ~= keptEntity and not fishing then
                local model = GetEntityModel(holding)
                if fishModels[model] then
                    NetworkRequestControlOfEntity(holding)
                    SetEntityAsMissionEntity(holding, true, true)
                    Wait(100)
                    DeleteEntity(holding)
                    Wait(500)
                    if GetFirstEntityPedIsCarrying(ped) == 0 then
                        TriggerServerEvent('rsg-fishing:server:catchFish', model, 0)
                    end
                end
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'controls', show = false })
    SendNUIMessage({ action = 'bobber', show = false })
    SendNUIMessage({ action = 'tension', show = false })
    if fishing then
        SetFishingBait(PlayerPedId(), '', 0, 1)
        music(false)
    end
    Citizen.InvokeNative(0x48B3886C1358D0D5, 0, 0, 0)
    releaseSounds()
    fishing = false
end)
