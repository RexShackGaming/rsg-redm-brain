-- Run from the resource directory: lua5.4 tests/lua_spec.lua
local tests = 0
local function check(name, fn)
    local thread = coroutine.create(fn)
    local ok, err = coroutine.resume(thread)
    assert(ok, name .. ': ' .. tostring(err))
    assert(coroutine.status(thread) == 'dead', name .. ': unexpected pending request')
    tests = tests + 1
    print('PASS ' .. name)
end

local registered, handlers, logs, commands = {}, {}, {}, {}
local schedulingProbeAnswer, schedulingProbeCalls
local state, caller, current = 'started', 'example-consumer', 'feather-mysql'
local response, held, delayed, bridgeCalls = nil, nil, false, 0
local lastRequest, failExport, resolutions = nil, false, 0
local selfCheckAnswer
local readyAnswer = function() return { ok = true, value = { ready = true } } end
function RegisterCommand(name,fn,restricted) commands[name]={callback=fn,restricted=restricted} end
function GetConvar(_, default) return default end
function GetInvokingResource() return caller end
function GetCurrentResourceName() return current end
local states = {}
function GetResourceState(name) return states[name] or state end
local now = 123
function GetGameTimer() return now end
function IsDuplicityVersion() return true end
function AddEventHandler(name, fn) handlers[name] = fn end
-- Minimal Cfx scheduler: threads only run when a test pumps them.
local threads, timers = {}, {}
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function SetTimeout(_, fn) timers[#timers + 1] = fn end
local function pump()
    local running = threads
    threads = {}
    for _, thread in ipairs(running) do
        local ok, err = coroutine.resume(thread)
        assert(ok, tostring(err))
        if coroutine.status(thread) ~= 'dead' then threads[#threads + 1] = thread end
    end
end
local function capturePrint(fn)
    local lines, real = {}, print
    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
        lines[#lines + 1] = table.concat(parts, ' ')
    end
    local ok, err = pcall(fn)
    print = real
    assert(ok, err)
    return lines
end
json = { encode = function(entry) logs[#logs + 1] = entry; return 'encoded' end }
exports = setmetatable({}, {
    __call = function(_, name, fn) registered[name] = fn end,
    __index = function()
        return setmetatable({}, { __index = function(_, name)
            return function(_, ...)
                if name == 'DriverSchedulingProbeV1' then
                    local mode,callback=...
                    schedulingProbeCalls=(schedulingProbeCalls or 0)+1
                    if schedulingProbeAnswer then return schedulingProbeAnswer(mode,callback) end
                    now=now+({inline=7,immediate=11,promise_immediate=19,tick=13,promise_tick=17})[mode]
                    callback({ok=true,value={mode=mode,probe=true,flag=false,promiseMs=0,queueMs=0}})
                elseif name == 'DriverSelfCheckV1' then
                    local callback = ...
                    if selfCheckAnswer then callback(selfCheckAnswer()) end
                elseif name == 'DriverReadyV1' then
                    local callback = ...
                    callback(readyAnswer())
                elseif name == 'DriverExecuteV1' then
                    bridgeCalls = bridgeCalls + 1
                    local request, callback = ...
                    lastRequest = request
                    assert(type(request.sql) == 'string')
                    if delayed then held = callback else callback(response) end
                else
                    if failExport then error('Export unavailable') end
                    -- The callback is always the last argument. Match the callable-table
                    -- representation used by Cfx msgpack.
                    local args = table.pack(...)
                    local callback = args[args.n]
                    args[args.n] = setmetatable({ __cfx_functionReference = 'fixture' }, {
                        __call = function(_, ...) return callback(...) end,
                    })
                    return registered[name](table.unpack(args, 1, args.n))
                end
            end
        end })
    end,
})
promise = { new = function()
    return { resolve = function(self, value)
        resolutions = resolutions + 1
        self.value = value
        self.done = true
    end }
end }
Citizen = { Await = function(deferred)
    while not deferred.done do coroutine.yield() end
    return deferred.value
end }

for _, name in ipairs({ 'config', 'errors', 'validation', 'results', 'logger', 'main' }) do
    dofile('server/' .. name .. '.lua')
end
dofile('lib/DB.lua')

-- The driver reports the first column by position as `first`.
local function rows(value) response = { ok = true, value = { kind = 'rows', rows = value, firstColumn = 'z', first = value[1] and value[1].z } } end
local function write(id, affected) response = { ok = true, value = { kind = 'write', header = { insertId = id, affectedRows = affected } } } end

check('five plain DB functions return the specified shapes', function()
    local methods = { 'query', 'one', 'value', 'insert', 'exec' }
    for _, method in ipairs(methods) do assert(type(DB[method]) == 'function') end
    local count = 0
    for _ in pairs(DB) do count = count + 1 end
    assert(count == 11 and type(DB.transaction) == 'function' and type(DB.raw) == 'function'
        and type(DB.stmt) == 'function' and type(DB.batchTransaction) == 'function' and MySQL == nil)
    rows({ { z = 42, a = 1 }, { z = 43 } })
    assert(#DB.query('SELECT ? AS z', 42) == 2)
    assert(DB.one('SELECT ? AS z', 42).z == 42)
    assert(DB.value('SELECT ? AS z', 42) == 42)
    write(13, 2)
    assert(DB.insert('INSERT INTO x (n) VALUES (?)', 42) == 13)
    assert(DB.exec('UPDATE x SET n = ?', 42) == 2)
    write('9007199254740993', 1)
    assert(DB.insert('INSERT INTO x (n) VALUES (?)', 42) == '9007199254740993')
end)
check('varargs preserve order and values without SQL interpolation', function()
    rows({})
    local sql, identifier = 'SELECT ?, ?, ?, ?, ?', "O'Brien ?; DROP TABLE imaginary; --"
    DB.query(sql, identifier, 'character-uuid', false, 0, '')
    assert(lastRequest.sql == sql and lastRequest.count == 5)
    local expected = { identifier, 'character-uuid', false, 0, '' }
    for i = 1, 5 do assert(lastRequest.parameters[i].value == expected[i]) end
    DB.query('SELECT 1')
    assert(lastRequest.count == 0 and next(lastRequest.parameters) == nil)
end)
check('nil arguments bind NULL at the first, middle and final positions', function()
    rows({})
    DB.query('SELECT ?, ?, ?, ?, ?', nil, false, nil, 'value', nil)
    assert(lastRequest.count == 5)
    for _, i in ipairs({ 1, 3, 5 }) do assert(lastRequest.parameters[i].isNull) end
    assert(lastRequest.parameters[2].value == false and lastRequest.parameters[4].value == 'value')
    DB.query('SELECT ?', nil)
    assert(lastRequest.count == 1 and lastRequest.parameters[1].isNull)
    DB.query('SELECT ?, ?', nil, nil)
    assert(lastRequest.count == 2 and lastRequest.parameters[1].isNull and lastRequest.parameters[2].isNull)
end)
check('empty results and NULL/false/zero/empty-string values remain distinct', function()
    rows({})
    assert(#DB.query('SELECT 1') == 0)
    assert(DB.one('SELECT 1') == nil)
    assert(DB.value('SELECT 1') == nil)
    rows({ { a = 99 } }); assert(DB.value('SELECT NULL AS z, 99 AS a') == nil)
    rows({ { z = false, a = 99 } }); assert(DB.value('SELECT false') == false)
    rows({ { z = 0, a = 99 } }); assert(DB.value('SELECT 0') == 0)
    rows({ { z = '', a = 99 } }); assert(DB.value("SELECT ''") == '')
    write(0, 0)
    assert(DB.exec('CREATE TABLE x (n INT)') == 0)
    assert(DB.insert('INSERT INTO x (n) VALUES (?)', 42) == 0)
end)
check('tables, callbacks and unsafe numbers are rejected without driver calls', function()
    for _, parameter in ipairs({ { 42 }, { named = 1 }, 0/0, math.huge, 9007199254740992, {}, function() end }) do
        local before = bridgeCalls
        local ok, err = pcall(DB.query, 'SELECT ?', parameter)
        assert(not ok and err.code == 'INVALID_ARGUMENT' and bridgeCalls == before)
    end
end)
check('invalid SQL arguments and old internal method names are rejected', function()
    for _, sql in ipairs({ '', '   ', false, {} }) do
        local before = bridgeCalls
        local ok, err = pcall(DB.query, sql)
        assert(not ok and err.code == 'INVALID_ARGUMENT' and bridgeCalls == before)
    end
    local ok, err = pcall(DB.query, nil)
    assert(not ok and err.code == 'INVALID_ARGUMENT')
    for _, method in ipairs({ 'single', 'scalar', 'update' }) do
        assert(FeatherMySQL.validate(method, 'SELECT 1') == nil)
    end
end)
check('errors retain safe details, caller and public method name', function()
    response = { ok = false, error = { code = 'DATABASE_ERROR', message = 'safe', driverCode = 'ER_PARSE_ERROR' } }
    for _, method in ipairs({ 'query', 'one', 'value', 'insert', 'exec' }) do
        local ok, err = pcall(DB[method], 'broken')
        assert(not ok and err.code == 'DATABASE_ERROR' and err.message == 'safe')
        assert(err.resource == 'example-consumer' and err.method == method and err.queryId)
        assert(err.driverCode == 'ER_PARSE_ERROR')
    end
end)
check('query rejects write headers and write methods reject rows', function()
    write(5, 1)
    for _, method in ipairs({ 'query', 'one', 'value' }) do
        local ok, err = pcall(DB[method], 'UPDATE x SET n = 1')
        assert(not ok and err.code == 'RESULT_TYPE')
        assert(err.message:find('already have executed', 1, true))
    end
    rows({ { z = 1 } })
    for _, method in ipairs({ 'insert', 'exec' }) do
        local ok, err = pcall(DB[method], 'SELECT 1')
        assert(not ok and err.code == 'RESULT_TYPE')
    end
end)
-- Deliberately call outside a coroutine: reject before any database work.
local beforeContext = bridgeCalls
local contextOk, contextError = pcall(DB.query, 'SELECT 1')
-- Also from the main thread: readiness needs to wait, so it needs a coroutine too.
local readyOk, readyError = pcall(DB.isReady)
local awaitOk, awaitError = pcall(DB.awaitReady, 10)
check('readiness helpers need a coroutine to wait in', function()
    assert(not readyOk and readyError.code == 'INVALID_CONTEXT')
    assert(not awaitOk and awaitError.code == 'INVALID_CONTEXT')
end)
check('nonyieldable callers fail before dispatch', function()
    assert(not contextOk and contextError.code == 'INVALID_CONTEXT' and bridgeCalls == beforeContext)
end)
check('unavailable resources and exports fail without driver calls', function()
    local before = bridgeCalls
    state = 'stopped'
    local ok, err = pcall(DB.query, 'SELECT 1')
    assert(not ok and err.code == 'UNAVAILABLE' and bridgeCalls == before)
    state, failExport = 'started', true
    ok, err = pcall(DB.query, 'SELECT 1')
    assert(not ok and err.code == 'UNAVAILABLE' and bridgeCalls == before)
    failExport = false
end)
check('DB calls yield, resume with results and retain attribution in logs', function()
    delayed = true
    FeatherMySQL.config.logQueries = true
    local result
    local co = coroutine.create(function() result = DB.value('SELECT ? AS z', 7) end)
    assert(coroutine.resume(co))
    assert(coroutine.status(co) == 'suspended' and result == nil)
    caller = 'another-consumer'
    held({ ok = true, value = { kind = 'rows', rows = { { z = 7 } }, firstColumn = 'z', first = 7 } })
    assert(coroutine.resume(co))
    assert(result == 7 and coroutine.status(co) == 'dead')
    assert(logs[#logs].resource == 'example-consumer' and logs[#logs].method == 'value')
    caller, delayed = 'example-consumer', false
    FeatherMySQL.config.logQueries = false
end)
check('provider stop settles once, ignores late results and permits calls after restart', function()
    delayed = true
    local ok, err
    local co = coroutine.create(function() ok, err = pcall(DB.query, 'SELECT 1') end)
    assert(coroutine.resume(co))
    handlers.onResourceStop('unrelated-resource')
    assert(coroutine.status(co) == 'suspended')
    state = 'stopped'
    handlers.onResourceStop('feather-mysql')
    local afterStop = resolutions
    assert(coroutine.resume(co))
    assert(not ok and err.code == 'RESOURCE_STOPPED')
    held({ ok = true, value = { kind = 'rows', rows = {} } })
    assert(resolutions == afterStop and coroutine.status(co) == 'dead')
    delayed, state = false, 'started'
    rows({ { z = 9 } })
    assert(DB.value('SELECT 9') == 9)
end)
check('slow and query logging omit values and SQL unless explicitly enabled', function()
    logs = {}
    FeatherMySQL.config.logQueries = false
    FeatherMySQL.config.logSql = false
    FeatherMySQL.config.slowMs = 200
    local context = { resource = 'consumer', method = 'query', id = 1, sql = 'SELECT secret' }
    FeatherMySQL.log(context, 199)
    assert(#logs == 0)
    FeatherMySQL.log(context, 200)
    assert(#logs == 1 and logs[1].slow and logs[1].sql == nil)
    FeatherMySQL.config.logQueries = true
    FeatherMySQL.log(context, 1)
    assert(#logs == 2 and logs[2].sql == nil)
    FeatherMySQL.config.logSql = true
    FeatherMySQL.log(context, 1)
    assert(logs[3].sql == context.sql)
end)
check('value reads the first column by position even when names repeat', function()
    -- SELECT a.id, b.id: the row object keeps one `id`, but the driver reports the first value.
    response = { ok = true, value = { kind = 'rows', rows = { { id = 2 } }, firstColumn = 'id', first = 1 } }
    assert(DB.value('SELECT a.id, b.id FROM a JOIN b') == 1)
    response = { ok = true, value = { kind = 'rows', rows = { { z = 5 } }, firstColumn = 'z', first = 0 } }
    assert(DB.value('SELECT 0') == 0)
end)
check('integers must fit in 2^53 on both sides; floats only need to be finite', function()
    local accepted = { 9007199254740991, -9007199254740991, 0.1, 1e20, -1e300, 0, -0.0 }
    local rejected = { math.mininteger, math.maxinteger, 9007199254740992, -9007199254740992, 0 / 0, math.huge, -math.huge }
    rows({})
    for _, value in ipairs(accepted) do
        local before = bridgeCalls
        DB.query('SELECT ?', value)
        assert(bridgeCalls == before + 1, tostring(value))
    end
    for _, value in ipairs(rejected) do
        local before = bridgeCalls
        local ok, err = pcall(DB.query, 'SELECT ?', value)
        assert(not ok and err.code == 'INVALID_ARGUMENT' and bridgeCalls == before, tostring(value))
    end
end)
check('errors say what may be assumed about the database', function()
    local expected = { INVALID_ARGUMENT = 'not_executed', RESULT_TYPE = 'executed', UNAVAILABLE = 'not_executed' }
    local _, invalid = pcall(DB.query, '')
    assert(invalid.outcome == expected.INVALID_ARGUMENT)
    write(1, 1)
    local _, mismatch = pcall(DB.query, 'UPDATE x SET n = 1')
    assert(mismatch.code == 'RESULT_TYPE' and mismatch.outcome == expected.RESULT_TYPE)
    state = 'stopped'
    local _, unavailable = pcall(DB.query, 'SELECT 1')
    state = 'started'
    assert(unavailable.code == 'UNAVAILABLE' and unavailable.outcome == expected.UNAVAILABLE)
    response = { ok = false, error = { code = 'DATABASE_ERROR', message = 'Database rejected the statement',
        driverCode = 'ER_DUP_ENTRY', sqlState = '23000', outcome = 'failed', detail = 'Duplicate entry' } }
    local _, rejected = pcall(DB.exec, 'INSERT INTO x VALUES (1)')
    assert(rejected.outcome == 'failed' and rejected.sqlState == '23000' and rejected.detail == 'Duplicate entry')
    assert(rejected.driverCode == 'ER_DUP_ENTRY' and rejected.resource == 'example-consumer')
    response = { ok = false, error = { code = 'DATABASE_ERROR', message = 'x', outcome = 42, sqlState = {}, detail = false } }
    local _, sanitized = pcall(DB.exec, 'INSERT INTO x VALUES (1)')
    assert(sanitized.outcome == nil and sanitized.sqlState == nil and sanitized.detail == nil, 'Untyped fields are dropped')
end)
check('raised errors print readably and record where they were raised', function()
    write(0, 0)
    response = { ok = false, error = { code = 'DATABASE_ERROR', message = 'Database rejected the statement',
        driverCode = 'ER_DUP_ENTRY', sqlState = '23000', outcome = 'failed', resource = 'example-consumer', method = 'exec', queryId = 9 } }
    local ok, err = pcall(DB.exec, 'INSERT INTO x VALUES (1)')
    assert(not ok and type(err) == 'table' and err.code == 'DATABASE_ERROR', 'Callers can still branch on err.code')
    local text = tostring(err)
    assert(text:find('DATABASE_ERROR', 1, true) and text:find('Database rejected the statement', 1, true))
    assert(text:find('ER_DUP_ENTRY', 1, true) and text:find('23000', 1, true) and text:find('outcome=failed', 1, true))
    assert(not text:find('table: 0x', 1, true))
    assert(type(err.traceback) == 'string' and err.traceback:find('stack traceback', 1, true), 'The call site is recorded')
    assert(text:find(err.traceback, 1, true))
end)
check('a reply that never arrives is turned into an error by the watchdog, and late replies are ignored', function()
    delayed = true
    local ok, err
    local co = coroutine.create(function() ok, err = pcall(DB.value, 'SELECT 1') end)
    assert(coroutine.resume(co) and coroutine.status(co) == 'suspended')
    pump()
    assert(#threads == 1, 'One sweeper watches outstanding requests')
    now = now + 34999; pump()
    assert(coroutine.status(co) == 'suspended', 'Not before the longest provider deadline plus its margin')
    now = now + 2; pump()
    assert(coroutine.status(co) == 'suspended' or coroutine.status(co) == 'dead')
    assert(coroutine.resume(co))
    assert(not ok and err.code == 'WATCHDOG_TIMEOUT' and err.outcome == 'unknown' and err.resource == GetCurrentResourceName())
    local settled = resolutions
    held({ ok = true, value = { kind = 'rows', rows = {}, first = 1 } })
    assert(resolutions == settled, 'A late reply cannot settle the request twice')
    pump()
    assert(#threads == 0, 'The sweeper ends when nothing is outstanding')
    delayed = false
    rows({ { z = 3 } })
    assert(DB.value('SELECT 3') == 3, 'Later calls still work')
    pump()
end)
check('error logging is rate limited during an outage and reports what was suppressed', function()
    logs = {}
    FeatherMySQL.config.logQueries, FeatherMySQL.config.slowMs, FeatherMySQL.config.errorLogLimit = false, 0, 3
    local context = { resource = 'consumer', method = 'query', id = 1 }
    local lines = capturePrint(function()
        now = 10000
        for _ = 1, 10 do FeatherMySQL.log(context, 1, { code = 'DATABASE_ERROR', outcome = 'unknown' }) end
        assert(#logs == 3, 'Only three lines in the first second')
        now = 11000
        FeatherMySQL.log(context, 1, { code = 'DATABASE_ERROR', outcome = 'unknown', sqlState = '08S01' })
    end)
    assert(#logs == 4 and logs[4].sqlState == '08S01' and logs[4].outcome == 'unknown')
    local summary = false
    for _, line in ipairs(lines) do if line:find('7 error log lines suppressed', 1, true) then summary = true end end
    assert(summary, 'The next window says how many lines were dropped')
    FeatherMySQL.config.errorLogLimit = 0
    logs = {}
    capturePrint(function() for _ = 1, 30 do FeatherMySQL.log(context, 1, { code = 'X' }) end end)
    assert(#logs == 30, 'A limit of 0 disables the cap')
    FeatherMySQL.config.errorLogLimit = 20
    FeatherMySQL.config.slowMs = 200
end)
check('the driver detail reaches the log only when it was supplied', function()
    logs = {}
    FeatherMySQL.config.errorLogLimit = 0
    local context = { resource = 'consumer', method = 'query', id = 1 }
    capturePrint(function()
        FeatherMySQL.log(context, 1, { code = 'DATABASE_ERROR' })
        FeatherMySQL.log(context, 1, { code = 'DATABASE_ERROR', detail = 'operator opted in' })
    end)
    assert(logs[1].detail == nil and logs[2].detail == 'operator opted in')
    FeatherMySQL.config.errorLogLimit = 20
end)
local sample = function()
    return { ok = true, value = { kind = 'rows', firstColumn = 'text', first = 'h\u{e9}llo \u{1F600} \u{65e5}\u{672c}\u{8a9e}',
        rows = { { text = 'h\u{e9}llo \u{1F600} \u{65e5}\u{672c}\u{8a9e}', number = 42, bytes = { 0, 255 }, big = '9007199254740993', flag = false } } } }
end
check('the startup self-check reports success only when every value shape round-trips', function()
    selfCheckAnswer = sample
    local lines = capturePrint(function() handlers.onResourceStart('feather-mysql') end)
    assert(#lines == 1 and lines[1]:find('Bridge self-check OK', 1, true), lines[1])
    assert(#timers >= 1, 'A no-response watchdog is armed')
    lines = capturePrint(function() handlers.onResourceStart('another-resource') end)
    assert(#lines == 0, 'Other resources starting is not our business')
    local broken = {
        function() local a = sample(); a.value.rows[1].text = 'h?llo'; return a end,
        function() local a = sample(); a.value.rows[1].bytes = { 0, 254 }; return a end,
        function() local a = sample(); a.value.rows[1].flag = 0; return a end,
        function() local a = sample(); a.value.rows[1].nothing = 'not nil'; return a end,
        function() return { ok = false, error = { code = 'INVALID_CALLER', message = 'Only this resource may call the internal database bridge' } } end,
        function() return 'garbage' end,
    }
    for index, variant in ipairs(broken) do
        selfCheckAnswer = variant
        lines = capturePrint(function() handlers.onResourceStart('feather-mysql') end)
        assert(#lines == 1 and lines[1]:find('Bridge self-check FAILED', 1, true), index .. ': ' .. tostring(lines[1]))
    end
    selfCheckAnswer = function() return { ok = false, error = { code = 'INVALID_CALLER', message = 'Only this resource may call the internal database bridge' } } end
    lines = capturePrint(function() handlers.onResourceStart('feather-mysql') end)
    assert(lines[1]:find('INVALID_CALLER', 1, true), 'The refusal reason is shown')
end)
check('a self-check that gets no answer says so after five seconds', function()
    selfCheckAnswer = nil
    timers = {}
    local lines = capturePrint(function()
        handlers.onResourceStart('feather-mysql')
        for _, fn in ipairs(timers) do fn() end
    end)
    assert(#lines == 1 and lines[1]:find('no response within 5 seconds', 1, true), tostring(lines[1]))
    failExport = true
    lines = capturePrint(function() handlers.onResourceStart('feather-mysql') end)
    failExport = false
    assert(#lines == 0 or lines[1] ~= nil)
end)
check('raw returns rows for row results and a write header for everything else', function()
    rows({ { z = 1 }, { z = 2 } })
    local result = DB.raw('SELECT z FROM t')
    assert(#result == 2 and result[1].z == 1)
    rows({})
    assert(#DB.raw('SELECT 1 WHERE 0') == 0, 'An empty result is an empty array, not a header')
    response = { ok = true, value = { kind = 'write', header = { insertId = 7, affectedRows = 3, warningStatus = 1, extra = 'dropped' } } }
    local header = DB.raw('UPDATE t SET n = ?', 1)
    assert(header.affectedRows == 3 and header.insertId == 7 and header.warningStatus == 1 and header.extra == nil)
    assert(FeatherMySQL.validate('raw', 'SELECT 1') ~= nil and FeatherMySQL.validate('other', 'SELECT 1') == nil)
    assert(lastRequest.parameters[1].value == 1)
end)
check('readiness is a plain boolean and never an error while the provider is down', function()
    readyAnswer = function() return { ok = true, value = { ready = true } } end
    assert(DB.isReady() == true)
    readyAnswer = function() return { ok = true, value = { ready = false, code = 'ECONNREFUSED' } } end
    assert(DB.isReady() == false)
    readyAnswer = function() return { ok = false, error = { code = 'CONFIG_ERROR', message = 'Invalid database configuration' } } end
    assert(DB.isReady() == false)
    state = 'stopped'
    assert(DB.isReady() == false)
    state = 'started'
    readyAnswer = function() return { ok = true, value = { ready = true } } end
    local ok, err = pcall(DB.isReady)
    assert(ok and err == true)
end)
check('awaitReady waits, then returns true; or false when the timeout passes first', function()
    readyAnswer = function() return { ok = true, value = { ready = false } } end
    local result
    local co = coroutine.create(function() result = DB.awaitReady(1000) end)
    assert(coroutine.resume(co) and coroutine.status(co) == 'suspended')
    readyAnswer = function() return { ok = true, value = { ready = true } } end
    assert(coroutine.resume(co))
    assert(result == true and coroutine.status(co) == 'dead')
    readyAnswer = function() return { ok = true, value = { ready = false } } end
    local timedOut
    co = coroutine.create(function() timedOut = DB.awaitReady(1000) end)
    assert(coroutine.resume(co) and coroutine.status(co) == 'suspended')
    now = now + 1500
    assert(coroutine.resume(co))
    assert(timedOut == false and coroutine.status(co) == 'dead')
    readyAnswer = function() return { ok = true, value = { ready = true } } end
end)
check('devmode turns the log switches on by default and an explicit convar still wins', function()
    local function configWith(convars)
        local env = setmetatable({ GetConvar = function(name, default) return convars[name] or default end }, { __index = _G })
        assert(loadfile('server/config.lua', 't', env))()
        return env.FeatherMySQL.config
    end
    local quiet = configWith({})
    assert(not quiet.devMode and not quiet.logQueries and not quiet.logSql)
    local dev = configWith({ feather_mysql_devmode = 'true' })
    assert(dev.devMode and dev.logQueries and dev.logSql)
    local mixed = configWith({ feather_mysql_devmode = 'true', feather_mysql_log_sql = 'false' })
    assert(mixed.logQueries and not mixed.logSql, 'An explicit false wins over devmode')
    assert(configWith({ feather_mysql_log_queries = 'true' }).logQueries, 'The switches still work without devmode')
end)
check('console scheduling probe runs fixed no-SQL samples and preserves normal exports', function()
    local cmd=commands.feather_mysql_bridge_probe
    assert(cmd.restricted)
    local prior=bridgeCalls; schedulingProbeCalls=0
    local lines=capturePrint(function() cmd.callback(0,{}); pump() end)
    local result=logs[#logs]
    assert(result.ok and result.value.readOnly and result.value.sampleCount==3)
    assert(result.value.modes.inline.medianMs==7 and result.value.modes.immediate.medianMs==11)
    assert(result.value.modes.promise_immediate.medianMs==19 and schedulingProbeCalls==15 and bridgeCalls==prior)
    assert(result.value.modes.tick.medianMs==13 and result.value.modes.promise_tick.medianMs==17)
    assert(#lines==1)
end)
check('console scheduling probe rejects player callers extra args and overlap', function()
    local cmd=commands.feather_mysql_bridge_probe; schedulingProbeCalls=0
    capturePrint(function()
        cmd.callback(1,{}); cmd.callback(0,{'inline'})
        assert(schedulingProbeCalls==0)
        cmd.callback(0,{}); cmd.callback(0,{})
        pump()
    end)
    assert(schedulingProbeCalls==15)
end)
check('console scheduling probe validates false marker and clears busy after failure', function()
    local cmd=commands.feather_mysql_bridge_probe
    schedulingProbeAnswer=function(mode,callback)
        callback({ok=true,value={mode=mode,probe=true,flag=true,promiseMs=0,queueMs=0}})
    end
    capturePrint(function() cmd.callback(0,{}); pump() end)
    assert(logs[#logs].code=='INVALID_PROBE_RESULT')
    schedulingProbeAnswer=nil
    capturePrint(function() cmd.callback(0,{}); pump() end)
    assert(logs[#logs].ok)
end)
check('console scheduling probe times out once and ignores late callback', function()
    local cmd=commands.feather_mysql_bridge_probe; local late
    schedulingProbeAnswer=function(_,callback) late=callback end
    local co
    capturePrint(function() cmd.callback(0,{}); pump() end)
    assert(late)
    -- Latest timeout belongs to this outstanding sample; older sample timers
    -- are deliberately left queued and cannot complete any result twice.
    timers[#timers]()
    capturePrint(function() pump() end)
    assert(logs[#logs].code=='PROBE_TIMEOUT')
    local before=resolutions
    late({ok=true,value={}})
    assert(resolutions==before)
    schedulingProbeAnswer=nil
    capturePrint(function() cmd.callback(0,{}); pump() end)
    assert(logs[#logs].ok)
end)
assert(DB.prepare == nil and type(DB.transaction) == 'function' and DB.startTransaction == nil)
print(('Lua contract tests: %d passed'):format(tests))
