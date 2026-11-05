RoutingResults = {}

function RoutingResults.Ok(value, meta)
    return { ok = true, value = value, meta = meta }
end

function RoutingResults.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end

