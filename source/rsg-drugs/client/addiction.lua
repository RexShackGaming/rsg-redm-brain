lib.locale()

local currentStage = 0
local activeFx = nil
local busy = false
local uiOpen = false
local highToken = 0

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getData()
    return LocalPlayer.state.addiction
end

local function inRehab()
    local d = getData()
    return d and (d.rehab or 0) > 0
end

-- Highest withdrawal stage across all substances
local function calcStage(d)
    if not d or not d.subs then return 0, nil end
    local best, bestKey = 0, nil
    for key, sub in pairs(d.subs) do
        local cfg = Config.Addiction.Substances[key]
        if cfg and (sub.level or 0) >= cfg.threshold then
            for i = #Config.Addiction.Stages, 1, -1 do
                if (sub.craving or 0) >= Config.Addiction.Stages[i].craving then
                    if i > best then best, bestKey = i, key end
                    break
                end
            end
        end
    end
    if best > 1 and (d.rehab or 0) > 0 then best = 1 end -- detox under supervision keeps it mild
    return best, bestKey
end

local function setFx(name)
    if activeFx == name then return end
    if activeFx then AnimpostfxStop(activeFx) end
    activeFx = name
    if name then AnimpostfxPlay(name) end
end

local function clearEffects()
    setFx(nil)
    StopGameplayCamShaking(true)
end

local function applyStage(stage, key)
    if stage == currentStage then return end
    local prev = currentStage
    currentStage = stage
    StopGameplayCamShaking(true)
    if stage == 0 then return setFx(nil) end
    local s = Config.Addiction.Stages[stage]
    ShakeGameplayCam(Config.Addiction.ShakeName, s.shake)
    setFx(s.fx)
    if stage > prev then
        local label = key and Config.Addiction.Substances[key].label or ''
        lib.notify({ title = locale('addiction_title'), description = locale('stage_' .. stage, label), type = stage >= 3 and 'error' or 'warning', duration = 6000 })
    end
end

---------------------------------------------------------------------
-- Rehab countdown HUD (top left, no NUI focus). The server syncs the remaining time
-- every ~30s; the page counts down locally in between.
---------------------------------------------------------------------
local hudShown = false
local function updateRehabHud(d)
    local left = d and tonumber(d.rehab) or 0
    if left > 0 then
        hudShown = true
        SendNUIMessage({
            action = 'rehab:hud', left = left, total = math.max(left, tonumber(d.rehabTotal) or left),
            title = locale('ui_rehab_hud_title'), sub = locale('ui_rehab_hud_sub'),
        })
    elseif hudShown then
        hudShown = false
        SendNUIMessage({ action = 'rehab:hide' })
    end
end

---------------------------------------------------------------------
-- Statebag sync
---------------------------------------------------------------------
AddStateBagChangeHandler('addiction', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    local stage, key = calcStage(value)
    applyStage(stage, key)
    updateRehabHud(value)
    if uiOpen then SendNUIMessage({ action = 'addiction:update', data = value }) end
end)

---------------------------------------------------------------------
-- Withdrawal effects loop
---------------------------------------------------------------------
CreateThread(function()
    while true do
        if currentStage == 0 then
            Wait(2000)
        else
            local s = Config.Addiction.Stages[currentStage]
            local ped = cache.ped

            -- stamina cap (core index 1 = ATTRIBUTE_CORE_STAMINA, natives/db/ATTRIBUTE.md)
            if s.staminaCap < 100 and Citizen.InvokeNative(0x36731AC041289BB1, ped, 1) > s.staminaCap then
                Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, s.staminaCap)
            end

            -- stumble
            if s.stumbleChance > 0 and not IsPedInAnyVehicle(ped, false) and not IsPedOnMount(ped) and not IsEntityDead(ped) then
                local moving = IsPedRunning(ped) or IsPedSprinting(ped) or IsPedWalking(ped)
                if (moving or not Config.Addiction.StumbleOnlyMoving) and math.random(100) <= s.stumbleChance then
                    SetPedToRagdoll(ped, 1200, 2200, 0, false, false, false)
                end
            end

            -- stress (same server event rsg-consume uses)
            if s.stress > 0 then TriggerServerEvent('hud:server:GainStress', s.stress) end

            -- keep shake running (some actions cancel it)
            if not IsGameplayCamShaking() then ShakeGameplayCam(Config.Addiction.ShakeName, s.shake) end

            Wait(Config.Addiction.EffectInterval)
        end
    end
end)

