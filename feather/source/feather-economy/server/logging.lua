EconomyLogging = {}

local function Encode(fields)
    if type(fields) ~= 'table' or next(fields) == nil then return '' end
    local ok, encoded = pcall(json.encode, fields)
    return ok and (' ' .. encoded) or ''
end

function EconomyLogging.Create(component)
    component = tostring(component or 'economy')
    local logger = {}
    function logger.Info(event, fields)
        print(('[feather-economy] level=info component=%s event=%s%s')
            :format(component, tostring(event), Encode(fields)))
    end
    function logger.Warn(event, fields)
        print(('[feather-economy] level=warn component=%s event=%s%s')
            :format(component, tostring(event), Encode(fields)))
    end
    function logger.Error(event, fields)
        print(('[feather-economy] level=error component=%s event=%s%s')
            :format(component, tostring(event), Encode(fields)))
    end
    return logger
end
