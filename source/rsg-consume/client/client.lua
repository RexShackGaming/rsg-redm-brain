local RSGCore = exports['rsg-core']:GetCoreObject()
local config = Config

local isBusy = false
local alcoholCount = 0
local drunkActive = false
local passingOut = false
local activeProps = {}
local toleranceMult = 1.0 -- from the server: raises the drunk / pass-out thresholds
local hintShown = false
local buffToken = { health = 0, stamina = 0 }
local targetNames = {}
local zones = {}

local fx = config.AlcoholEffects
local alc = config.AlcoholSystem

-- =========================================================================================
-- Helpers
-- =========================================================================================

local function notify(key, nType, duration)
    RSGCore.Functions.Notify({
        title = locale(key .. '_title'),
        description = locale(key .. '_desc'),
        type = nType,
        duration = duration,
        position = 'top-right',
    })
end

---Notification with the generic title and a single description key
local function say(key, nType, duration)
    RSGCore.Functions.Notify({
        title = locale('title_consume'), description = locale(key),
        type = nType, duration = duration, position = 'top-right',
    })
end

local function loadAsset(hasLoaded, request, asset)
    if hasLoaded(asset) then return true end
    request(asset)
    local timeout = GetGameTimer() + 5000
    while not hasLoaded(asset) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function playAnim(ped, dict, anim, flag, duration)
    if not loadAsset(HasAnimDictLoaded, RequestAnimDict, dict) then return end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flag or 1, 0, false, false, false)
    RemoveAnimDict(dict)
end

---Loads a model and creates a networked object at the ped.
local function createProp(ped, model)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(model) or not loadAsset(HasModelLoaded, RequestModel, model) then return end
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false, false, true)
    SetModelAsNoLongerNeeded(model)
    activeProps[#activeProps + 1] = obj
    return obj
end

local function attachProp(ped, model, bone, x, y, z, rx, ry, rz)
    local prop = createProp(ped, model)
    if not prop then return end
    AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, bone), x, y, z, rx, ry, rz, true, true, false, true, 1, true)
    return prop
end

local function safeDelete(obj)
    if obj and DoesEntityExist(obj) then
        DetachEntity(obj, true, true)
        DeleteObject(obj)
    end
end

local function setDrunkLevel(ped, level)
    Citizen.InvokeNative(0x406CCF555B04FAD3, ped, 1, level) -- _SET_PED_DRUNKNESS
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- =========================================================================================
-- Alcohol System
-- =========================================================================================

local function drunkThreshold() return alc.DrunkThreshold * toleranceMult end
local function passOutThreshold() return alc.PassOutThreshold * toleranceMult end

---Drunkness (0-1) for the current level, scaled between the drunk and pass-out thresholds.
local function drunkLevel()
    if not alc.ScaleDrunkness then return alc.MaxDrunkLevel end
    local span = math.max(1, passOutThreshold() - drunkThreshold())
    local t = clamp((alcoholCount - drunkThreshold()) / span, 0.0, 1.0)
    return alc.MinDrunkLevel + (alc.MaxDrunkLevel - alc.MinDrunkLevel) * t
end

local function resetAlcohol(ped)
    if drunkActive and fx.DrunkEffect then AnimpostfxStop(fx.DrunkEffectName) end
    alcoholCount = 0
    drunkActive = false
    setDrunkLevel(ped, 0.0)
end

local function setDrunk(ped, state)
    if state == drunkActive then
        if state then setDrunkLevel(ped, drunkLevel()) end -- keep it applied/scaled (survives respawn)
        return
    end
    drunkActive = state
    setDrunkLevel(ped, state and drunkLevel() or 0.0)

    if fx.DrunkEffect then
        if state then AnimpostfxPlay(fx.DrunkEffectName) else AnimpostfxStop(fx.DrunkEffectName) end
    end
    if state then notify('drunk', 'inform', 3000) else notify('sober', 'success', 2000) end
end