---------------------------------------------------------------------
-- Using a substance registered by this resource (server already removed the item)
---------------------------------------------------------------------
RegisterNetEvent('rsg-drugs:client:useSubstance', function(key)
    local cfg = Config.Addiction.Substances[key]
    if not cfg or busy then return end
    busy = true
    local ped = cache.ped
    if cfg.useScenario and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
        TaskStartScenarioInPlaceHash(ped, joaat(cfg.useScenario), cfg.useTime or 8000, true, 0, -1.0, false)
        Wait(cfg.useTime or 8000)
        ClearPedTasks(ped)
    end
    local b = cfg.boost
    lib.notify({ title = locale('addiction_title'), description = b and locale('boost') or locale('used', cfg.label), type = b and 'success' or 'inform', duration = 6000 })
    if b then
        ped = cache.ped
        for core, value in pairs(b.fillCores or {}) do
            Citizen.InvokeNative(0xC6258F41D86676E0, ped, core, value) -- _SET_ATTRIBUTE_CORE_VALUE
        end
        for _, core in ipairs(b.goldCores or {}) do
            Citizen.InvokeNative(0x4AF5A4C7B9157D14, ped, core, b.goldSeconds or 45.0, true) -- _ENABLE_ATTRIBUTE_CORE_OVERPOWER
        end
    end
    if cfg.highEffect and cfg.highEnabled ~= false then
        -- a second joint extends the high instead of the first timer cutting it short
        highToken = highToken + 1
        local token = highToken
        if not AnimpostfxIsRunning(cfg.highEffect) then AnimpostfxPlay(cfg.highEffect) end
        SetTimeout(cfg.highTime or 30000, function()
            if token == highToken then AnimpostfxStop(cfg.highEffect) end
        end)
    end
    busy = false
end)

-- Hook rsg-consume (alcohol etc.). Server validates the item + rate limits.
RegisterNetEvent('rsg-consume:client:consume', function(itemName)
    TriggerServerEvent('rsg-drugs:server:consumed', itemName)
end)

---------------------------------------------------------------------
-- Rehab teleport + local fence
---------------------------------------------------------------------
RegisterNetEvent('rsg-drugs:client:teleport', function(pos)
    local ped = cache.ped
    DoScreenFadeOut(500)
    local t = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(10) end
    -- a mounted/seated ped would drag the horse or wagon along (or fail to move)
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then ClearPedTasksImmediately(ped) end
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    if pos.w then SetEntityHeading(ped, pos.w) end
    Wait(800)
    DoScreenFadeIn(800)
end)

---------------------------------------------------------------------
-- Rehab belongings: disarm on admission, re-equip on release (rsg-weapons)
---------------------------------------------------------------------
RegisterNetEvent('rsg-drugs:client:disarm', function()
    if GetResourceState('rsg-weapons') == 'started' then
        for _, v in pairs(exports['rsg-weapons']:GetUsedWeapons() or {}) do
            if v.name then TriggerEvent('rsg-weapons:client:UseWeapon', { name = v.name }) end -- name only = unequip
        end
    end
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true, 0, false, false)
end)

RegisterNetEvent('rsg-drugs:client:reequip', function(list)
    if type(list) ~= 'table' or GetResourceState('rsg-weapons') ~= 'started' then return end
    CreateThread(function()
        Wait(1500) -- let the inventory sync first
        for _, item in ipairs(list) do
            TriggerEvent('rsg-weapons:client:UseWeapon', item)
            Wait(500)
        end
        Wait(500)
        Citizen.InvokeNative(0x94A3C1B804D291EC, cache.ped, false, false, false, true) -- holster (same as rsg-weapons restore)
    end)
end)

---------------------------------------------------------------------
-- Voluntary check-in
---------------------------------------------------------------------
DrugsProximityNpc(Config.Addiction.Rehab.CheckIn, {
    name = 'rsg_addiction_checkin',
    icon = 'fa-solid fa-hand-holding-medical',
    label = locale('rehab_checkin'),
    canInteract = function() return not inRehab() end,
    onSelect = function() TriggerServerEvent('rsg-drugs:server:checkIn') end,
})

---------------------------------------------------------------------
-- NUI status panel
---------------------------------------------------------------------
local function buildLabels()
    local subs = {}
    for key, cfg in pairs(Config.Addiction.Substances) do subs[key] = { label = cfg.label, threshold = cfg.threshold } end
    return {
        subs = subs,
        title = locale('addiction_title'), subtitle = locale('ui_subtitle'),
        level = locale('ui_level'), craving = locale('ui_craving'),
        clean = locale('ui_clean'), hooked = locale('ui_hooked'), rehab = locale('ui_rehab'),
    }
end

RegisterNetEvent('rsg-drugs:client:openUI', function()
    if uiOpen then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'addiction:open', data = getData(), labels = buildLabels(), stage = currentStage, stageLabel = currentStage > 0 and Config.Addiction.Stages[currentStage].label or nil })
end)

local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'addiction:close' })
end

RegisterNUICallback('addictionClose', function(_, cb) closeUI(); cb('ok') end)

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    clearEffects()
    currentStage = 0
    closeUI()
    updateRehabHud(nil)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    local stage, key = calcStage(getData())
    applyStage(stage, key)
    updateRehabHud(getData())
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearEffects()
    for _, cfg in pairs(Config.Addiction.Substances) do
        if cfg.highEffect then AnimpostfxStop(cfg.highEffect) end
    end
    if uiOpen then SetNuiFocus(false, false) end
end)
