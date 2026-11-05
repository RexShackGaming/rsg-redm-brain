ToolkitAnimations = {}

function ToolkitAnimations.LoadDictionary(dictionary, timeoutMs)
    if type(dictionary) ~= 'string' or dictionary == '' or #dictionary > 128 then
        return ToolkitResults.Err('invalid_input', 'Animation dictionary is invalid.')
    end

    timeoutMs = tonumber(timeoutMs) or Config.AnimDictTimeoutMs
    if timeoutMs < 1 or timeoutMs > 60000 then
        return ToolkitResults.Err('invalid_input', 'Animation dictionary timeout must be between 1 and 60000 milliseconds.')
    end

    if HasAnimDictLoaded(dictionary) then
        return ToolkitResults.Ok({ dictionary = dictionary, cached = true })
    end

    RequestAnimDict(dictionary)
    local deadline = GetGameTimer() + timeoutMs
    while not HasAnimDictLoaded(dictionary) and GetGameTimer() < deadline do
        Wait(0)
    end

    if not HasAnimDictLoaded(dictionary) then
        return ToolkitResults.Err('timeout', 'Animation dictionary loading timed out.', {
            dictionary = dictionary
        })
    end

    return ToolkitResults.Ok({ dictionary = dictionary, cached = false })
end
