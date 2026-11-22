RSGCore = exports['rsg-core']:GetCoreObject() -- global so server/logs.lua can use it

local Ambushes    = {}   -- [src] = { id, cid, gang, count, wave, region, started, peds = { [netId] = looted(bool) }, horses = { netId }, ... }
local Claimed     = {}   -- [netId] = src: a network id can only belong to one running ambush
local Cooldowns   = {}   -- [citizenid] = os.time() when the next ambush is allowed
local RequestAt   = {}   -- [src] = os.time() of the last ambush check
local LootCD      = {}   -- [src] = GetGameTimer() of the last loot attempt
local WarnedItems = {}   -- unknown loot items already reported in the console

-- an ambush can't outlive its fight + corpse window (stops stale state blocking or being farmed)
local AMBUSH_TTL       = Config.MaxDuration + Config.CorpseTime + 30
local REGISTER_TIMEOUT = 6000   -- ms to wait for client-spawned peds to replicate to the server
local LOOT_RATE_MS     = 1500   -- minimum time between two loot attempts of one player
local WAVE_MIN_SECONDS = 5      -- reinforcements can't be registered sooner than this after the start

local GangModels, HorseModels = {}, {}   -- [modelHash] = true
local LootItems = {}                     -- validated copy of Config.LootItems
local LootCash  = { min = 0, max = 0 }   -- validated copy of Config.LootCash
local GangLoot  = {}                     -- [gang] = { cash = {min,max}|nil, items = {...}|nil } validated per-gang overrides
local Strongbox = { cash = { min = 0, max = 0 }, items = {}, chance = 0 }

---------------------------------------------------------------------
-- Config validation (a typo in the config must not break the script at runtime)
---------------------------------------------------------------------
local function warn(msg, ...)
    print(('^3[rsg-ambush] ' .. msg .. '^7'):format(...))
end

local function toSet(list)
    local set = {}
    for _, name in ipairs(list) do set[joaat(name)] = true end
    return set
end

local function validRange(r, minValue)
    return type(r) == 'table' and math.type(r.min) == 'integer' and math.type(r.max) == 'integer'
        and r.min >= minValue and r.min <= r.max
end

