ToolkitClipboard = {}

function ToolkitClipboard.Copy(text)
    text = tostring(text or '')
    if text == '' or #text > 65536 then
        return ToolkitResults.Err('invalid_input', 'Clipboard text is invalid.')
    end

    SendNUIMessage({ type = 'copy', text = text })

    return ToolkitResults.Ok({ copied = true, length = #text })
end
