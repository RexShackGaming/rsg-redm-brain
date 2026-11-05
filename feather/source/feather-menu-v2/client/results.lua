MenuResults = {}

function MenuResults.Ok(value, meta)
    local result = { ok = true, value = value }
    if meta ~= nil then result.meta = meta end
    return result
end

function MenuResults.Err(code, message, details)
    local result = { ok = false, code = code, message = message }
    if details ~= nil then result.details = details end
    return result
end

