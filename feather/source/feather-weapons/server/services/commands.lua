-- Native-only console diagnostics. Other commands live in their service owners.
RegisterCommand("WeaponProvenanceInspect", function(source, args)
        if source ~= 0 then return end
        local key = args and args[1]
        local request = { limit = tonumber(args and args[2]) or 10 }
        if tonumber(key) then request.itemInstanceId = tonumber(key) else request.serialNumber = key end
        local result = WeaponProvenanceService.Inspect(request,
            { correlationId = "provenance-inspect:" .. tostring(os.time()) }, "feather-weapons")
        if not result.ok then
            print(("[WeaponProvenanceInspect] FAIL code=%s message=%s"):format(
                tostring(result.error and result.error.code), tostring(result.error and result.error.message)))
            return
        end
        local value = result.value
        print(("[WeaponProvenanceInspect] item=%s serial=%s current=%s destroyed=%s events=%d"):format(
            tostring(value.itemInstanceId), tostring(value.serialNumber), tostring(value.current ~= nil),
            tostring(value.destroyed), #(value.events or {})))
        for _, event in ipairs(value.events or {}) do
            print(("[WeaponProvenanceInspect] event=%s type=%s operation=%s from=%s/%s to=%s/%s reason=%s at=%s"):format(
                tostring(event.id), tostring(event.event_type), tostring(event.operation),
                tostring(event.from_inventory_id), tostring(event.from_character_id),
                tostring(event.to_inventory_id), tostring(event.to_character_id),
                tostring(event.reason), tostring(event.occurred_at)))
        end
    end, true)
