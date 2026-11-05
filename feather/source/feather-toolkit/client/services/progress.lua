ToolkitProgress = { records = {}, queue = {}, activeId = nil, nextId = 0 }

local themes = { linear = true, circle = true, innercircle = true }

local function IsCallable(value)
    return type(value) == 'function'
        or (type(value) == 'table' and type(rawget(value, '__cfx_functionReference')) == 'string')
end

local function Settings()
    return type(Config.Progress) == 'table' and Config.Progress or {}
end

local function Snapshot(record)
    return {
        id = record.id,
        state = record.state,
        message = record.message,
        durationMs = record.durationMs,
        theme = record.theme
    }
end

local function RemoveQueued(id)
    for index, queuedId in ipairs(ToolkitProgress.queue) do
        if queuedId == id then
            table.remove(ToolkitProgress.queue, index)
            return true
        end
    end
    return false
end

local function Notify(record, outcome)
    if not IsCallable(record.callback) then return end

    local called, reason = pcall(record.callback, ToolkitResults.Ok({
        id = record.id,
        outcome = outcome
    }))
    if not called then
        print(('[feather-toolkit] progress callback failed id=%s reason=%s'):format(record.id, tostring(reason)))
    end
end

local function Pump()
    if ToolkitProgress.activeId then return end
    while #ToolkitProgress.queue > 0 do
        local id = table.remove(ToolkitProgress.queue, 1)
        local record = ToolkitProgress.records[id]
        if record then
            record.state = 'active'
            ToolkitProgress.activeId = id
            SendNUIMessage({
                type = 'progress.open',
                id = id,
                message = record.message,
                durationMs = record.durationMs,
                theme = record.theme,
                color = record.color,
                widthPercent = record.widthPercent
            })
            return
        end
    end
end

local function Finish(id, outcome, notify)
    local record = ToolkitProgress.records[id]
    if not record then return false end

    RemoveQueued(id)
    if ToolkitProgress.activeId == id then
        ToolkitProgress.activeId = nil
    end

    ToolkitProgress.records[id] = nil
    if notify ~= false then
        Notify(record, outcome)
    end

    Pump()
    return true
end

local function Validate(spec, callback)
    if type(spec) ~= 'table' then
        return ToolkitResults.Err('invalid_input', 'Progress specification is required.')
    end

    local allowed = { message = true, durationMs = true, theme = true, color = true, widthPercent = true }
    for field in pairs(spec) do
        if not allowed[field] then
            return ToolkitResults.Err('invalid_input', 'Unexpected progress specification field.')
        end
    end

    local settings = Settings()
    local message = type(spec.message) == 'string' and spec.message:match('^%s*(.-)%s*$') or nil
    local durationMs = tonumber(spec.durationMs)
    local theme = spec.theme or 'linear'
    local color = spec.color or '#7c2d2d'
    local widthPercent = spec.widthPercent == nil and 20 or tonumber(spec.widthPercent)
    if not message or message == '' or message:find('[%c]')
        or #message > (tonumber(settings.MaxMessageLength) or 160) then
        return ToolkitResults.Err('invalid_input', 'Progress message is invalid.')
    end

    if not durationMs or durationMs % 1 ~= 0
        or durationMs < (tonumber(settings.MinDurationMs) or 100)
        or durationMs > (tonumber(settings.MaxDurationMs) or 600000) then
        return ToolkitResults.Err('invalid_input', 'Progress duration is invalid.')
    end

    if type(theme) ~= 'string' or not themes[theme] then
        return ToolkitResults.Err('invalid_input', 'Progress theme is invalid.')
    end

    if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then
        return ToolkitResults.Err('invalid_input', 'Progress color must be a six-digit hex color.')
    end

    if not widthPercent or widthPercent % 1 ~= 0 or widthPercent < 5 or widthPercent > 100 then
        return ToolkitResults.Err('invalid_input', 'Progress width must be between 5 and 100 percent.')
    end

    if callback ~= nil and not IsCallable(callback) then
        return ToolkitResults.Err('invalid_input', 'Progress callback is not callable.')
    end

    return ToolkitResults.Ok({
        message = message,
        durationMs = durationMs,
        theme = theme,
        color = color:lower(),
        widthPercent = widthPercent
    })
end

function ToolkitProgress.Start(owner, spec, callback)
    local valid = Validate(spec, callback)
    if not valid.ok then return valid end

    local settings = Settings()
    local count = 0
    for _ in pairs(ToolkitProgress.records) do
        count = count + 1
    end

    if count >= (tonumber(settings.MaxQueue) or 16) then
        return ToolkitResults.Err('limit_exceeded', 'Progress queue is full.')
    end

    ToolkitProgress.nextId = ToolkitProgress.nextId + 1
    local id = ('progress:%d'):format(ToolkitProgress.nextId)
    local value = valid.value
    local record = {
        id = id,
        owner = owner,
        state = 'queued',
        callback = callback,
        message = value.message,
        durationMs = value.durationMs,
        theme = value.theme,
        color = value.color,
        widthPercent = value.widthPercent
    }
    ToolkitProgress.records[id] = record
    ToolkitProgress.queue[#ToolkitProgress.queue + 1] = id
    Pump()
    return ToolkitResults.Ok(Snapshot(record))
end

function ToolkitProgress.Get(owner, id)
    local record = type(id) == 'string' and ToolkitProgress.records[id] or nil
    if not record then
        return ToolkitResults.Err('not_found', 'Progress request was not found.')
    end

    if record.owner ~= owner then
        return ToolkitResults.Err('forbidden', 'Progress request belongs to another resource.')
    end

    return ToolkitResults.Ok(Snapshot(record))
end

function ToolkitProgress.Cancel(owner, id)
    local record = type(id) == 'string' and ToolkitProgress.records[id] or nil
    if not record then
        return ToolkitResults.Err('not_found', 'Progress request was not found.')
    end

    if record.owner ~= owner then
        return ToolkitResults.Err('forbidden', 'Progress request belongs to another resource.')
    end

    local active = ToolkitProgress.activeId == id
    if active then
        SendNUIMessage({
            type = 'progress.close',
            id = id
        })
    end

    Finish(id, 'cancelled', true)
    return ToolkitResults.Ok({ id = id, cancelled = true, wasActive = active })
end

function ToolkitProgress.Cleanup(owner)
    local ids = {}
    for id, record in pairs(ToolkitProgress.records) do
        if record.owner == owner then
            ids[#ids + 1] = id
        end
    end

    local removed = 0
    for _, id in ipairs(ids) do
        if ToolkitProgress.activeId == id then
            SendNUIMessage({
                type = 'progress.close',
                id = id
            })
        end

        if Finish(id, 'cancelled', false) then
            removed = removed + 1
        end
    end

    return removed
end

function ToolkitProgress.CleanupAll()
    SendNUIMessage({
        type = 'progress.reset'
    })
    ToolkitProgress.records, ToolkitProgress.queue, ToolkitProgress.activeId = {}, {}, nil
end

function ToolkitProgress.Validate(spec, callback)
    return Validate(spec, callback)
end

RegisterNUICallback('toolkit_progress_complete', function(payload, cb)
    local id = type(payload) == 'table' and payload.id or nil
    if type(id) == 'string' and ToolkitProgress.activeId == id then
        Finish(id, 'completed', true)
    end
    cb('ok')
end)
