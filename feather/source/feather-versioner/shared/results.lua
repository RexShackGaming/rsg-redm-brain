VersionerResults = {}

function VersionerResults.Ok(value)
    return { ok = true, value = value }
end

function VersionerResults.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end
