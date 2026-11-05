-- Import this server-side in each consumer. No framework dependency.
if not IsDuplicityVersion() then error('feather-mysql is server-only', 0) end
if DB ~= nil then error('DB is already defined in this resource', 0) end

-- The provider this library talks to. The file runs inside each consumer, so the
-- name cannot come from GetCurrentResourceName().
local PROVIDER = 'feather-mysql'
-- The provider enforces its own deadlines; this only guards against a reply that
-- never arrives, so it waits for the longest provider deadline plus a margin.
local WATCHDOG_MARGIN_MS = 5000

DB = {}
local pending, startedAt, nextId = {}, {}, 0
local transactions = setmetatable({}, { __mode = 'k' })
local providerGeneration = 0
local sqlNull = { __feather_mysql_null = true }

-- What a caller may assume about the database for errors raised in this file.
-- Errors reported by the provider carry their own outcome.
local outcomes = {
    INVALID_CONTEXT = 'not_executed', INVALID_ARGUMENT = 'not_executed', NESTED_TRANSACTION = 'not_executed',
    TRANSACTION_CLOSED = 'not_executed', UNAVAILABLE = 'not_executed',
    BRIDGE_ERROR = 'unknown', RESOURCE_STOPPED = 'unknown', WATCHDOG_TIMEOUT = 'unknown', LUA_ERROR = 'rolled_back',
}

local function failure(code, message)
    return { code = code, message = message, resource = GetCurrentResourceName(), outcome = outcomes[code] }
end

