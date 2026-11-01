RSGCore = exports['rsg-core']:GetCoreObject() -- global so server/logs.lua can use it

local Ambushes  = {}   -- [src] = { id, gang, started, peds = { [netId] = looted(bool) } }
local Cooldowns = {}   -- [citizenid] = os.time() when next ambush allowed
local LootCD    = {}   -- [src] = GetGameTimer()

-- an ambush can't outlive its fight + corpse window (stops stale state blocking or being farmed)
local AMBUSH_TTL = Config.MaxDuration + Config.CorpseTime + 30

local function getAmbush(src, id)
    local amb = Ambushes[src]
    if not amb then return nil end
    if os.time() - amb.started > AMBUSH_TTL then
        Ambushes[src] = nil
        return nil
    end
    if id ~= nil and amb.id ~= id then return nil end
    return amb
end

local function isGangModel(gang, model)
    for _, m in ipairs(gang.models) do
        if joaat(m) == model then return true end
    end
    return false
end

-- reject netIds that already resolve to something other than one of this gang's peds
local function isBandit(amb, netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return true end -- not replicated yet; loot re-validates
    return GetEntityType(ent) == 1 and not IsPedAPlayer(ent) and isGangModel(Config.Gangs[amb.gang], GetEntityModel(ent))
end

local function pickGang()
    local total = 0
    for _, g in pairs(Config.Gangs) do total = total + (g.weight or 1) end
    local roll, acc = math.random(1, total), 0
    for key, g in pairs(Config.Gangs) do
        acc = acc + (g.weight or 1)
        if roll <= acc then return key end
    end
end

---------------------------------------------------------------------
-- Start: server decides if the player may be ambushed and which gang
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-ambush:server:requestAmbush', function(src, cb)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or getAmbush(src) then return cb(false) end
    if Player.PlayerData.metadata.isdead then return cb(false) end

    local cid = Player.PlayerData.citizenid
    if not Config.Debug and Cooldowns[cid] and Cooldowns[cid] > os.time() then return cb(false) end

    local gang = pickGang()
    if not gang then return cb(false) end

    local id = ('%d:%d'):format(src, os.time())
    Ambushes[src] = { id = id, gang = gang, started = os.time(), peds = {}, cash = 0, bodies = 0 }
    Cooldowns[cid] = os.time() + Config.PlayerCooldown

    if SvConfig.Log.AmbushStart then
        SendLog('Ambush', locale('log_start_title'), SvConfig.Colours.start, src,
            locale('log_start_desc', locale('gang_' .. gang)))
    end
    return cb({ id = id, gang = gang })
end)

-- client reports the network ids of the bandits it spawned
RegisterNetEvent('rsg-ambush:server:registerPeds', function(id, netIds)
    local src = source
    local amb = getAmbush(src, id)
    if not amb or amb.registered or type(netIds) ~= 'table' then
        if amb and amb.registered then SecurityLog(src, locale('sec_double_register')) end
        return
    end
    amb.registered = true -- only one registration per ambush
    local max = Config.Gangs[amb.gang].count[2]
    local n = 0
    for _, netId in ipairs(netIds) do
        if n >= max then break end
        if math.type(netId) == 'integer' and amb.peds[netId] == nil and isBandit(amb, netId) then
            amb.peds[netId] = false
            n = n + 1
        end
    end
end)

RegisterNetEvent('rsg-ambush:server:finish', function(id)
    local src = source
    local amb = getAmbush(src, id)
    if not amb then return end
    Ambushes[src] = nil
    if SvConfig.Log.AmbushEnd then
        SendLog('Ambush', locale('log_end_title'), SvConfig.Colours.finish, src, nil, {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_duration'), value = locale('log_seconds', os.time() - amb.started), inline = true },
            { name = locale('log_field_bodies'), value = tostring(amb.bodies), inline = true },
            { name = locale('log_field_cash_paid'), value = locale('log_money', amb.cash), inline = true },
        })
    end
end)

---------------------------------------------------------------------
-- Looting a bandit (all validation server side)
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-ambush:server:loot', function(src, cb, id, netId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local now = GetGameTimer()
    if LootCD[src] and now - LootCD[src] < 1500 then return cb(false) end
    LootCD[src] = now

    local amb = getAmbush(src, id)
    if not amb or math.type(netId) ~= 'integer' then return cb(false) end
    if amb.peds[netId] == true then return cb('empty') end -- already searched
    if amb.peds[netId] ~= false then return cb(false) end -- not one of this ambush's bandits

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return cb(false) end
    -- must be a dead, non-player ped of this ambush's gang
    if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then
        SecurityLog(src, locale('sec_loot_player'), locale('sec_netid', netId))
        return cb(false)
    end
    if not isGangModel(Config.Gangs[amb.gang], GetEntityModel(ent)) then
        SecurityLog(src, locale('sec_loot_wrong_ped'), locale('sec_netid', netId))
        return cb(false)
    end
    if GetEntityHealth(ent) > 0 then return cb(false) end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent))
    if dist > Config.LootDistance + 2.0 then
        SecurityLog(src, locale('sec_loot_far'), locale('sec_distance', ('%.1f'):format(dist), ('%.1f'):format(Config.LootDistance + 2.0)))
        return cb(false)
    end

    amb.peds[netId] = true

    local cash = math.random(Config.LootCash.min, Config.LootCash.max)
    if cash > 0 then Player.Functions.AddMoney('cash', cash, 'rsg-ambush-loot') end

    local gotItem, invFull = false, false
    local itemLines = {}
    for _, l in ipairs(Config.LootItems) do
        if math.random(1, 100) <= l.chance then
            local amt = math.random(l.min, l.max)
            if exports['rsg-inventory']:CanAddItem(src, l.item, amt) then
                -- AddItem shows the ItemBox itself
                if exports['rsg-inventory']:AddItem(src, l.item, amt, nil, nil, 'rsg-ambush-loot') then
                    gotItem = true
                    itemLines[#itemLines + 1] = ('%dx %s'):format(amt, RSGCore.Shared.Items[l.item] and RSGCore.Shared.Items[l.item].label or l.item)
                end
            else
                invFull = true
            end
        end
    end

    if cash > 0 then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('loot_title'), description = locale('loot_cash', cash), type = 'success' })
    end
    if invFull then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('loot_title'), description = locale('loot_full'), type = 'error' })
    end
    amb.cash = amb.cash + cash
    amb.bodies = amb.bodies + 1
    if SvConfig.Log.Loot then
        SendLog('Loot', locale('log_loot_title'), SvConfig.Colours.loot, src, nil, {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_cash'), value = locale('log_money', cash), inline = true },
            { name = locale('log_field_items'), value = #itemLines > 0 and table.concat(itemLines, '\n') or locale('log_none'), inline = true },
        })
    end

    cb((cash > 0 or gotItem) and 'ok' or 'empty')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local amb = Ambushes[src]
    if amb and SvConfig.Log.AmbushEnd then
        SendLog('Ambush', locale('log_left_title'), SvConfig.Colours.finish, nil,
            locale('log_left_desc', GetPlayerName(src) or locale('log_unknown'), src), {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_bodies'), value = tostring(amb.bodies), inline = true },
            { name = locale('log_field_cash_paid'), value = locale('log_money', amb.cash), inline = true },
        })
    end
    Ambushes[src] = nil
    LootCD[src] = nil
end)

if Config.Debug then
    RSGCore.Commands.Add('testambush', locale('cmd_testambush_help'), {}, false, function(source)
        TriggerClientEvent('rsg-ambush:client:force', source)
    end, 'admin')
end
