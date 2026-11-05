RoutingService = {}

local resourceName = GetCurrentResourceName()
local routes = {}
local routesByOwnerKey = {}
local playerRoutes = {}
local allocatedBuckets = {}
local nextBucket = tonumber(Config.Buckets.first) or 1000
local routeSequence = 0

local validModes = { strict = true, relaxed = true, inactive = true }

local function Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local output = {}
    for key, child in pairs(value) do output[Copy(key, seen)] = Copy(child, seen) end
    return output
end

local function OwnerKey(owner, key)
    return ('%s\0%s'):format(owner, key)
end

local function ValidSource(source)
    source = tonumber(source)
    if not source or source < 1 or source % 1 ~= 0 then return nil end
    return source
end

local function SourceExists(source)
    return GetPlayerName(source) ~= nil
end

local function PublicRoute(route)
    if not route then return nil end
    return {
        routeId = route.routeId,
        key = route.key,
        mode = route.mode,
        populationEnabled = route.populationEnabled,
        owner = route.owner,
        playerCount = route.playerCount,
        createdAt = route.createdAt
    }
end

local function AllocateBucket()
    local first = tonumber(Config.Buckets.first) or 1000
    local last = tonumber(Config.Buckets.last) or 999999
    local candidate = nextBucket
    repeat
        if candidate > last then candidate = first end
        if not allocatedBuckets[candidate] then
            local occupied = false
            for _, player in ipairs(GetPlayers()) do
                if GetPlayerRoutingBucket(tonumber(player)) == candidate then
                    occupied = true
                    break
                end
            end
            if not occupied then
                allocatedBuckets[candidate] = true
                nextBucket = candidate + 1
                return candidate
            end
        end
        candidate = candidate + 1
    until candidate == nextBucket
    return nil
end

local function NewRouteId(owner)
    routeSequence = routeSequence + 1
    return ('route:%08x:%08x:%08x'):format(
        GetHashKey(owner), GetGameTimer() & 0xffffffff, routeSequence & 0xffffffff)
end

local function RequireOwnedRoute(owner, routeId)
    if type(routeId) ~= 'string' or routeId == '' then
        return nil, RoutingResults.Err('invalid_input', 'routeId must be a non-empty string.')
    end
    local route = routes[routeId]
    if not route then return nil, RoutingResults.Err('not_found', 'The route was not found.') end
    if route.owner ~= owner then
        return nil, RoutingResults.Err('forbidden', 'The calling resource does not own this route.')
    end
    return route
end

local function LeaveInternal(source, expectedOwner)
    local routeId = playerRoutes[source]
    if not routeId then
        if SourceExists(source) then SetPlayerRoutingBucket(source, 0) end
        return RoutingResults.Ok({ routeId = nil })
    end
    local route = routes[routeId]
    if route and expectedOwner and route.owner ~= expectedOwner then
        return RoutingResults.Err('forbidden', 'The calling resource does not own the player route.')
    end
    if route then
        route.players[source] = nil
        route.playerCount = math.max(0, route.playerCount - 1)
    end
    playerRoutes[source] = nil
    if SourceExists(source) then SetPlayerRoutingBucket(source, 0) end
    TriggerEvent('routing.player.left.v1', {
        routeId = routeId, source = source, owner = route and route.owner or nil
    })
    return RoutingResults.Ok({ routeId = routeId })
end

function RoutingService.Create(owner, spec)
    if type(owner) ~= 'string' or owner == '' then
        return RoutingResults.Err('unauthenticated', 'A calling resource is required.')
    end
    if type(spec) ~= 'table' or type(spec.key) ~= 'string' or spec.key == '' or #spec.key > 128 then
        return RoutingResults.Err('invalid_input', 'A route key between 1 and 128 characters is required.')
    end
    for key in pairs(spec) do
        if key ~= 'key' and key ~= 'mode' and key ~= 'populationEnabled' then
            return RoutingResults.Err('invalid_input', 'The route specification contains an unknown field.', { field = key })
        end
    end
    local mode = spec.mode or Config.Defaults.mode
    if not validModes[mode] then
        return RoutingResults.Err('invalid_input', 'mode must be strict, relaxed, or inactive.')
    end
    local populationEnabled = spec.populationEnabled
    if populationEnabled == nil then populationEnabled = Config.Defaults.populationEnabled end
    if type(populationEnabled) ~= 'boolean' then
        return RoutingResults.Err('invalid_input', 'populationEnabled must be boolean.')
    end
    local ownerKey = OwnerKey(owner, spec.key)
    local existingId = routesByOwnerKey[ownerKey]
    if existingId and routes[existingId] then
        local existing = routes[existingId]
        if existing.mode ~= mode or existing.populationEnabled ~= populationEnabled then
            return RoutingResults.Err('conflict',
                'The route key already exists with different settings.', {
                    key = spec.key
                })
        end
        return RoutingResults.Ok(PublicRoute(existing), { idempotent = true })
    end
    local bucket = AllocateBucket()
    if not bucket then return RoutingResults.Err('route_limit', 'No routing bucket is available.') end
    local routeId = NewRouteId(owner)
    local route = {
        routeId = routeId,
        bucket = bucket,
        key = spec.key,
        mode = mode,
        populationEnabled = populationEnabled,
        owner = owner,
        players = {},
        playerCount = 0,
        createdAt = os.time()
    }
    routes[routeId] = route
    routesByOwnerKey[ownerKey] = routeId
    SetRoutingBucketEntityLockdownMode(bucket, mode)
    SetRoutingBucketPopulationEnabled(bucket, populationEnabled)
    TriggerEvent('routing.route.created.v1', PublicRoute(route))
    return RoutingResults.Ok(PublicRoute(route), { idempotent = false })
