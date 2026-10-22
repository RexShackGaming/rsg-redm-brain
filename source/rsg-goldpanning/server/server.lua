local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local sessions  = {} -- [src] = { start, duration, coords }  active, server-authorised pans
local cooldowns = {} -- [src] = GetGameTimer() of the last pan start
local lastSpots = {} -- [src] = { coords, time }             last successfully panned spot

local CLAIM_EARLY_TOLERANCE = 1000  -- ms a claim may arrive early (timer drift)
local CLAIM_LATE_TOLERANCE  = 10000 -- ms a claim may arrive late (latency / hitches)

local function Notify(src, key, nType, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = locale('title'),
        description = locale(key, ...),
        type        = nType,
        duration    = 5000,
    })
end

local function GetPedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function Flag(src, reason, details)
    print(('^1[rsg-goldpanning] %s from %s (%s): %s^0'):format(reason, GetPlayerName(src), src, details or ''))
    SendGoldPanExploitWebhook(reason, GetPlayerName(src), src, details)
end

local function RollTier()
    local roll, acc = math.random(1, 100), 0
    for _, t in ipairs(Config.RewardTiers) do
        acc = acc + t.chance
        if roll <= acc then return t end
    end
    return Config.RewardTiers[1]
end

----------------------------
-- useable item: ask the client to run its local checks (water, busy)
----------------------------
RSGCore.Functions.CreateUseableItem(Config.PanItem, function(source)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end

    if sessions[src] then return Notify(src, 'already_panning', 'error') end

    local last = cooldowns[src]
    if last then
        local remaining = Config.Cooldown * 1000 - (GetGameTimer() - last)
        if remaining > 0 then
            return Notify(src, 'cooldown', 'error', math.ceil(remaining / 1000))
        end
    end

    TriggerClientEvent('rsg-goldpanning:client:tryPan', src)
end)

----------------------------
-- client passed its local checks: open a server-side session
----------------------------
RegisterNetEvent('rsg-goldpanning:server:startPan', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or sessions[src] then return end

    if not Player.Functions.GetItemByName(Config.PanItem) then
        return Notify(src, 'no_pan', 'error')
    end

    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < Config.Cooldown * 1000 then return end

    local coords = GetPedCoords(src)
    if not coords then return end

    -- spot memory is enforced here so it can't be bypassed client-side
    local spot = lastSpots[src]
    if spot and now - spot.time < Config.SpotMemoryTime
       and #(coords.xy - spot.coords.xy) < Config.MinMovementDistance then
        return Notify(src, 'move_further', 'error')
    end

    local duration = math.random(Config.PanTime.min, Config.PanTime.max)
    sessions[src]  = { start = now, duration = duration, coords = coords }
    cooldowns[src] = now

    TriggerClientEvent('rsg-goldpanning:client:beginPan', src, duration)
end)

----------------------------
-- player cancelled / failed client-side
----------------------------
RegisterNetEvent('rsg-goldpanning:server:cancelPan', function()
    sessions[source] = nil
end)

----------------------------
-- reward claim
----------------------------
RegisterNetEvent('rsg-goldpanning:server:claimPan', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local session = sessions[src]
    if not session then
        return Flag(src, locale('wh_no_session'), locale('wh_no_session_desc'))
    end
    sessions[src] = nil -- consume on first attempt to block replays

    local elapsed = GetGameTimer() - session.start
    local minMs, maxMs = session.duration - CLAIM_EARLY_TOLERANCE, session.duration + CLAIM_LATE_TOLERANCE
    if elapsed < minMs or elapsed > maxMs then
        return Flag(src, locale('wh_timing'), locale('wh_timing_desc', elapsed, minMs, maxMs))
    end

    local coords = GetPedCoords(src)
    if not coords then return end
    local drift = #(coords - session.coords)
    if drift > Config.MaxDriftDistance then
        Notify(src, 'moved_too_far', 'error')
        return Flag(src, locale('wh_drift'), locale('wh_drift_desc', drift, Config.MaxDriftDistance))
    end

    if not Player.Functions.GetItemByName(Config.PanItem) then
        return Notify(src, 'no_pan', 'error')
    end

    -- spot is used whether or not anything is found
    lastSpots[src] = { coords = session.coords, time = GetGameTimer() }

    if math.random(1, 100) > Config.GoldChance then
        return Notify(src, 'nothing_found', 'error')
    end

    local tier = RollTier()
    local item = Config.RewardItems[math.random(#Config.RewardItems)]
    local itemData = RSGCore.Shared.Items[item]
    if not itemData then
        return print(('^1[rsg-goldpanning] reward item "%s" does not exist in rsg-core shared items^0'):format(item))
    end

    if not exports['rsg-inventory']:CanAddItem(src, item, tier.amount) then
        return Notify(src, 'inventory_full', 'error')
    end

    if not exports['rsg-inventory']:AddItem(src, item, tier.amount, nil, nil, 'rsg-goldpanning reward') then return end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemData, 'add', tier.amount)
    Notify(src, 'found_' .. tier.tier, 'success')

    local charinfo = Player.PlayerData.charinfo
    local charName = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    TriggerEvent('rsg-log:server:CreateLog', 'goldpanning', locale('log_title_' .. tier.tier), 'yellow',
        locale('log_found', charName, tier.amount, itemData.label))
    SendGoldPanRewardWebhook(tier.tier, GetPlayerName(src), charName, Player.PlayerData.citizenid, itemData.label, tier.amount, coords)
end)

----------------------------
-- cleanup
----------------------------
AddEventHandler('playerDropped', function()
    local src = source
    sessions[src], cooldowns[src], lastSpots[src] = nil, nil, nil
end)
