local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local lootedBodies = {}   -- [netId] = true
local lootCooldown = {}   -- [src] = os.time()
local robCooldown  = {}   -- [victimSrc] = os.time()
local pendingRob   = {}   -- [robberSrc] = { target = id, time = GetGameTimer() }

local ROB_MIN_TIME  = 4500   -- ms: progress bar is 5-7s, so anything faster skipped it
local ROB_MAX_TIME  = 30000  -- ms: approval from canRob expires after this
local HANDSUP_TIMEOUT = 3000 -- ms to wait for the victim's client to answer

local function notify(src, title, desc, nType)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = desc, type = nType or 'inform', duration = 7000 })
end

-- reject + log a failed validation (possible exploit)
local function reject(src, event, reason)
    Webhooks.Exploit(src, event, reason)
    return false
end

-- raise the player's outlaw status in the players table (0 = disabled)
local function addOutlaw(Player, amount)
    if not amount or amount <= 0 then return end
    MySQL.update('UPDATE players SET outlawstatus = outlawstatus + ? WHERE citizenid = ?',
        { amount, Player.PlayerData.citizenid })
end

local function distanceBetween(a, b)
    return #(GetEntityCoords(a) - GetEntityCoords(b))
end

-----------------------------------------------------------------------
-- NPC loot reward
-----------------------------------------------------------------------
lib.callback.register('rsg-looting:server:lootReward', function(src, netId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    if type(netId) ~= 'number' then return reject(src, 'lootReward', locale('wh_reason_bad_netid')) end

    local now = os.time()
    if lootCooldown[src] and now - lootCooldown[src] < Config.LootCooldown then return false end
    if lootedBodies[netId] then return reject(src, 'lootReward', locale('wh_reason_already_looted')) end

    local body = NetworkGetEntityFromNetworkId(netId)
    if body == 0 or not DoesEntityExist(body) or GetEntityType(body) ~= 1 or IsPedAPlayer(body) then
        return reject(src, 'lootReward', locale('wh_reason_invalid_entity'))
    end
    if GetEntityHealth(body) > 0 then return reject(src, 'lootReward', locale('wh_reason_not_dead')) end
    if distanceBetween(GetPlayerPed(src), body) > Config.LootDistance + 1.0 then
        return reject(src, 'lootReward', locale('wh_reason_too_far_body'))
    end

    lootCooldown[src] = now
    lootedBodies[netId] = true
    Entity(body).state:set('rsgLooted', true, true) -- hides the prompt for everyone

    local rare = math.random(1, 100) <= Config.RareChance
    local pool = rare and Config.RareItems or Config.CommonItems
    local cash = rare and Config.RareCash or Config.CommonCash
    local item = pool[math.random(1, #pool)]
    local itemData = RSGCore.Shared.Items[item]

    local given = nil
    if itemData then
        if exports['rsg-inventory']:CanAddItem(src, item, 1) then
            given = itemData.label
            exports['rsg-inventory']:AddItem(src, item, 1, nil, nil, 'rsg-looting')
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemData, 'add', 1)
            notify(src, locale('loot_title'), locale(rare and 'loot_rare' or 'loot_common', itemData.label), 'success')
        else
            notify(src, locale('loot_title'), locale('inventory_full'), 'error')
        end
    else
        print(('^1[rsg-looting] item "%s" is not in rsg-core shared items^7'):format(item))
    end

    local cashAmount = math.random(cash[1], cash[2])
    Player.Functions.AddMoney('cash', cashAmount, 'rsg-looting')
    addOutlaw(Player, Config.OutlawLoot)
    Webhooks.Loot(src, given, given and 1 or 0, cashAmount, rare)
    return true
end)

-- entity netIds get reused, so clear them when the body is removed
AddEventHandler('entityRemoved', function(entity)
    lootedBodies[NetworkGetNetworkIdFromEntity(entity)] = nil
end)

-----------------------------------------------------------------------
-- rob player
-----------------------------------------------------------------------
local function canRob(src, targetId)
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return false end
    local Player, Target = RSGCore.Functions.GetPlayer(src), RSGCore.Functions.GetPlayer(targetId)
    if not Player or not Target then return false end
    if Player.PlayerData.metadata.isdead then return false end
    if distanceBetween(GetPlayerPed(src), GetPlayerPed(targetId)) > Config.RobDistance + 1.0 then
        return reject(src, 'robPlayer', locale('wh_reason_too_far_target', targetId))
    end
    if robCooldown[targetId] and os.time() - robCooldown[targetId] < Config.RobCooldown then return false end

    local md = Target.PlayerData.metadata
    if md.isdead then return Player, Target, locale('wh_state_dead') end
    if md.ishandcuffed then return Player, Target, locale('wh_state_handcuffed') end
    -- ask the victim's own client (the robber cannot spoof this); time out so an
    -- unresponsive victim client can't hang the robber's callback forever
    local p = promise.new()
    lib.callback('rsg-looting:client:isHandsUp', targetId, function(up) p:resolve(up == true) end)
    SetTimeout(HANDSUP_TIMEOUT, function() if p.state == 0 then p:resolve(false) end end)
    if Citizen.Await(p) then return Player, Target, locale('wh_state_handsup') end
    return false
end

lib.callback.register('rsg-looting:server:canRob', function(src, targetId)
    if pendingRob[src] and GetGameTimer() - pendingRob[src].time < 1000 then return false end -- spam guard
    local ok = canRob(src, targetId)
    pendingRob[src] = ok and { target = tonumber(targetId), time = GetGameTimer() } or nil
    return ok and true or false
end)

local function takeMoney(Player, Target, moneyType, victimKey, robberKey)
    local amount = Target.PlayerData.money[moneyType] or 0
    if amount <= 0 then return 0 end
    if Target.Functions.RemoveMoney(moneyType, amount, moneyType .. '-robbed') then
        Player.Functions.AddMoney(moneyType, amount, moneyType .. '-robbed')
        notify(Target.PlayerData.source, locale('rob_title'), locale(victimKey, amount), 'error')
        notify(Player.PlayerData.source, locale('rob_title'), locale(robberKey, amount), 'success')
        return amount
    end
    return 0
end

RegisterNetEvent('rsg-looting:server:robPlayer', function(targetId)
    local src = source
    local pending = pendingRob[src]
    pendingRob[src] = nil
    targetId = tonumber(targetId)
    local elapsed = pending and GetGameTimer() - pending.time
    if not pending or pending.target ~= targetId or elapsed < ROB_MIN_TIME or elapsed > ROB_MAX_TIME then
        Webhooks.Exploit(src, 'robPlayer', locale('wh_reason_rob_skipped', tostring(targetId)))
        return
    end

    local Player, Target, reason = canRob(src, targetId)
    if not Player then
        -- client already passed canRob before the progress bar, so a failure here is suspicious
        Webhooks.Exploit(src, 'robPlayer', locale('wh_reason_rob_failed', tostring(targetId)))
        return notify(src, locale('rob_title'), locale('rob_not_valid'), 'error')
    end
    robCooldown[targetId] = os.time()
    local cash = Config.TakeCash and takeMoney(Player, Target, 'cash', 'cash_robbed_victim', 'cash_robbed_robber') or 0
    local blood = Config.TakeBloodMoney and takeMoney(Player, Target, 'bloodmoney', 'bloodmoney_robbed_victim', 'bloodmoney_robbed_robber') or 0
    if cash == 0 and blood == 0 then
        notify(src, locale('rob_title'), locale('rob_no_money'), 'inform')
    end
    addOutlaw(Player, Config.OutlawRob)
    Webhooks.Rob(src, targetId, reason, cash, blood)

    exports['rsg-inventory']:OpenInventoryById(src, targetId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lootCooldown[src], robCooldown[src], pendingRob[src] = nil, nil, nil
end)