end

function RoutingService.Join(owner, routeId, source)
    local route, failure = RequireOwnedRoute(owner, routeId)
    if not route then return failure end
    source = ValidSource(source)
    if not source then return RoutingResults.Err('invalid_input', 'source must identify a player.') end
    if not SourceExists(source) then return RoutingResults.Err('not_found', 'The player is not connected.') end
    if playerRoutes[source] == routeId and GetPlayerRoutingBucket(source) == route.bucket then
        return RoutingResults.Ok({ routeId = routeId }, { idempotent = true })
    end
    local currentRoute = playerRoutes[source] and routes[playerRoutes[source]] or nil
    if currentRoute and currentRoute.owner ~= owner then
        return RoutingResults.Err('forbidden',
            'The player is assigned to a route owned by another resource.')
    end
    if not currentRoute and GetPlayerRoutingBucket(source) ~= 0 then
        return RoutingResults.Err('route_desynchronized',
            'The player is assigned to an unmanaged native routing bucket.')
    end
    local left = LeaveInternal(source, nil)
    if not left.ok then return left end
    route.players[source] = true
    route.playerCount = route.playerCount + 1
    playerRoutes[source] = routeId
    SetPlayerRoutingBucket(source, route.bucket)
    TriggerEvent('routing.player.joined.v1', { routeId = routeId, source = source, owner = route.owner })
    return RoutingResults.Ok({ routeId = routeId }, { idempotent = false })
end

function RoutingService.Leave(owner, source)
    source = ValidSource(source)
    if not source then return RoutingResults.Err('invalid_input', 'source must identify a player.') end
    return LeaveInternal(source, owner)
end

function RoutingService.GetPlayer(owner, source)
    source = ValidSource(source)
    if not source then return RoutingResults.Err('invalid_input', 'source must identify a player.') end
    local routeId = playerRoutes[source]
    if not routeId then return RoutingResults.Ok(nil) end
    local route, failure = RequireOwnedRoute(owner, routeId)
    if not route then return failure end
    if SourceExists(source) and GetPlayerRoutingBucket(source) ~= route.bucket then
        return RoutingResults.Err('route_desynchronized',
            'The player routing bucket does not match the authoritative route.')
    end
    return RoutingResults.Ok(PublicRoute(route))
end

function RoutingService.Get(owner, routeId)
    local route, failure = RequireOwnedRoute(owner, routeId)
    if not route then return failure end
    return RoutingResults.Ok(PublicRoute(route))
end

function RoutingService.GetPlayers(owner, routeId)
    local route, failure = RequireOwnedRoute(owner, routeId)
    if not route then return failure end
    local players = {}
    for source in pairs(route.players) do players[#players + 1] = source end
    table.sort(players)
    return RoutingResults.Ok(players)
end

function RoutingService.Delete(owner, routeId)
    local route, failure = RequireOwnedRoute(owner, routeId)
    if not route then return failure end
    local players = {}
    for source in pairs(route.players) do players[#players + 1] = source end
    for _, source in ipairs(players) do LeaveInternal(source, nil) end
    routes[routeId] = nil
    routesByOwnerKey[OwnerKey(route.owner, route.key)] = nil
    allocatedBuckets[route.bucket] = nil
    TriggerEvent('routing.route.deleted.v1', PublicRoute(route))
    return RoutingResults.Ok({ routeId = routeId, releasedPlayers = #players })
end

function RoutingService.CleanupOwner(owner)
    local owned = {}
    for routeId, route in pairs(routes) do
        if route.owner == owner then owned[#owned + 1] = routeId end
    end
    for _, routeId in ipairs(owned) do RoutingService.Delete(owner, routeId) end
    return #owned
end

function RoutingService.Disconnect(source)
    source = ValidSource(source)
    if not source then return RoutingResults.Err('invalid_input', 'source must identify a player.') end
    return LeaveInternal(source, nil)
end

function RoutingService.Shutdown()
    local players = {}
    for source in pairs(playerRoutes) do players[#players + 1] = source end
    for _, source in ipairs(players) do LeaveInternal(source, nil) end
    local routeIds = {}
    for routeId in pairs(routes) do routeIds[#routeIds + 1] = routeId end
    for _, routeId in ipairs(routeIds) do
        local route = routes[routeId]
        routesByOwnerKey[OwnerKey(route.owner, route.key)] = nil
        allocatedBuckets[route.bucket] = nil
        routes[routeId] = nil
    end
    return #players, #routeIds
end

function RoutingService.Capabilities()
    return RoutingResults.Ok({
        resource = resourceName,
        contract = 1,
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        state = 'ready',
        features = { routes = 1, ownership = 1, cleanup = 1, opaqueHandles = 1 }
    })
end

RoutingService.Copy = Copy
