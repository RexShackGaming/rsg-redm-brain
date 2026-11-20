local RSGCore = exports['rsg-core']:GetCoreObject()
-- Activity log viewer, territories, upkeep and member map blips.
local Territories = {} -- [territoryId] = gangName

-- Drop territory entries that cannot work, with a console warning.
do
    local list, seen, valid = (Config.Territories and Config.Territories.list) or {}, {}, {}
    for i, t in ipairs(list) do
        local ok = type(t.id) == 'string' and not seen[t.id] and type(t.label) == 'string'
            and t.coords and RSGGangs.ValidCoords(t.coords) and type(t.radius) == 'number' and t.radius > 0
        if ok then seen[t.id] = true valid[#valid + 1] = t
        else print(('^3[rsg-gangs] Config.Territories.list[%d] is invalid or duplicated and was ignored^7'):format(i)) end
    end
    if Config.Territories then Config.Territories.list = valid end
end

local function territoryCfg(id)
    for _, t in ipairs((Config.Territories and Config.Territories.list) or {}) do
        if t.id == id then return t end
    end
end

local function gangLabel(name)
    local g = RSGGangs.Gangs[name]
    return g and g.label or nil
end

local function ownedCount(gangName)
    local n = 0
    for _, owner in pairs(Territories) do
        if owner == gangName then n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------
-- Territories
---------------------------------------------------------------------
local function registry()
    local out = {}
    for _, t in ipairs((Config.Territories and Config.Territories.list) or {}) do
        local owner = Territories[t.id]
        out[#out + 1] = {
            id = t.id, label = t.label, x = t.coords.x, y = t.coords.y, z = t.coords.z,
            radius = t.radius, owner = owner, ownerLabel = owner and gangLabel(owner) or nil,
        }
    end
    return out
end

local function pushRegistry(target)
    if not (Config.Territories and Config.Territories.enabled) then return end
    TriggerClientEvent('rsg-gangs:client:territories', target or -1, registry())
end

function RSGGangs.TerritoryPayload(gang)
    if not (Config.Territories and Config.Territories.enabled) then return nil end
    local out = {}
    for _, t in ipairs(Config.Territories.list or {}) do
        local owner = Territories[t.id]
        out[#out + 1] = {
            id = t.id, label = t.label, income = t.income, claimCost = t.claimCost,
            owner = owner, ownerLabel = owner and gangLabel(owner) or nil,
            ownerHonor = owner and RSGGangs.Gangs[owner] and RSGGangs.Gangs[owner].honorAvg or nil,
            mine = owner == gang.name,
        }
    end
    return out
end

local function loadTerritories()
    if not (Config.Territories and Config.Territories.enabled) then return end
    local rows = MySQL.query.await('SELECT territory_id, gang_name FROM rsg_gang_territories') or {}
    for _, row in ipairs(rows) do
        if territoryCfg(row.territory_id) then Territories[row.territory_id] = row.gang_name end
    end
end

function RSGGangs.OnGangDestroyed(gang)
    if RSGGangs.ClearRivals then RSGGangs.ClearRivals(gang.name) end
    local changed = false
    for id, owner in pairs(Territories) do
        if owner == gang.name then Territories[id] = nil changed = true end
    end
    if changed then pushRegistry() end
end

RegisterNetEvent('rsg-gangs:server:requestTerritories', function()
    pushRegistry(source)
end)

local function memberContext(src, permission)
    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return end
    local gang = RSGGangs.FindGangByMember(citizenid)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end
    if permission and not RSGGangs.HasPermission(gang.members[citizenid].rank, permission) then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end
    return gang, citizenid
end

RegisterNetEvent('rsg-gangs:server:claimTerritory', function(id)
    local src = source
    if not (Config.Territories and Config.Territories.enabled) then return end
    if type(id) ~= 'string' or RSGGangs.OnCooldown(src, 'territory', 1500) then return end
    local t = territoryCfg(id)
    if not t then return end
    local gang, citizenid = memberContext(src, 'upgrade')
    if not gang then return end

    if Territories[id] then RSGGangs.Notify(src, locale('error_territory_owned'), 'error') return end
    if not RSGGangs.IsNear(src, t.coords, t.radius) then RSGGangs.Notify(src, locale('error_territory_far'), 'error') return end
    if ownedCount(gang.name) >= (Config.Territories.maxPerGang or 1) then
        RSGGangs.Notify(src, locale('error_territory_max', Config.Territories.maxPerGang or 1), 'error')
        return
    end
    if gang.bank < (t.claimCost or 0) then RSGGangs.Notify(src, locale('error_insufficient_gang_funds'), 'error') return end

    -- Reserve it first so two gangs claiming at once cannot both win.
    Territories[id] = gang.name
    local inserted = MySQL.insert.await('INSERT IGNORE INTO rsg_gang_territories (territory_id, gang_name) VALUES (?, ?)', { id, gang.name })
    if not inserted then
        Territories[id] = nil
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    if (t.claimCost or 0) > 0 and not RSGGangs.AdjustBank(gang, -t.claimCost) then
        Territories[id] = nil
        MySQL.update.await('DELETE FROM rsg_gang_territories WHERE territory_id = ?', { id })
        RSGGangs.Notify(src, locale('error_insufficient_gang_funds'), 'error')
        return
    end

    if Config.Reputation and Config.Reputation.enabled and GetResourceState('rsg-reputation') == 'started' then
        pcall(function() exports['rsg-reputation']:ApplyAction(src, Config.Reputation.claimAction, t.region) end)
    end
    RSGGangs.AddLog(gang, citizenid, 'territory_claim', t.label, t.claimCost or 0)
    RSGGangs.Log('Territory claimed', ('%s claimed %s'):format(gang.name, id))
    RSGGangs.Notify(src, locale('success_territory_claimed', t.label), 'success')
    pushRegistry()
    RSGGangs.BroadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:abandonTerritory', function(id)
    local src = source
    if not (Config.Territories and Config.Territories.enabled) then return end
    if type(id) ~= 'string' or RSGGangs.OnCooldown(src, 'territory', 1500) then return end
    local t = territoryCfg(id)
    if not t then return end
    local gang, citizenid = memberContext(src, 'upgrade')
    if not gang then return end
    if Territories[id] ~= gang.name then return end

    if not RSGGangs.DbOk('DELETE FROM rsg_gang_territories WHERE territory_id = ?', { id }) then
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    Territories[id] = nil
    RSGGangs.AddLog(gang, citizenid, 'territory_abandon', t.label)
    RSGGangs.Notify(src, locale('success_territory_abandoned', t.label), 'success')
    pushRegistry()
    RSGGangs.BroadcastGangUpdate(gang)
end)

local function onlineMemberCount(gang)
    local n = 0
    for _, m in pairs(gang.members) do
        if m.source then n = n + 1 end
    end
    return n
end

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    loadTerritories()
    if not (Config.Territories and Config.Territories.enabled) then return end
    pushRegistry()
    local interval = math.max(1, Config.Territories.incomeIntervalMinutes or 30) * 60000
    while true do
        Wait(interval)
        local paid = {}
        for id, owner in pairs(Territories) do
            local gang, t = RSGGangs.Gangs[owner], territoryCfg(id)
            if gang and t and (t.income or 0) > 0
                and (not Config.Territories.requireOnlineMember or onlineMemberCount(gang) > 0) then
                if RSGGangs.AdjustBank(gang, t.income) then
                    RSGGangs.AddLog(gang, nil, 'territory_income', t.label, t.income)
                    paid[gang.name] = gang
                end
            end
        end
        for _, gang in pairs(paid) do RSGGangs.BroadcastGangUpdate(gang) end
    end
end)

