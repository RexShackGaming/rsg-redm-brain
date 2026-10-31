lib.checkDependency('ox_lib', '3.0.0', true)

-- tracks networked entities flagged as having target options so clients can drop
-- their options once the entity is deleted

---@type table<number, table>
local entityStates = {}

RegisterNetEvent('rsg-target:server:setEntityHasOptions', function(netId)
    if type(netId) ~= 'number' then return end

    if entityStates[netId] then return end -- already flagged

    local handle = NetworkGetEntityFromNetworkId(netId)
    if not handle or handle == 0 or not DoesEntityExist(handle) then return end

    local entity = Entity(handle)
    entity.state.hasTargetOptions = true
    entityStates[netId] = entity
end)

CreateThread(function()
    local removed = {}

    while true do
        Wait(Config.CleanupInterval)

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
end)
