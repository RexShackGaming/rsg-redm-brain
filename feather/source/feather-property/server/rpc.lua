PropertyRoutes = {}
local Ok, Err = Property.Ok, Property.Err

-- Players see the properties they hold and their own interest in each, not
-- manager, metadata or other holders' internals.
local function Public(property, characterId)
    local mine = {}
    for _, list in ipairs({ property.owners, property.tenants }) do
        for _, interest in ipairs(list) do
            if interest.holderType == 'character' and interest.holderId == characterId then
                mine[#mine + 1] = { interestType = interest.interestType, validUntil = interest.validUntil }
            end
        end
    end
    return {
        propertyId = property.propertyId,
        propertyType = property.propertyType,
        label = property.label,
        status = property.status,
        interests = mine
    }
end

-- Client-callable routes are read-only. Every mutation stays a trusted server
-- export; the character is always derived from the caller's Core session.
local routes = {
    {
        name = 'property.held.list.v1',
        handler = function(payload, source)
            if not Property.IsReady() then
                return Err('not_ready', 'Property is not ready.')
            end
            local session = exports['feather-core']:GetSessionContext(source)
            if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
                or not Property.Uuid(session.value.characterId) then
                return Err('character_required', 'An active character is required.')
            end
            local characterId = session.value.characterId:lower()
            local listed = PropertyRecords.QueryByHolder('character', characterId, {
                propertyType = payload.propertyType,
                includeMetadata = false,
                limit = Config.Limits.maxClientProperties
            })
            if not listed.ok then
                return listed
            end
            local properties = {}
            for _, property in ipairs(listed.value.items) do
                properties[#properties + 1] = Public(property, characterId)
            end
            return Ok({ properties = properties })
        end,
        options = {
            contract = 1,
            direction = 'client_to_server',
            requireCharacter = true,
            windowMs = 5000,
            maxCalls = 5,
            maxPayloadBytes = 128,
            maxDepth = 2,
            maxNodes = 4,
            validatePayload = function(payload)
                if type(payload) ~= 'table' then
                    return false, 'property.held.list.v1 requires a table payload.'
                end
                for field in pairs(payload) do
                    if field ~= 'propertyType' then
                        return false, 'property.held.list.v1 accepts only propertyType.'
                    end
                end
                if payload.propertyType ~= nil and not Config.PropertyTypes[payload.propertyType] then
                    return false, 'property.held.list.v1 property type is not configured.'
                end
                return true
            end
        }
    }
}

function PropertyRoutes.Register()
    for _, route in ipairs(routes) do
        local result = exports['feather-core']:RegisterRpc(route.name, route.handler, route.options)
        if type(result) ~= 'table' or not result.ok then
            return Err('dependency_unavailable', 'Could not register property RPC route.', {
                route = route.name,
                code = type(result) == 'table' and result.code or 'invalid_result'
            })
        end
    end
    return Ok(#routes)
end
