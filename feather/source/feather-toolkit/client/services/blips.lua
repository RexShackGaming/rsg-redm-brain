ToolkitBlips = { records = {}, nextId = 0 }

function ToolkitBlips.Create(owner, spec)
    if type(spec) ~= 'table' or not tonumber(spec.x) or not tonumber(spec.y) or not tonumber(spec.z) then
        return ToolkitResults.Err('invalid_input', 'Blip specification is invalid.')
    end

    local x, y, z = tonumber(spec.x), tonumber(spec.y), tonumber(spec.z)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, tonumber(spec.style) or 1664425300, x + 0.0, y + 0.0, z + 0.0)
    if not blip or blip == 0 then
        return ToolkitResults.Err('create_failed', 'Blip creation failed.')
    end

    local sprite = spec.sprite ~= nil and tonumber(spec.sprite) or nil
    if spec.sprite ~= nil and not sprite then
        RemoveBlip(blip)
        return ToolkitResults.Err('invalid_input', 'Blip sprite must be numeric.')
    end

    if sprite then
        SetBlipSprite(blip, sprite, true)
    end

    if spec.name then
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, tostring(spec.name))
    end

    ToolkitBlips.nextId = ToolkitBlips.nextId + 1
    local id = ('blip:%d'):format(ToolkitBlips.nextId)
    ToolkitBlips.records[id] = { owner = owner, handle = blip }

    return ToolkitResults.Ok({ id = id, handle = blip })
end

function ToolkitBlips.Remove(owner, id)
    local v = ToolkitBlips.records[id]
    if not v then
        return ToolkitResults.Err('not_found', 'Blip was not found.')
    end

    if v.owner ~= owner then
        return ToolkitResults.Err('forbidden', 'Blip belongs to another resource.')
    end

    RemoveBlip(v.handle)
    ToolkitBlips.records[id] = nil
    return ToolkitResults.Ok({ removed = true, id = id })
end

function ToolkitBlips.Cleanup(owner)
    local n = 0
    for id, v in pairs(ToolkitBlips.records) do
        if v.owner == owner then
            RemoveBlip(v.handle)
            ToolkitBlips.records[id] = nil
            n = n + 1
        end
    end
    return n
end

function ToolkitBlips.CleanupAll()
    local count = 0
    for id, record in pairs(ToolkitBlips.records) do
        RemoveBlip(record.handle)
        ToolkitBlips.records[id] = nil
        count = count + 1
    end
    return count
end
