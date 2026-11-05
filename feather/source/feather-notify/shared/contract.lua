NotifyContract = {
    Version = 1,
    Styles = {
        tooltip=true, advanced=true, location=true, right=true, left=true, top_banner=true,
        advanced_right=true, top=true, center=true, standard=true, bottom_right=true,
        mission_failed=true, dead_player=true, warning=true
    },
    Fields = {
        style=true, message=true, title=true, duration=true, location=true, dictionary=true,
        icon=true, color=true, quality=true, audioSource=true, audioName=true
    }
}

local function PositiveLimit(name, fallback)
    return math.max(1, math.floor(tonumber(Config[name]) or fallback))
end

local function QualityBounds()
    local minimum = tonumber(Config.minQuality)
    local maximum = tonumber(Config.maxQuality)
    if not minimum or minimum % 1 ~= 0 or minimum < -2147483648
        or not maximum or maximum % 1 ~= 0 or maximum > 2147483647
        or minimum > maximum then
        return -2147483648, 2147483647
    end
    return minimum, maximum
end

function NotifyContract.Limits()
    local minimumQuality, maximumQuality = QualityBounds()
    return {
        maxMessageLength = PositiveLimit('maxMessageLength', 512),
        maxTitleLength = PositiveLimit('maxTitleLength', 256),
        maxLocationLength = PositiveLimit('maxLocationLength', 256),
        maxIdentifierLength = PositiveLimit('maxIdentifierLength', 128),
        maxDurationMs = PositiveLimit('maxDurationMs', 15000),
        minQuality = minimumQuality,
        maxQuality = maximumQuality
    }
end

local function ValidateOptionalString(request, value, field, maximum)
    local fieldValue = request[field]
    if fieldValue == nil then return nil end
    if type(fieldValue) ~= 'string' or #fieldValue > maximum then
        return NotifyResults.Err('invalid_input', 'Notification field is invalid.', {
            field = field,
            maxLength = maximum
        })
    end
    value[field] = fieldValue
    return nil
end

function NotifyContract.Validate(request)
    if type(request) ~= 'table' then
        return NotifyResults.Err('invalid_input', 'Notification request must be a table.')
    end
    for key in pairs(request) do
        if not NotifyContract.Fields[key] then
            return NotifyResults.Err('invalid_input', 'Unknown notification field.', { field=key })
        end
    end

    local value = {}
    value.style = request.style or 'right'
    if not NotifyContract.Styles[value.style] then
        return NotifyResults.Err('invalid_input', 'Notification style is unsupported.', { style=value.style })
    end

    local limits = NotifyContract.Limits()
    if type(request.message) ~= 'string' or request.message == ''
        or #request.message > limits.maxMessageLength then
        return NotifyResults.Err('invalid_input', 'Notification message is invalid.', {
            maxLength=limits.maxMessageLength
        })
    end
    value.message = request.message

    value.duration = tonumber(request.duration) or tonumber(Config.defaultDurationMs) or 3000
    if value.duration < 1 or value.duration > limits.maxDurationMs or value.duration % 1 ~= 0 then
        return NotifyResults.Err('invalid_input', 'Notification duration is invalid.', {
            maxDurationMs=limits.maxDurationMs
        })
    end

    local stringFields = {
        title = limits.maxTitleLength,
        location = limits.maxLocationLength,
        dictionary = limits.maxIdentifierLength,
        icon = limits.maxIdentifierLength,
        color = limits.maxIdentifierLength,
        audioSource = limits.maxIdentifierLength,
        audioName = limits.maxIdentifierLength
    }
    for field, limit in pairs(stringFields) do
        local invalid = ValidateOptionalString(request, value, field, limit)
        if invalid then return invalid end
    end

    if request.quality ~= nil then
        if type(request.quality) ~= 'number' or request.quality % 1 ~= 0
            or request.quality < limits.minQuality or request.quality > limits.maxQuality then
            return NotifyResults.Err('invalid_input', 'Notification quality is invalid.', {
                field = 'quality',
                minimum = limits.minQuality,
                maximum = limits.maxQuality
            })
        end
        value.quality = request.quality
    end

    if (value.style == 'top_banner' or value.style == 'advanced'
        or value.style == 'mission_failed' or value.style == 'warning')
        and (type(value.title) ~= 'string' or value.title == '') then
        return NotifyResults.Err('invalid_input', 'This notification style requires a title.')
    end
    return NotifyResults.Ok(value)
end
