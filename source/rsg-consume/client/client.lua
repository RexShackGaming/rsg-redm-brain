local config = require 'shared.config'
lib.locale()

local isBusy = false
local alcoholCount = 0
local drunkActive = false
local passingOut = false

local fx = config.AlcoholEffects
local alc = config.AlcoholSystem

-- =========================================================================================
-- Helpers
-- =========================================================================================

local function notify(key, nType, duration)
    lib.notify({
        title = locale(key .. '_title'),
        description = locale(key .. '_desc'),
        type = nType,
        duration = duration,
        position = 'top-right',
    })
end

local function playAnim(ped, dict, anim, flag, duration)
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flag or 1, 0, false, false, false)
    RemoveAnimDict(dict)
end

---Loads a model and creates a networked object at the ped.
local function createProp(ped, model)
    model = type(model) == 'string' and joaat(model) or model
    lib.requestModel(model)
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false, false, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function attachProp(ped, model, bone, x, y, z, rx, ry, rz)
    local prop = createProp(ped, model)
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

local function setDrunk(ped, state)
    if state == drunkActive then return end
    drunkActive = state
    setDrunkLevel(ped, state and 0.95 or 0.0)

    if fx.DrunkEffect then
        if state then AnimpostfxPlay(fx.DrunkEffectName) else AnimpostfxStop(fx.DrunkEffectName) end
    end
    if state then notify('drunk', 'inform', 3000) else notify('sober', 'success', 2000) end
end

local function handlePassOut(ped)
    passingOut = true
    notify('passout', 'error', 5000)

    playAnim(ped, 'amb_misc@world_human_vomit@male_a@idle_b', 'idle_f', 31, fx.VomitDuration)
    Wait(fx.VomitDuration)
    ClearPedTasks(ped)

    playAnim(ped, 'amb_rest@world_human_sleep_ground@arm@male_b@idle_b', 'idle_f', 1, fx.SleepDuration)
    AnimpostfxPlay(fx.PassOutEffect)
    DoScreenFadeOut(fx.FadeOutDuration)
    Wait(fx.FadeOutDuration)
    AnimpostfxStop(fx.PassOutEffect)

    ClearPedTasks(ped)
    Citizen.InvokeNative(0x58F7DB5BD8FA2288, ped) -- _CLEAR_PED_TASKS_EXTRA (wake up)

    alcoholCount = 0
    if drunkActive and fx.DrunkEffect then AnimpostfxStop(fx.DrunkEffectName) end
    drunkActive = false

    AnimpostfxPlay(fx.GroggyEffectName)
    setDrunkLevel(ped, 0.95)
    AnimpostfxPlay(fx.WakeUpEffect)
    DoScreenFadeIn(fx.FadeInDuration)
    Wait(fx.FadeInDuration)
    AnimpostfxStop(fx.WakeUpEffect)
    notify('wakeup', 'inform', 5000)

    Wait(fx.GroggyDuration)
    AnimpostfxStop(fx.GroggyEffectName)
    setDrunkLevel(ped, 0.0)
    notify('sober', 'success', 2000)
    passingOut = false
end

CreateThread(function()
    while true do
        if alcoholCount > 0 then
            Wait(alc.DecreaseInterval)
            alcoholCount = math.max(0, alcoholCount - alc.DecreaseAmount)
            local ped = cache.ped

            if alcoholCount > alc.PassOutThreshold then
                handlePassOut(ped)
            else
                setDrunk(ped, alcoholCount > alc.DrunkThreshold)
            end
        else
            Wait(2000)
        end
    end
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
-- Consumption handler (only triggered by the server after the item was removed)
-- =========================================================================================

local function applyStats(data)
    if data.alcohol then
        alcoholCount = clamp(alcoholCount + data.alcohol, 0, alc.MaxAlcoholLevel)
    end
    if data.hunger and data.hunger ~= 0 then
        TriggerEvent('hud:client:UpdateHunger', clamp((LocalPlayer.state.hunger or 0) + data.hunger, 0, 100))
    end
    if data.thirst and data.thirst ~= 0 then
        TriggerEvent('hud:client:UpdateThirst', clamp((LocalPlayer.state.thirst or 0) + data.thirst, 0, 100))
    end
    if data.stress then
        if data.stress > 0 then
            TriggerEvent('hud:client:RelieveStress', data.stress)
        elseif data.stress < 0 then
            TriggerServerEvent('hud:server:GainStress', -data.stress)
        end
    end
end

RegisterNetEvent('rsg-consume:client:consume', function(itemName, category)
    if GetInvokingResource() then return end -- server-only trigger
    local data = config.Consumables[category] and config.Consumables[category][itemName]
    local anim = animations[category]
    local ped = cache.ped

    -- Server already removed the item: if we can't play it, tell the server to refund it
    if not data or not anim or isBusy or passingOut or IsEntityDead(ped) then
        TriggerServerEvent('rsg-consume:server:finish', false)
        return
    end

    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    local ok, duration, prop, prop2 = pcall(anim, ped, data)
    if ok then Wait(duration) end

    ClearPedTasks(ped)
    safeDelete(prop)
    safeDelete(prop2)

    applyStats(data)
    TriggerEvent('rsg-consume:client:onConsume', data)

    -- Releases the server lock and gives back any return item (e.g. emptybottle)
    TriggerServerEvent('rsg-consume:server:finish', true)

    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false
end)
