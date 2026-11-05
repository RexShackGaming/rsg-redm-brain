local sequence, pending = 0, {}
local provider = GetCurrentResourceName()

local function operation(method, sql, callback)
    -- Cfx deserializes cross-resource Lua function references as callable tables.
    local callbackMt = type(callback) == 'table' and getmetatable(callback)
    if type(callback) ~= 'function' and not (type(callbackMt) == 'table' and type(callbackMt.__call) == 'function') then
        return
    end
    -- Capture before asynchronous work; never accept caller-supplied attribution.
    local resource = GetInvokingResource() or provider
    sequence = sequence + 1
    local context = { resource = resource, method = type(method) == 'string' and method or 'invalid', id = sequence, sql = sql }
    local started, completed = GetGameTimer(), false
    local function finish(value, err)
        if completed then return end
        completed = true
        pending[context.id] = nil
        FeatherMySQL.log(context, (GetGameTimer() - started) % 4294967296, err)
        local ok = pcall(callback, { ok = err == nil, value = value, error = err })
        if not ok then print(('[%s] Consumer callback unavailable: %s'):format(provider, resource)) end
    end
    local function fail(code, message, driverCode, extra)
        finish(nil, FeatherMySQL.error(code, message, resource, context.method, context.id, driverCode, extra))
    end
    pending[context.id] = fail
    return context, finish, fail
end

local function bridge(name, arguments, finish, fail, convert)
    arguments.n = arguments.n + 1
    arguments[arguments.n] = function(response)
        if type(response) ~= 'table' or type(response.ok) ~= 'boolean' then
            fail('BRIDGE_ERROR', 'Invalid database bridge response')
        elseif not response.ok then
            local err = response.error
            if type(err) ~= 'table' or type(err.code) ~= 'string' or type(err.message) ~= 'string' then
                fail('BRIDGE_ERROR', 'Invalid database bridge error')
            else
                fail(err.code, err.message, err.driverCode, err)
            end
        elseif convert then
            local payload = response.value
            if type(payload) ~= 'table' or (payload.kind ~= 'rows' and payload.kind ~= 'write') then
                fail('BRIDGE_ERROR', 'Invalid database result'); return
            end
            local ok, value, resultError = pcall(convert, response.value)
            if not ok then fail('BRIDGE_ERROR', 'Invalid database result')
            elseif resultError then fail('RESULT_TYPE', resultError)
            else finish(value) end
        else
            finish(response.value)
        end
    end
    local ok = pcall(function()
        local driver = exports[provider]
        driver[name](driver, table.unpack(arguments, 1, arguments.n))
    end)
    if not ok then fail('UNAVAILABLE', 'Database bridge unavailable') end
end

-- One statement.
function FeatherMySQL.execute(method, sql, parameters, callback)
    local context, finish, fail = operation(method, sql, callback)
    if not context then return end
    local request, validationError = FeatherMySQL.validate(method, sql, parameters)
    if not request then fail('INVALID_ARGUMENT', validationError); return end
    request.resource = context.resource
    bridge('DriverExecuteV1', table.pack(request), finish, fail, function(payload)
        return FeatherMySQL.result(method, payload)
    end)
end
exports('ExecuteV1', FeatherMySQL.execute)

-- { ready = boolean, code = string|nil }: whether the database has been reached since start.
function FeatherMySQL.ready(callback)
    local context, finish, fail = operation('ready', nil, callback)
    if not context then return end
    bridge('DriverReadyV1', table.pack(), finish, fail)
end
exports('ReadyV1', FeatherMySQL.ready)

exports('BeginTransactionV1', function(callback)
    local context, finish, fail = operation('transaction.begin', nil, callback)
    if not context then return end
    bridge('DriverTransactionBeginV1', table.pack(context.resource), finish, fail)
end)

exports('TransactionQueryV1', function(id, method, sql, parameters, callback)
    local context, finish, fail = operation(method, sql, callback)
    if not context then return end
    if type(id) ~= 'string' or id == '' then fail('INVALID_ARGUMENT', 'Invalid transaction ID'); return end
    local request, validationError = FeatherMySQL.validate(method, sql, parameters)
    if not request then fail('INVALID_ARGUMENT', validationError); return end
    request.resource = context.resource
    bridge('DriverTransactionQueryV1', table.pack(context.resource, id, request), finish, fail, function(payload)
        return FeatherMySQL.result(method, payload)
    end)
end)

exports('TransactionBatchV1', function(id, statements, callback)
    local context,finish,fail=operation('transaction.batch',nil,callback)
    if not context then return end
    if type(id)~='string' or id=='' then fail('INVALID_ARGUMENT','Invalid transaction ID'); return end
    local batch,err=FeatherMySQL.validateBatch(statements)
    if not batch then fail('INVALID_ARGUMENT',err); return end
    bridge('DriverTransactionBatchV1',table.pack(context.resource,id,batch),function(payload)
        if type(payload)~='table' or #payload~=batch.count then fail('BRIDGE_ERROR','Invalid batch response'); return end
        local results={}
        for index=1,batch.count do
            local item=payload[index]
            if type(item)~='table' or (item.kind~='rows' and item.kind~='write') then
                fail('BRIDGE_ERROR','Invalid batch result'); return
            end
            local ok,value,resultError=pcall(FeatherMySQL.result,'raw',item)
            if not ok or resultError or type(value)~='table' then fail('BRIDGE_ERROR','Invalid batch result'); return end
            results[index]=value
        end
        finish(results)
    end,fail)
end)

