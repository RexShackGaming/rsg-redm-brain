ToolkitResults = {}
function ToolkitResults.Ok(value) return { ok = true, value = value } end

function ToolkitResults.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end
