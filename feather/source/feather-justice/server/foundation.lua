Justice = {}
local health = { state = 'starting', phase = 'foundation', contract = 1 }
local generation = 0
local forced = setmetatable({}, { __mode = 'k' })
Justice.Version = '0.3.0'
Justice.Handlers = {}

-- Database time is the legal clock; Mutate folds this read into its receipt lock.
Justice.NowSql = 'SELECT FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000)'

-- SHA-256 in Lua, byte-identical to MariaDB SHA2(text,256), so receipt
-- fingerprints need no database round trip and earlier receipts still match.
local K = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2 }
local function rotr(x, n) return ((x >> n) | (x << (32 - n))) & 0xffffffff end
function Justice.Sha256(message)
    local h = { 0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19 }
    local length = #message
    message = message .. '\128' .. string.rep('\0', (55 - length) % 64) .. string.pack('>I8', length * 8)
    local w = {}
    for chunk = 1, #message, 64 do
        for i = 0, 15 do w[i] = string.unpack('>I4', message, chunk + i * 4) end
        for i = 16, 63 do
            local a, b = w[i - 15], w[i - 2]
            local s0 = rotr(a, 7) ~ rotr(a, 18) ~ (a >> 3)
            local s1 = rotr(b, 17) ~ rotr(b, 19) ~ (b >> 10)
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff
        end
        local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
        for i = 0, 63 do
            local t1 = (hh + (rotr(e, 6) ~ rotr(e, 11) ~ rotr(e, 25)) + ((e & f) ~ (~e & g)) + K[i + 1] + w[i]) & 0xffffffff
            local t2 = ((rotr(a, 2) ~ rotr(a, 13) ~ rotr(a, 22)) + ((a & b) ~ (a & c) ~ (b & c))) & 0xffffffff
            hh, g, f, e, d, c, b, a = g, f, e, (d + t1) & 0xffffffff, c, b, a, (t1 + t2) & 0xffffffff
        end
        h[1], h[2], h[3], h[4] = (h[1] + a) & 0xffffffff, (h[2] + b) & 0xffffffff, (h[3] + c) & 0xffffffff, (h[4] + d) & 0xffffffff
        h[5], h[6], h[7], h[8] = (h[5] + e) & 0xffffffff, (h[6] + f) & 0xffffffff, (h[7] + g) & 0xffffffff, (h[8] + hh) & 0xffffffff
    end
    return string.format(string.rep('%08x', 8), table.unpack(h))
end
-- Random (v4) UUIDs generated here, stored as CHAR(36); a collision fails the
-- primary-key insert and the whole transaction, never overwrites a record.
math.randomseed()
function Justice.NewUuid()
    local bytes = {}
    for i = 1, 16 do bytes[i] = math.random(0, 255) end
    bytes[7] = (bytes[7] & 0x0f) | 0x40
    bytes[9] = (bytes[9] & 0x3f) | 0x80
    local hex = string.format(string.rep('%02x', 16), table.unpack(bytes))
    return hex:sub(1, 8) .. '-' .. hex:sub(9, 12) .. '-' .. hex:sub(13, 16) .. '-' .. hex:sub(17, 20) .. '-' .. hex:sub(21, 32)
end

function Justice.Ok(value) return { ok = true, value = value } end
function Justice.Err(code, message) return { ok = false, code = code, message = message } end
function Justice.Copy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = Justice.Copy(child) end
    return copy
end
function Justice.Uuid(value)
    return type(value) == 'string' and value:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end
