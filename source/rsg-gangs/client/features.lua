-- Territory blips, member map blips and the NUI hooks for the log and territory tabs.
local STYLE_FRIENDLY = joaat('BLIP_STYLE_FRIENDLY')
local STYLE_CAMP = joaat('BLIP_STYLE_CAMP')

local territoryBlips = {}

local function setBlipName(blip, name)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', name)) -- _SET_BLIP_NAME
end

local function addBlip(style, x, y, z, name)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, style, x, y, z) -- BLIP_ADD_FOR_COORDS
    if blip and blip ~= 0 then setBlipName(blip, name) end
    return blip
end

local function clearBlips(list)
    for i = #list, 1, -1 do
        if DoesBlipExist(list[i]) then RemoveBlip(list[i]) end
        list[i] = nil
    end
end

RegisterNetEvent('rsg-gangs:client:territories', function(list)
    clearBlips(territoryBlips)
    if type(list) ~= 'table' then return end
    for _, t in ipairs(list) do
        local name = t.owner and ('%s - %s'):format(t.label, t.ownerLabel or t.owner) or (t.label .. ' - ' .. locale('ui_territory_free'))
        local blip = addBlip(STYLE_CAMP, t.x, t.y, t.z, name)
        if blip then territoryBlips[#territoryBlips + 1] = blip end
    end
end)

local memberBlipById = {} -- [serverId] = blip; moved in place so the map does not flicker
local wagonBlip
local KVP_BLIPS = 'rsg_gangs_member_blips'

local function blipsEnabled() return GetResourceKvpInt(KVP_BLIPS) ~= -1 end

local function clearWagonBlip()
    if wagonBlip and DoesBlipExist(wagonBlip) then RemoveBlip(wagonBlip) end
    wagonBlip = nil
end

local function clearMemberBlips()
    clearWagonBlip()
    for id, blip in pairs(memberBlipById) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        memberBlipById[id] = nil
    end
end

RegisterNetEvent('rsg-gangs:client:memberBlips', function(list, wagon)
    if type(list) ~= 'table' then return end
    if not blipsEnabled() then return end
    local seen = {}
    for _, m in ipairs(list) do
        seen[m.id] = true
        local blip = memberBlipById[m.id]
        if blip and DoesBlipExist(blip) then
            Citizen.InvokeNative(0x4FF674F5E23D49CE, blip, m.x, m.y, m.z) -- SET_BLIP_COORDS
        else
            blip = addBlip(STYLE_FRIENDLY, m.x, m.y, m.z, m.name)
            if blip then memberBlipById[m.id] = blip end
        end
    end
    if type(wagon) == 'table' then
        if wagonBlip and DoesBlipExist(wagonBlip) then
            Citizen.InvokeNative(0x4FF674F5E23D49CE, wagonBlip, wagon.x, wagon.y, wagon.z)
        else
            wagonBlip = addBlip(STYLE_CAMP, wagon.x, wagon.y, wagon.z, locale('ui_wagon_blip'))
        end
    else
        clearWagonBlip()
    end
    for id, blip in pairs(memberBlipById) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            memberBlipById[id] = nil
        end
    end
end)

RegisterNetEvent('rsg-gangs:client:setState', function(state)
    if not state or not state.inGang then
        clearMemberBlips()
        return
    end
    TriggerServerEvent('rsg-gangs:server:setBlips', blipsEnabled())
    SendNUIMessage({ action = 'blips', data = blipsEnabled() })
end)

RegisterNUICallback('setBlips', function(data, cb)
    local enabled = type(data) == 'table' and data.enabled == true
    SetResourceKvpInt(KVP_BLIPS, enabled and 1 or -1)
    TriggerServerEvent('rsg-gangs:server:setBlips', enabled)
    if not enabled then clearMemberBlips() end
    SendNUIMessage({ action = 'blips', data = enabled })
    cb('ok')
end)

RegisterNetEvent('rsg-gangs:client:leaderboard', function(data)
    SendNUIMessage({ action = 'leaderboard', data = data })
end)

RegisterNUICallback('requestLeaderboard', function(_, cb)
    TriggerServerEvent('rsg-gangs:server:requestLeaderboard')
    cb('ok')
end)

RegisterNUICallback('startRaid', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then TriggerServerEvent('rsg-gangs:server:startRaid', data.id) end
    cb('ok')
end)

RegisterNUICallback('setTag', function(data, cb)
    TriggerServerEvent('rsg-gangs:server:setTag', type(data) == 'table' and data.tag or '')
    cb('ok')
end)

RegisterNetEvent('rsg-gangs:client:logs', function(rows)
    SendNUIMessage({ action = 'logs', data = type(rows) == 'table' and rows or {} })
end)

RegisterNUICallback('requestLogs', function(_, cb)
    TriggerServerEvent('rsg-gangs:server:requestLogs')
    cb('ok')
end)

RegisterNUICallback('postBounty', function(data, cb)
    TriggerServerEvent('rsg-gangs:server:postBounty', type(data) == 'table' and tonumber(data.amount) or nil)
    cb('ok')
end)

RegisterNUICallback('claimTerritory', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then
        TriggerServerEvent('rsg-gangs:server:claimTerritory', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('abandonTerritory', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then
        TriggerServerEvent('rsg-gangs:server:abandonTerritory', data.id)
    end
    cb('ok')
end)

local function requestTerritories()
    TriggerServerEvent('rsg-gangs:server:requestTerritories')
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', requestTerritories)
CreateThread(function()
    Wait(3000)
    if LocalPlayer.state.isLoggedIn ~= false then requestTerritories() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips(territoryBlips)
    clearMemberBlips()
end)