exports('FinishTransactionV1', function(id, commit, callback)
    local context, finish, fail = operation('transaction.finish', nil, callback)
    if not context then return end
    if type(id) ~= 'string' or id == '' or type(commit) ~= 'boolean' then
        fail('INVALID_ARGUMENT', 'Invalid transaction completion arguments'); return
    end
    bridge('DriverTransactionFinishV1', table.pack(context.resource, id, commit), finish, fail)
end)

-- The mocked test suites cannot prove the real Cfx boundary, so the provider
-- checks it once at start: the private export must accept its own calls (the
-- caller-identity guard) and the value shapes a result contains must arrive intact.
local function selfCheck()
    local expectedText = 'h\u{e9}llo \u{1F600} \u{65e5}\u{672c}\u{8a9e}'
    local answered = false
    local function report(problem)
        if problem then
            print(('[%s] Bridge self-check FAILED: %s. Database calls will not work.'):format(provider, problem))
        else
            print(('[%s] Bridge self-check OK.'):format(provider))
        end
    end
    local ok = pcall(function()
        local driver = exports[provider]
        driver.DriverSelfCheckV1(driver, function(response)
            answered = true
            if type(response) ~= 'table' or response.ok ~= true then
                local err = type(response) == 'table' and response.error
                report(type(err) == 'table' and ('%s %s'):format(tostring(err.code), tostring(err.message)) or 'invalid response')
                return
            end
            local row = type(response.value) == 'table' and type(response.value.rows) == 'table' and response.value.rows[1]
            if type(row) ~= 'table' or row.text ~= expectedText or row.number ~= 42 or row.nothing ~= nil
                or type(row.bytes) ~= 'table' or row.bytes[1] ~= 0 or row.bytes[2] ~= 255
                or row.big ~= '9007199254740993' or row.flag ~= false or response.value.first ~= expectedText then
                report('values did not round-trip through the Cfx boundary')
            else
                report(nil)
            end
        end)
    end)
    if not ok then report('the bridge export is unavailable'); return end
    SetTimeout(5000, function()
        if not answered then report('no response within 5 seconds') end
    end)
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= provider then return end
    selfCheck()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= provider then return end
    local callbacks = {}
    for _, fail in pairs(pending) do callbacks[#callbacks + 1] = fail end
    for _, fail in ipairs(callbacks) do
        fail('RESOURCE_STOPPED', 'Database resource stopped; write outcome may be unknown')
    end
end)


-- Console-only scheduler comparison. No SQL, connection or driver mutation.
-- Normal Execute/Transaction/Ready callback delivery remains unchanged.
local bridgeProbeBusy=false
RegisterCommand(provider:gsub('[^%w]+','_')..'_bridge_probe',function(source,args)
    if source~=0 then return end
    if #args~=0 then print(('[%s] bridge_probe accepts no arguments.'):format(provider)); return end
    if bridgeProbeBusy then print(('[%s] bridge_probe busy.'):format(provider)); return end
    bridgeProbeBusy=true
    CreateThread(function()
        local ok,result=pcall(function()
            local output={readOnly=true,sampleCount=3,modes={}}
            for _,mode in ipairs({'inline','immediate','promise_immediate','tick','promise_tick'}) do
                local samples,ordered={},{}
                for index=1,3 do
                    local deferred=promise.new()
                    local answered=false
                    local began=GetGameTimer()
                    local function finish(response)
                        if answered then return end
                        answered=true
                        deferred:resolve(response)
                    end
                    SetTimeout(5000,function() finish({ok=false,error={code='PROBE_TIMEOUT'}}) end)
                    local called=pcall(function()
                        local driver=exports[provider]
                        driver.DriverSchedulingProbeV1(driver,mode,finish)
                    end)
                    if not called then finish({ok=false,error={code='PROBE_UNAVAILABLE'}}) end
                    local response=Citizen.Await(deferred)
                    local elapsed=GetGameTimer()-began
                    local v=type(response)=='table' and response.value
                    if type(response)~='table' or response.ok~=true or type(v)~='table'
                        or v.mode~=mode or v.probe~=true or v.flag~=false
                        or type(v.promiseMs)~='number' or v.promiseMs<0
                        or type(v.queueMs)~='number' or v.queueMs<0 then
                        local err=type(response)=='table' and response.error
                        return {ok=false,code=type(err)=='table' and err.code or 'INVALID_PROBE_RESULT',mode=mode}
                    end
                    samples[index]={roundTripMs=elapsed,promiseMs=v.promiseMs,queueMs=v.queueMs}
                    ordered[index]=elapsed
                end
                table.sort(ordered)
                output.modes[mode]={samples=samples,minMs=ordered[1],medianMs=ordered[2],maxMs=ordered[3]}
            end
            return {ok=true,value=output}
        end)
        bridgeProbeBusy=false
        print(('[%s] bridge_probe %s'):format(provider,json.encode(ok and result or {ok=false,code='PROBE_FAILED'})))
    end)
end,true)