local function endPassOut(ped)
    FreezeEntityPosition(ped, false)
    AnimpostfxStop(fx.PassOutEffect)
    AnimpostfxStop(fx.WakeUpEffect)
    AnimpostfxStop(fx.GroggyEffectName)
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(500) end
    resetAlcohol(ped)
    passingOut = false
end

local function handlePassOut(ped)
    passingOut = true
    notify('passout', 'error', 5000)

    playAnim(ped, 'amb_misc@world_human_vomit@male_a@idle_b', 'idle_f', 31, fx.VomitDuration)
    Wait(fx.VomitDuration)
    if IsEntityDead(ped) then return endPassOut(ped) end
    ClearPedTasks(ped)

    -- sleep on the ground for SleepDuration in total; the screen fades out while falling asleep
    local frozen = not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
    if frozen then FreezeEntityPosition(ped, true) end
    playAnim(ped, 'amb_rest@world_human_sleep_ground@arm@male_b@idle_b', 'idle_f', 1, fx.SleepDuration)
    AnimpostfxPlay(fx.PassOutEffect)
    DoScreenFadeOut(fx.FadeOutDuration)
    Wait(math.max(fx.FadeOutDuration, fx.SleepDuration))
    if IsEntityDead(ped) then return endPassOut(ped) end

    AnimpostfxStop(fx.PassOutEffect)
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    Citizen.InvokeNative(0x58F7DB5BD8FA2288, ped) -- _CLEAR_PED_TASKS_EXTRA (wake up)

    resetAlcohol(ped)

    AnimpostfxPlay(fx.GroggyEffectName)
    setDrunkLevel(ped, alc.MaxDrunkLevel)
    AnimpostfxPlay(fx.WakeUpEffect)
    DoScreenFadeIn(fx.FadeInDuration)
    Wait(fx.FadeInDuration)
    AnimpostfxStop(fx.WakeUpEffect)
    notify('wakeup', 'inform', 5000)
    TriggerServerEvent('rsg-consume:server:passedOut') -- hangover: server takes thirst / adds stress

    Wait(fx.GroggyDuration)
    AnimpostfxStop(fx.GroggyEffectName)
    setDrunkLevel(PlayerPedId(), 0.0)
    notify('sober', 'success', 2000)
    passingOut = false
end

---Applies the current alcohol level: pass out, drunk or sober.
local function evaluateAlcohol(ped)
    if passingOut then return end
    if alcoholCount > passOutThreshold() then
        handlePassOut(ped)
    else
        setDrunk(ped, alcoholCount > drunkThreshold())
    end
end

CreateThread(function()
    while true do
        if alcoholCount > 0 and not passingOut then
            Wait(alc.DecreaseInterval)
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                resetAlcohol(ped) -- dying sobers you up
            else
                alcoholCount = math.max(0, alcoholCount - alc.DecreaseAmount)
                evaluateAlcohol(ped)
            end
        else
            Wait(2000)
        end
    end
end)

-- A new character must not inherit the previous one's drunkenness
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    if not passingOut then resetAlcohol(PlayerPedId()) end
    toleranceMult = 1.0
end)

RegisterNetEvent('rsg-consume:client:tolerance', function(mult)
    if GetInvokingResource() then return end
    toleranceMult = clamp(tonumber(mult) or 1.0, 1.0, 3.0)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    RSGCore.Functions.TriggerCallback('rsg-consume:server:getTolerance', function(mult)
        toleranceMult = clamp(tonumber(mult) or 1.0, 1.0, 3.0)
    end)
end)

-- =========================================================================================
-- Consumption animations (return props + duration)
-- =========================================================================================

local animations = {}

function animations.Eat(ped, data)
    local prop = attachProp(ped, data.propname, 'SKEL_L_Finger01', 0.04, -0.03, -0.01, 0.0, 19.0, 46.0)
    playAnim(ped, 'mech_inventory@eating@multi_bite@sphere_d8-2_sandwich', 'quick_left_hand', 31, -1)
    return 5000, prop
end

