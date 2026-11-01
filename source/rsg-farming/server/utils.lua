-- shared server helpers for rsg-farming (loaded before server.lua / wellpump.lua)
local RSGCore = exports['rsg-core']:GetCoreObject()

Utils = {}

-- rsg-core callback that lets handlers `return ok, msg` like before
function Utils.callback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        cb(fn(source, ...))
    end)
end

function Utils.notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('farming'), description = desc, type = ntype or 'inform', duration = 4000,
    })
end

function Utils.getPlayer(src)
    return RSGCore.Functions.GetPlayer(src)
end

function Utils.distanceTo(src, x, y, z)
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(x, y, z))
end

local function finite(v) return v and v == v and v ~= math.huge and v ~= -math.huge end

-- accepts a vector3/table from the client, rejects NaN/inf and non-numbers
function Utils.toCoords(c)
    local t = type(c)
    if t ~= 'vector3' and t ~= 'table' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return vector3(x, y, z)
end

function Utils.toHeading(h)
    h = tonumber(h)
    if not finite(h) then return 0.0 end
    return h % 360
end

function Utils.hasItem(src, item)
    return (exports['rsg-inventory']:GetItemCount(src, item) or 0) > 0
end

function Utils.canAdd(src, item, amount)
    if not RSGCore.Shared.Items[item] then return false end
    local ok, res = pcall(exports['rsg-inventory'].CanAddItem, exports['rsg-inventory'], src, item, amount or 1)
    return ok and res ~= false
end

-- strict check that ALL items fit together (combined weight + free slots), not just one at a time
-- list = { { item = 'corn', amount = 3 }, ... }
function Utils.canAddAll(src, list)
    local inv = exports['rsg-inventory']
    local weight, slotsNeeded, seen = 0, 0, {}
    for _, r in ipairs(list) do
        local shared = RSGCore.Shared.Items[r.item]
        if not shared or not Utils.canAdd(src, r.item, r.amount) then return false end
        weight = weight + (tonumber(shared.weight) or 0) * r.amount
        if shared.unique then
            slotsNeeded = slotsNeeded + r.amount
        elseif not seen[r.item] then
            seen[r.item] = true
            if (inv:GetItemCount(src, r.item) or 0) <= 0 then slotsNeeded = slotsNeeded + 1 end
        end
    end
    if weight > (inv:GetFreeWeight(src) or 0) then return false end
    local _, freeSlots = inv:GetSlots(src)
    return slotsNeeded <= (freeSlots or 0)
end

-- rsg-inventory shows the ItemBox itself, so no manual ItemBox events here
function Utils.removeItem(src, item, amount, slot, reason)
    return exports['rsg-inventory']:RemoveItem(src, item, amount or 1, slot, reason) and true or false
end

function Utils.addItem(src, item, amount, info, reason, slot)
    amount = amount or 1
    if amount <= 0 or not Utils.canAdd(src, item, amount) then return false end
    return exports['rsg-inventory']:AddItem(src, item, amount, info, slot, reason) and true or false
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
