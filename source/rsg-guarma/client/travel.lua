-------------------------------------
-- boarding, crossing and arrival
-------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()

local travelling = false
local setInvBusy = false
local boardingPort = nil

-- dead, hogtied or lassoed players can't use the ticket office or board
function IsIncapacitated(ped)
    if IsEntityDead(ped) then return true end
    local hogtied = Citizen.InvokeNative(0x3AA24CCC0D451379, ped) -- IS_PED_HOGTIED
    local lassoed = Citizen.InvokeNative(0x9682F850056C9ADE, ped) -- IS_PED_LASSOED
    return hogtied == true or hogtied == 1 or lassoed == true or lassoed == 1
end

function NotifyError(key)
    RSGCore.Functions.Notify({
        title = locale(key),
        type = 'error',
        duration = 5000,
    })
end

-- true if the player may get on a boat right now (notifies why not)
function CanBoardBoat()
    local ped = PlayerPedId()
    if travelling or IsIncapacitated(ped) then
        NotifyError('cannot_travel')
        return false
    end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then
        NotifyError('dismount_first')
        return false
    end
    return true
end

function IsTravelling()
    return travelling
end

RSGCore.Functions.CreateClientCallback('rsg-guarma:client:canBoard', function(cb)
    cb(CanBoardBoat())
end)

-------------------------------------
-- waiting for the scheduled boat
-------------------------------------
local function EndBoarding()
    if not boardingPort then return end
    boardingPort = nil
    SendNUIMessage({ action = 'hudHide' })
end

RegisterNetEvent('rsg-guarma:client:boarded', function(portId, seconds)
    local port = Config.Ports[portId]
    if not port then return end

    boardingPort = portId
    SendNUIMessage({
        action  = 'hudShow',
        seconds = seconds,
        title   = locale('hud_departs'),
        text    = locale('hud_stay'),
    })

    -- walking away cancels; the server checks the distance again at departure
    CreateThread(function()
        while boardingPort == portId do
            local ped = PlayerPedId()
            if IsIncapacitated(ped) or #(GetEntityCoords(ped) - port.npccoords.xyz) > Config.Schedule.boardRadius then
                EndBoarding()
                TriggerServerEvent('rsg-guarma:server:cancelBoarding')
                break
            end
            Wait(1000)
        end
    end)
end)

RegisterNetEvent('rsg-guarma:client:boardingEnded', EndBoarding)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', EndBoarding)

-------------------------------------
-- travel (server only sends this after taking a ticket, or for rescue passage)
-------------------------------------
local function FinishTravel()
    travelling = false
    if setInvBusy then
        setInvBusy = false
        LocalPlayer.state:set('inv_busy', false, true)
    end
end

local function ShowArrivalBanner(dest)
    if not Config.Voyage.banner or GetResourceState('rsg-zonenotify') ~= 'started' then return end
    exports['rsg-zonenotify']:ShowBanner(locale(dest.label), locale('banner_subtitle'), 6000)
end

RegisterNetEvent('rsg-guarma:client:performTravel', function(destId, seconds)
    -- must come from the server (GetInvokingResource is nil for TriggerClientEvent)
    if GetInvokingResource() or travelling then return end

    local dest = Config.Ports[destId]
    if not dest then return end
    seconds = math.max(0, math.min(300, tonumber(seconds) or 3))

    travelling = true
    EndBoarding()
    CloseTicketUI()

    -- no inventory use during the crossing (left alone if another script already set it)
    if not LocalPlayer.state.inv_busy then
        setInvBusy = true
        LocalPlayer.state:set('inv_busy', true, true)
        exports['rsg-inventory']:CloseInventory()
    end

    DoScreenFadeOut(1000)
    -- time limit in case another script fades the screen back in
    local fadeTimeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do Wait(0) end

    if Config.Voyage.enabled then
        SendNUIMessage({
            action  = 'voyageShow',
            seconds = seconds,
            title   = locale('voyage_title', locale(dest.label)),
            text    = locale('voyage_desc'),
        })
    end
    local arriveAt = GetGameTimer() + math.floor(seconds * 1000)

    local ped = PlayerPedId()
    SetGuarmaWorld(dest.guarma)
    local a = dest.arrival
    -- _SET_ENTITY_COORDS_AND_HEADING
    Citizen.InvokeNative(0x203BEFFDBE12E96A, ped, a.x, a.y, a.z - 1.0, a.w)
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(a.x, a.y, a.z)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(100)
    end

    Wait(math.max(0, arriveAt - GetGameTimer()))
    FreezeEntityPosition(PlayerPedId(), false)

    SendNUIMessage({ action = 'voyageHide' })
    DoScreenFadeIn(1500)
    FinishTravel()

    Wait(1500)
    ShowArrivalBanner(dest)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if travelling then
        FreezeEntityPosition(PlayerPedId(), false)
        FinishTravel()
        DoScreenFadeIn(500)
    end
end)
