local RSGCore = exports['rsg-core']:GetCoreObject()
local cooldowns = {}

local function setWalkstyleState(src, key)
    if key and Config.Walkstyles[key] then
        Player(src).state:set('walkstyle', key, true)
    end
end

RegisterNetEvent('rsg-radialmenu:server:setWalkstyle', function(key)
    local src = source
    if type(key) ~= 'string' or not Config.Walkstyles[key] then return end

    local now = os.time()
    if cooldowns[src] and now - cooldowns[src] < Config.WalkstyleCooldown then return end
    cooldowns[src] = now

    setWalkstyleState(src, key)

    -- persist so it survives relogs
    local ply = RSGCore.Functions.GetPlayer(src)
    if ply then ply.Functions.SetMetaData('walkstyle', key) end
end)

-- restore saved walkstyle when a character loads
AddEventHandler('RSGCore:Server:PlayerLoaded', function(ply)
    if not ply or not ply.PlayerData then return end
    setWalkstyleState(ply.PlayerData.source, ply.PlayerData.metadata and ply.PlayerData.metadata.walkstyle)
end)

-- restore for everyone already online after a resource restart
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, src in ipairs(GetPlayers()) do
        local ply = RSGCore.Functions.GetPlayer(tonumber(src))
        if ply then setWalkstyleState(ply.PlayerData.source, ply.PlayerData.metadata.walkstyle) end
    end
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
