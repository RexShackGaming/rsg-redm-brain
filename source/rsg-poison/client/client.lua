lib.locale()

local poisoned = false
local antidoteUsed = false
local drinking = false
local activeAntidoteProp = nil

local ANTIDOTE_PROP = `p_bottlebeer01a`
local ANTIDOTE_ANIM_MS = 4000
local DEATH_CHECK_MS = 1000
local EVENT_ENTITY_DAMAGED = `EVENT_ENTITY_DAMAGED`

-- Hash lookups built once at load, not per damage event
local function toHashSet(list, key)
    local set = {}
    for _, entry in ipairs(list or {}) do
        set[joaat(key and entry[key] or entry)] = true
    end
    return set
end

local poisonAmmoHashes   = toHashSet(Config.PoisonAmmo)
local poisonWeaponHashes = toHashSet(Config.PoisonWeapons)
local snakeModelHashes   = toHashSet(Config.Snakes, 'model')

local function safeDelete(obj)
    if obj and DoesEntityExist(obj) then
        DetachEntity(obj, true, true)
        DeleteObject(obj)
    end
end

local function setIndicator(state)
    SendNUIMessage({ action = 'poisonState', state = state, text = state and locale('cl_poison_indicator_text') or nil })
end

local function resetPoisonState()
    poisoned = false
    antidoteUsed = false
    setIndicator(false)
    TriggerServerEvent('rsg-poison:server:setPoisoned', false)
end

--- Starts the drain loop in its own thread.
--- resumed: true when restoring state the server already holds (no server push, softer notify).
local function startPoison(resumed, cause)
    if poisoned then return end
    poisoned = true
    antidoteUsed = false
    setIndicator(true)

    if not resumed then
        TriggerServerEvent('rsg-poison:server:setPoisoned', true, cause)
    end

    lib.notify({
        title = locale(resumed and 'cl_still_poisoned_title' or 'cl_poisoned_title'),
        description = locale(resumed and 'cl_still_poisoned_desc' or 'cl_poisoned_desc'),
        type = 'error',
        duration = 7000
    })

    CreateThread(function()
        local sinceDrain = 0
        while poisoned do
            Wait(DEATH_CHECK_MS)
            sinceDrain = sinceDrain + DEATH_CHECK_MS

            local ped = cache.ped
            if antidoteUsed or IsPedDeadOrDying(ped, true) then
                resetPoisonState()
                return
            end

            if sinceDrain >= Config.PoisonTickInterval then
                sinceDrain = 0
                ApplyDamageToPed(ped, Config.PoisonHealthDrainBase, false, true, true)
            end
        end
    end)
end

local function resumeFromServer()
    if lib.callback.await('rsg-poison:server:getPoisonState', false) then
        startPoison(true)
    end
end

RegisterNetEvent('rsg-poison:client:useAntidote', function()
    if drinking then return end
    -- server only sends this after confirming we're poisoned and taking the item,
    -- so resync a desynced client instead of silently wasting the antidote
    if not poisoned then startPoison(true) end
    drinking = true

    local ped = cache.ped
    lib.requestModel(ANTIDOTE_PROP)
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(ANTIDOTE_PROP, coords.x, coords.y, coords.z, true, false, false)
    SetModelAsNoLongerNeeded(ANTIDOTE_PROP)
    AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, 'PH_R_HAND'), 0.0, 0.0, 0.04, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    activeAntidoteProp = prop
    TaskItemInteraction_2(ped, 1737033966, prop, `p_bottleJD01x_ph_r_hand`, `DRINK_Bottle_Cylinder_d1-55_H18_Neck_A8_B1-8_QUICK_RIGHT_HAND`, true, 0, 0)

    -- poll so we can bail out cleanly if the ped dies mid-animation
    local interrupted = false
    for _ = 1, ANTIDOTE_ANIM_MS / 100 do
        Wait(100)
        if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
            interrupted = true
            break
        end
    end

    ClearPedTasks(ped)
    safeDelete(prop)
    activeAntidoteProp = nil
    drinking = false

    if interrupted then return end

    antidoteUsed = true
    lib.notify({
        title = locale('cl_antidote_used_title'),
        description = locale('cl_antidote_used_desc'),
        type = 'success',
        duration = 5000
    })
end)

-- Cured by the server (medic / other resource via exports.CurePlayer)
RegisterNetEvent('rsg-poison:client:cured', function()
    if not poisoned then return end
    poisoned = false
    antidoteUsed = false
    setIndicator(false)
    lib.notify({
        title = locale('cl_cured_title'),
        description = locale('cl_cured_desc'),
        type = 'success',
        duration = 5000
    })
end)

-- Server rejected our cure or wants us back in sync
RegisterNetEvent('rsg-poison:client:resumePoison', function()
    startPoison(true)
end)

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000) -- let the ped finish spawning
    resumeFromServer()
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    poisoned = false
    antidoteUsed = false
    setIndicator(false)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then
        Wait(1000)
        resumeFromServer()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    safeDelete(activeAntidoteProp)
end)

-- Watch damage events for poison ammo/weapons and snake bites
CreateThread(function()
    while true do
        if poisoned then
            Wait(500) -- already poisoned: nothing to detect, idle cheaply
        else
            Wait(0)
            for i = 0, GetNumberOfEvents(0) - 1 do
                if GetEventAtIndex(0, i) == EVENT_ENTITY_DAMAGED then
                    local data = DataView.ArrayBuffer(128)
                    -- GetEventData: 0 = victim, 8 = attacker, 16 = weapon hash, 24 = ammo hash
                    if Citizen.InvokeNative(0x57EC5FA4D4D6AFCA, 0, i, data:Buffer(), 9) and data:GetInt32(0) == cache.ped then
                        local attacker = data:GetInt32(8)
                        local cause
                        if poisonAmmoHashes[data:GetInt32(24)] then
                            cause = 'ammo'
                        elseif poisonWeaponHashes[data:GetInt32(16)] then
                            cause = 'weapon'
                        elseif attacker ~= 0 and DoesEntityExist(attacker) and snakeModelHashes[GetEntityModel(attacker)] then
                            cause = 'snake'
                        end
                        if cause then
                            startPoison(false, cause)
                            break
                        end
                    end
                end
            end
        end
    end
end)