local function validItems(list, label)
    local out = {}
    for i, l in ipairs(list or {}) do
        if type(l) == 'table' and type(l.item) == 'string' and validRange(l, 1) and type(l.chance) == 'number' and l.chance > 0 then
            out[#out + 1] = l
        else
            warn('%s[%d] is invalid (item, whole min/max >= 1, chance) and was skipped', label, i)
        end
    end
    return out
end

local function validateConfig()
    HorseModels = toSet(Config.Horses)

    for key, g in pairs(Config.Gangs) do
        local valid = type(g.models) == 'table' and #g.models > 0
            and type(g.weapons) == 'table' and #g.weapons > 0
            and type(g.count) == 'table' and math.type(g.count[1]) == 'integer' and math.type(g.count[2]) == 'integer'
            and g.count[1] >= 1 and g.count[1] <= g.count[2]
            and (g.weight or 1) > 0
        if valid then
            GangModels[key] = toSet(g.models)
            local r = g.reinforcements
            if r and not (type(r) == 'table' and type(r.chance) == 'number' and type(r.count) == 'table'
                and math.type(r.count[1]) == 'integer' and math.type(r.count[2]) == 'integer' and r.count[1] >= 1 and r.count[1] <= r.count[2]) then
                g.reinforcements = nil
                warn('gang "%s": reinforcements is invalid (chance, count = { min, max }) and was disabled', key)
            end
            local gl = {}
            if g.loot then
                if g.loot.cash ~= nil then
                    if validRange(g.loot.cash, 0) then gl.cash = g.loot.cash
                    else warn('gang "%s": loot.cash must be whole numbers with 0 <= min <= max, using the global cash loot', key) end
                end
                if g.loot.items ~= nil then gl.items = validItems(g.loot.items, ('Config.Gangs.%s.loot.items'):format(key)) end
            end
            GangLoot[key] = gl
        else
            Config.Gangs[key] = nil
            warn('gang "%s" is invalid (models, weapons, count or weight) and was disabled', key)
        end
    end
    if next(Config.Gangs) == nil then warn('no valid gangs configured, ambushes are disabled') end

    if validRange(Config.LootCash, 0) then
        LootCash = Config.LootCash
    else
        warn('Config.LootCash must be whole numbers with 0 <= min <= max, cash loot is disabled')
    end
    LootItems = validItems(Config.LootItems, 'Config.LootItems')

    local sb = Config.Strongbox
    if sb and sb.Enabled then
        if validRange(sb.Cash, 0) and type(sb.Chance) == 'number' then
            Strongbox = { chance = sb.Chance, cash = sb.Cash, items = validItems(sb.Items, 'Config.Strongbox.Items') }
        else
            warn('Config.Strongbox is invalid (Chance, Cash = { min, max }) and was disabled')
        end
    end

    local b = Config.Bounty
    if b and b.Enabled and not validRange(b.PerBandit, 0) then
        Config.Bounty.Enabled = false
        warn('Config.Bounty.PerBandit must be whole numbers with 0 <= min <= max, bounties are disabled')
    end
end

validateConfig()

---------------------------------------------------------------------
-- Optional integrations (rsg-reputation, rsg-skills, rsg-economy): never an error if they are missing
---------------------------------------------------------------------
local function callExport(res, fn, ...)
    if GetResourceState(res) ~= 'started' then return false end
    local exp = exports[res]
    return pcall(function(...) return exp[fn](exp, ...) end, ...)
end

local function getRegion(src)
    local z = Config.Zones
    if not (z and z.Enabled) then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local ok, region = callExport('rsg-economy', 'GetRegionAt', GetEntityCoords(ped), z.Radius)
    if ok and type(region) == 'string' then return region end
    return nil
end

local function chanceMultiplier(src, region)
    local mult = 1.0

    local h = Config.Hooks and Config.Hooks.Honor
    if h and h.Enabled then
        local ok, honor = callExport('rsg-reputation', 'GetHonor', src)
        honor = ok and tonumber(honor) or nil
        if honor then
            for _, e in ipairs(h.Chance or {}) do
                if (e.maxHonor and honor <= e.maxHonor) or (e.minHonor and honor >= e.minHonor) then
                    mult = mult * (tonumber(e.mult) or 1.0)
                    break
                end
            end
        end
    end

    local area = region and Config.Zones and Config.Zones.Areas and Config.Zones.Areas[region]
    if area then mult = mult * (tonumber(area.chance) or 1.0) end
    return mult
end

local function extraBandits(src)
    local s = Config.Hooks and Config.Hooks.Scaling
    if not (s and s.Enabled) then return 0 end
    local ok, level = callExport('rsg-skills', 'GetLevel', src, s.Skill)
    level = ok and tonumber(level) or nil
    if not level or (s.PerLevels or 0) < 1 then return 0 end
    return math.min(math.floor(level / s.PerLevels) * (s.Extra or 1), s.MaxExtra or 0)
end

---------------------------------------------------------------------
-- Ambush state
---------------------------------------------------------------------
local function deleteNetEntity(netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
end

-- Ends an ambush and removes whatever bandits are still in the world. The client normally cleans up
-- itself first; this is the backstop for crashes, disconnects and expired ambushes.
local function endAmbush(src)
    local amb = Ambushes[src]
    if not amb then return nil end
    Ambushes[src] = nil
    for netId in pairs(amb.peds) do
        Claimed[netId] = nil
        deleteNetEntity(netId)
    end
    for _, netId in ipairs(amb.horses) do
        Claimed[netId] = nil
        deleteNetEntity(netId)
    end
    return amb
end

local function getAmbush(src, id)
    local amb = Ambushes[src]
    if not amb then return nil end
    if os.time() - amb.started > AMBUSH_TTL then
        endAmbush(src)
        return nil
    end
    if id ~= nil and amb.id ~= id then return nil end
    return amb
end

-- weighted random gang; the area can make a gang more common (> 1), rarer (< 1) or impossible (0)
local function pickGang(region)
    local areaGangs = region and Config.Zones and Config.Zones.Areas and Config.Zones.Areas[region] and Config.Zones.Areas[region].gangs
    local weights, total = {}, 0.0
    for key, g in pairs(Config.Gangs) do
        local w = (g.weight or 1) * ((areaGangs and tonumber(areaGangs[key])) or 1.0)
        if w > 0 then
            weights[key] = w
            total = total + w
        end
    end
    if total <= 0 then return nil end
    local roll, acc = math.random() * total, 0.0
    for key, w in pairs(weights) do
        acc = acc + w
        if roll < acc then return key end
    end
    return next(weights)
end

-- wait (up to the deadline) for a client-spawned entity to replicate to the server
local function awaitEntity(netId, deadline)
    while true do
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
        if GetGameTimer() >= deadline then return nil end
        Wait(200)
    end
end

-- Validates the network ids a client reports: they must resolve to a real non-player ped of the right
-- model, owned by that client, near that client, and not claimed by another ambush.
local function registerList(src, amb, list, models, limit, deadline, onAccept)
    if type(list) ~= 'table' then return end
    local playerPed = GetPlayerPed(src)
    local accepted = 0
    for i = 1, math.min(#list, limit * 3) do
        if accepted >= limit then break end
        local netId = list[i]
        if math.type(netId) == 'integer' and not Claimed[netId] then
            local ent = awaitEntity(netId, deadline)
            if Ambushes[src] ~= amb then return end -- ambush ended while waiting
            if ent then
                if GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) or not models[GetEntityModel(ent)] then
                    SecurityLog(src, locale('sec_register_invalid'), locale('sec_netid', netId))
                elseif NetworkGetEntityOwner(ent) == src
                    and (playerPed == 0 or #(GetEntityCoords(playerPed) - GetEntityCoords(ent)) <= Config.DespawnDistance) then
                    Claimed[netId] = src
                    onAccept(netId)
                    accepted = accepted + 1
                end
            end
        end
    end
end

local function notify(src, title, text, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = text, type = ntype })
end

---------------------------------------------------------------------
-- Start: the server rolls the chance, decides if the player may be ambushed, which gang, how many
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-ambush:server:requestAmbush', function(src, cb, force)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or getAmbush(src) then return cb(false) end

    local now = os.time()
    if not Config.Debug then
        if RequestAt[src] and now - RequestAt[src] < Config.RequestThrottle then return cb(false) end
    end
    RequestAt[src] = now

    local meta = Player.PlayerData.metadata
    if meta.isdead or (meta.injail or 0) > 0 then return cb(false) end

    local cid = Player.PlayerData.citizenid
    if not Config.Debug and Cooldowns[cid] and Cooldowns[cid] > now then return cb(false) end

    local region = getRegion(src)

    -- the roll happens here, so a modified client can't skip it. Debug mode (server-side only) always hits.
    if not Config.Debug then
        local chance = Config.TriggerChance * chanceMultiplier(src, region)
        if math.random() * 100.0 >= chance then return cb(false) end
    end

    local gangKey = pickGang(region)
    if not gangKey then return cb(false) end
    local gang = Config.Gangs[gangKey]

    local count = math.random(gang.count[1], gang.count[2]) + extraBandits(src)

    local wave
    local r = gang.reinforcements
    if r and math.random(1, 100) <= r.chance then
        wave = { count = math.random(r.count[1], r.count[2]), delay = math.floor(tonumber(r.delay) or 45) }
    end

    local id = ('%d:%d'):format(src, now)
    Ambushes[src] = {
        id = id, cid = cid, gang = gangKey, count = count, wave = wave, region = region,
        started = now, peds = {}, horses = {}, cash = 0, bounty = 0, bodies = 0,
        previousCooldown = Cooldowns[cid],
    }
    Cooldowns[cid] = now + Config.PlayerCooldown

    if SvConfig.Log.AmbushStart then
        SendLog('Ambush', locale('log_start_title'), SvConfig.Colours.start, src,
            locale('log_start_desc', locale('gang_' .. gangKey)))
    end
    return cb({ id = id, gang = gangKey, count = count, wave = wave, region = region })
end)

-- client reports the network ids of the bandits (and their horses) it spawned.
-- batch 1 = the first group, batch 2 = reinforcements (only when the server planned a wave)
RegisterNetEvent('rsg-ambush:server:registerPeds', function(id, netIds, horseNetIds, batch)
    local src = source
    local amb = getAmbush(src, id)
    if not amb then return end

    local limit
    if batch == 2 then
        if not amb.wave or amb.waveRegistered or not amb.registered or os.time() - amb.started < WAVE_MIN_SECONDS then
            SecurityLog(src, locale('sec_double_register'))
            return
        end
        amb.waveRegistered = true
        limit = amb.wave.count
    else
        if amb.registered then
            SecurityLog(src, locale('sec_double_register'))
            return
        end
        amb.registered = true -- only one registration per batch
        limit = amb.count
    end

    local deadline = GetGameTimer() + REGISTER_TIMEOUT
    local firstBatch = {}
    registerList(src, amb, netIds, GangModels[amb.gang], limit, deadline, function(netId)
        amb.peds[netId] = false
        firstBatch[#firstBatch + 1] = netId
    end)
    registerList(src, amb, horseNetIds, HorseModels, limit, deadline, function(netId) amb.horses[#amb.horses + 1] = netId end)

    -- the strongbox: one of the first group carries it, only the server knows which
    if batch ~= 2 and Strongbox.chance > 0 and #firstBatch > 0 and Ambushes[src] == amb
        and math.random() * 100.0 < Strongbox.chance then
        amb.strongbox = firstBatch[math.random(#firstBatch)]
    end
end)

RegisterNetEvent('rsg-ambush:server:finish', function(id, aborted)
    local src = source
    local amb = getAmbush(src, id)
    if not amb then return end
    endAmbush(src)
    -- the client could not even place the gang (no safe ground): don't burn the player's cooldown
    if aborted == true and not amb.registered and amb.cid then
        Cooldowns[amb.cid] = amb.previousCooldown
        return
    end
    if SvConfig.Log.AmbushEnd then
        SendLog('Ambush', locale('log_end_title'), SvConfig.Colours.finish, src, nil, {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_duration'), value = locale('log_seconds', os.time() - amb.started), inline = true },
            { name = locale('log_field_bodies'), value = tostring(amb.bodies), inline = true },
            { name = locale('log_field_cash_paid'), value = locale('log_money', amb.cash + amb.bounty), inline = true },
        })
    end
end)

---------------------------------------------------------------------
-- Beating the gang: bounty, honor, standing and skill XP (all decided here, paid once)
---------------------------------------------------------------------
local function countBandits(amb)
    local total, dead, alive = 0, 0, 0
    for netId in pairs(amb.peds) do
        total = total + 1
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            if GetEntityHealth(ent) <= 0 then dead = dead + 1 else alive = alive + 1 end
        end
    end
    return total, dead, alive
end

local function bountyMultiplier(Player)
    local job = Player.PlayerData.job
    if not job or not job.onduty then return 1.0 end
    local m = Config.Bounty.JobMultipliers or {}
    return tonumber(m[job.name] or m[job.type]) or 1.0
end

RegisterNetEvent('rsg-ambush:server:claimWin', function(id)
    local src = source
    local amb = getAmbush(src, id)
    if not amb or amb.won or amb.claiming or not amb.registered then return end
    if amb.wave and not amb.waveRegistered then return end -- reinforcements still on their way
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    amb.claiming = true
    -- the bandits' health can lag a moment behind the client, so look again for a few seconds
    local total, dead, alive, need = 0, 0, 0, 1
    for _ = 1, 6 do
        total, dead, alive = countBandits(amb)
        need = math.max(1, math.ceil(total * (tonumber(Config.Rewards.MinKilledPct) or 50) / 100))
        if total > 0 and dead >= need then break end
        Wait(500)
        if Ambushes[src] ~= amb then return end
    end
    if total == 0 or dead < need then
        amb.claiming = false
        return
    end
    amb.won = true

    local gang = Config.Gangs[amb.gang]

    -- bounty: cash for every killed bandit, doubled for on-duty lawmen etc. (Config.Bounty.JobMultipliers)
    local bounty = 0
    if Config.Bounty.Enabled then
        local range = validRange(gang.bounty, 0) and gang.bounty or Config.Bounty.PerBandit
        for _ = 1, dead do bounty = bounty + math.random(range.min, range.max) end
        bounty = math.floor(bounty * bountyMultiplier(Player))
        if bounty > 0 and Player.Functions.AddMoney('cash', bounty, 'rsg-ambush-bounty') then
            amb.bounty = bounty
            notify(src, locale('bounty_title'), locale('bounty_paid', bounty), 'success')
        else
            bounty = 0
        end
    end

    -- bandits left alive (surrendered or ran off) earn a little mercy honor
    local spared = math.min(alive, tonumber(Config.Rewards.MercyMax) or 0)
    local honor = (tonumber(Config.Rewards.Honor) or 0) + spared * (tonumber(Config.Rewards.MercyHonor) or 0)
    if honor ~= 0 then callExport('rsg-reputation', 'AddHonor', src, honor, 'ambush_gang_defeated') end
    if amb.region and (tonumber(Config.Rewards.Standing) or 0) ~= 0 then
        callExport('rsg-reputation', 'AddStanding', src, amb.region, Config.Rewards.Standing, 'ambush_gang_defeated')
    end
    local skill = Config.Rewards.Skill
    if skill and skill.name and (tonumber(skill.xp) or 0) > 0 then
        callExport('rsg-skills', 'AddXP', src, skill.name, skill.xp, 'rsg-ambush')
    end

    if SvConfig.Log.AmbushEnd then
        SendLog('Ambush', locale('log_won_title'), SvConfig.Colours.finish, src, nil, {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_killed'), value = ('%d / %d'):format(dead, total), inline = true },
            { name = locale('log_field_spared'), value = tostring(alive), inline = true },
            { name = locale('log_field_bounty'), value = locale('log_money', bounty), inline = true },
        })
    end
end)

---------------------------------------------------------------------
-- Looting a bandit (all validation server side)
---------------------------------------------------------------------
-- rolls an item list into the player's inventory; returns whether anything was added and whether space ran out
local function giveItems(src, list, itemLines)
    local gotItem, invFull = false, false
    for _, l in ipairs(list) do
        local shared = RSGCore.Shared.Items[l.item]
        if not shared then
            if not WarnedItems[l.item] then
                WarnedItems[l.item] = true
                warn('loot item "%s" does not exist in the shared items and is never given', l.item)
            end
        elseif math.random(1, 100) <= l.chance then
            local amt = math.random(l.min, l.max)
            if exports['rsg-inventory']:CanAddItem(src, l.item, amt) then
                -- AddItem shows the ItemBox itself
                if exports['rsg-inventory']:AddItem(src, l.item, amt, nil, nil, 'rsg-ambush-loot') then
                    gotItem = true
                    itemLines[#itemLines + 1] = ('%dx %s'):format(amt, shared.label or l.item)
                end
            else
                invFull = true
            end
        end
    end
    return gotItem, invFull
end

RSGCore.Functions.CreateCallback('rsg-ambush:server:loot', function(src, cb, id, netId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local now = GetGameTimer()
    if LootCD[src] and now - LootCD[src] < LOOT_RATE_MS then return cb(false) end
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
    if not GangModels[amb.gang][GetEntityModel(ent)] then
        SecurityLog(src, locale('sec_loot_wrong_ped'), locale('sec_netid', netId))
        return cb(false)
    end
    if GetEntityHealth(ent) > 0 then return cb(false) end

    local maxDist = Config.LootDistance + 2.0
    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent))
    if dist > maxDist then
        SecurityLog(src, locale('sec_loot_far'), locale('sec_distance', ('%.1f'):format(dist), ('%.1f'):format(maxDist)))
        return cb(false)
    end

    amb.peds[netId] = true

    -- this gang's own loot table, or the global one
    local gl = GangLoot[amb.gang] or {}
    local cashRange = gl.cash or LootCash
    local cash = cashRange.max > 0 and math.random(cashRange.min, cashRange.max) or 0
    local itemLines = {}
    local gotItem, invFull = giveItems(src, gl.items or LootItems, itemLines)

    -- the strongbox
    local box = amb.strongbox == netId
    if box then
        amb.strongbox = nil
        cash = cash + (Strongbox.cash.max > 0 and math.random(Strongbox.cash.min, Strongbox.cash.max) or 0)
        local boxFull
        local boxGot
        boxGot, boxFull = giveItems(src, Strongbox.items, itemLines)
        gotItem = gotItem or boxGot
        invFull = invFull or boxFull
    end

    if cash > 0 then Player.Functions.AddMoney('cash', cash, box and 'rsg-ambush-strongbox' or 'rsg-ambush-loot') end

    if box then
        notify(src, locale('loot_title'), locale('loot_strongbox', cash), 'success')
    elseif cash > 0 then
        notify(src, locale('loot_title'), locale('loot_cash', cash), 'success')
    end
    if invFull then
        notify(src, locale('loot_title'), locale('loot_full'), 'error')
    end
    amb.cash = amb.cash + cash
    amb.bodies = amb.bodies + 1
    if SvConfig.Log.Loot then
        local fields = {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_cash'), value = locale('log_money', cash), inline = true },
            { name = locale('log_field_items'), value = #itemLines > 0 and table.concat(itemLines, '\n') or locale('log_none'), inline = true },
        }
        if box then fields[#fields + 1] = { name = locale('log_field_strongbox'), value = locale('log_money', cash), inline = true } end
        SendLog('Loot', locale('log_loot_title'), SvConfig.Colours.loot, src, nil, fields)
    end

    cb((cash > 0 or gotItem) and 'ok' or 'empty')
end)

---------------------------------------------------------------------
-- Housekeeping
---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local amb = endAmbush(src) -- also removes the bandits the disconnected client can no longer clean up
    if amb and SvConfig.Log.AmbushEnd then
        SendLog('Ambush', locale('log_left_title'), SvConfig.Colours.finish, nil,
            locale('log_left_desc', GetPlayerName(src) or locale('log_unknown'), src), {
            { name = locale('log_field_gang'), value = locale('gang_' .. amb.gang), inline = true },
            { name = locale('log_field_bodies'), value = tostring(amb.bodies), inline = true },
            { name = locale('log_field_cash_paid'), value = locale('log_money', amb.cash + amb.bounty), inline = true },
        })
    end
    LootCD[src] = nil
    RequestAt[src] = nil
end)

-- expire ambushes whose client never reported back, and forget finished cooldowns
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for src, amb in pairs(Ambushes) do
            if now - amb.started > AMBUSH_TTL then endAmbush(src) end
        end
        for cid, untilTime in pairs(Cooldowns) do
            if untilTime <= now then Cooldowns[cid] = nil end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Ambushes) do endAmbush(src) end
end)

if Config.Debug then
    RSGCore.Commands.Add('testambush', locale('cmd_testambush_help'), {}, false, function(source)
        TriggerClientEvent('rsg-ambush:client:force', source)
    end, 'admin')
end
