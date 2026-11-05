NotifyResults = {}

function NotifyResults.Ok(value)
    return { ok = true, value = value }
end

function NotifyResults.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end