function animations.Drink(ped, data)
    local prop = attachProp(ped, data.propname, 'PH_R_HAND', 0.0, 0.0, 0.04, 0.0, 0.0, 0.0)
    if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) then
        local dict = 'mech_inventory@drinking@bottle_cylinder_d1-3_h30-5_neck_a13_b2-5'
        playAnim(ped, dict, 'uncork', 31, 500)
        Wait(500)
        playAnim(ped, dict, 'chug_a', 31, -1)
        return 4500, prop
    end
    TaskItemInteraction_2(ped, 1737033966, prop, `p_bottleJD01x_ph_r_hand`, `DRINK_Bottle_Cylinder_d1-55_H18_Neck_A8_B1-8_QUICK_RIGHT_HAND`, true, 0, 0)
    return 4000, prop
end

-- Stew and Hotdrinks use fixed props: the item-interaction clips are bound to these models
function animations.Stew(ped)
    local bowl = createProp(ped, `p_bowl04x_stew`)
    local spoon = createProp(ped, `p_spoon01x`)
    Citizen.InvokeNative(0x669655FFB29EF1A9, bowl, 0, 'Stew_Fill', 1.0)
    Citizen.InvokeNative(0xCAAF2BCCFEF37F77, bowl, 20)
    Citizen.InvokeNative(0xCAAF2BCCFEF37F77, spoon, 82)
    TaskItemInteraction_2(ped, 599184882, bowl, `p_bowl04x_stew_ph_l_hand`, -583731576, 1, 0, 0.0)
    TaskItemInteraction_2(ped, 599184882, spoon, `p_spoon01x_ph_r_hand`, -583731576, 1, 0, 0.0)
    Citizen.InvokeNative(0xB35370D5353995CB, ped, -583731576, 1.0)

    -- Wait for the interaction to actually finish instead of cutting it off at a fixed time.
    -- 0x6AA3DCA2C6F5EB6D = _GET_ITEM_INTERACTION_STATE; -1318807663 = no active interaction.
    Wait(500) -- give the task time to start
    local timeout = GetGameTimer() + 15000
    while GetGameTimer() < timeout do
        local state = Citizen.InvokeNative(0x6AA3DCA2C6F5EB6D, ped)
        if not state or state == 0 or state == -1318807663 or IsEntityDead(ped) then break end
        Wait(250)
    end
    return 0, bowl, spoon
end

function animations.Hotdrinks(ped)
    local mug = createProp(ped, `P_MUGCOFFEE01X`)
    Citizen.InvokeNative(0x669655FFB29EF1A9, mug, 0, 'CTRL_cupFill', 1.0)
    TaskItemInteraction_2(ped, `CONSUMABLE_COFFEE`, mug, `P_MUGCOFFEE01X_PH_R_HAND`, `DRINK_COFFEE_HOLD`, 1, 0, -1)
    return 5000, mug
end

function animations.Eatcanned(ped, data)
    local prop = attachProp(ped, data.propname, 'SKEL_L_Finger00', 0.10, -0.03, 0.02, 20.0, -70.0, -20.0)
    if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) and not IsPedUsingAnyScenario(ped) then
        playAnim(ped, 'mech_inventory@eating@canned_food@cylinder@d8-2_h10-5', 'left_hand', 31, -1)
    else
        TaskItemInteraction(ped, 0, `EAT_CANNED_FOOD_CYLINDER@D8-2_H10-5_QUICK_LEFT`, true, 0, 0)
    end
    return 2750, prop
end

-- =========================================================================================
-- Timed effects (all values come from the server)
-- =========================================================================================

---Sick from rotten food: vomit for a while
RegisterNetEvent('rsg-consume:client:sick', function(duration)
    if GetInvokingResource() or passingOut then return end
    say('spoiled', 'error', 5000)
    CreateThread(function()
        local ped = PlayerPedId()
        playAnim(ped, 'amb_misc@world_human_vomit@male_a@idle_b', 'idle_f', 31, tonumber(duration) or 6000)
        Wait(tonumber(duration) or 6000)
        if not IsEntityDead(ped) then ClearPedTasks(ped) end
    end)
end)

