ChatResults = {}

function ChatResults.Ok(value, meta)
    return { ok = true, value = value, meta = meta }
end

function ChatResults.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details,
        messageKey = ChatLocale.MessageKey(message) }
end
