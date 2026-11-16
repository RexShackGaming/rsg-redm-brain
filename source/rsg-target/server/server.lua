-- tracks networked entities flagged as having target options so clients can drop
-- their options once the entity is deleted

local MAX_FLAGS_PER_WINDOW = 30     -- flag requests allowed per player per window
local FLAG_WINDOW = 5000            -- (ms)
local MAX_ENTITY_DISTANCE = 500.0   -- the entity has to be near the player that flags it

local RSGCore = exports['rsg-core']:GetCoreObject()

---@type table<number, table>
local entityStates = {}

---@type table<number, { count: number, reset: number }>
local rateLimits = {}

---@param src number
---@return boolean
local function isRateLimited(src)
    local now = GetGameTimer()
    local bucket = rateLimits[src]

    if not bucket or now >= bucket.reset then
        rateLimits[src] = { count = 1, reset = now + FLAG_WINDOW }
        return false
    end

    bucket.count += 1

    return bucket.count > MAX_FLAGS_PER_WINDOW
end

RegisterNetEvent('rsg-target:server:setEntityHasOptions', function(netId)
    local src = source

    if type(netId) ~= 'number' or math.type(netId) ~= 'integer' or netId <= 0 then return end
    if entityStates[netId] then return end -- already flagged
    if isRateLimited(src) then return end

    local handle = NetworkGetEntityFromNetworkId(netId)
    if not handle or handle == 0 or not DoesEntityExist(handle) then return end

    -- the flagging player has to actually be near the entity
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - GetEntityCoords(handle)) > MAX_ENTITY_DISTANCE then return end

    local entity = Entity(handle)
    entity.state.hasTargetOptions = true
    entityStates[netId] = entity
end)

AddEventHandler('playerDropped', function()
    rateLimits[source] = nil
end)

CreateThread(function()
    local removed = {}

    while true do
        Wait(Config.CleanupInterval)

        if next(entityStates) then
            local n = 0

            for netId, entity in pairs(entityStates) do
                if not DoesEntityExist(entity.__data) or not entity.state.hasTargetOptions then
                    entityStates[netId] = nil
                    n += 1
                    removed[n] = netId
                end
            end

            if n > 0 then
                TriggerClientEvent('rsg-target:client:removeEntity', -1, removed)
                table.wipe(removed)
            end
        end
    end
end)

-- every job a player holds (multi job), used for `groups` checks on the client
RSGCore.Functions.CreateCallback('rsg-target:server:getJobs', function(source, cb)
    local ok, jobs = pcall(function()
        return exports['rsg-core']:GetPlayerJobs(source)
    end)

    local out = {}

    if ok and type(jobs) == 'table' then
        for name, data in pairs(jobs) do
            if type(name) == 'string' then
                local grade = data

                if type(data) == 'table' then
                    grade = data.grade or data.level
                    if type(grade) == 'table' then grade = grade.level end
                end

                out[name] = tonumber(grade) or 0
            elseif type(data) == 'string' then -- array of names
                out[data] = 0
            end
        end
    end

    cb(out)
end)
