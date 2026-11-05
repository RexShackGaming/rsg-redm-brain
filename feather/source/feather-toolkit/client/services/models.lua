ToolkitModels = {}

function ToolkitModels.Load(model, timeoutMs)
    local hash = type(model) == 'number' and model or type(model) == 'string' and joaat(model) or nil
    if not hash or not IsModelValid(hash) then
        return ToolkitResults.Err('invalid_input', 'Model is invalid.')
    end

    timeoutMs = tonumber(timeoutMs) or Config.ModelTimeoutMs
    if timeoutMs < 1 or timeoutMs > 60000 then
        return ToolkitResults.Err('invalid_input', 'Model timeout must be between 1 and 60000 milliseconds.')
    end

    RequestModel(hash)

    local deadline = GetGameTimer() + timeoutMs
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
    end

    if not HasModelLoaded(hash) then
        return ToolkitResults.Err('timeout', 'Model loading timed out.', { model = hash })
    end

    return ToolkitResults.Ok({ hash = hash })
end