---------------------------------------------------------------------
-- Upkeep
---------------------------------------------------------------------
function RSGGangs.UpkeepPayload(gang)
    local cfg = Config.Upkeep
    if not (cfg and cfg.enabled) then return nil end
    return { cost = cfg.cost, due = gang.upkeepDue, missed = gang.upkeepMissed or 0, maxMissed = cfg.maxMissed }
end

local function notifyGang(gang, text, kind)
    for _, m in pairs(gang.members) do
        if m.source then RSGGangs.Notify(m.source, text, kind) end
    end
end

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local cfg = Config.Upkeep
    if not (cfg and cfg.enabled) then return end
    local period = math.max(1, cfg.intervalHours or 168) * 3600
    while true do
        local now = os.time()
        for _, gang in pairs(RSGGangs.Gangs) do
            if not gang.upkeepDue then
                gang.upkeepDue = now + period
                RSGGangs.DbOk('UPDATE rsg_gangs SET upkeep_due = ? WHERE name = ?', { gang.upkeepDue, gang.name })
            elseif gang.upkeepDue <= now then
                if RSGGangs.AdjustBank(gang, -cfg.cost) then
                    gang.upkeepMissed = 0
                    RSGGangs.AddLog(gang, nil, 'upkeep_paid', cfg.cost)
                    notifyGang(gang, locale('notify_upkeep_paid', cfg.cost), 'inform')
                else
                    gang.upkeepMissed = (gang.upkeepMissed or 0) + 1
                    if gang.upkeepMissed >= (cfg.maxMissed or 3) then
                        RSGGangs.Log('Gang disbanded (upkeep)', gang.name)
                        RSGGangs.DestroyGang(gang, 'notify_upkeep_disbanded', 'error')
                        goto continue
                    end
                    RSGGangs.AddLog(gang, nil, 'upkeep_missed', gang.upkeepMissed, cfg.maxMissed or 3)
                    notifyGang(gang, locale('notify_upkeep_missed', cfg.cost, gang.upkeepMissed, cfg.maxMissed or 3), 'warning')
                end
                gang.upkeepDue = now + period
                RSGGangs.DbOk('UPDATE rsg_gangs SET upkeep_due = ?, upkeep_missed = ? WHERE name = ?',
                    { gang.upkeepDue, gang.upkeepMissed or 0, gang.name })
                RSGGangs.BroadcastGangUpdate(gang)
            end
            ::continue::
        end
        Wait(60 * 1000)
    end