-- Errors are tables so callers can branch on err.code. This makes them readable when printed
-- and records where in the caller they were raised. Left uncaught, the Cfx runtime shows a
-- table error only as "error object is not a string", so callers should pcall them.
local errorMeta = { __tostring = function(err)
    local parts = { ('[%s] %s: %s'):format(PROVIDER, tostring(err.code), tostring(err.message)) }
    local details = {}
    for _, key in ipairs({ 'resource', 'method', 'queryId', 'driverCode', 'sqlState', 'outcome' }) do
        if err[key] ~= nil then details[#details + 1] = key .. '=' .. tostring(err[key]) end
    end
    if #details > 0 then parts[#parts + 1] = '  ' .. table.concat(details, ' ') end
    if err.detail then parts[#parts + 1] = '  detail: ' .. tostring(err.detail) end
    if err.traceback and err.traceback ~= '' then parts[#parts + 1] = err.traceback end
    return table.concat(parts, '\n')
end }

local function raise(err)
    if type(err) == 'table' and getmetatable(err) == nil then
        if err.traceback == nil and type(debug) == 'table' and debug.traceback then
            err.traceback = debug.traceback('', 2)
        end
        setmetatable(err, errorMeta)
    end
    error(err, 0)
end

local function requireCoroutine()
    if not coroutine.isyieldable() then
        raise(failure('INVALID_CONTEXT', 'DB calls require a yieldable coroutine, such as CreateThread'))
    end
end

local function parameters(...)
    local packed = { ... }
    -- select counts explicit nil arguments, including trailing ones. The sentinel
    -- keeps the transport array dense without treating false or zero as NULL.
    for i = 1, select('#', ...) do
        if packed[i] == nil then packed[i] = sqlNull end
    end
    return packed
end

local function milliseconds(name, fallback)
    local value = tonumber(GetConvar(name, ''))
    return value and value > 0 and value or fallback
end
local WATCHDOG_MS = math.max(
    milliseconds('feather_mysql_query_timeout_ms', 30000),
    milliseconds('feather_mysql_transaction_timeout_ms', milliseconds('feather_mysql_transaction_timeout', 10000))
) + WATCHDOG_MARGIN_MS

-- A deadlock always makes InnoDB roll back the whole transaction on its own; a lock-wait timeout
-- does not necessarily (with the default innodb_rollback_on_timeout=0, InnoDB itself only rolls
-- back the failed statement). Either way nothing is applied twice, because bridge/driver.js
-- explicitly issues its own ROLLBACK for both cases before FinishTransactionV1 is even called --
-- see transactionQuery()'s catch there. Off by default, because the callback is run again exactly
-- as written -- it must have no side effects outside tx.* (no TriggerEvent, no writing a module-level
-- table, nothing a second run would repeat). Read live, like feather_mysql_devmode, so it can be
-- flipped without a restart. Bounded the same way bridge/config.js bounds the JS-side reader of the
-- same convar (0-20), so a live convar change cannot make this unbounded even though the JS side,
-- read only at startup, would refuse to start at all outside that range.
local RETRYABLE_DRIVER_CODES = { ER_LOCK_DEADLOCK = true, ER_LOCK_WAIT_TIMEOUT = true }
local MAX_RETRY_DEADLOCKS = 20
local function retryDeadlocksLimit()
    if GetConvar('feather_mysql_retry_deadlocks', 'false') ~= 'true' then return 0 end
    local value = tonumber(GetConvar('feather_mysql_retry_deadlocks_max', '3'))
    if not value or value < 0 then return 3 end
    return math.min(math.floor(value), MAX_RETRY_DEADLOCKS)
end

-- One sweeper thread exists only while requests are outstanding, so idle
-- consumers pay nothing and the request path allocates no timer.
local sweeper = false
local function watch()
    if sweeper then return end
    sweeper = true
    CreateThread(function()
        while next(pending) do
            Wait(1000)
            local now = GetGameTimer()
            for id, finish in pairs(pending) do
                local began = startedAt[id]
                if began and (now - began) % 4294967296 >= WATCHDOG_MS then
                    finish({ ok = false, error = failure('WATCHDOG_TIMEOUT',
                        'No response from the database provider; outcome unknown') })
                end
            end
        end
        sweeper = false
    end)
end

local function callExport(name, ...)
    requireCoroutine()
    local arguments = table.pack(...)
    local deferred = promise.new()
    nextId = nextId + 1
    local id = nextId
    local function finish(envelope)
        if not pending[id] then return end
        pending[id], startedAt[id] = nil, nil
        if type(envelope) ~= 'table' or type(envelope.ok) ~= 'boolean'
            or (not envelope.ok and (type(envelope.error) ~= 'table'
                or type(envelope.error.code) ~= 'string' or type(envelope.error.message) ~= 'string')) then
            envelope = { ok = false, error = failure('BRIDGE_ERROR', 'Invalid database response') }
        end
        -- Resolve the envelope so nil/false values and structured errors survive.
        deferred:resolve(envelope)
    end
    pending[id] = finish
    if GetResourceState(PROVIDER) ~= 'started' then
        finish({ ok = false, error = failure('UNAVAILABLE', PROVIDER .. ' is not started') })
    else
        startedAt[id] = GetGameTimer()
        watch()
        arguments.n = arguments.n + 1
        arguments[arguments.n] = finish
        local ok = pcall(function()
            local provider = exports[PROVIDER]
            provider[name](provider, table.unpack(arguments, 1, arguments.n))
        end)
        if not ok then
            finish({ ok = false, error = failure('UNAVAILABLE', 'Database export is unavailable') })
        end
    end
    local response = Citizen.Await(deferred)
    if not response.ok then raise(response.error) end
    return response.value
end

-- The first place in the stack that is not this library: where the consumer made the call.
local function callSite()
    if type(debug) ~= 'table' or not debug.getinfo then return nil end
    for level = 2, 16 do
        local info = debug.getinfo(level, 'Sl')
        if not info then return nil end
        local source = info.source or ''
        if info.what ~= 'C' and not source:find('lib/DB%.lua$') then
            return ('%s:%d'):format((source:gsub('^@', '')), info.currentline)
        end
    end
end

-- A plain DB.* call made from inside a DB.transaction callback does not use the
-- transaction's connection. It is a common mistake and can also wait on locks the
-- transaction itself holds. Each place is reported once, so a busy script does not
-- repeat it for every transaction; with feather_mysql_devmode every transaction reports it.
local reported = {}
local function warnIfInTransaction(method)
    local state = transactions[coroutine.running()]
    if not state or state.warned then return end
    state.warned = true
    local site = callSite()
    if GetConvar('feather_mysql_devmode', 'false') ~= 'true' then
        local key = method .. '@' .. tostring(site)
        if reported[key] then return end
        reported[key] = true
    end
    print(('[%s] WARNING: DB.%s was called inside a DB.transaction callback in %s%s. It runs on a separate '
        .. 'connection and is NOT part of the transaction; use tx.%s instead.')
        :format(PROVIDER, method, GetCurrentResourceName(), site and (' at ' .. site) or '', method))
end

local function invoke(method, sql, ...)
    warnIfInTransaction(method)
    return callExport('ExecuteV1', method, sql, parameters(...))
end

function DB.query(sql, ...)
    return invoke('query', sql, ...)
end

function DB.one(sql, ...)
    return invoke('one', sql, ...)
end

function DB.value(sql, ...)
    return invoke('value', sql, ...)
end

function DB.insert(sql, ...)
    return invoke('insert', sql, ...)
end

function DB.exec(sql, ...)
    return invoke('exec', sql, ...)
end

-- For callers that cannot know the statement kind in advance (for example generic admin tooling
-- running an arbitrary statement): rows (an array) for a statement that returns rows, otherwise
-- the write header { affectedRows, insertId, warningStatus }. Prefer the specific functions above.
function DB.raw(sql, ...)
    return invoke('raw', sql, ...)
end

-- Whether the provider has reached the database since it started. False while the provider is
-- stopped or starting. Must be called from a coroutine.
function DB.isReady()
    requireCoroutine()
    local ok, value = pcall(callExport, 'ReadyV1')
    return ok and type(value) == 'table' and value.ready == true
end

-- Waits until the database is reachable. timeoutMs nil waits indefinitely. Returns true when
-- ready, false if the timeout passed first. Must be called from a coroutine.
function DB.awaitReady(timeoutMs)
    requireCoroutine()
    local started, polls = GetGameTimer(), 0
    while not DB.isReady() do
        if timeoutMs and (GetGameTimer() - started) % 4294967296 >= timeoutMs then return false end
        polls = polls + 1
        Wait(polls < 20 and 250 or 1000)
    end
    return true
end

function DB.transaction(callback)
    requireCoroutine()
    if type(callback) ~= 'function' then
        raise(failure('INVALID_ARGUMENT', 'DB.transaction requires a callback function'))
    end
    local thread = coroutine.running()
    if transactions[thread] then
        raise(failure('NESTED_TRANSACTION', 'Nested DB.transaction calls are not supported'))
    end
    local retriesLeft = retryDeadlocksLimit()
    local generation = providerGeneration
    for attempt = 1, math.huge do
        if generation ~= providerGeneration then
            transactions[thread] = nil
            raise(failure('RESOURCE_STOPPED', 'Database resource stopped during transaction; retry cancelled'))
        end
        local state = { closed = false }
        transactions[thread] = state
        local begun, transaction = pcall(callExport, 'BeginTransactionV1')
        if not begun then
            transactions[thread] = nil
            raise(transaction)
        end
        if type(transaction) ~= 'table' or type(transaction.id) ~= 'string' then
            transactions[thread] = nil
            raise(failure('BRIDGE_ERROR', 'Invalid transaction response'))
        end
        local function query(method, sql, ...)
            if state.closed then raise(failure('TRANSACTION_CLOSED', 'Transaction is closed')) end
            if state.error then raise(state.error) end
            local ok, value = pcall(callExport, 'TransactionQueryV1', transaction.id, method, sql, parameters(...))
            if not ok then
                if type(value) ~= 'table' then value = failure('BRIDGE_ERROR', tostring(value)) end
                state.error = state.error or value
                raise(state.error)
            end
            return value
        end
        local tx = {}
        function tx.query(sql, ...)
            return query('query', sql, ...)
        end
        function tx.one(sql, ...)
            return query('one', sql, ...)
        end
        function tx.value(sql, ...)
            return query('value', sql, ...)
        end
        function tx.insert(sql, ...)
            return query('insert', sql, ...)
        end
        function tx.exec(sql, ...)
            return query('exec', sql, ...)
        end
        function tx.raw(sql, ...)
            return query('raw', sql, ...)
        end
        -- One Lua/JS round trip for independent statements on this transaction's
        -- connection. Results use DB.raw shapes; validation still occurs in Lua.
        function tx.batch(statements)
            if state.closed then raise(failure('TRANSACTION_CLOSED', 'Transaction is closed')) end
            if state.error then raise(state.error) end
            local ok,value=pcall(callExport,'TransactionBatchV1',transaction.id,statements)
            if not ok then
                if type(value)~='table' then value=failure('BRIDGE_ERROR',tostring(value)) end
                state.error=state.error or value
                raise(state.error)
            end
            return value
        end
        local ok, result = pcall(callback, tx)
        if not ok then
            if type(result) == 'table' and type(result.code) == 'string' and type(result.message) == 'string' then
                state.error = state.error or result
            else
                state.error = state.error or failure('LUA_ERROR', type(result) == 'string' and result or 'Transaction callback failed')
            end
        elseif result ~= true and result ~= false and result ~= nil then
            state.error = state.error or failure('INVALID_ARGUMENT', 'Transaction callback must return true, false or nil')
        end
        state.closed = true
        local commit = state.error == nil and result == true
        local finished, value = pcall(callExport, 'FinishTransactionV1', transaction.id, commit)
        transactions[thread] = nil
        if state.error then
            -- A query error can already have rolled back in the driver. Its finish reply
            -- carries that confirmation; a missing or failed transport reply does not.
            local rolledBack = (finished and value == false)
                or (not finished and type(value) == 'table' and value.rollbackConfirmed == true)
            state.error.rollbackConfirmed = rolledBack
            if rolledBack then
                state.error.outcome = 'rolled_back'
            else
                state.error.rollbackError = state.error.rollbackError or (not finished and value)
                    or failure('BRIDGE_ERROR', 'Invalid transaction rollback response')
                state.error.outcome = 'unknown'
            end
            if rolledBack and generation == providerGeneration and retriesLeft > 0
                and RETRYABLE_DRIVER_CODES[state.error.driverCode] then
                retriesLeft = retriesLeft - 1
                transactions[thread] = state
                Wait(math.random(20, 40) * attempt)
            else
                raise(state.error)
            end
        else
            if not finished then raise(value) end
            if type(value) ~= 'boolean' or value ~= commit then
                raise(failure('BRIDGE_ERROR', 'Invalid transaction completion response'))
            end
            return value
        end
    end
end

--- Builds one statement for DB.batchTransaction. Needed instead of a bare {sql, ...} table because
--- a Lua table constructor cannot reliably keep a nil parameter in the middle or at the end (the #
--- operator is undefined over holes); calling this as a real function reuses the same select('#', ...)
--- handling every other DB.* call gets, via parameters(...).
function DB.stmt(sql, ...)
    if type(sql) ~= 'string' then
        raise(failure('INVALID_ARGUMENT', 'DB.stmt requires a SQL string'))
    end
    return { sql = sql, params = parameters(...) }
end

--- Runs an array of DB.stmt(...) statements atomically without a callback, for the common case of
--- several independent statements that must all succeed or all roll back together and where one
--- statement's result does not feed into another (that case still needs DB.transaction directly).
--- Returns one result per statement, each shaped like DB.raw's: rows for a statement that returns
--- rows, otherwise { affectedRows, insertId, warningStatus }.
function DB.batchTransaction(statements)
    if type(statements) ~= 'table' or #statements == 0 then
        raise(failure('INVALID_ARGUMENT', 'DB.batchTransaction requires a non-empty array built with DB.stmt(...)'))
    end
    for i, statement in ipairs(statements) do
        if type(statement) ~= 'table' or type(statement.sql) ~= 'string' or type(statement.params) ~= 'table' then
            raise(failure('INVALID_ARGUMENT', ('DB.batchTransaction statement %d was not built with DB.stmt(...)'):format(i)))
        end
    end
    local results = {}
    DB.transaction(function(tx)
        for i, statement in ipairs(statements) do
            results[i] = tx.raw(statement.sql, table.unpack(statement.params, 1, #statement.params))
        end
        return true
    end)
    return results
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= PROVIDER then return end
    providerGeneration = providerGeneration + 1
    for _, state in pairs(transactions) do
        state.error = state.error or failure('RESOURCE_STOPPED', 'Database resource stopped; write outcome may be unknown')
    end
    local callbacks = {}
    for _, finish in pairs(pending) do callbacks[#callbacks + 1] = finish end
    for _, finish in ipairs(callbacks) do
        finish({ ok = false, error = failure('RESOURCE_STOPPED', 'Database resource stopped; write outcome may be unknown') })
    end
end)
