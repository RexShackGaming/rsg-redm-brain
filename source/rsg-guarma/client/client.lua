local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local blips = {}
local nuiPort = false
local travelling = false

-------------------------------------
-- blips
-------------------------------------
CreateThread(function()
    for _, port in pairs(Config.Ports) do
        if port.showblip then
            local blip = BlipAddForCoords(1664425300, port.npccoords.xyz)
            SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipName(blip, locale(port.label))
            blips[#blips + 1] = blip
        end
    end
end)

-------------------------------------
-- ticket office NUI
-------------------------------------
local function GetTicketData()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local cash = PlayerData and PlayerData.money and PlayerData.money.cash or 0
    local owned = exports['rsg-inventory']:GetItemCount(Config.TicketItem) or 0
    return cash, owned
end

local function CloseTicketUI()
    if not nuiPort then return end
    nuiPort = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function OpenTicketUI(portId)
    local port = Config.Ports[portId]
    if not port or travelling then return end
    local dest = Config.Ports[port.destination]
    local cash, owned = GetTicketData()
    nuiPort = portId
    SetNuiFocus(true, true)

    -- close if the player dies or gets moved away while the ticket office is open
    CreateThread(function()
        local origin = port.npccoords.xyz
        while nuiPort == portId do
            if IsEntityDead(cache.ped) or #(GetEntityCoords(cache.ped) - origin) > Config.InteractRadius then
                CloseTicketUI()
            end
            Wait(500)
        end
    end)
    SendNUIMessage({
        action      = 'open',
        port        = locale(port.label),
        destination = locale(dest.label),
        price       = Config.TicketCost,
        max         = Config.MaxTickets,
        cash        = cash,
        owned       = owned,
        text = {
            subtitle   = locale('ui_subtitle'),
            route      = locale('ui_route'),
            owned      = locale('ui_owned'),
            qty        = locale('ticket_amount'),
            price      = locale('buy_tickets_desc'),
            cash       = locale('ui_cash'),
            total      = locale('ui_total'),
            buy        = locale('ui_buy'),
            close      = locale('ui_close'),
            travel     = locale('travel_to', locale(dest.label)),
            travelDesc = locale('travel_desc'),
        },
    })
end

RegisterNUICallback('buy', function(data, cb)
    if not nuiPort then return cb({}) end
    local ok = lib.callback.await('rsg-guarma:server:buyTicket', false, nuiPort, data.amount)
    if not ok then return cb({}) end
    Wait(250) -- let the money/inventory update reach the client
    local cash, owned = GetTicketData()
    cb({ cash = cash, owned = owned })
end)

RegisterNUICallback('travel', function(_, cb)
    cb({})
    local portId = nuiPort
    CloseTicketUI()
    if not portId then return end
    if IsPedOnMount(cache.ped) or IsPedInAnyVehicle(cache.ped, false) then
        return lib.notify({ title = locale('dismount_first'), type = 'error' })
    end
    TriggerServerEvent('rsg-guarma:server:requestTravel', portId)
end)

RegisterNUICallback('close', function(_, cb)
    CloseTicketUI()
    cb({})
end)

-------------------------------------
-- travel (server only sends this after taking a ticket)
-------------------------------------
RegisterNetEvent('rsg-guarma:client:performTravel', function(destId)
    if GetInvokingResource() or travelling then return end -- must come from the server
    local dest = Config.Ports[destId]
    if not dest then return end
    travelling = true

    DoScreenFadeOut(1000)
    while not IsScreenFadedOut() do Wait(0) end

    SetGuarmaWorld(dest.guarma)
    local a = dest.arrival
    Citizen.InvokeNative(0x203BEFFDBE12E96A, cache.ped, a.x, a.y, a.z - 1.0, a.w) -- _SET_ENTITY_COORDS_AND_HEADING
    FreezeEntityPosition(cache.ped, true)
    RequestCollisionAtCoord(a.x, a.y, a.z)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < timeout do Wait(100) end
    Wait(Config.TravelTime)
    FreezeEntityPosition(cache.ped, false)

    DoScreenFadeIn(1500)
    travelling = false
end)

-------------------------------------
-- cleanup
-------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    CloseTicketUI()
    if travelling then FreezeEntityPosition(cache.ped, false) end
    if IsScreenFadedOut() then DoScreenFadeIn(500) end
end)