---Health / stamina over time. A new buff of the same kind replaces the running one.
RegisterNetEvent('rsg-consume:client:buff', function(buffs)
    if GetInvokingResource() or type(buffs) ~= 'table' then return end
    for kind, b in pairs(buffs) do
        if (kind == 'health' or kind == 'stamina') and b.duration > 0 then
            buffToken[kind] = buffToken[kind] + 1
            local token = buffToken[kind]
            CreateThread(function()
                local untilTime = GetGameTimer() + b.duration
                while GetGameTimer() < untilTime and buffToken[kind] == token do
                    Wait(b.interval)
                    local ped = PlayerPedId()
                    if IsEntityDead(ped) then break end
                    if kind == 'health' then
                        local hp, maxHp = GetEntityHealth(ped), GetEntityMaxHealth(ped)
                        if hp < maxHp then SetEntityHealth(ped, math.min(maxHp, hp + b.amount)) end
                    else
                        Citizen.InvokeNative(0x675680D089BFA21F, ped, b.amount + 0.0) -- RESTORE_PED_STAMINA
                    end
                end
            end)
        end
    end
end)

---Warm / cold items change the body temperature shown and used by rsg-hud (needs rsg-hud 'AddWarmth')
RegisterNetEvent('rsg-consume:client:warmth', function(amount, duration)
    if GetInvokingResource() or GetResourceState('rsg-hud') ~= 'started' then return end
    pcall(function() exports['rsg-hud']:AddWarmth(tonumber(amount) or 0, tonumber(duration) or 0) end)
end)

-- =========================================================================================
-- Consumption handler (only triggered by the server after the item was removed)
-- =========================================================================================

local function applyStats(data)
    -- hunger, thirst and stress are applied server-side in rsg-consume:server:finish (rsg-hud is authoritative)
    if data.alcohol then
        alcoholCount = clamp(alcoholCount + data.alcohol, 0, alc.MaxAlcoholLevel)
    end
end

