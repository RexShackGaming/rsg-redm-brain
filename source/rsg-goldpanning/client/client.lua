local RSGCore = exports['rsg-core']:GetCoreObject()

local PAN_MODEL = `P_CS_MININGPAN01X`
local CROUCH    = { dict = 'script_rc@cldn@ig@rsc2_ig1_questionshopkeeper', clip = 'inspectfloor_player' }
local SHAKE     = { dict = 'script_re@gold_panner@gold_success',            clip = 'SEARCH02' }

local isBusy = false
local panId  = 0 -- increments per pan so a stale anim thread never touches a newer pan
local panProp

local validWater = {}
for _, w in ipairs(Config.WaterTypes) do validWater[w.waterhash] = true end

local function Notify(key, nType)
    RSGCore.Functions.Notify({ title = locale('title'), description = locale(key), type = nType, duration = 5000 })
end

local function IsInPannableWater(ped)
    if not IsEntityInWater(ped) then return false end
    local c = GetEntityCoords(ped)
    local water = Citizen.InvokeNative(0x5BA7A68A346A5A91, c.x, c.y, c.z) -- _GET_WATER_MAP_ZONE_AT_COORDS
    return validWater[water] == true
end

local function PlayAnim(ped, anim)
    if not RSGCore.Functions.RequestAnimDict(anim.dict, 5000) then return end
    TaskPlayAnim(ped, anim.dict, anim.clip, 1.0, 8.0, -1, 1, 0, false, false, false)
end

local function AttachPan(ped)
    if panProp and DoesEntityExist(panProp) then return end
    if not RSGCore.Functions.RequestModel(PAN_MODEL, 5000) then return end

    local c = GetEntityCoords(ped)
    panProp = CreateObject(PAN_MODEL, c.x, c.y, c.z, true, false, false)
    SetModelAsNoLongerNeeded(PAN_MODEL)
    AttachEntityToEntity(panProp, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_HAND'),
        0.2, 0.0, -0.20, -100.0, -50.0, 0.0, false, false, false, true, 2, true)
end

local function Cleanup()
    if panProp and DoesEntityExist(panProp) then DeleteEntity(panProp) end
    panProp = nil
    ClearPedTasks(PlayerPedId())
    RemoveAnimDict(CROUCH.dict)
    RemoveAnimDict(SHAKE.dict)
    LocalPlayer.state:set('inv_busy', false, true)
    isBusy = false
end

-- server says the item was used: run the checks only the client can do
RegisterNetEvent('rsg-goldpanning:client:tryPan', function()
    if isBusy then return Notify('already_panning', 'error') end
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or not IsPedOnFoot(ped) or IsPedSwimming(ped) then
        return Notify('not_in_river', 'error')
    end
    if not IsInPannableWater(ped) then return Notify('not_in_river', 'error') end
    TriggerServerEvent('rsg-goldpanning:server:startPan')
end)

-- server opened a session and chose the duration
RegisterNetEvent('rsg-goldpanning:client:beginPan', function(duration)
    if isBusy or type(duration) ~= 'number' then return end
    isBusy = true
    panId = panId + 1
    local thisPan = panId
    local ped = PlayerPedId()
    LocalPlayer.state:set('inv_busy', true, true)

    AttachPan(ped)
    PlayAnim(ped, CROUCH)

    -- switch from scooping to shaking part-way through the progress bar
    CreateThread(function()
        Wait(Config.PanTime.crouch)
        if isBusy and panId == thisPan then PlayAnim(ped, SHAKE) end
    end)

    local completed = RSGCore.Functions.ProgressBar({
        duration     = duration,
        label        = locale('progress_panning'),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, sprint = true, mount = true, combat = true, mouse = false },
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
