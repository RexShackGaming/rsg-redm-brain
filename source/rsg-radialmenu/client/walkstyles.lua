-- Walkstyles are validated server-side and replicated through the player state bag 'walkstyle'.
-- Every client keeps every nearby player's ped in sync, including players who stream in later,
-- respawn (new ped handle) or join after the style was set.

local applied = {} -- [serverId] = { ped = handle, key = walkstyle }

local function applyWalkstyle(ped, key)
    local ws = key and Config.Walkstyles[key]
    if not ws or not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    Citizen.InvokeNative(0x923583741DC87BCE, ped, ws[1]) -- _SET_PED_DESIRED_LOCO_FOR_MODEL
    Citizen.InvokeNative(0x89F5E7ADECCCB49C, ped, ws[2]) -- _SET_PED_DESIRED_LOCO_MOTION_TYPE
    return true
end

local function syncPlayer(serverId, force)
    local ply = GetPlayerFromServerId(serverId)
    if ply == -1 then applied[serverId] = nil return end

    local key = Player(serverId).state.walkstyle
    if not key then return end

    local ped = GetPlayerPed(ply)
    local cache = applied[serverId]
    if force or not cache or cache.ped ~= ped or cache.key ~= key then
        if applyWalkstyle(ped, key) then
            applied[serverId] = { ped = ped, key = key }
        end
    end
end

-- Selected from the radial menu
RegisterNetEvent('rsg-radialmenu:client:setWalkstyle', function(data)
    local key = type(data) == 'table' and data.walkstyle or data
    if not Config.Walkstyles[key] then return end
    applyWalkstyle(PlayerPedId(), key) -- instant local feedback
    TriggerServerEvent('rsg-radialmenu:server:setWalkstyle', key)
end)

-- Instant update when anyone changes style
AddStateBagChangeHandler('walkstyle', nil, function(bagName, _, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end
    local serverId = GetPlayerServerId(ply)
    applied[serverId] = nil
    SetTimeout(0, function() syncPlayer(serverId, true) end) -- state is readable next tick
end)

-- Catch-up loop: players streaming in, respawns, late joins
CreateThread(function()
    while true do
        Wait(1500)
        local seen = {}
        for _, ply in ipairs(GetActivePlayers()) do
            local serverId = GetPlayerServerId(ply)
            seen[serverId] = true
            syncPlayer(serverId)
        end
        for serverId in pairs(applied) do
            if not seen[serverId] then applied[serverId] = nil end
        end
    end
end)

-- Re-apply own style after character load / skin reload (loadskin can reset loco)
local function reapplySelf()
    SetTimeout(2000, function() syncPlayer(GetPlayerServerId(PlayerId()), true) end)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', reapplySelf)
RegisterNetEvent('rsg-radialmenu:client:reapplyWalkstyle', reapplySelf)
AddEventHandler('onClientResourceStart', function(res)
    if res == 'rsg-appearance' then reapplySelf() end
end)
