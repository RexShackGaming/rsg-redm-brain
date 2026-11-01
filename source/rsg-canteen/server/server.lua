local RSGCore = exports['rsg-core']:GetCoreObject()

-- server-side action state: [src] = { type, slot?, coords?, started }
local pending = {}
local MAX_PUMP_DIST = Config.TargetDistance + 1.5
local TIME_GRACE = 500 -- ms allowed under the progress duration
local PENDING_TIMEOUT = 15000 -- ms after the duration before a pending action is dropped

---------------------------------
-- helpers
---------------------------------
local function notify(src, msg, typ)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('notify_title'), description = msg, type = typ or 'inform' })
end

local function getUses(item)
    return item and item.info and tonumber(item.info.uses) or 0
end

local function setUses(Player, slot, uses)
    local item = Player.PlayerData.items[slot]
    if not item or item.name ~= Config.CanteenItem then return false end
    local info = item.info or {}
    info.uses = uses
    exports['rsg-inventory']:SetItemInfo(Player.PlayerData.source, slot, info)
    return true
end

-- canteen with the fewest uses (so filling tops up the emptiest one first)
local function getFillableCanteen(Player)
    local best
    for _, item in pairs(Player.PlayerData.items) do
        if item.name == Config.CanteenItem and getUses(item) < Config.MaxUses then
            if not best or getUses(item) < getUses(best) then
                best = item
            end
        end
    end
    return best
end

local function playerCoords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

-- a pending action whose finish event never arrived (crash, resource restart) must not lock the player out
local function isPending(src)
    local action = pending[src]
    if not action then return false end
    local duration = action.type == 'drink' and Config.DrinkTime or Config.FillTime
    if GetGameTimer() - action.started > duration + PENDING_TIMEOUT then
        pending[src] = nil
        return false
    end
    return true
end

local function takePending(src, actionType, duration)
    local action = pending[src]
    pending[src] = nil
    if not action or action.type ~= actionType then return nil end
    if GetGameTimer() - action.started < duration - TIME_GRACE then return nil end
    return action
end

---------------------------------
-- drink
---------------------------------
RSGCore.Functions.CreateUseableItem(Config.CanteenItem, function(source, item)
    local src = source
    if isPending(src) then
        return notify(src, locale('busy'), 'error')
    end
    if getUses(item) <= 0 then
        return notify(src, locale('canteen_empty'), 'error')
    end
    pending[src] = { type = 'drink', slot = item.slot, started = GetGameTimer() }
    TriggerClientEvent('rsg-canteen:client:drink', src)
end)

RegisterNetEvent('rsg-canteen:server:finishDrink', function(completed)
    local src = source
    local action = takePending(src, 'drink', Config.DrinkTime)
    if not completed or not action then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = Player.PlayerData.items[action.slot]
    if not item or item.name ~= Config.CanteenItem then return end
    local uses = getUses(item)
    if uses <= 0 then
        return notify(src, locale('canteen_empty'), 'error')
    end

    uses = uses - 1
    setUses(Player, action.slot, uses)

    -- rsg-hud owns the live needs values client-side, so update thirst through it
    TriggerClientEvent('rsg-canteen:client:addThirst', src, Config.ThirstAmount)

    notify(src, locale('drank'):format(uses, Config.MaxUses), 'success')
end)

---------------------------------
-- fill
---------------------------------
RSGCore.Functions.CreateCallback('rsg-canteen:server:startFill', function(source, cb, pumpCoords, fromWater)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or isPending(src) or type(pumpCoords) ~= 'vector3' then return cb(false) end
    if fromWater and not Config.WaterFill.Enabled then return cb(false) end

    if #(playerCoords(src) - pumpCoords) > MAX_PUMP_DIST then
        notify(src, locale('too_far'), 'error')
        return cb(false)
    end
    if not exports['rsg-inventory']:HasItem(src, Config.CanteenItem, 1) then
        notify(src, locale('no_canteen'), 'error')
        return cb(false)
    end
    if not getFillableCanteen(Player) then
        notify(src, locale('canteens_full'), 'error')
        return cb(false)
    end

    pending[src] = { type = 'fill', coords = pumpCoords, started = GetGameTimer() }
    cb(true)
end)

RegisterNetEvent('rsg-canteen:server:finishFill', function(completed)
    local src = source
    local action = takePending(src, 'fill', Config.FillTime)
    if not completed or not action then return end

    if #(playerCoords(src) - action.coords) > MAX_PUMP_DIST then
        return notify(src, locale('too_far'), 'error')
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = getFillableCanteen(Player)
    if not item then
        return notify(src, locale('canteens_full'), 'error')
    end

    if setUses(Player, item.slot, Config.MaxUses) then
        notify(src, locale('canteen_filled'):format(Config.MaxUses), 'success')
    end
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