end)

---------------------------------------------------------------------
-- Activity log (read + prune)
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:requestLogs', function()
    local src = source
    local cfg = Config.ActivityLog
    if not (cfg and cfg.enabled) or RSGGangs.OnCooldown(src, 'logs', 2000) then return end
    local gang, citizenid = memberContext(src)
    if not gang then return end
    if RSGGangs.RankWeight(gang.members[citizenid].rank) < (cfg.minWeight or 0) then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end
    local rows = MySQL.query.await(
        'SELECT actor, action, detail, UNIX_TIMESTAMP(created_at) AS ts FROM rsg_gang_logs WHERE gang_name = ? ORDER BY id DESC LIMIT ?',
        { gang.name, cfg.show or 50 }) or {}
    TriggerClientEvent('rsg-gangs:client:logs', src, rows)
end)

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local cfg = Config.ActivityLog
    if not (cfg and cfg.enabled) then return end
    while true do
        for name in pairs(RSGGangs.Gangs) do
            pcall(MySQL.update.await, [[
                DELETE FROM rsg_gang_logs WHERE gang_name = ? AND id <= (
                    SELECT id FROM (SELECT id FROM rsg_gang_logs WHERE gang_name = ? ORDER BY id DESC LIMIT 1 OFFSET ?) t)
            ]], { name, name, cfg.keep or 200 })
        end
        Wait(30 * 60 * 1000)
    end
end)

