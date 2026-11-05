AttachmentService = {}

local function AtGunsmithStation(source, rpcContext)
    local settings = Config.Attachments or {}
    if settings.requireStation ~= true then return WeaponResult.Ok(true, rpcContext.correlationId) end
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT, "Unable to verify gunsmith location", nil,
            rpcContext.correlationId)
    end
    local position = GetEntityCoords(ped, false, true)
    local tolerance = tonumber(settings.serverTolerance) or 3.0
    for stationId, station in pairs(settings.stations or {}) do
        local coords = station.coords
        if coords then
            local dx, dy, dz = position.x - coords.x, position.y - coords.y, position.z - coords.z
            if math.sqrt(dx * dx + dy * dy + dz * dz) <= tolerance then
                return WeaponResult.Ok({ stationId = stationId, label = station.label }, rpcContext.correlationId)
            end
        end
    end
    return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        "Weapon attachments can only be modified at a gunsmith bench", nil, rpcContext.correlationId)
end

local function AuthorizeModification(source, rpcContext, station, operation, equipped, attachment)
    local authorization = (Config.Attachments or {}).authorization or {}
    if authorization.enabled ~= true then return WeaponResult.Ok(true, rpcContext.correlationId) end

    local action = authorization.action
    if type(action) ~= "string" or action == "" then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Gunsmith authorization is not configured", nil, rpcContext.correlationId)
    end

    local called, decision = pcall(function()
        return exports["feather-core"]:Authorize(action, {
            source = source,
            correlationId = rpcContext.correlationId,
            subject = {
                operation = operation,
                stationId = type(station.value) == "table" and station.value.stationId or nil,
                weaponDefinitionId = equipped.definitionId,
                attachmentId = attachment.id
            }
        })
    end)
    if not called or type(decision) ~= "table" or decision.ok ~= true
        or type(decision.value) ~= "table" or type(decision.value.allowed) ~= "boolean" then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Gunsmith authorization is unavailable", nil, rpcContext.correlationId)
    end
    if decision.value.allowed ~= true then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "This character is not authorized to modify weapons", {
                action = action,
                code = decision.value.code
            }, rpcContext.correlationId)
    end
    return WeaponResult.Ok(true, rpcContext.correlationId)
end

-- Shared server station/authorization policy; native ownership and generation
-- are independently reserved by the native transition coordinator, not legacy.
function AttachmentService.AuthorizeNativeModification(source,context,operation,weapon,attachment)
    if operation~='install' and operation~='remove' then return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,'Invalid native attachment action') end
    local station=AtGunsmithStation(source,context)
    if not station.ok then return station end
    return AuthorizeModification(source,context,station,operation,{definitionId=weapon.id},attachment)
end
