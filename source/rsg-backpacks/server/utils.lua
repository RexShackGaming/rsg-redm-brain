BP = BP or {}

BP.BackpackByItem = Config.backpackByItem

-- ox_lib notification to a player (texts come from locales)
function BP.Notify(src, nType, titleKey, descKey, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale(titleKey),
        description = descKey and locale(descKey, ...) or nil,
        type = nType or 'inform',
        duration = 5000,
    })
end

-- Per player / per key cooldown. Returns true when the call must be rejected.
local lastCall = {}

function BP.RateLimited(src, key, ms)
    local now = GetGameTimer()
    lastCall[src] = lastCall[src] or {}
    local last = lastCall[src][key]
    if last and (now - last) < ms then
        return true
    end
    lastCall[src][key] = now
    return false
end

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
end)

-- Returns the backpack config + item when the player really holds a backpack with this serial
function BP.GetHeldBackpack(Player, serial)
    if not Player or type(serial) ~= 'string' or serial == '' then return nil end
    for _, it in pairs(Player.PlayerData.items or {}) do
        if it and type(it.info) == 'table' and it.info.serie == serial and BP.BackpackByItem[it.name] then
            return BP.BackpackByItem[it.name], it
        end
    end
    return nil
end