---------------------------------------------------------------------
-- Member map blips: each member only receives their own gang's online members.
---------------------------------------------------------------------
local blipsOff = {} -- [src] = true, filled by the preference event at the end of this file

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local cfg = Config.MemberBlips
    if not (cfg and cfg.enabled) then return end
    local interval = math.max(1000, cfg.interval or 3000)
    while true do
        for _, gang in pairs(RSGGangs.Gangs) do
            local list, online = {}, {}
            for _, m in pairs(gang.members) do
                if m.source and not blipsOff[m.source] then
                    online[#online + 1] = m.source
                    local c = RSGGangs.PlayerCoords(m.source)
                    if c then list[#list + 1] = { id = m.source, name = m.name or '?', x = c.x, y = c.y, z = c.z } end
                end
            end
            local live = RSGGangs.WagonLiveCoords and RSGGangs.WagonLiveCoords(gang.name)
            local wagon = live and { x = live.x, y = live.y, z = live.z }
                or gang.wagon and { x = gang.wagon.x, y = gang.wagon.y, z = gang.wagon.z } or nil
            if #online > 1 or wagon then
                for _, src in ipairs(online) do
                    local others = {}
                    for _, e in ipairs(list) do
                        if e.id ~= src then others[#others + 1] = e end
                    end
                    TriggerClientEvent('rsg-gangs:client:memberBlips', src, others, wagon)
                end
                gang.blipsCleared = nil
            elseif not gang.blipsCleared then
                for _, src in ipairs(online) do TriggerClientEvent('rsg-gangs:client:memberBlips', src, {}, nil) end
                gang.blipsCleared = true
            end
        end
        Wait(interval)
    end
end)

---------------------------------------------------------------------
-- Gang honor (average of the members' rsg-reputation honor, shown in the UI)
---------------------------------------------------------------------
CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local cfg = Config.Reputation
    if not (cfg and cfg.enabled) then return end
    while true do
        if GetResourceState('rsg-reputation') == 'started' then
            for _, gang in pairs(RSGGangs.Gangs) do
                local sum, n = 0, 0
                for citizenid in pairs(gang.members) do
                    local ok, honor = pcall(function() return exports['rsg-reputation']:GetHonorByCitizenId(citizenid) end)
                    if ok and type(honor) == 'number' then sum, n = sum + honor, n + 1 end
                end
                gang.honorAvg = n > 0 and math.floor(sum / n + 0.5) or nil
            end
        end
        Wait((cfg.refreshMinutes or 5) * 60000)
    end
end)

---------------------------------------------------------------------
-- Gang bounties: the gang escrows money and names a target (one player, or a rival gang);
-- rsg-bountyhunter lists the poster on every board and pays the hunter who brings the target in.
---------------------------------------------------------------------
local Bounties = {} -- [ref] = { id, gang, reward, targetType, targetKey, targetLabel }
local posting = {}  -- [gangName] = true while a bounty is being posted (the escrow awaits the database)

function RSGGangs.BountyPayload(gang)
    local cfg = Config.Bounties
    if not (cfg and cfg.enabled) or GetResourceState('rsg-bountyhunter') ~= 'started' then return nil end
    local list, total = {}, 0
    for _, b in pairs(Bounties) do
        if b.gang == gang.name then
            list[#list + 1] = { type = b.targetType, target = b.targetLabel, reward = b.reward }
            total = total + b.reward
        end
    end
    return {
        min = cfg.minReward, max = cfg.maxReward, maxActive = cfg.maxActive,
        active = #list, total = total, list = list,
        players = cfg.targetPlayers ~= false, gangs = cfg.targetGangs ~= false,
    }
end

local function settleBounty(ref, refund)
    local b = Bounties[ref]
    if not b then return end
    Bounties[ref] = nil
    MySQL.update.await('DELETE FROM rsg_gang_bounties WHERE id = ?', { b.id })
    local gang = RSGGangs.Gangs[b.gang]
    if gang and refund > 0 then
        RSGGangs.AdjustBank(gang, refund)
        RSGGangs.AddLog(gang, nil, 'bounty_refund', refund)
        notifyGang(gang, locale('notify_bounty_refund', refund), 'inform')
    end
    if gang then RSGGangs.BroadcastGangUpdate(gang) end
end

-- Server-only event from rsg-bountyhunter (not a net event, clients cannot fire it).
AddEventHandler('rsg-bountyhunter:server:posterClosed', function(ref, reason, paid)
    local b = Bounties[ref]
    if not b then return end
    if reason == 'completed' then
        local gang = RSGGangs.Gangs[b.gang]
        if gang then
            RSGGangs.AddLog(gang, nil, 'bounty_paid', tonumber(paid) or 0)
            notifyGang(gang, locale('notify_bounty_done', tonumber(paid) or 0), 'inform')
        end
        settleBounty(ref, math.max(0, b.reward - (tonumber(paid) or 0))) -- dead pays less, the rest comes back
    else
        settleBounty(ref, b.reward)
    end
end)

-- Target lists for the gang UI dropdown: players are listed by character name and sent as server ids,
-- gangs by label and sent as gang names. The server re-validates the pick when the bounty is posted.
RSGCore.Functions.CreateCallback('rsg-gangs:server:bountyTargets', function(src, cb, kind)
    local cfg = Config.Bounties
    if not (cfg and cfg.enabled) or RSGGangs.OnCooldown(src, 'bountyTargets', 800) then cb({}) return end
    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    local gang = citizenid and RSGGangs.FindGangByMember(citizenid)
    if not gang or not RSGGangs.HasPermission(gang.members[citizenid].rank, 'bounty') then cb({}) return end

    local out = {}
    if kind == 'player' and cfg.targetPlayers ~= false then
        for psrc, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
            local cid = P.PlayerData.citizenid
            if psrc ~= src and cid and not gang.members[cid] then
                out[#out + 1] = { value = psrc, label = RSGGangs.CharName(P) }
            end
        end
    elseif kind == 'gang' and cfg.targetGangs ~= false then
        for name, g in pairs(RSGGangs.Gangs) do
            if name ~= gang.name then out[#out + 1] = { value = name, label = g.label } end
        end
    end
    table.sort(out, function(x, y) return tostring(x.label):lower() < tostring(y.label):lower() end)
    cb(out)
end)

local function postBounty(src, gang, citizenid, amount, targetType, targetId)
    local cfg = Config.Bounties
    local opts = { sponsorGang = gang.name }
    local targetKey, targetLabel

    if targetType == 'player' then
        if cfg.targetPlayers == false then return end
        local tsrc = tonumber(targetId)
        local TPlayer = tsrc and RSGCore.Functions.GetPlayer(tsrc)
        if not TPlayer or tsrc == src then RSGGangs.Notify(src, locale('error_bounty_target'), 'error') return end
        local tcid = TPlayer.PlayerData.citizenid
        if gang.members[tcid] then RSGGangs.Notify(src, locale('error_bounty_own'), 'error') return end
        targetKey, targetLabel = 'p:' .. tcid, RSGGangs.CharName(TPlayer)
        opts.targetCitizenid, opts.targetName = tcid, targetLabel
    else
        if cfg.targetGangs == false then return end
        local tg = type(targetId) == 'string' and RSGGangs.Gangs[targetId] or nil
        if not tg then RSGGangs.Notify(src, locale('error_bounty_target'), 'error') return end
        if tg.name == gang.name then RSGGangs.Notify(src, locale('error_bounty_own'), 'error') return end
        targetKey, targetLabel = 'g:' .. tg.name, tg.label
        opts.targetGang, opts.targetName = tg.name, locale('bounty_target_gang', tg.label)
    end

    local active = 0
    for _, b in pairs(Bounties) do
        if b.gang == gang.name then
            active = active + 1
            if b.targetKey == targetKey then RSGGangs.Notify(src, locale('error_bounty_duplicate'), 'error') return end
        end
    end
    if active >= cfg.maxActive then RSGGangs.Notify(src, locale('error_bounty_max', cfg.maxActive), 'error') return end
    if gang.bank < amount then RSGGangs.Notify(src, locale('error_insufficient_gang_funds'), 'error') return end

    if not RSGGangs.AdjustBank(gang, -amount) then RSGGangs.Notify(src, locale('error_generic'), 'error') return end
    local id = MySQL.insert.await(
        'INSERT INTO rsg_gang_bounties (gang_name, reward, target_type, target_id, target_name) VALUES (?, ?, ?, ?, ?)',
        { gang.name, amount, targetType, opts.targetCitizenid or opts.targetGang, targetLabel })
    local ref = id and ('gb:' .. id) or nil
    local posted, posterId = false, nil
    if ref then
        opts.ref, opts.reward, opts.sponsor = ref, amount, gang.label
        opts.expireMinutes = (cfg.expireHours or 6) * 60
        posted, posterId = pcall(function() return exports['rsg-bountyhunter']:PostBounty(opts) end)
    end
    if not posted or not posterId then
        RSGGangs.AdjustBank(gang, amount) -- give the escrow back
        if id then MySQL.update.await('DELETE FROM rsg_gang_bounties WHERE id = ?', { id }) end
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    Bounties[ref] = { id = id, gang = gang.name, reward = amount, targetType = targetType, targetKey = targetKey, targetLabel = targetLabel }
    RSGGangs.AddLog(gang, citizenid, 'bounty_post', amount)
    RSGGangs.Log('Gang bounty', ('%s posted $%s on %s (%s)'):format(gang.name, amount, targetLabel, targetType))
    RSGGangs.Notify(src, locale('success_bounty_posted', amount, targetLabel), 'success')
    RSGGangs.BroadcastGangUpdate(gang)
end

RegisterNetEvent('rsg-gangs:server:postBounty', function(amount, targetType, targetId)
    local src = source
    local cfg = Config.Bounties
    if not (cfg and cfg.enabled) or RSGGangs.OnCooldown(src, 'bounty', 2000) then return end
    if GetResourceState('rsg-bountyhunter') ~= 'started' then return end
    if targetType ~= 'player' and targetType ~= 'gang' then return end
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount < cfg.minReward or amount > cfg.maxReward then
        RSGGangs.Notify(src, locale('error_bounty_amount', cfg.minReward, cfg.maxReward), 'error')
        return
    end
    local gang, citizenid = memberContext(src, 'bounty')
    if not gang or posting[gang.name] then return end

    posting[gang.name] = true
    local ok, err = pcall(postBounty, src, gang, citizenid, amount, targetType, targetId)
    posting[gang.name] = nil
    if not ok then print(('^1[rsg-gangs] postBounty failed: %s^7'):format(tostring(err))) end
end)

-- Online members of a gang (server ids), for rsg-bountyhunter's gang-targeted bounties.
exports('GetGangOnlineSources', function(gangName)
    local gang = RSGGangs.Gangs[gangName]
    if not gang then return {} end
    local out = {}
    for _, m in pairs(gang.members) do
        if m.source then out[#out + 1] = m.source end
    end
    return out
end)

-- The board lives in rsg-bountyhunter's memory, so escrow left over from before a restart is returned.
CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local rows = MySQL.query.await('SELECT id, gang_name, reward FROM rsg_gang_bounties') or {}
    for _, row in ipairs(rows) do
        local gang = RSGGangs.Gangs[row.gang_name]
        if gang then RSGGangs.AdjustBank(gang, row.reward) end
        MySQL.update.await('DELETE FROM rsg_gang_bounties WHERE id = ?', { row.id })
    end
end)

---------------------------------------------------------------------
-- Rivalries: confirmed player kills between members of different gangs (rsg-core OnPlayerKilled)
---------------------------------------------------------------------
local Rivals = {}      -- [gang][rival] = kills the gang made against the rival
local pairCooldown = {} -- [killerCid .. ':' .. victimCid] = os.time()

function RSGGangs.ClearRivals(name)
    Rivals[name] = nil
    for _, map in pairs(Rivals) do map[name] = nil end
end

function RSGGangs.RivalPayload(gang)
    if not (Config.Rivalry and Config.Rivalry.enabled) then return nil end
    local out = {}
    local seen = {}
    for rival in pairs(Rivals[gang.name] or {}) do seen[rival] = true end
    for other, map in pairs(Rivals) do
        if map[gang.name] then seen[other] = true end
    end
    for rival in pairs(seen) do
        local g = RSGGangs.Gangs[rival]
        if g then
            out[#out + 1] = { label = g.label, kills = (Rivals[gang.name] or {})[rival] or 0, deaths = (Rivals[rival] or {})[gang.name] or 0 }
        end
    end
    table.sort(out, function(a, b) return (a.kills + a.deaths) > (b.kills + b.deaths) end)
    while #out > 8 do out[#out] = nil end
    return out
end

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    if not (Config.Rivalry and Config.Rivalry.enabled) then return end
    for _, row in ipairs(MySQL.query.await('SELECT gang_name, rival_name, kills FROM rsg_gang_rivals') or {}) do
        Rivals[row.gang_name] = Rivals[row.gang_name] or {}
        Rivals[row.gang_name][row.rival_name] = row.kills
    end
end)

AddEventHandler('RSGCore:Server:OnPlayerKilled', function(victim, killer)
    local cfg = Config.Rivalry
    if not (cfg and cfg.enabled) then return end
    local victimCid, killerCid = RSGGangs.GetPlayerCitizenId(victim), RSGGangs.GetPlayerCitizenId(killer)
    if not victimCid or not killerCid then return end
    local vGang, kGang = RSGGangs.FindGangByMember(victimCid), RSGGangs.FindGangByMember(killerCid)
    if not vGang or not kGang or vGang.name == kGang.name then return end

    -- the same killer farming the same victim only counts once per cooldown window
    local key, now = killerCid .. ':' .. victimCid, os.time()
    if pairCooldown[key] and now - pairCooldown[key] < (cfg.pairCooldownSeconds or 300) then return end
    pairCooldown[key] = now

    Rivals[kGang.name] = Rivals[kGang.name] or {}
    Rivals[kGang.name][vGang.name] = (Rivals[kGang.name][vGang.name] or 0) + 1
    MySQL.update('INSERT INTO rsg_gang_rivals (gang_name, rival_name, kills) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE kills = kills + 1',
        { kGang.name, vGang.name })

    local kName = kGang.members[killerCid] and kGang.members[killerCid].name or '?'
    local vName = vGang.members[victimCid] and vGang.members[victimCid].name or '?'
    RSGGangs.AddLog(kGang, killerCid, 'rival_kill', vName, vGang.label)
    RSGGangs.AddLog(vGang, victimCid, 'rival_death', kName, kGang.label)
    RSGGangs.BroadcastGangUpdate(kGang)
    RSGGangs.BroadcastGangUpdate(vGang)
end)

---------------------------------------------------------------------
-- Gang tags
---------------------------------------------------------------------
local function tagOf(src)
    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    local gang = citizenid and RSGGangs.FindGangByMember(citizenid)
    return gang and gang.tag or nil
end
exports('GetGangTag', tagOf) -- server id -> tag string or nil (for chat / name resources)

RegisterNetEvent('rsg-gangs:server:setTag', function(tag)
    local src = source
    local cfg = Config.Tags
    if not (cfg and cfg.enabled) or RSGGangs.OnCooldown(src, 'tag', 2000) then return end
    local gang, citizenid = memberContext(src, 'rename')
    if not gang then return end
    tag = type(tag) == 'string' and tag:upper():gsub('[^%w]', '') or ''
    if tag ~= '' and (#tag < cfg.minLength or #tag > cfg.maxLength) then
        RSGGangs.Notify(src, locale('error_tag_invalid', cfg.minLength, cfg.maxLength), 'error')
        return
    end
    local value = tag ~= '' and tag or nil
    if not RSGGangs.DbOk('UPDATE rsg_gangs SET tag = ? WHERE name = ?', { value, gang.name }) then
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    gang.tag = value
    RSGGangs.AddLog(gang, citizenid, 'tag', value or '-')
    RSGGangs.Notify(src, locale('success_tag_set', value or '-'), 'success')
    RSGGangs.BroadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- Discord webhook (server-only config in server/sv_config.lua)
---------------------------------------------------------------------
local hookQueue, hookBusy = {}, false

local function pumpHooks()
    if hookBusy then return end
    hookBusy = true
    CreateThread(function()
        while #hookQueue > 0 do
            local body = table.remove(hookQueue, 1)
            PerformHttpRequest(SvConfig.Webhook.Url, function() end, 'POST', json.encode(body), { ['Content-Type'] = 'application/json' })
            Wait(1500) -- stay well under Discord's rate limit
        end
        hookBusy = false
    end)
end

function RSGGangs.Webhook(gang, actor, action, parts)
    local cfg = SvConfig and SvConfig.Webhook
    if not (cfg and cfg.Enabled and cfg.Url and cfg.Url ~= '') then return end
    if cfg.Actions and not cfg.Actions[action] then return end
    if #hookQueue >= 50 then return end
    local ok, text = pcall(locale, 'log_' .. action, table.unpack(parts))
    if not ok then text = action end
    hookQueue[#hookQueue + 1] = {
        username = cfg.Name or 'rsg-gangs',
        allowed_mentions = { parse = {} }, -- gang labels are player text: never let them ping @everyone
        embeds = {{
            title = gang.label,
            description = (actor and (actor .. ': ') or '') .. text,
            color = tonumber((gang.color or '#e63946'):gsub('#', ''), 16) or 15083846,
        }},
    }
    pumpHooks()
end

---------------------------------------------------------------------
-- Turf raids: hold a rival's territory with more members than its defenders for holdSeconds
---------------------------------------------------------------------
local Raids = {}        -- [territoryId] = { attacker, defender, ends, held, startedBy }
local Protected = {}    -- [territoryId] = os.time() until which it cannot be raided
local RaidCooldown = {} -- [gangName] = os.time() until which the gang cannot start another raid

local function raidOf(gangName)
    for id, r in pairs(Raids) do
        if r.attacker == gangName then return id, r end
    end
end

local function membersInside(gang, t)
    local n = 0
    for _, m in pairs(gang.members) do
        if m.source and RSGGangs.IsNear(m.source, t.coords, t.radius) then n = n + 1 end
    end
    return n
end

local function endRaid(id)
    Raids[id] = nil
end

local function protectTerritory(id)
    local mins = Config.Raids and Config.Raids.protectMinutes or 0
    if mins > 0 then Protected[id] = os.time() + mins * 60 end
end

local oldOnGangDestroyed = RSGGangs.OnGangDestroyed
function RSGGangs.OnGangDestroyed(gang)
    oldOnGangDestroyed(gang)
    for id, r in pairs(Raids) do
        if r.attacker == gang.name or r.defender == gang.name then endRaid(id) end
    end
end

local oldTerritoryPayload = RSGGangs.TerritoryPayload
function RSGGangs.TerritoryPayload(gang)
    local list = oldTerritoryPayload(gang)
    if not list then return nil end
    local now = os.time()
    for _, row in ipairs(list) do
        local r = Raids[row.id]
        row.raidBy = r and gangLabel(r.attacker) or nil
        row.protected = Protected[row.id] and Protected[row.id] > now or false
        row.raidable = Config.Raids and Config.Raids.enabled or false
    end
    return list
end

RegisterNetEvent('rsg-gangs:server:startRaid', function(id)
    local src = source
    local cfg = Config.Raids
    if not (cfg and cfg.enabled and Config.Territories and Config.Territories.enabled) then return end
    if type(id) ~= 'string' or RSGGangs.OnCooldown(src, 'raid', 2000) then return end
    local t = territoryCfg(id)
    if not t then return end
    local gang, citizenid = memberContext(src, 'upgrade')
    if not gang then return end

    local owner = Territories[id]
    if not owner then RSGGangs.Notify(src, locale('error_raid_unowned'), 'error') return end
    if owner == gang.name then RSGGangs.Notify(src, locale('error_raid_own'), 'error') return end
    local defender = RSGGangs.Gangs[owner]
    if not defender then return end
    if Raids[id] or raidOf(gang.name) then RSGGangs.Notify(src, locale('error_raid_active'), 'error') return end
    if Protected[id] and Protected[id] > os.time() then RSGGangs.Notify(src, locale('error_raid_protected'), 'error') return end
    if RaidCooldown[gang.name] and RaidCooldown[gang.name] > os.time() then RSGGangs.Notify(src, locale('error_raid_cooldown'), 'error') return end
    if not RSGGangs.IsNear(src, t.coords, t.radius) then RSGGangs.Notify(src, locale('error_territory_far'), 'error') return end
    if cfg.requireDefenderOnline and onlineMemberCount(defender) < 1 then RSGGangs.Notify(src, locale('error_raid_no_defenders'), 'error') return end
    if membersInside(gang, t) < cfg.minAttackers then RSGGangs.Notify(src, locale('error_raid_attackers', cfg.minAttackers), 'error') return end

    Raids[id] = { attacker = gang.name, defender = owner, ends = os.time() + cfg.durationSeconds, held = 0 }
    RaidCooldown[gang.name] = os.time() + cfg.cooldownMinutes * 60
    RSGGangs.Log('Territory raid', ('%s started a raid on %s (%s)'):format(gang.name, id, owner))
    notifyGang(gang, locale('notify_raid_start_atk', t.label), 'inform')
    notifyGang(defender, locale('notify_raid_start_def', t.label, gang.label), 'warning')
    RSGGangs.BroadcastGangUpdate(gang)
    RSGGangs.BroadcastGangUpdate(defender)
end)

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local cfg = Config.Raids
    if not (cfg and cfg.enabled) then return end
    local step = 5
    while true do
        Wait(step * 1000)
        local now = os.time()
        for id, r in pairs(Raids) do
            local atk, def, t = RSGGangs.Gangs[r.attacker], RSGGangs.Gangs[r.defender], territoryCfg(id)
            if not (atk and def and t) or Territories[id] ~= r.defender then
                endRaid(id)
            else
                local a, d = membersInside(atk, t), membersInside(def, t)
                if a > 0 and a > d then r.held = r.held + step end
                if r.held >= cfg.holdSeconds then
                    Territories[id] = atk.name
                    RSGGangs.DbOk('UPDATE rsg_gang_territories SET gang_name = ?, claimed_at = NOW() WHERE territory_id = ?', { atk.name, id })
                    protectTerritory(id)
                    RSGGangs.AddLog(atk, nil, 'raid_won', t.label, def.label)
                    RSGGangs.AddLog(def, nil, 'raid_lost', t.label, atk.label)
                    notifyGang(atk, locale('notify_raid_won', t.label), 'success')
                    notifyGang(def, locale('notify_raid_lost', t.label, atk.label), 'error')
                    endRaid(id)
                    pushRegistry()
                    RSGGangs.BroadcastGangUpdate(atk)
                    RSGGangs.BroadcastGangUpdate(def)
                elseif r.ends <= now then
                    RSGGangs.AddLog(def, nil, 'raid_defended', t.label, atk.label)
                    notifyGang(def, locale('notify_raid_defended', t.label), 'success')
                    notifyGang(atk, locale('notify_raid_failed', t.label), 'error')
                    endRaid(id)
                    RSGGangs.BroadcastGangUpdate(atk)
                    RSGGangs.BroadcastGangUpdate(def)
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Leaderboard with an optional monthly reset of rivalry kills
---------------------------------------------------------------------
local function season() return os.date('%Y-%m') end

local function leaderboard()
    local cfg = Config.Leaderboard
    local rows = {}
    for name, gang in pairs(RSGGangs.Gangs) do
        local kills = 0
        for _, k in pairs(Rivals[name] or {}) do kills = kills + k end
        local turf = ownedCount(name)
        rows[#rows + 1] = { label = gang.label, tag = gang.tag, members = RSGGangs.MemberCount(gang),
            turf = turf, kills = kills, score = turf * cfg.turfPoints + kills * cfg.killPoints }
    end
    table.sort(rows, function(a, b) return a.score > b.score end)
    while #rows > cfg.size do rows[#rows] = nil end
    return rows
end

RegisterNetEvent('rsg-gangs:server:requestLeaderboard', function()
    local src = source
    if not (Config.Leaderboard and Config.Leaderboard.enabled) or RSGGangs.OnCooldown(src, 'top', 3000) then return end
    if not RSGGangs.FindGangByMember(RSGGangs.GetPlayerCitizenId(src) or '') then return end
    TriggerClientEvent('rsg-gangs:client:leaderboard', src, { season = season(), rows = leaderboard() })
end)

CreateThread(function()
    while not RSGGangs.Loaded do Wait(1000) end
    local cfg = Config.Leaderboard
    if not (cfg and cfg.enabled and cfg.monthlyReset) then return end
    while true do
        local saved, now = GetResourceKvpString('rsg_gangs:season'), season()
        if saved and saved ~= now then
            MySQL.update.await('DELETE FROM rsg_gang_rivals')
            for k in pairs(Rivals) do Rivals[k] = nil end
            print(('^2[rsg-gangs] new season %s: rivalry kills reset^7'):format(now))
        end
        if saved ~= now then SetResourceKvp('rsg_gangs:season', now) end
        Wait(10 * 60 * 1000)
    end
end)

---------------------------------------------------------------------
-- Member blip preference (players can hide themselves from the map and stop receiving it)
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:setBlips', function(enabled)
    local src = source
    if RSGGangs.OnCooldown(src, 'blipPref', 500) then return end
    blipsOff[src] = enabled == false or nil
end)

AddEventHandler('playerDropped', function() blipsOff[source] = nil end)

---------------------------------------------------------------------
-- Staff panel helpers (used by server/admin.lua)
---------------------------------------------------------------------
RSGGangs.PushTerritories = pushRegistry

function RSGGangs.AdminTerritories()
    local out, now = {}, os.time()
    for _, t in ipairs((Config.Territories and Config.Territories.list) or {}) do
        local owner = Territories[t.id]
        local raid = Raids[t.id]
        out[#out + 1] = {
            id = t.id, label = t.label, owner = owner, ownerLabel = owner and gangLabel(owner) or nil,
            income = t.income or 0, claimCost = t.claimCost or 0,
            raidBy = raid and gangLabel(raid.attacker) or nil,
            protected = Protected[t.id] ~= nil and Protected[t.id] > now,
            x = t.coords.x, y = t.coords.y, z = t.coords.z,
        }
    end
    return out
end

-- Gives a territory to a gang, or frees it when gangName is nil. Returns true on success.
function RSGGangs.AdminSetTerritory(id, gangName)
    if not (Config.Territories and Config.Territories.enabled) or not territoryCfg(id) then return false end
    if gangName then
        if not RSGGangs.Gangs[gangName] then return false end
        if not RSGGangs.DbOk(
            'INSERT INTO rsg_gang_territories (territory_id, gang_name) VALUES (?, ?) ON DUPLICATE KEY UPDATE gang_name = VALUES(gang_name), claimed_at = NOW()',
            { id, gangName }) then return false end
        Territories[id] = gangName
    else
        if not RSGGangs.DbOk('DELETE FROM rsg_gang_territories WHERE territory_id = ?', { id }) then return false end
        Territories[id] = nil
    end
    endRaid(id)
    Protected[id] = nil
    pushRegistry()
    return true
end
