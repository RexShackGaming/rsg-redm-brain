local RSGCore = exports['rsg-core']:GetCoreObject()

local blips = {}
local nuiPort = false
local opening = false
local uiSession = 0

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
local function ApplyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

function CloseTicketUI()
    if not nuiPort then return end
    nuiPort = false
    ApplyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function UiText(destLabel)
    local text = {}
    for key, localeKey in pairs({
        subtitle = 'ui_subtitle', route = 'ui_route', owned = 'ui_owned', qty = 'ticket_amount',
        price = 'buy_tickets_desc', cash = 'ui_cash', total = 'ui_total', buy = 'ui_buy', max = 'ui_max',
        close = 'ui_close', travelDesc = 'travel_desc', tabPassage = 'ui_tab_passage', tabCargo = 'ui_tab_cargo',
        returnPair = 'ui_return', discount = 'ui_discount', boarded = 'ui_boarded',
        boardingOpen = 'ui_boarding_open', boardingIn = 'ui_boarding_in', closedWeather = 'ui_closed_weather',
        closedManual = 'ui_closed_manual', alert = 'ui_alert', rescue = 'ui_rescue', rescueDesc = 'ui_rescue_desc',
        buyQty = 'ui_buy_qty', sellQty = 'ui_sell_qty', sellAll = 'ui_sell_all', cargoPrice = 'ui_cargo_price',
        cargoOwned = 'ui_cargo_owned', cargoLeft = 'ui_cargo_left', noteBuy = 'ui_cargo_note_buy',
        noteSell = 'ui_cargo_note_sell',
    }) do
        text[key] = locale(localeKey)
    end
    text.travel = locale('travel_to', destLabel)
    text.board = locale('ui_board', destLabel)
    return text
end

local function FetchOffice(portId)
    return RSGCore.Functions.AwaitCallback('rsg-guarma:server:getOffice', nil, portId)
end

local function WatchTicketUI(session, origin)
    -- while open: allow only push-to-talk, and close if the player is incapacitated or moves away
    CreateThread(function()
        local nextCheck = 0
        while nuiPort and uiSession == session do
            if GetGameTimer() >= nextCheck then
                nextCheck = GetGameTimer() + 500
                local ped = PlayerPedId()
                if IsIncapacitated(ped) or #(GetEntityCoords(ped) - origin) > Config.InteractRadius then
                    CloseTicketUI()
                    break
                end
            end

            if Config.AllowPushToTalkWhileOpen then
                for group = 0, 2 do
                    DisableAllControlActions(group)
                    for i = 1, #Config.PushToTalkControls do
                        EnableControlAction(group, Config.PushToTalkControls[i], true)
                    end
                end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)
end

function OpenTicketUI(portId)
    local port = Config.Ports[portId]
    if not port or nuiPort or opening or IsTravelling() then return end
    if IsIncapacitated(PlayerPedId()) then return NotifyError('cannot_travel') end

    local dest = Config.Ports[port.destination]
    if not dest then return end

    opening = true
    local data = FetchOffice(portId)
    opening = false
    if not data or IsTravelling() then return end

    nuiPort = portId
    uiSession = uiSession + 1
    ApplyNuiFocus(true)
    WatchTicketUI(uiSession, port.npccoords.xyz)

    SendNUIMessage({
        action      = 'open',
        port        = locale(port.label),
        destination = locale(dest.label),
        tradeMax    = Config.Trade.dailyLimit,
        office      = data,
        text        = UiText(locale(dest.label)),
    })
end

-- runs a server action, then replies with fresh office data
-- ({} when it failed or the office was closed / reopened meanwhile)
local function ActionThenRefresh(cb, action)
    if not nuiPort then return cb({}) end
    local portId, session = nuiPort, uiSession
    if action and not action(portId) then return cb({}) end
    if session ~= uiSession or not nuiPort then return cb({}) end

    local data = FetchOffice(portId)
    if not data or session ~= uiSession then return cb({}) end
    cb(data)
end

RegisterNUICallback('buy', function(data, cb)
    ActionThenRefresh(cb, function(portId)
        return RSGCore.Functions.AwaitCallback('rsg-guarma:server:buyTicket', nil,
            portId, data and data.amount, data and data.kind)
    end)
end)

RegisterNUICallback('trade', function(data, cb)
    ActionThenRefresh(cb, function(portId)
        return RSGCore.Functions.AwaitCallback('rsg-guarma:server:trade', nil,
            portId, data and data.item, data and data.qty)
    end)
end)

RegisterNUICallback('refresh', function(_, cb)
    ActionThenRefresh(cb)
end)

local function LeaveBy(event, cb)
    cb({})
    local portId = nuiPort
    CloseTicketUI()
    if not portId or not CanBoardBoat() then return end
    TriggerServerEvent(event, portId)
end

RegisterNUICallback('travel', function(_, cb)
    LeaveBy('rsg-guarma:server:requestTravel', cb)
end)

RegisterNUICallback('rescue', function(_, cb)
    LeaveBy('rsg-guarma:server:requestRescue', cb)
end)

RegisterNUICallback('close', function(_, cb)
    CloseTicketUI()
    cb({})
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
end)
