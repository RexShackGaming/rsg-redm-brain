-- shared server helpers for rsg-farming (loaded before server.lua / wellpump.lua)
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

Utils = {}

function Utils.notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('farming'), description = desc, type = ntype or 'inform', duration = 4000,
    })
end

function Utils.getPlayer(src)
    return RSGCore.Functions.GetPlayer(src)
end

function Utils.distanceTo(src, x, y, z)
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z))
end

-- accepts a vector3/table from the client, rejects NaN/inf and non-numbers
function Utils.toCoords(c)
    if type(c) ~= 'vector3' and type(c) ~= 'table' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    for _, v in ipairs({ x, y, z }) do
        if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    end
    return vector3(x, y, z)
end

function Utils.toHeading(h)
    h = tonumber(h)
    if not h or h ~= h or h == math.huge or h == -math.huge then return 0.0 end
    return h % 360
end

function Utils.hasItem(Player, item)
    local it = Player.Functions.GetItemByName(item)
    return it ~= nil and (it.amount or 0) > 0
end

local function itemBox(src, item, mode, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], mode, amount)
end

function Utils.canAdd(src, item, amount)
    if not RSGCore.Shared.Items[item] then return false end
    local ok, res = pcall(function() return exports['rsg-inventory']:CanAddItem(src, item, amount or 1) end)
    return not ok or res ~= false
end

function Utils.removeItem(src, item, amount, slot, reason)
    amount = amount or 1
    if not exports['rsg-inventory']:RemoveItem(src, item, amount, slot, reason) then return false end
    itemBox(src, item, 'remove', amount)
    return true
end

function Utils.addItem(src, item, amount, info, reason)
    amount = amount or 1
    if amount <= 0 or not Utils.canAdd(src, item, amount) then return false end
    if not exports['rsg-inventory']:AddItem(src, item, amount, nil, info, reason) then return false end
    itemBox(src, item, 'add', amount)
    return true
end

---------------------------------
-- action tokens: the server starts a timer at the pre-check and only
-- accepts the action once the progress bar could really have finished.
-- Stops clients from skipping the animation / spamming callbacks.
---------------------------------
local Pending = {}

function Utils.startAction(src, key, durationMs)
    Pending[src] = { key = key, t = GetGameTimer(), min = math.floor((durationMs or 0) * 0.8) }
end

function Utils.finishAction(src, key)
    local p = Pending[src]
    Pending[src] = nil
    return p ~= nil and p.key == key and (GetGameTimer() - p.t) >= p.min
end

AddEventHandler('playerDropped', function()
    Pending[source] = nil
end)
