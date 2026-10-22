lib.locale()

local PAN_MODEL  = `P_CS_MININGPAN01X`
local CROUCH     = { dict = 'script_rc@cldn@ig@rsc2_ig1_questionshopkeeper', clip = 'inspectfloor_player' }
local SHAKE      = { dict = 'script_re@gold_panner@gold_success',            clip = 'SEARCH02' }

local isBusy = false
local panProp

local validWater = {}
for _, w in ipairs(Config.WaterTypes) do validWater[w.waterhash] = true end

local function Notify(key, nType)
    lib.notify({ title = locale('title'), description = locale(key), type = nType, duration = 5000 })
end

local function IsInPannableWater()
    if not IsEntityInWater(cache.ped) then return false end
    local c = GetEntityCoords(cache.ped)
    local water = Citizen.InvokeNative(0x5BA7A68A346A5A91, c.x, c.y, c.z) -- GetWaterMapZoneAtCoords
    return validWater[water] == true
end

local function PlayAnim(anim)
    if not lib.requestAnimDict(anim.dict, 5000) then return end
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 1.0, 8.0, -1, 1, 0, false, false, false)
end

local function AttachPan()
    if panProp and DoesEntityExist(panProp) then return end
    if not lib.requestModel(PAN_MODEL, 5000) then return end

    local c = GetEntityCoords(cache.ped)
    panProp = CreateObject(PAN_MODEL, c.x, c.y, c.z, true, false, false)
    SetModelAsNoLongerNeeded(PAN_MODEL)
    AttachEntityToEntity(panProp, cache.ped, GetEntityBoneIndexByName(cache.ped, 'SKEL_R_HAND'),
        0.2, 0.0, -0.20, -100.0, -50.0, 0.0, false, false, false, true, 2, true)
end

local function Cleanup()
    if panProp and DoesEntityExist(panProp) then DeleteEntity(panProp) end
    panProp = nil
    ClearPedTasks(cache.ped)
    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false
end

-- server says the item was used: run the checks only the client can do
RegisterNetEvent('rsg-goldpanning:client:tryPan', function()
    if isBusy then return Notify('already_panning', 'error') end
    if IsPedOnMount(cache.ped) or IsPedInAnyVehicle(cache.ped, false) or not IsPedOnFoot(cache.ped)
       or not IsInPannableWater() then
        return Notify('not_in_river', 'error')
    end
    TriggerServerEvent('rsg-goldpanning:server:startPan')
end)

-- server opened a session and chose the duration
RegisterNetEvent('rsg-goldpanning:client:beginPan', function(duration)
    if isBusy then return end
    isBusy = true
    LocalPlayer.state:set('inv_busy', true, true)

    AttachPan()
    PlayAnim(CROUCH)

    -- switch from scooping to shaking part-way through the progress bar
    CreateThread(function()
        Wait(Config.PanTime.crouch)
        if isBusy then PlayAnim(SHAKE) end
    end)

    local completed = lib.progressBar({
        duration     = duration,
        label        = locale('progress_panning'),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true, mouse = false },
    })

    Cleanup()

    if completed then
        TriggerServerEvent('rsg-goldpanning:server:claimPan')
    else
        TriggerServerEvent('rsg-goldpanning:server:cancelPan')
        Notify('cancelled', 'inform')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not isBusy then return end
    Cleanup()
end)
