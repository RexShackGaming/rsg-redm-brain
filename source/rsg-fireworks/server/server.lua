local RSGCore = exports['rsg-core']:GetCoreObject()

-- A player may only place a firework after using an item. The item is consumed
-- once rsg-gizmo reports a valid placement, never on the initial item use.
local pendingFireworks = {}
local lastBroadcastAt = {}
local lastDisplayAt = {}

local function notifyError(source, titleKey, descriptionKey)
    TriggerClientEvent('RSGCore:Client:Notify', source, {
        title = locale(titleKey),
        description = locale(descriptionKey),
        type = 'error',
        duration = 5000,
    })
end

local function getPending(source, item)
    local pending = pendingFireworks[source]
    if not pending or pending.item ~= item or GetGameTimer() > pending.expiresAt then
        return nil
    end
    return pending
end

-- Best-effort server-side interior check. Some RedM server builds do not expose
-- the interior natives; when they are unavailable, rsg-gizmo still blocks
-- interior placement on the client (allowInterior = false).
local function isInsideInterior(ped, coords)
    if type(GetInteriorFromEntity) == 'function' and ped and ped ~= 0 then
        local ok, interior = pcall(GetInteriorFromEntity, ped)
        if ok and interior and interior ~= 0 then
            return true
        end
    end

    if type(GetInteriorAtCoords) == 'function' then
        local ok, interior = pcall(GetInteriorAtCoords, coords.x, coords.y, coords.z)
        if ok and interior and interior ~= 0 then
            return true
        end
    end

    return false
end

local function useFireworkItem(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    if not RSGCore.Shared.Items[item] then
        return
    end

    local pending = pendingFireworks[source]
    if pending and GetGameTimer() <= pending.expiresAt then
        notifyError(source, 'firework_in_progress_title', 'firework_in_progress')
        return
    end

    pendingFireworks[source] = {
        item = item,
        expiresAt = GetGameTimer() + (Config.PendingFireworkTimeout or 30000),
    }

    TriggerClientEvent('rsg-fireworks:client:' .. item, source)
end

-----------------------------------
-- player use big firework
-----------------------------------
RSGCore.Functions.CreateUseableItem('firework_big', function(source)
    useFireworkItem(source, 'firework_big')
end)

-----------------------------------
-- player use small firework
-----------------------------------
RSGCore.Functions.CreateUseableItem('firework_small', function(source)
    useFireworkItem(source, 'firework_small')
end)

local function getBroadcastEvent(item)
    if item == 'firework_big' then
        return 'rsg-fireworks:client:big_fireworks_players'
    elseif item == 'firework_small' then
        return 'rsg-fireworks:client:small_fireworks_players'
    end
end

local function isDisplayValid(displayName)
    for _, display in ipairs(Config.Displays) do
        if display.name == displayName then
            return true
        end
    end
    return false
end

-----------------------------------
-- validated firework placement (rsg-gizmo)
-----------------------------------
RegisterNetEvent('rsg-fireworks:server:place', function(item, coords, rot)
    local source = source

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    if type(item) ~= 'string' or type(coords) ~= 'vector3' then
        return
    end

    local pending = getPending(source, item)
    local eventName = getBroadcastEvent(item)

    if not pending or not eventName then
        return
    end

    if not exports['rsg-gizmo']:IsPlacementValid(source, coords, Config.PlacementDistance or 6.0) then
        pendingFireworks[source] = nil
        notifyError(source, 'firework_in_progress_title', 'placement_failed')
        return
    end

    if not Config.AllowInteriorPlacement and isInsideInterior(GetPlayerPed(source), coords) then
        pendingFireworks[source] = nil
        notifyError(source, 'firework_in_progress_title', 'placement_indoor')
        return
    end

    rot = exports['rsg-gizmo']:SanitiseRotation(rot)

    local now = GetGameTimer()
    local last = lastBroadcastAt[source]
    if last and now - last < (Config.BroadcastCooldown or 1000) then
        pendingFireworks[source] = nil
        notifyError(source, 'firework_in_progress_title', 'firework_cooldown')
        return
    end

    if not exports['rsg-inventory']:RemoveItem(source, item, 1, nil, 'rsg-fireworks-place') then
        pendingFireworks[source] = nil
        notifyError(source, 'firework_in_progress_title', 'firework_missing')
        return
    end

    pendingFireworks[source] = nil
    lastBroadcastAt[source] = now

    TriggerClientEvent('rsg-fireworks:client:ignite', source, item, coords, rot)

    -- Other clients see the particles when the fuse runs out.
    SetTimeout(Config.FuseTime or 5000, function()
        TriggerClientEvent(eventName, -1, coords)
    end)
end)

-----------------------------------
-- placement cancelled (item is not consumed)
-----------------------------------
RegisterNetEvent('rsg-fireworks:server:cancel', function(item)
    local source = source
    local pending = pendingFireworks[source]

    if not pending then
        return
    end

    if type(item) == 'string' and pending.item ~= item then
        return
    end

    pendingFireworks[source] = nil
end)

-----------------------------------
-- display broadcast to client side
-----------------------------------
RegisterNetEvent('rsg-fireworks:server:display', function(displayName)
    local source = source

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    if not (RSGCore.Functions.HasPermission(source, 'admin') or IsPlayerAceAllowed(source, 'command')) then
        notifyError(source, 'command_failed', 'no_permission')
        return
    end

    if type(displayName) ~= 'string' or not isDisplayValid(displayName) then
        return
    end

    local now = GetGameTimer()
    local last = lastDisplayAt[source]
    if last and now - last < (Config.DisplayCooldown or 5000) then
        notifyError(source, 'command_failed', 'display_cooldown')
        return
    end
    lastDisplayAt[source] = now

    TriggerClientEvent('rsg-fireworks:client:display', -1, displayName)
end)

AddEventHandler('playerDropped', function()
    local source = source
    pendingFireworks[source] = nil
    lastBroadcastAt[source] = nil
    lastDisplayAt[source] = nil
end)
