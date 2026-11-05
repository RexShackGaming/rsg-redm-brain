FeatherAuditSearch = {}

local fields = { fromEpoch = true, toEpoch = true, limit = true,
    sourceResource = true, eventType = true, correlationId = true, eventId = true, cursor = true,
    targetAccountId = true, targetCharacterId = true, adminAction = true }
local cursors = {}
local function err(code) return { ok = false, code = code, message = 'Audit read unavailable or request rejected.' } end

function FeatherAuditSearch.Validate(request)
    if type(request) ~= 'table' then return nil end
    for key in pairs(request) do if not fields[key] then return nil end end
    if request.cursor ~= nil and (type(request.cursor) ~= 'string' or #request.cursor ~= 36
        or not request.cursor:match('^[a-fA-F0-9%-]+$')) then return nil end
    local from, to, limit = request.fromEpoch, request.toEpoch, request.limit or 25
    local function integer(value) return type(value) == 'number' and value % 1 == 0 end
    if not integer(from) or not integer(to) or from < 0 or to < from
        or to > 253402300799 or to - from > 7 * 86400
        or not integer(limit) or limit < 1 or limit > 50 then return nil end
    for _, key in ipairs({ 'sourceResource', 'eventType', 'correlationId', 'eventId' }) do
        local value = request[key]
        if value ~= nil and (type(value) ~= 'string' or #value == 0 or #value > 128
            or not value:match('^[A-Za-z0-9][A-Za-z0-9_.:%-]*$')) then return nil end
    end
    for _, field in ipairs({ 'targetAccountId', 'targetCharacterId' }) do
        if request[field] ~= nil and (type(request[field]) ~= 'string'
            or not request[field]:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')) then return nil end
    end
    if request.adminAction ~= nil and (type(request.adminAction) ~= 'string' or #request.adminAction > 100
        or not request.adminAction:match('^[a-z][a-z0-9_.]*$')) then return nil end
    return { fromEpoch = from, toEpoch = to, limit = limit,
        sourceResource = request.sourceResource, eventType = request.eventType,
        correlationId = request.correlationId, eventId = request.eventId, targetAccountId = request.targetAccountId,
        targetCharacterId = request.targetCharacterId, adminAction = request.adminAction }
end

local function binding(request, identity)
    return FeatherAuditCanonical.Encode({ query = request, character = identity.id,
        session = identity.sessionId or '', generation = identity.generation or 0,
        caller = identity.caller or '', sensitive = identity.sensitive == true }, { type = 'object' })
end

local function prune()
    local now, count = os.time(), 0
    for token, value in pairs(cursors) do
        if value.expires <= now then cursors[token] = nil else count = count + 1 end
    end
    return count
end

-- Caller identity/permission is supplied only by the server authorization boundary.
-- Search/correlation return metadata; detail returns only schema-approved context.
-- Raw payloads, summaries, display names, and actor identifiers never leave here.
function FeatherAuditSearch.Read(request, identity, operation)
    if not identity or identity.allowed ~= true then return err('forbidden') end
    local normalized = FeatherAuditSearch.Validate(request)
    if not normalized then return err('invalid_request') end
    operation = operation or 'audit.search.v1'
    if operation == 'audit.event.get.v1' then
        if not normalized.eventId or request.cursor or request.limit then return err('invalid_request') end
        normalized.limit = 1
    elseif operation == 'audit.correlation.get.v1' then
        if not normalized.correlationId then return err('invalid_request') end
    elseif operation ~= 'audit.search.v1' then return err('invalid_request') end
    normalized.operation = operation
    prune()
    local fingerprint = binding(normalized, identity)
    if request.cursor then
        local cursor = cursors[request.cursor]
        if not cursor or cursor.binding ~= fingerprint then return err('invalid_cursor') end
        normalized.positionTime, normalized.positionId = cursor.time, cursor.id
    end
    local ok, value = pcall(FeatherAuditSearchRepository.Read, normalized, identity)
    if not ok then return err('read_unavailable') end
    local rows = value.events
    local more = #rows > normalized.limit
    while #rows > normalized.limit do table.remove(rows) end
    if more then
        if prune() >= 256 then return err('cursor_capacity') end
        local generated, token = pcall(DB.value, 'SELECT UUID()')
        if not generated or type(token) ~= 'string' then return err('read_unavailable') end
        local last = rows[#rows]
        cursors[token] = { binding = fingerprint, expires = os.time() + 300,
            time = last.positionTime, id = last.eventId }
        value.nextCursor = token
    end
    for _, row in ipairs(rows) do row.positionTime = nil end
    if operation == 'audit.event.get.v1' then
        value = { event = rows[1] } -- missing and hidden are indistinguishable
    end
    return { ok = true, value = value }
end
