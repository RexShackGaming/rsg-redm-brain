-- Justice on a real MariaDB scratch schema (see tests/run.py). Dependencies are
-- mocked at their export boundary; the database, SQL and transactions are real.
local checks, failures = 0, 0

-- JSON (objects, arrays, strings, numbers, booleans) -------------------------
json = {}
local function escape(s)
    return (s:gsub('[%c"\\]', function(c)
        local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return map[c] or string.format('\\u%04x', c:byte())
    end))
end
function json.encode(v)
    local t = type(v)
    if t == 'nil' then return 'null' elseif t == 'boolean' then return tostring(v)
    elseif t == 'number' then return (math.type(v) == 'integer' or v % 1 == 0) and string.format('%d', v) or string.format('%.17g', v)
    elseif t == 'string' then return '"' .. escape(v) .. '"' end
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    if n > 0 and #v == n then
        local parts = {}
        for i = 1, #v do parts[i] = json.encode(v[i]) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys, parts = {}, {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = '"' .. escape(k) .. '":' .. json.encode(v[k]) end
    return '{' .. table.concat(parts, ',') .. '}'
end
function json.decode(s)
    if type(s) ~= 'string' then return nil end
    local i = 1
    local function ws() i = s:find('[^ \t\r\n]', i) or #s + 1 end
    local value
    local function str()
        i = i + 1
        local out = {}
        while true do
            local c = s:sub(i, i)
            if c == '"' then i = i + 1; break end
            if c == '\\' then
                local n = s:sub(i + 1, i + 1)
                if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)); i = i + 6
                else out[#out + 1] = ({ n = '\n', r = '\r', t = '\t', b = '\b', f = '\f' })[n] or n; i = i + 2 end
            else out[#out + 1] = c; i = i + 1 end
        end
        return table.concat(out)
    end
    function value()
        ws()
        local c = s:sub(i, i)
        if c == '{' then
            i = i + 1; local o = {}; ws()
            if s:sub(i, i) == '}' then i = i + 1; return o end
            while true do ws(); local k = str(); ws(); i = i + 1; o[k] = value(); ws(); local d = s:sub(i, i); i = i + 1; if d == '}' then return o end end
        elseif c == '[' then
            i = i + 1; local a = {}; ws()
            if s:sub(i, i) == ']' then i = i + 1; return a end
            while true do a[#a + 1] = value(); ws(); local d = s:sub(i, i); i = i + 1; if d == ']' then return a end end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == 'true' then i = i + 4; return true
        elseif s:sub(i, i + 4) == 'false' then i = i + 5; return false
        elseif s:sub(i, i + 3) == 'null' then i = i + 4; return nil
        else
            local number = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', i)
            i = i + #number
            return math.tointeger(tonumber(number)) or tonumber(number)
        end
    end
    return value()
end

-- Database through the bridge ------------------------------------------------
local fault = {}
-- Parameters travel as a JSON array so nil stays an explicit null.
local function Run(connection, sql, ...)
    if fault.match and sql:find(fault.match, 1, true) then
        fault.match = nil
        error({ code = 'INJECTED', message = 'injected failure' }, 0)
    end
    local packed, parts = table.pack(...), {}
    for index = 1, packed.n do parts[index] = json.encode(packed[index]) end
    local response = json.decode(__db('{"conn":' .. connection .. ',"sql":' .. json.encode(sql)
        .. ',"params":[' .. table.concat(parts, ',') .. ']}'))
    if not response.ok then error({ code = 'QUERY_FAILED', message = response.error }, 0) end
    return response.rows or {}
end
local function Api(connection)
    local api = {}
    function api.query(sql, ...) return Run(connection, sql, ...) end
    function api.one(sql, ...) return Run(connection, sql, ...)[1] end
    function api.value(sql, ...)
        local row = Run(connection, sql, ...)[1]
        if not row then return nil end
        local _, value = next(row)
        return value
    end
    function api.exec(sql, ...) Run(connection, sql, ...); return true end
    return api
end
DB = Api(1)
DB.isReady = function() return true end
DB.awaitReady = function() return true end
function DB.transaction(callback)
    Run(1, 'START TRANSACTION')
    local ok, result = pcall(callback, Api(1))
    if not ok or result ~= true then
        Run(1, 'ROLLBACK')
        if not ok then error(result, 0) end
        return false
    end
    Run(1, 'COMMIT')
    if fault.commitLost then fault.commitLost = false; error({ code = 'COMMIT_UNKNOWN', message = 'acknowledgement lost' }, 0) end
    return true
end

-- Runtime and dependency mocks -------------------------------------------------
local now, kvp, commands = 0, {}, {}
local registered = {}
exports = setmetatable({}, { __call = function(_, name, handler) registered[name] = handler end })
GetGameTimer = function() return now end
-- Background threads (main.lua workers) park at their first Wait; tests call the
-- workers directly. Waits on the command coroutine advance a virtual clock.
local threads = setmetatable({}, { __mode = 'k' })
Wait = function(ms)
    local current = coroutine.running()
    if threads[current] then coroutine.yield() else now = now + ms end
end
CreateThread = function(fn)
    local co = coroutine.create(fn)
    threads[co] = true
    local ok, err = coroutine.resume(co)
    if not ok then error(err, 0) end
end
local handlers = {}
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterCommand = function(name, fn) commands[name] = fn end
SetResourceKvp = function(k, v) kvp[k] = v end
GetResourceKvpString = function(k) return kvp[k] end
DeleteResourceKvp = function(k) kvp[k] = nil end
GetCurrentResourceName = function() return 'feather-justice' end
local invoking = 'bcc-law'
GetInvokingResource = function() return invoking end
local stopped = {}
GetResourceState = function(name) return stopped[name] and 'stopped' or 'started' end

local function uuid(n) return ('8f37d250-3b6a-4c19-8e72-%012x'):format(n) end
local characters = { [uuid(1)] = 'active', [uuid(2)] = 'active', [uuid(3)] = 'active', [uuid(4)] = 'retired' }
local sessions = { [5] = { characterId = uuid(1), accountId = uuid(91), sessionId = uuid(92) },
    [6] = { characterId = uuid(3), accountId = uuid(93), sessionId = uuid(94) } }
local policy = { denied = {}, outage = false, sealed = {}, wide = {}, current = true }
local serviceGrants = { ['justice.definition.manage'] = true, ['justice.definition.view'] = true, ['justice.custody.view'] = true,
    ['justice.sentence.view'] = true, ['justice.sentence.complete'] = true }
local published, subscribers = {}, {}
declarations = 0
exports['feather-core'] = {
    AwaitReady = function() return { ok = true, value = { state = 'ready' } } end,
    GetCapabilities = function() return { ok = true, value = { contract = 1 } } end,
    GetHealth = function() return { ok = true, value = { state = 'ready' } } end,
    DeclareEvent = function() declarations = declarations + 1; return { ok = true, value = {} } end,
    PublishEvent = function(_, name, payload) published[#published + 1] = { name = name, payload = payload }; return { ok = true, value = {} } end,
    SubscribeEvent = function(_, name, fn) subscribers[name] = fn; return { ok = true, value = { token = name } } end,
    GetSessionContext = function(_, source)
        local s = sessions[source]
        if not s then return { ok = false, code = 'not_found' } end
        return { ok = true, value = { characterId = s.characterId, accountId = s.accountId, sessionId = s.sessionId } }
    end,
    IsSessionCurrent = function() return policy.current end,
    Authorize = function(_, action, context)
        if policy.outage then error('policy outage') end
        if context.source == 0 then return { ok = true, value = { allowed = serviceGrants[action] == true } } end
        local character = sessions[context.source] and sessions[context.source].characterId
        if action == 'justice.case.view_sealed' then return { ok = true, value = { allowed = policy.sealed[character] == true } } end
        if action == 'justice.case.view_all' or action == 'justice.case.manage_all' then
            return { ok = true, value = { allowed = policy.wide[character] == true } }
        end
        return { ok = true, value = { allowed = not policy.denied[action] } }
    end,
    GetProvider = function()
        return { ok = true, value = { implementation = { GetIdentity = function(id)
            if not characters[id] then return { ok = false, code = 'not_found' } end
            return { ok = true, value = { characterId = id, status = characters[id] } }
        end } } }
    end
}
exports['feather-character'] = { GetHealth = function() return { ok = true, value = { state = 'ready' } } end }

local contractsEnv = setmetatable({ AddEventHandler = function() end, ContractsLogging = { Create = function() return {} end } }, { __index = _G })
for _, file in ipairs({ 'config.lua', 'shared/results.lua', 'server/services/validation.lua', 'server/services/types.lua' }) do
    assert(loadfile('../feather-contracts/' .. file, 't', contractsEnv))()
end
local obligations, drafts, contractsCount, contracts = {}, {}, 0, { refuseIssue = false }
local function copy(v) if type(v) ~= 'table' then return v end local c = {} for k, x in pairs(v) do c[k] = copy(x) end return c end
exports['feather-contracts'] = {
    RegisterObligationType = function(_, definition)
        local normalized = contractsEnv.ContractsTypes.Normalize(definition)
        if not normalized.ok then return { ok = false, code = 'invalid_type' } end
        return { ok = true, value = { typeKey = definition.typeKey } }
    end,
    CreateDraft = function(_, p)
        if drafts[p.requestId] then return { ok = true, value = copy(obligations[drafts[p.requestId]]) } end
        contractsCount = contractsCount + 1
        local id = uuid(5000 + contractsCount)
        obligations[id] = { obligationId = id, obligationType = p.obligationType, issuerResource = 'feather-justice', issuer = p.issuer,
            debtor = p.debtor, creditor = p.creditor, amount = p.amount, currency = p.currency, dueInSeconds = p.dueInSeconds,
            referenceType = p.referenceType, referenceId = p.referenceId, status = 'draft', requiresAcceptance = false,
            debtorMaySettle = true, issuerMaySettle = false, debtorMayDispute = false }
        drafts[p.requestId] = id
        return { ok = true, value = copy(obligations[id]) }
    end,
    IssueObligation = function(_, p)
        if contracts.refuseIssue then return { ok = false, code = 'authorization_denied' } end
        local o = obligations[p.obligationId]; if o.status == 'draft' then o.status = 'issued' end
        return { ok = true, value = copy(o) }
    end,
    CancelObligation = function(_, p)
        local o = obligations[p.obligationId]
        if o.status == 'settled' then return { ok = false, code = 'invalid_transition' } end
        o.status = 'cancelled'
        return { ok = true, value = copy(o) }
    end,
    GetObligation = function(_, p) return obligations[p.obligationId] and { ok = true, value = copy(obligations[p.obligationId]) } or { ok = false, code = 'obligation_not_found' } end,
    SettleObligation = function() error('Justice must never settle') end
}
local items, guards = { [501] = 'evidence_knife', [502] = 'evidence_letter' }, {}
exports['feather-inventory'] = { initiate = function() return {
    Instances = { GetInstance = function(id)
        if items[id] then return { ok = true, value = { id = id, definition = { name = items[id] } } } end
        return { ok = false, error = { code = 'not_found' } }
    end },
    Guards = { RegisterDestroyGuard = function(name, fn) guards[name] = fn; return { ok = true, value = true } end,
        UnregisterDestroyGuard = function(name) guards[name] = nil end,
        CanDestroyInstance = function(id)
            for _, guard in pairs(guards) do local allowed = guard({ id = id }); if allowed == false then return false end end
            return true
        end } } end }
local organizations = { [uuid(700)] = 'active', [uuid(701)] = 'dissolved' }
exports['feather-organizations'] = { GetOrganization = function(_, p)
    local status = organizations[p.organizationId]
    if not status then return { ok = false, code = 'organization_not_found' } end
    return { ok = true, value = { organizationId = p.organizationId, status = status } }
end }

-- Load Justice in manifest order ----------------------------------------------
local manifest = io.open('fxmanifest.lua'):read('a')
dofile('config.lua')
for file in manifest:match('server_scripts%s*(%b{})'):gmatch("'(server/[%w_]+%.lua)'") do dofile(file) end
local J = Justice
local migrated, why = pcall(J.Migrate)
if not migrated then print('migration error: ' .. tostring(type(why) == 'table' and why.message or why)) end
J.Migrate()
J.State('ready', 'tests')
J.ReloadEvidenceIndex()

-- Test context -------------------------------------------------------------
local t = { uuid = uuid, actor = uuid(1), subject = uuid(2), other = uuid(3), retired = uuid(4),
    organization = uuid(700), dissolvedOrganization = uuid(701), policy = policy, published = published,
    obligations = obligations, contracts = contracts, items = items, guards = guards, commands = commands,
    subscribers = subscribers, sessions = sessions, handlers = handlers, characters = characters, stopped = stopped, fault = fault, kvp = kvp }
function t.check(label, condition, detail)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print('FAIL ' .. t.suite .. ': ' .. label .. (detail ~= nil and (' (' .. tostring(detail) .. ')') or ''))
    end
    return condition
end
local serial = 0
function t.rid() serial = serial + 1; return 'test-' .. serial end
-- Calls an export through its registered boundary, as another resource would.
function t.call(name, request, options)
    options = options or {}
    invoking = options.caller or 'bcc-law'
    if type(request) == 'table' then
        if request.actorSource == nil and not options.service then request.actorSource = options.source or 5 end
        if request.reasonCode and not request.requestId then request.requestId = t.rid() end
    end
    local handler = assert(registered[name], 'export ' .. name)
    local result = handler(request)
    invoking = 'bcc-law'
    return result
end
function t.code(result) return result.ok and 'ok' or tostring(result.code) end
t.sql = Api(1)
function t.advance(ms) now = now + ms end
function t.declarations() return declarations end
function t.ago(table_, column, idColumn, id, ms)
    -- Moves a stored deadline into the past (simulates real time passing).
    t.sql.exec('UPDATE ' .. table_ .. ' SET ' .. column .. '=? WHERE ' .. idColumn .. '=?', J.Repo.Now(DB.value) - ms, id)
end

local suites = {}
local listing = io.popen('ls tests/suite/*.lua 2>/dev/null')
for path in listing:lines() do if (__suite == '' or path:find(__suite, 1, true)) then suites[#suites + 1] = path end end
listing:close()
table.sort(suites)
for _, path in ipairs(suites) do
    t.suite = path:match('([%w_]+)%.lua$')
    local before = checks - failures
    local ok, err = pcall(dofile(path), t)
    if not ok then
        failures = failures + 1
        print('FAIL ' .. t.suite .. ': aborted: ' .. tostring(type(err) == 'table' and (err.code .. ' ' .. tostring(err.message)) or err))
    end
    print(('suite %-12s %d checks'):format(t.suite, checks - before))
end
print(('%s Justice: %d checks, %d failed (real MariaDB, mocked dependencies)'):format(failures == 0 and 'PASS' or 'FAIL', checks, failures))
if failures > 0 then error('tests failed', 0) end