function Justice.Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and value:find('%z') == nil and value:find('[\1-\8\11\12\14-\31\127]') == nil
end
function Justice.Token(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and value:match('^[A-Za-z0-9][A-Za-z0-9_.:%-]*$') ~= nil
end
function Justice.Integer(value, minimum, maximum)
    return type(value) == 'number' and value >= minimum and value <= maximum and value % 1 == 0
end
function Justice.Fields(request, fields)
    if type(request) ~= 'table' then return false end
    for key in pairs(request) do if not fields[key] then return false end end
    return true
end
function Justice.State(state, phase)
    generation = generation + 1
    health.state, health.phase = state, phase
end
function Justice.Generation() return generation end
function Justice.Ready() return health.state == 'ready' end
function Justice.Health() return Justice.Ok(Justice.Copy(health)) end
-- Capability document (master plan: Capability document). The plan's feature keys
-- first; extra keys describe optional behaviour. Only healthy, running features are 1.
function Justice.Capabilities()
    local guard = Justice.EvidenceGuardActive and Justice.EvidenceGuardActive() and 1 or 0
    return Justice.Ok({ resource = 'feather-justice', contract = 'feather.justice', version = 1,
        release = Justice.Version, state = health.state, features = {
            jurisdictions = 1, statutes = 1, cases = 1, charges = 1, warrants = 1, citations = 1, custody = 1,
            rulings = 1, sentences = 1, evidenceLinks = 1, sealing = 1,
            parties = 1, organizationParties = 1, expungement = 1, auditHistory = 1, subjectSearchAudit = 1,
            citationPayments = 1, sentenceObligations = 1, evidenceGuard = guard,
            warrantlessCustody = Justice.WarrantlessEnabled and Justice.WarrantlessEnabled() and 1 or 0,
            restrictions = 0
        } })
end
-- In-memory metrics since resource start: counts and timings only, no IDs,
-- characters or narratives. Workflow backlog is read from the database on demand.
local metrics = { since = GetGameTimer and GetGameTimer() or 0, operations = {}, providers = {} }
local function Clock() return GetGameTimer and GetGameTimer() or 0 end
local function Record(bucket, name, ms, code, replayed)
    local entry = bucket[name]
    if not entry then entry = { calls = 0, ok = 0, codes = {}, replayed = 0, totalMs = 0, maxMs = 0 }; bucket[name] = entry end
    entry.calls = entry.calls + 1
    if code == nil then entry.ok = entry.ok + 1 else entry.codes[code] = (entry.codes[code] or 0) + 1 end
    if replayed then entry.replayed = entry.replayed + 1 end
    entry.totalMs, entry.maxMs = entry.totalMs + ms, math.max(entry.maxMs, ms)
end
function Justice.Metrics() return Justice.Copy(metrics) end
function Justice.ResetMetrics() metrics = { since = Clock(), operations = {}, providers = {} } end
local function Logging() return type(JusticeConfig) == 'table' and type(JusticeConfig.Logging) == 'table' and JusticeConfig.Logging or {} end

function Justice.Call(resource, operation, ...)
    if GetResourceState(resource) ~= 'started' then
        Record(metrics.providers, resource .. '.' .. operation, 0, 'dependency_unavailable')
        return Justice.Err('dependency_unavailable', resource .. ' is unavailable.')
    end
    local provider, args = exports[resource], table.pack(...)
    local started = Clock()
    local called, result = pcall(function()
        return provider[operation](provider, table.unpack(args, 1, args.n))
    end)
    local valid = called and type(result) == 'table' and type(result.ok) == 'boolean'
    Record(metrics.providers, resource .. '.' .. operation, Clock() - started,
        not valid and 'dependency_unavailable' or (not result.ok and (type(result.code) == 'string' and result.code or 'error')) or nil)
    if not valid then
        return Justice.Err('dependency_unavailable', resource .. ' returned no valid result.')
    end
    return result
end
-- Console acceptance only: binds a constructed actor to the calling coroutine so
-- offline UUID tests reach the real repositories without a connected player.
-- Nothing outside that coroutine (other resources, other threads) can see it.
function Justice.WithActor(actor, callback)
    local thread = coroutine.running()
    forced[thread] = actor
    local ok, result = pcall(callback)
    forced[thread] = nil
    if not ok then error(result, 0) end
    return result
end
local function Forced() return forced[coroutine.running()] end
function Justice.Trusted(resource)
    local actor = Forced()
    return JusticeConfig.TrustedResources[resource or ''] == true or (actor ~= nil and actor.resource == resource)
end
local function Allowed(action, source, resource, jurisdictionId, attributes)
    local subject = { resource = resource, jurisdictionId = jurisdictionId }
    for key, value in pairs(attributes or {}) do subject[key] = value end
    local policy = Justice.Call('feather-core', 'Authorize', action, { source = source or 0, subject = subject })
    if not policy.ok or type(policy.value) ~= 'table' then return nil end
    return policy.value.allowed == true
end
function Justice.Principal(resource, action, request, jurisdictionId, definitions, attributes)
    if not Justice.Ready() then return Justice.Err('not_ready', 'Justice is not ready.') end
    local override = Forced()
    if override then
        if override.resource ~= resource then return Justice.Err('authorization_denied', 'Caller is not trusted for this operation.') end
        local actor = Justice.Copy(override)
        actor.generation, actor.forced = generation, true
        return Justice.Ok(actor)
    end
    if not JusticeConfig.TrustedResources[resource or '']
        or (definitions and not JusticeConfig.DefinitionResources[resource]) then
        return Justice.Err('authorization_denied', 'Caller is not trusted for this operation.')
    end
    local epoch = generation
    local actor = { source = request.actorSource, resource = resource }
    if actor.source ~= nil and not Justice.Integer(actor.source, 1, 65535) then
        return Justice.Err('invalid_input', 'A connected actor source is required.')
    end
    -- Service mode: no player, only the narrow actions listed in SystemActions.
    if not definitions and actor.source == nil then
        if not (JusticeConfig.SystemActions or {})[action] then
            return Justice.Err('actor_required', 'An active actor is required for case access.')
        end
        actor.system = true
    end
    if actor.source then
        local session = Justice.Call('feather-core', 'GetSessionContext', actor.source)
        if not session.ok or type(session.value) ~= 'table'
            or not Justice.Uuid(session.value.characterId) or not Justice.Uuid(session.value.accountId)
            or not Justice.Uuid(session.value.sessionId) then
            return Justice.Err('session_expired', 'An active character session is required.')
        end
        actor.characterId, actor.accountId, actor.sessionId = session.value.characterId,
            session.value.accountId, session.value.sessionId
    end
    local allowed = Allowed(action, actor.source, resource, jurisdictionId, attributes)
    if allowed == nil then return Justice.Err('policy_unavailable', 'The policy provider is unavailable.') end
    if not allowed then return Justice.Err('authorization_denied', 'This action is not authorized.') end
    if not definitions and not actor.system then
        for _, mode in ipairs({ 'view', 'manage' }) do
            actor[mode .. 'All'] = Allowed('justice.case.' .. mode .. '_all', actor.source, resource, jurisdictionId) == true
        end
        actor.viewSealed = Allowed('justice.case.view_sealed', actor.source, resource, jurisdictionId) == true
    end
    actor.generation = epoch
    if not Justice.Current(actor) then return Justice.Err('session_expired', 'Actor context changed.') end
    return Justice.Ok(actor)
end
function Justice.Current(actor)
    if not Justice.Ready() or actor.generation ~= generation then return false end
    if not actor.source then return true end
    local ok, current = pcall(function()
        return exports['feather-core']:IsSessionCurrent(actor.source, actor.sessionId, actor.characterId)
    end)
    return ok and current == true
end
function Justice.Export(name, handler)
    Justice.Handlers[name] = handler
    exports(name, function(request)
        local resource = GetInvokingResource()
        local started = Clock()
        local called, result = pcall(handler, request, resource)
        if not called then
            print('[feather-justice] event=operation.failed operation=' .. name .. ' caller=' .. tostring(resource))
            result = Justice.Err('operation_failed', 'Operation outcome is unknown; reuse the same request ID.')
        end
        local ms = Clock() - started
        local code = not result.ok and result.code or nil
        Record(metrics.operations, name, ms, code, result.ok and type(result.value) == 'table' and result.value.replayed == true)
        -- Structured, narrative-free logs: operation, caller, code, duration, correlation (request ID).
        local log = Logging()
        local correlation = type(request) == 'table' and (Justice.Token(request.correlationId, 128) and request.correlationId
            or Justice.Token(request.requestId, 128) and request.requestId) or '-'
        if ms >= (log.SlowOperationMs or 1500) or (code and log.Rejections == true) then
            print(('[feather-justice] event=operation.%s operation=%s caller=%s code=%s ms=%d correlation=%s'):format(
                code and 'rejected' or 'slow', name, tostring(resource), code or 'ok', ms, correlation))
        end
        return result
    end)
end
exports('GetHealth', Justice.Health)
exports('GetCapabilities', Justice.Capabilities)
exports('AwaitReady', function(timeoutMs)
    timeoutMs = timeoutMs == nil and 30000 or timeoutMs
    if not Justice.Integer(timeoutMs, 0, 60000) then
        return Justice.Err('invalid_input', 'Timeout must be between 0 and 60000 milliseconds.')
    end
    local started = GetGameTimer()
    repeat
        if Justice.Ready() then return Justice.Health() end
        if health.state == 'failed' then return Justice.Err('startup_failed', 'Justice startup failed.') end
        if GetGameTimer() - started >= timeoutMs then break end
        Wait(50)
    until false
    return Justice.Err('not_ready', 'Justice is not ready.')
end)