---Things that make eating or drinking impossible right now
local function canConsume(ped)
    return not (IsPedSwimming(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedClimbing(ped))
end

---Waits for the animation, polling the cancel key. Returns true when the player cancelled.
local function waitForAnimation(ped, duration, canCancel)
    local cfg = config.Cancel
    local key = canCancel and cfg and RSGCore.Shared.Keybinds[cfg.Key]
    local untilTime = GetGameTimer() + duration
    while GetGameTimer() < untilTime do
        if IsEntityDead(ped) then return false end
        if key and IsControlJustPressed(0, key) then return true end
        Wait(key and 0 or 100)
    end
    return false
end

RegisterNetEvent('rsg-consume:client:consume', function(itemName, category, extra)
    if GetInvokingResource() then return end -- server-only trigger
    extra = type(extra) == 'table' and extra or {}
    if extra.tolerance then toleranceMult = clamp(tonumber(extra.tolerance) or 1.0, 1.0, 3.0) end
    local data = config.Consumables[category] and config.Consumables[category][itemName]
    local anim = animations[category]
    local ped = PlayerPedId()

    -- Server already removed the item: if we can't play it, tell the server to refund it
    if not data or not anim or isBusy or passingOut or IsEntityDead(ped) or not canConsume(ped) then
        if not IsEntityDead(ped) then
            RSGCore.Functions.Notify({ title = locale('title_consume'), description = locale('cannot_now'), type = 'error', duration = 3000, position = 'top-right' })
        end
        TriggerServerEvent('rsg-consume:server:finish', false)
        return
    end

    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local ok, duration, prop, prop2 = pcall(anim, ped, data)
    local cancelled, progress = false, 1.0
    if ok then
        local canCancel = extra.cancel == true and duration > 0
        if canCancel and config.Cancel.Hint and not hintShown then
            hintShown = true
            say('cancel_hint', 'inform', 4000)
        end
        local started = GetGameTimer()
        cancelled = waitForAnimation(ped, duration, canCancel)
        if cancelled then progress = clamp((GetGameTimer() - started) / duration, 0.0, 1.0) end
    else
        print(('^1[rsg-consume] animation error (%s/%s): %s^7'):format(category, itemName, duration))
    end

    ClearPedTasks(ped)
    safeDelete(prop)
    safeDelete(prop2)
    activeProps = {}

    local alive = not IsEntityDead(PlayerPedId())
    if ok and alive then
        -- alcohol is tracked locally; a cancelled drink only counts for the part that was drunk
        local scaled = {}
        for k, v in pairs(data) do scaled[k] = v end
        if scaled.alcohol then scaled.alcohol = scaled.alcohol * progress end
        applyStats(scaled)
        TriggerEvent('rsg-consume:client:onConsume', data)
    end

    -- Releases the server lock, applies hunger/thirst/stress and gives back any return item.
    -- A failed animation or a death mid-use is reported as "not consumed" so the item is refunded.
    TriggerServerEvent('rsg-consume:server:finish', ok and alive, cancelled)

    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false

    -- react to the new alcohol level straight away instead of at the next decay tick
    if data.alcohol and data.alcohol > 0 then evaluateAlcohol(PlayerPedId()) end
end)

-- =========================================================================================
-- Bars (order a drink at the counter) and sharing (hand a drink to a nearby player)
-- =========================================================================================

local function itemLabel(name)
    local shared = RSGCore.Shared.Items[name]
    return shared and shared.label or name
end

CreateThread(function()
    for index, bar in ipairs(config.Bars or {}) do
        local options = {}
        for itemName, price in pairs(bar.items) do
            options[#options + 1] = {
                name = ('rsg-consume:bar:%d:%s'):format(index, itemName),
                icon = bar.icon or 'fa-solid fa-champagne-glasses',
                label = locale('bar_label', itemLabel(itemName), price),
                distance = 2.0,
                onSelect = function() TriggerServerEvent('rsg-consume:server:bar', index, itemName) end,
            }
        end
        table.sort(options, function(a, b) return a.label < b.label end)
        zones[#zones + 1] = exports['rsg-target']:addSphereZone({
            name = ('rsg-consume:bar:%d'):format(index),
            coords = bar.coords, radius = bar.radius or 3.0, options = options,
        })
    end

    if config.Share and config.Share.Enabled then
        local options = {}
        for itemName in pairs(config.Share.Items) do
            local name = 'rsg-consume:share:' .. itemName
            targetNames[#targetNames + 1] = name
            options[#options + 1] = {
                name = name,
                icon = 'fa-solid fa-wine-glass',
                label = locale('share_label', itemLabel(itemName)),
                distance = config.Share.Distance,
                canInteract = function() return RSGCore.Functions.HasItem(itemName, 1) end,
                onSelect = function(target)
                    local player = NetworkGetPlayerIndexFromPed(target.entity)
                    if player == -1 then return end
                    TriggerServerEvent('rsg-consume:server:share', GetPlayerServerId(player), itemName)
                end,
            }
        end
        exports['rsg-target']:addGlobalPlayer(options)
    end
end)

-- =========================================================================================
-- Cleanup
-- =========================================================================================

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    for _, obj in ipairs(activeProps) do safeDelete(obj) end
    if isBusy then
        ClearPedTasks(ped)
        LocalPlayer.state:set('inv_busy', false, true)
    end
    AnimpostfxStop(fx.DrunkEffectName)
    AnimpostfxStop(fx.PassOutEffect)
    AnimpostfxStop(fx.WakeUpEffect)
    AnimpostfxStop(fx.GroggyEffectName)
    setDrunkLevel(ped, 0.0)
    FreezeEntityPosition(ped, false)
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(500) end
    buffToken.health, buffToken.stamina = buffToken.health + 1, buffToken.stamina + 1
    for _, zone in ipairs(zones) do exports['rsg-target']:removeZone(zone) end
    if #targetNames > 0 then exports['rsg-target']:removeGlobalPlayer(targetNames) end
end)
