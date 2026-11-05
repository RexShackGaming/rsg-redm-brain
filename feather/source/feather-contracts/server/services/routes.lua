ContractsRoutes = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local V = ContractsValidation
local Repo = ContractsObligationRepository
local logger = ContractsLogging.Create('routes')
local resourceName = GetCurrentResourceName()

-- Identity always comes from Core's request context, never from the payload.
local function ClientContext(src, context, requestId)
    local characterId = V.Lower(context.characterId)
    return {
        resource = resourceName,
        actorSource = src,
        actorAccountId = context.accountId,
        actorCharacterId = characterId,
        correlationId = context.correlationId,
        receiptResource = resourceName,
        receiptRequestId = requestId and (characterId .. ':' .. requestId) or nil,
        view = Repo.ClientView
    }
end

local function CurrentSession(src, context)
    if type(context) ~= 'table' or not V.Uuid(context.characterId) then
        return Err('character_required', 'A current character session is required.')
    end
    local current = exports['feather-core']:IsSessionCurrent(src, context.sessionId, context.characterId)
    if current ~= true then return Err('character_required', 'The character session changed.') end
    return Ok(true)
end

local function Guard(handler)
    return function(params, src, context)
        local ready = ContractsFoundation.RequireReady()
        if not ready.ok then return ready end
        local session = CurrentSession(src, context)
        if not session.ok then return session end
        local called, result = xpcall(handler, debug.traceback, params, src, context)
        if not called then
            logger.Error('route.crashed', { reason = tostring(result) })
            return Err('internal_error', 'Contracts request failed.')
        end
        return result
    end
end

local function ClientRequestId(value)
    return V.RequestId(value, Config.Limits.maximumClientRequestIdLength)
end

local function Mutation(fields, extra)
    return function(params)
        if type(params) ~= 'table' then return false, 'Request payload required.' end
        for field in pairs(params) do
            if not fields[field] then return false, 'Unexpected request field.' end
        end
        if not ClientRequestId(params.requestId) or not V.Uuid(params.obligationId) then
            return false, 'Stable requestId and obligation UUID are required.'
        end
        if extra then return extra(params) end
        return true
    end
end

local function ListResult(result)
    if not result.ok then return result end
    local items = {}
    for index, item in ipairs(result.value.items) do items[index] = Repo.ClientView(item) end
    return Ok({ items = items, nextCursor = result.value.nextCursor })
end

local routes = {
    {
        name = 'contracts.obligations.list.v1',
        options = { maxCalls = 4, windowMs = 2000, maxPayloadBytes = 512, maxDepth = 3, maxNodes = 24,
            validatePayload = function(params)
                if params ~= nil and type(params) ~= 'table' then return false, 'Request payload must be a table.' end
                return true
            end },
        handler = function(params, _, context)
            local options = ContractsObligations.ValidateListOptions(params or {}, false)
            if not options.ok then return options end
            options = options.value
            options.partyType = 'character'
            options.partyId = V.Lower(context.characterId)
            options.excludeDrafts = true
            return ListResult(Repo.ListParty(options))
        end
    },
    {
        name = 'contracts.obligation.get.v1',
        options = { maxCalls = 6, windowMs = 2000, maxPayloadBytes = 128, maxDepth = 2, maxNodes = 4,
            validatePayload = function(params)
                if type(params) ~= 'table' or not V.Uuid(params.obligationId) then
                    return false, 'Obligation UUID required.'
                end
                for field in pairs(params) do
                    if field ~= 'obligationId' then return false, 'Unexpected request field.' end
                end
                return true
            end },
        handler = function(params, _, context)
            local characterId = V.Lower(context.characterId)
            local current = Repo.Get(params.obligationId:lower())
            if not current.ok then return Err('obligation_not_found', 'Obligation was not found.') end
            local value = current.value
            local party = value.debtor.id == characterId
                or (value.creditor.type == 'character' and value.creditor.id == characterId)
            if value.status == 'draft' or not party then
                return Err('obligation_not_found', 'Obligation was not found.')
            end
            return Ok(Repo.ClientView(value))
        end
    },
    {
        name = 'contracts.obligation.accept.v1',
        options = { maxCalls = 2, windowMs = 2000, maxPayloadBytes = 256, maxDepth = 2, maxNodes = 6,
            validatePayload = Mutation({ requestId = true, obligationId = true }) },
        handler = function(params, src, context)
            return ContractsObligations.AcceptObligation(params,
                ClientContext(src, context, params.requestId), resourceName, true)
        end
    },
    {
        name = 'contracts.obligation.settle.v1',
        options = { maxCalls = 2, windowMs = 3000, maxPayloadBytes = 256, maxDepth = 2, maxNodes = 6,
            validatePayload = Mutation({ requestId = true, obligationId = true }) },
        handler = function(params, src, context)
            return ContractsSettlement.SettleObligation(params,
                ClientContext(src, context, params.requestId), resourceName, true)
        end
    },
    {
        name = 'contracts.obligation.dispute.v1',
        options = { maxCalls = 2, windowMs = 3000, maxPayloadBytes = 320, maxDepth = 2, maxNodes = 8,
            validatePayload = Mutation({ requestId = true, obligationId = true, reasonCode = true }, function(params)
                if not V.Code(params.reasonCode, 64) then return false, 'reasonCode must be a stable code.' end
                return true
            end) },
        handler = function(params, src, context)
            return ContractsObligations.DisputeObligation(params,
                ClientContext(src, context, params.requestId), resourceName, true)
        end
    }
}

function ContractsRoutes.Register()
    if Config.ClientRoutes.enabled ~= true then
        return Ok({ registered = 0 })
    end
    for _, route in ipairs(routes) do
        local options = {}
        for key, value in pairs(route.options) do options[key] = value end
        options.contract = 1
        options.direction = 'client_to_server'
        options.requireCharacter = true
        local registered = exports['feather-core']:RegisterContractRPC(route.name, Guard(route.handler), options)
        if type(registered) ~= 'table' or registered.ok ~= true then
            return Err('dependency_unavailable', 'A Contracts client route could not be registered.', {
                route = route.name, code = type(registered) == 'table' and registered.code or 'invalid_result'
            })
        end
    end
    return Ok({ registered = #routes })
end

function ContractsRoutes.Names()
    local names = {}
    for index, route in ipairs(routes) do names[index] = route.name end
    return names
end
