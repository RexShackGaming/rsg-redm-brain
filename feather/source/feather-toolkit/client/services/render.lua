ToolkitRender = {}

function ToolkitRender.Text2D(spec)
    if type(spec) ~= 'table' then
        return ToolkitResults.Err('invalid_input', 'Text specification is required.')
    end

    local c = type(spec.color) == 'table' and spec.color or { r = 255, g = 255, b = 255, a = 255 }
    local scale = tonumber(spec.scale) or 0.35
    SetTextScale(scale, scale)
    SetTextColor(c.r or 255, c.g or 255, c.b or 255, c.a or 255)
    if spec.shadow then
        SetTextDropshadow(1, 0, 0, 0, 255)
    end

    DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(spec.text or '')), tonumber(spec.x) or 0.5, tonumber(spec.y) or 0.5)

    return ToolkitResults.Ok({ drawn = true })
end

function ToolkitRender.Text3D(spec)
    if type(spec) ~= 'table' or not tonumber(spec.x) or not tonumber(spec.y) or not tonumber(spec.z) then
        return ToolkitResults.Err('invalid_input', 'World text coordinates are required.')
    end

    local visible, x, y = GetScreenCoordFromWorldCoord(spec.x + 0.0, spec.y + 0.0, spec.z + 0.0)
    if not visible then
        return ToolkitResults.Ok({ drawn = false })
    end

    return ToolkitRender.Text2D({
        x = x,
        y = y,
        text = spec.text,
        color = spec.color,
        scale = spec.scale,
        shadow = spec.shadow
    })
end
