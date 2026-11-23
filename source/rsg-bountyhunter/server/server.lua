local RSGCore = exports['rsg-core']:GetCoreObject()

local Board = {}         -- [posterId] = poster
local Contracts = {}     -- [src] = { poster, cid, expires, warned, netId, foundAt, missing }
local Cooldowns = {}     -- [citizenid] = os.time() when the next accept is allowed (by citizenid so relogging can't skip it)
local BoardThrottle = {} -- [src] = GetGameTimer() of the last board request
local TurnInBusy = {}    -- [src] = true while a turn-in is being processed
local StatsCache = {}    -- [citizenid] = { row, at }
local nextPosterId = 0
local RepCfg = Config.ReputationBounty or { Enabled = false }
local RepPosters = {}    -- [citizenid] = { id = posterId, src = source } reputation posters currently on the board
local RepCooldowns = {}  -- [citizenid] = os.time() until which no new reputation poster is made
local leaderboardCache = { rows = {}, at = 0 }
local Streaks = {}       -- [citizenid] = { count, last } consecutive NPC captures
local warnedItems = {}   -- evidence items already reported missing

local LOST_CHECKS = 3    -- consecutive 15s checks with a missing target entity before the contract fails

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 7000 })
end

local function pick(t) return t[math.random(#t)] end

local function flag(v) return v == true or (type(v) == 'number' and v ~= 0) end

local function getOffice(id)
    for _, o in ipairs(Config.Offices) do
        if o.id == id then return o end
    end
end

-- Config.Hideouts entries are a vector3, or { coords = vector3, props = { ... } }
local function hideoutPos(idx)
    local h = Config.Hideouts[idx]
    if not h then return nil end
    if type(h) == 'table' then return h.coords end
    return h
end

-- props for the client to spawn at a hideout (plain tables so they travel over events)
local function hideoutProps(idx)
    local h = Config.Hideouts[idx]
    local list
    if type(h) == 'table' then list = h.props elseif Config.Hideout.Dress then list = Config.Hideout.DefaultProps end
    local out = {}
    for _, pr in ipairs(list or {}) do
        local o = pr.offset or vector3(0.0, 0.0, 0.0)
        out[#out + 1] = { model = pr.model, x = o.x, y = o.y, z = o.z, heading = pr.heading or 0.0 }
    end
    return out
end

local function playerDistance(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

local function nearOffice(src, office)
    local dist = playerDistance(src, office.coords.xyz)
    if Config.Debug then
        print(('[rsg-bountyhunter] %s is %.2fm from %s (max %.2f)'):format(src, dist, office.id, Config.ServerCheckDistance))
    end
    return dist <= Config.ServerCheckDistance
end

-- Config.RequiredJob can be one job name or a list of job names
local function hasRequiredJob(Player)
    local req = Config.RequiredJob
    if not req then return true end
    local job = Player.PlayerData.job and Player.PlayerData.job.name
    if type(req) == 'table' then
        for _, name in ipairs(req) do
            if job == name then return true end
        end
        return false
    end
    return job == req
end

local function dbCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        print('^1[rsg-bountyhunter] database error: ' .. tostring(res) .. '^7')
        return nil
    end
    return res
end

-- runs one step of the main loop so a single error can't kill the whole thread
local function safe(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then print(('^1[rsg-bountyhunter] %s error: %s^7'):format(name, tostring(err))) end
end

local function getTargetEntity(c)
    if not c or not c.netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(c.netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
end

-- Gang membership lives in rsg-gangs (its own table), not in the core gang field.
local function gangNameOf(Player)
    local cid = Player and Player.PlayerData and Player.PlayerData.citizenid
    if cid and GetResourceState('rsg-gangs') == 'started' then
        local ok, g = pcall(function() return exports['rsg-gangs']:GetPlayerGang(cid) end)
        if ok and g and g.name then return g.name end
    end
    local g = Player and Player.PlayerData and Player.PlayerData.gang
    if g and g.name and g.name ~= 'none' then return g.name end
end

-- online players of a gang (used by gang-targeted bounties)
local function onlineGangMembers(name)
    local out = {}
    if not name or GetResourceState('rsg-gangs') ~= 'started' then return out end
    local ok, sources = pcall(function() return exports['rsg-gangs']:GetGangOnlineSources(name) end)
    if not ok or type(sources) ~= 'table' then return out end
    for _, psrc in ipairs(sources) do
        local P = RSGCore.Functions.GetPlayer(psrc)
        if P then out[#out + 1] = P end
    end
    return out
end

---------------------------------
-- optional integrations and bonuses
---------------------------------
local function skillLevel(src)
    if not Config.Skills.Enabled or GetResourceState('rsg-skills') ~= 'started' then return 1 end
    local ok, level = pcall(function() return exports['rsg-skills']:GetLevel(src, Config.Skills.Key) end)
    return ok and tonumber(level) or 1
end

local function skillPerk(src) -- percent
    if not Config.Skills.Enabled or GetResourceState('rsg-skills') ~= 'started' then return 0 end
    local ok, v = pcall(function() return exports['rsg-skills']:GetPerk(src, Config.Skills.Key, Config.Skills.RewardPerk) end)
    return ok and tonumber(v) or 0
end

local function awardXP(src, tier, alive, isNpc)
    if not Config.Skills.Enabled or GetResourceState('rsg-skills') ~= 'started' then return end
    local xp = isNpc and ((Config.Skills.XP[tier] or 0) + (alive and Config.Skills.AliveBonusXP or 0)) or Config.Skills.PlayerXP
    if xp and xp > 0 then
        pcall(function() exports['rsg-skills']:AddXP(src, Config.Skills.Key, xp, 'rsg-bountyhunter') end)
    end
end

local function registerSkill()
    if not Config.Skills.Enabled or GetResourceState('rsg-skills') ~= 'started' then return end
    pcall(function() exports['rsg-skills']:RegisterSkill(Config.Skills.Key, Config.Skills.Definition) end)
end

local function streakOf(cid)
    local st = Streaks[cid]
    if st and os.time() - st.last <= Config.Streak.WindowMinutes * 60 then return st.count end
    return 0
end

local function telegram(cid, subject, message)
    if not Config.Telegram.Enabled or GetResourceState('rsg-telegram') ~= 'started' then return end
    pcall(function() exports['rsg-telegram']:SendTelegram(cid, subject, message, { senderName = locale('tg_sender') }) end)
end

-- gang members the server can confirm dead at the hideout (registered through registerGang)
local function clearedGang(c)
    local n = 0
    for _, nid in ipairs(c.gangIds or {}) do
        local ent = NetworkGetEntityFromNetworkId(nid)
        if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityHealth(ent) <= 0 then n = n + 1 end
    end
    return n
end

local function giveEvidence(src, tier, alive)
    local cfg = Config.Evidence
    if not cfg.Enabled or (cfg.OnlyWhenDead and alive) then return end
    for _, e in ipairs(cfg.Items[tier] or {}) do
        if math.random() <= e.chance then
            local item = RSGCore.Shared.Items[e.name]
            if not item then
                if not warnedItems[e.name] then
                    warnedItems[e.name] = true
                    print(('^3[rsg-bountyhunter] evidence item "%s" is not in the rsg-core shared items, skipping it (see installation/items.lua)^7'):format(e.name))
                end
            else
                local amount = math.random(e.amount[1], e.amount[2])
                if exports['rsg-inventory']:CanAddItem(src, e.name, amount) then
                    exports['rsg-inventory']:AddItem(src, e.name, amount, nil, nil, 'rsg-bountyhunter-evidence')
                    notify(src, locale('evidence_found', item.label), 'inform')
                end
            end
        end
    end
end

-- sentence a player who was brought in alive (same hand-off rsg-lawman uses)
local function jailTarget(TPlayer, tsrc, hunterSrc, name)
    local mins = tonumber(Config.Jail.Minutes) or 0
    if mins <= 0 or GetResourceState('rsg-prison') ~= 'started' or GetResourceState('rsg-lawman') ~= 'started' then return end
    TPlayer.Functions.SetMetaData('injail', mins)
    TriggerClientEvent('rsg-lawman:client:sendtojail', tsrc, mins)
    notify(tsrc, locale('jail_target', mins), 'warning')
    notify(hunterSrc, locale('jail_sent', name, mins), 'inform')
end

---------------------------------
-- board
---------------------------------
local function newPoster()
    nextPosterId = nextPosterId + 1
    local tier = math.random(#Config.Tiers)
    local t = Config.Tiers[tier]
    local reward = math.random(t.rewardAlive[1], t.rewardAlive[2])
    local rewardAlive, rewardDead = reward, math.floor(reward * t.deadMultiplier)
    local condition = 'any'
    local cfg = Config.Conditions
    if cfg.Enabled then
        local roll = math.random()
        if roll < cfg.AliveOnlyChance then
            condition = 'alive'
            rewardAlive, rewardDead = math.floor(reward * cfg.AliveOnlyMultiplier), 0
        elseif roll < cfg.AliveOnlyChance + cfg.DeadOnlyChance then
            condition = 'dead'
            rewardAlive, rewardDead = 0, math.floor(reward * cfg.DeadOnlyMultiplier)
        end
    end
    return {
        id = nextPosterId,
        tier = tier,
        name = ('%s %s'):format(pick(Config.FirstNames), pick(Config.LastNames)),
        crime = pick(Config.Crimes[tier]),
        condition = condition,
        rewardAlive = rewardAlive,
        rewardDead = rewardDead,
        model = pick(t.models),
        hideout = math.random(#Config.Hideouts),
        gang = math.random(t.gang[1], t.gang[2]),
        ambush = Config.Ambush.Enabled and tier >= Config.Ambush.MinTier and math.random() < Config.Ambush.Chance,
    }
end

local function fillBoard(reroll)
    local open = 0
    for id, p in pairs(Board) do
        if not p.taken and not p.sponsored then
            if reroll then Board[id] = nil else open = open + 1 end
        end
    end
    for _ = open + 1, Config.BoardSize do
        local p = newPoster()
        Board[p.id] = p
    end
end

local function publicPosters(level)
    local out = {}
    for _, p in pairs(Board) do
        if not p.taken then
            local crime = locale(p.crime)
            if p.sponsored and p.ref then crime = ('%s (%s)'):format(crime, p.sponsor) end
            local minLevel = (not p.playerTarget and not p.targetGang and Config.Skills.Enabled) and (Config.Skills.TierLevels[p.tier] or 1) or 1
            out[#out + 1] = {
                id = p.id, tier = p.tier, tierLabel = locale(Config.Tiers[p.tier].label),
                name = p.name, crime = crime, rewardAlive = p.rewardAlive, rewardDead = p.rewardDead,
                condition = p.condition or 'any', minLevel = minLevel, locked = level < minLevel,
            }
        end
    end
    table.sort(out, function(x, y) return math.max(x.rewardAlive, x.rewardDead) > math.max(y.rewardAlive, y.rewardDead) end)
    return out
end

---------------------------------
-- contracts
---------------------------------
-- removes the contract server-side; reason 'completed' skips the accept cooldown
-- silent = don't message the client (it has logged out / disconnected)
local function endContract(src, reason, silent)
    local c = Contracts[src]
    if not c then return end
    local ent = getTargetEntity(c)
    if ent then DeleteEntity(ent) end
    if c.poster.sponsored and reason ~= 'completed' then
        c.poster.taken = nil -- a sponsored poster goes back on the board until it expires
    else
        Board[c.poster.id] = nil
    end
    Contracts[src] = nil
    if reason ~= 'completed' and reason ~= 'cancelled' then Streaks[c.cid] = nil end -- a lost, abandoned or expired contract breaks the streak
    Cooldowns[c.cid] = (reason ~= 'completed' and reason ~= 'cancelled') and (os.time() + Config.AcceptCooldown) or nil
    if not silent then TriggerClientEvent('rsg-bountyhunter:client:endContract', src, reason) end
end

local function publicContract(c)
    if not c then return nil end
    return {
        name = c.poster.name, crime = locale(c.poster.crime),
        rewardAlive = c.poster.rewardAlive, rewardDead = c.poster.rewardDead,
        remaining = math.max(0, c.expires - os.time()),
    }
end

local function abandon(src)
    local c = Contracts[src]
    if not c then
        notify(src, locale('no_contract'), 'error')
        return false
    end
    notify(src, locale('abandoned', c.poster.name), 'inform')
    BountyLog.Event('abandoned', src, BountyLog.ContractFields(c.poster))
    endContract(src, 'abandoned')
    return true
end

---------------------------------
-- stats
---------------------------------
local function getStats(cid)
    local now = os.time()
    local cached = StatsCache[cid]
    if cached and now - cached.at < Config.LeaderboardCache then return cached.row end
    local row = dbCall(MySQL.single.await, 'SELECT completed, alive, dead, earned FROM rsg_bountyhunter WHERE citizenid = ?', { cid })
        or { completed = 0, alive = 0, dead = 0, earned = 0 }
    StatsCache[cid] = { row = row, at = now }
    return row
end

local function getLeaderboard()
    local now = os.time()
    if now - leaderboardCache.at >= Config.LeaderboardCache then
        local rows = dbCall(MySQL.query.await, 'SELECT name, completed, earned FROM rsg_bountyhunter ORDER BY earned DESC LIMIT ?', { Config.LeaderboardSize })
        if rows then leaderboardCache = { rows = rows, at = now } end
    end
    return leaderboardCache.rows
end

-- fire and forget: the payout flow never waits on the database
local function recordStats(cid, charName, alive, amount)
    MySQL.insert([[
        INSERT INTO rsg_bountyhunter (citizenid, name, completed, alive, dead, earned) VALUES (?, ?, 1, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), completed = completed + 1, alive = alive + VALUES(alive),
        dead = dead + VALUES(dead), earned = earned + VALUES(earned)
    ]], { cid, charName, alive and 1 or 0, alive and 0 or 1, amount })
    StatsCache[cid] = nil
    leaderboardCache.at = 0
end

---------------------------------
-- callbacks
---------------------------------
RSGCore.Functions.CreateCallback('rsg-bountyhunter:server:getBoard', function(src, cb, officeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb({ error = 'board_error' }) end
    local now = GetGameTimer()
    if BoardThrottle[src] and now - BoardThrottle[src] < 1000 then return cb({ silent = true }) end -- anti-spam (DB reads)
    BoardThrottle[src] = now
    local office = getOffice(officeId)
    if not office then
        print(('^1[rsg-bountyhunter] unknown office id: %s^7'):format(tostring(officeId)))
        return cb({ error = 'board_error' })
    end
    if not nearOffice(src, office) then return cb({ error = 'too_far' }) end

    local level = skillLevel(src)
    cb({
        office = locale(office.label),
        posters = publicPosters(level),
        contract = publicContract(Contracts[src]),
        stats = getStats(Player.PlayerData.citizenid),
        leaderboard = getLeaderboard(),
        canHunt = hasRequiredJob(Player),
        level = Config.Skills.Enabled and level or nil,
        streak = Config.Streak.Enabled and streakOf(Player.PlayerData.citizenid) or nil,
    })
end)

local function accept(src, officeId, posterId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local office = getOffice(officeId)
    posterId = tonumber(posterId)
    if not office or not posterId then return false end
    if not nearOffice(src, office) then notify(src, locale('too_far'), 'error') return false end
    if not hasRequiredJob(Player) then notify(src, locale('not_hunter'), 'error') return false end
    if Contracts[src] then notify(src, locale('already_active'), 'error') return false end

    local cid = Player.PlayerData.citizenid
    local now = os.time()
    if Cooldowns[cid] and Cooldowns[cid] > now then
        notify(src, locale('cooldown', Cooldowns[cid] - now), 'error')
        return false
    end

    local poster = Board[posterId]
    if not poster or poster.taken then notify(src, locale('poster_gone'), 'error') return false end
    if not poster.playerTarget and not poster.targetGang and Config.Skills.Enabled then
        local need = Config.Skills.TierLevels[poster.tier] or 1
        if skillLevel(src) < need then notify(src, locale('tier_locked', need), 'error') return false end
    end

    -- player / gang poster: the target is a real player (reputation bounty or a gang-sponsored bounty)
    local hunterGang = gangNameOf(Player)
    if poster.sponsorGang and hunterGang == poster.sponsorGang then
        notify(src, locale('gang_own_bounty'), 'error')
        return false
    end
    if poster.playerTarget then
        if poster.playerTarget == cid then notify(src, locale('rep_own_bounty'), 'error') return false end
        local targetPlayer = RSGCore.Functions.GetPlayerByCitizenId(poster.playerTarget)
        if not targetPlayer then notify(src, locale('poster_gone'), 'error') return false end
        local tg = gangNameOf(targetPlayer)
        if (RepCfg.BlockSameGang or poster.sponsored) and hunterGang and tg and hunterGang == tg then
            notify(src, locale('rep_same_gang'), 'error')
            return false
        end
    elseif poster.targetGang then
        if hunterGang == poster.targetGang then notify(src, locale('rep_same_gang'), 'error') return false end
        if #onlineGangMembers(poster.targetGang) == 0 then notify(src, locale('poster_gone'), 'error') return false end
    end

    poster.taken = true
    local c = { poster = poster, cid = cid, expires = now + Config.ContractMinutes * 60 }
    Contracts[src] = c
    fillBoard(false)

    if poster.playerTarget or poster.targetGang then
        local r = math.floor((RepCfg.TrackRadius or 250.0) * 0.5)
        c.playerTarget = poster.playerTarget
        c.gangTarget = poster.targetGang
        c.startedAt = now
        c.offX, c.offY = math.random(-r, r), math.random(-r, r) -- fixed offset so the area isn't centred on the target
        c.nextTrack = 0 -- the main loop sends the first search area within a few seconds
        TriggerClientEvent('rsg-bountyhunter:client:startPlayerContract', src, { name = poster.name })
        notify(src, locale('accepted', poster.name, Config.ContractMinutes), 'success')
        BountyLog.Event('accepted', src, BountyLog.ContractFields(poster, {
            { name = locale('wh_office'), value = locale(office.label) },
            { name = locale('wh_time_limit'), value = locale('wh_minutes', Config.ContractMinutes) },
        }))
        return true
    end

    local tier = Config.Tiers[poster.tier]
    TriggerClientEvent('rsg-bountyhunter:client:startContract', src, {
        name = poster.name,
        model = poster.model,
        hideout = hideoutPos(poster.hideout),
        props = hideoutProps(poster.hideout),
        idle = Config.Hideout.IdleUntilAlert,
        alertDistance = Config.Hideout.AlertDistance,
        scenarios = Config.Hideout.Scenarios,
        ambush = poster.ambush == true,
        gang = poster.gang,
        behaviour = tier.behaviour,
        accuracy = tier.accuracy,
        models = tier.models,
        weapons = tier.weapons,
    })
    notify(src, locale('accepted', poster.name, Config.ContractMinutes), 'success')
    BountyLog.Event('accepted', src, BountyLog.ContractFields(poster, {
        { name = locale('wh_office'), value = locale(office.label) },
        { name = locale('wh_hideout'), value = ('#%s'):format(poster.hideout) },
        { name = locale('wh_gang_size'), value = poster.gang },
        { name = locale('wh_time_limit'), value = locale('wh_minutes', Config.ContractMinutes) },
    }))
    return true
end

RSGCore.Functions.CreateCallback('rsg-bountyhunter:server:accept', function(src, cb, officeId, posterId)
    cb(accept(src, officeId, posterId))
end)

RSGCore.Functions.CreateCallback('rsg-bountyhunter:server:abandon', function(src, cb)
    cb(abandon(src))
end)

-- true when another contract already holds this networked entity (as its target or a registered gang member)
local function targetTaken(src, netId)
    for hsrc, c in pairs(Contracts) do
        if hsrc ~= src then
            if c.netId == netId then return true end
            for _, g in ipairs(c.gangIds or {}) do
                if g == netId then return true end
            end
        end
    end
    return false
end

-- the hunter's client spawns the networked target and registers it here.
-- server verifies the model, that the ped is at the hideout, that the hunter is actually there
-- and that the ped is not already another hunter's target.
RegisterNetEvent('rsg-bountyhunter:server:registerTarget', function(netId)
    local src = source
    local c = Contracts[src]
    if not c or c.netId or c.playerTarget or c.gangTarget then return end
    netId = tonumber(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local hideout = hideoutPos(c.poster.hideout)
    if not hideout then return end

    local reason
    local owner = NetworkGetEntityOwner(ent)
    if GetEntityModel(ent) ~= joaat(c.poster.model) then
        reason = locale('wh_reason_wrong_model')
    elseif #(GetEntityCoords(ent) - hideout) > 50.0 then
        reason = locale('wh_reason_ped_far', math.floor(#(GetEntityCoords(ent) - hideout)))
    elseif playerDistance(src, hideout) > Config.SpawnDistance + 50.0 then
        reason = locale('wh_reason_player_far', math.floor(playerDistance(src, hideout)))
    elseif targetTaken(src, netId) or (owner and owner > 0 and owner ~= src) then
        reason = locale('wh_reason_duplicate')
    end
    if reason then
        BountyLog.Event('exploit', src, { { name = locale('wh_check'), value = locale('wh_check_registration') }, { name = locale('wh_target'), value = c.poster.name } }, reason)
        return
    end

    c.netId = netId
    c.foundAt = os.time()
end)

-- the hunter's client registers the gang it spawned so the server can see how many were left dead.
-- Same checks as the target (model of the tier, near the hideout, owned by the hunter, not held elsewhere);
-- the bonus is capped, so a faked list gains little.
RegisterNetEvent('rsg-bountyhunter:server:registerGang', function(ids)
    local src = source
    local c = Contracts[src]
    if not c or not c.netId or c.gangIds or c.playerTarget or c.gangTarget or type(ids) ~= 'table' then return end
    local hideout = hideoutPos(c.poster.hideout)
    local tier = Config.Tiers[c.poster.tier]
    if not hideout or not tier then return end
    local allowed = {}
    for _, m in ipairs(tier.models) do allowed[joaat(m)] = true end

    local out, seen = {}, {}
    for i = 1, math.min(#ids, c.poster.gang) do
        local netId = tonumber(ids[i])
        if netId and not seen[netId] and netId ~= c.netId and not targetTaken(src, netId) then
            seen[netId] = true
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) and allowed[GetEntityModel(ent)] and #(GetEntityCoords(ent) - hideout) <= 60.0 then
                local owner = NetworkGetEntityOwner(ent)
                if not (owner and owner > 0 and owner ~= src) then out[#out + 1] = netId end
            end
        end
    end
    c.gangIds = out
end)

---------------------------------
-- turn-in helpers
---------------------------------
-- minimum seconds between finding the target and turning it in: the flat minimum, or the time it takes
-- to cover the hideout -> office distance at Config.MaxTravelSpeed, whichever is longer
local function requiredHuntSeconds(c, office)
    local need = Config.MinHuntSeconds
    local hideout = c.poster.hideout and hideoutPos(c.poster.hideout)
    local speed = Config.MaxTravelSpeed or 0
    if hideout and speed > 0 then
        need = math.max(need, math.floor(#(hideout - office.coords.xyz) / speed))
    end
    return need
end

-- true (and the hunter is told) when the turn-in is faster than humanly possible
local function huntTooFast(src, c, office, secs)
    local need = requiredHuntSeconds(c, office)
    if secs >= need then return false end
    print(('^3[rsg-bountyhunter] %s turned in a target %ss after finding it, minimum %ss (possible teleport exploit)^7'):format(src, secs, need))
    BountyLog.Event('exploit', src, { { name = locale('wh_check'), value = locale('wh_check_min_hunt') }, { name = locale('wh_target'), value = c.poster.name } },
        locale('wh_reason_instant', secs, need))
    notify(src, locale('too_soon', need - secs), 'error')
    return true
end

-- shared payout for NPC and player targets. The contract is removed before the money is paid
-- so it can't be claimed twice. NPC contracts get the skill, streak, gang and region adjustments.
local function completeContract(src, Player, office, c, alive, secs)
    local poster = c.poster
    local isNpc = not (c.playerTarget or c.gangTarget)
    local pd = Player.PlayerData
    local cid = pd.citizenid
    local charName = ('%s %s'):format(pd.charinfo.firstname, pd.charinfo.lastname)
    local regionId = Config.Reputation.Regions[office.id] or office.id

    local pct, streakCount, regionMult = 0.0, 0, 1.0
    if isNpc then
        pct = skillPerk(src) / 100
        if Config.Streak.Enabled then
            streakCount = streakOf(cid) + 1
            pct = pct + math.min(Config.Streak.MaxBonus, (streakCount - 1) * Config.Streak.BonusPerStep)
        end
        if Config.GangBonus.Enabled then
            pct = pct + math.min(Config.GangBonus.MaxBonus, clearedGang(c) * Config.GangBonus.PerMember)
        end
        if Config.Economy.Enabled then regionMult = tonumber(Config.Economy.Multipliers[regionId]) or 1.0 end
    end
    local base = alive and poster.rewardAlive or poster.rewardDead
    local amount = math.max(0, math.floor(base * (1 + pct) * regionMult))

    local logFields = BountyLog.ContractFields(poster, {
        { name = locale('wh_condition'), value = locale(alive and 'ui_alive' or 'ui_dead') },
        { name = locale('wh_paid'), value = ('$%s (%s)'):format(amount, Config.MoneyType) },
        { name = locale('wh_office'), value = locale(office.label) },
        { name = locale('wh_hunt_time'), value = locale('wh_minutes', math.floor(secs / 60)) },
    })

    endContract(src, 'completed')
    local paid = Player.Functions.AddMoney(Config.MoneyType, amount, 'rsg-bountyhunter-reward')
    if not paid then
        print(('^1[rsg-bountyhunter] could not pay $%s to %s (%s)^7'):format(amount, cid, src))
    end
    -- sponsored posters: the caller settles its escrow (paid = 0 refunds everything)
    if poster.ref then TriggerEvent('rsg-bountyhunter:server:posterClosed', poster.ref, 'completed', paid and amount or 0) end
    if not paid then return false end

    local charName2 = charName
    recordStats(cid, charName2, alive, amount)
    notify(src, locale(alive and 'paid_alive' or 'paid_dead', poster.name, amount), 'success')
    if pct > 0 then notify(src, locale('bonus_summary', ('%d%%'):format(math.floor(pct * 100 + 0.5))), 'success') end

    if isNpc then
        if Config.Streak.Enabled then Streaks[cid] = { count = streakCount, last = os.time() } end
        giveEvidence(src, poster.tier, alive)
        if Config.Economy.Enabled and Config.Economy.PayFromTreasury and GetResourceState('rsg-economy') == 'started' then
            pcall(function() exports['rsg-economy']:WithdrawTreasury(regionId, amount, 'Bounty: ' .. poster.name, charName) end)
        end
    end
    awardXP(src, poster.tier, alive, isNpc)

    -- rsg-reputation (optional): honor and standing in the town of the office
    if Config.Reputation.Enabled and GetResourceState('rsg-reputation') == 'started' then
        exports['rsg-reputation']:ApplyAction(src, Config.Reputation.Action, Config.Reputation.Regions[office.id] or office.id)
    end
    BountyLog.Event('completed', src, logFields,
        locale(alive and 'wh_turned_in_alive' or 'wh_turned_in_dead', charName, cid, poster.name, amount))
    return true
end

---------------------------------
-- reputation bounties (rsg-reputation)
---------------------------------
-- removes the poster of a player; a hunter holding it is told and released without a cooldown
local function closeRepPoster(cid, reason)
    local entry = RepPosters[cid]
    if not entry then return end
    RepPosters[cid] = nil
    local key = reason == 'cleared' and 'rep_target_cleared' or reason == 'jailed' and 'rep_target_jailed' or 'rep_target_left'
    for hsrc, c in pairs(Contracts) do
        if c.playerTarget == cid then
            notify(hsrc, locale(key, c.poster.name), 'warning')
            endContract(hsrc, 'cancelled')
        end
    end
    Board[entry.id] = nil
end

local function repReward(honor)
    local over = math.max(0, RepCfg.Threshold - honor)
    local alive = math.floor(math.min(RepCfg.MaxReward, RepCfg.BaseReward + over * RepCfg.PerPoint))
    return alive, math.floor(alive * RepCfg.DeadMultiplier)
end

-- returns true, or false plus the reason ('jailed')
local function repEligible(Player)
    local pd = Player.PlayerData
    local jobType = pd.job and pd.job.type
    for _, t in ipairs(RepCfg.ExemptJobTypes or {}) do
        if jobType == t then return false end
    end
    if RepCfg.SkipJailed and flag(pd.metadata and pd.metadata.injail) then return false, 'jailed' end
    local cd = RepCooldowns[pd.citizenid]
    if cd and cd > os.time() then return false end
    return true
end

-- posts, updates or removes the poster of one player from their current honor
local function evaluateRep(src)
    if not RepCfg.Enabled or GetResourceState('rsg-reputation') ~= 'started' then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local honor = tonumber(exports['rsg-reputation']:GetHonor(src))
    if not honor then return end

    local ok, why = repEligible(Player)
    local entry = RepPosters[cid]
    if entry then
        entry.src = src
        if not ok or honor > RepCfg.ClearAbove then
            closeRepPoster(cid, why == 'jailed' and 'jailed' or 'cleared')
            if ok and RepCfg.NotifyTarget then notify(src, locale('rep_cleared'), 'success') end
        else
            local p = Board[entry.id]
            if p and not p.taken then p.rewardAlive, p.rewardDead = repReward(honor) end
        end
        return
    end

    if not ok or honor > RepCfg.Threshold then return end
    local alive, dead = repReward(honor)
    local ci = Player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''):gsub('%s+$', '')
    nextPosterId = nextPosterId + 1
    Board[nextPosterId] = {
        id = nextPosterId, tier = 3, name = name,
        crime = 'crime_reputation', rewardAlive = alive, rewardDead = dead,
        sponsored = true, expiresAt = math.huge, playerTarget = cid, -- sponsored: survives board re-rolls, returns when abandoned
    }
    RepPosters[cid] = { id = nextPosterId, src = src }
    if RepCfg.NotifyTarget then notify(src, locale('rep_posted'), 'warning') end
    if Config.Telegram.Posted then telegram(cid, locale('tg_posted_subject'), locale('tg_posted_body', alive)) end
end

-- the target is secured when dead (server metadata) or bound: cuffed (server metadata) or hogtied (asked of the target's own client)
local function repTargetCondition(tsrc, TPlayer)
    local meta = TPlayer.PlayerData.metadata or {}
    if flag(meta.isdead) then return 'dead' end
    if flag(meta.ishandcuffed) then return 'alive' end
    local ok, hogtied = pcall(RSGCore.Functions.AwaitClientCallback, 'rsg-bountyhunter:client:isRestrained', tsrc, 3000)
    if ok and hogtied == true then return 'alive' end
    return nil
end

-- online players a player / gang contract can be satisfied with
local function targetCandidates(c)
    if c.playerTarget then
        local P = RSGCore.Functions.GetPlayerByCitizenId(c.playerTarget)
        return P and { P } or {}
    end
    return onlineGangMembers(c.gangTarget)
end

local function turnInPlayer(src, Player, office, c)
    local isRep = c.poster.ref == nil -- reputation posters have no sponsor ref
    local candidates = targetCandidates(c)
    if #candidates == 0 then
        if c.playerTarget and isRep then closeRepPoster(c.playerTarget, 'left') end
        notify(src, locale('target_not_here'), 'error')
        return false
    end
    if isRep and RepCfg.SkipJailed and flag(candidates[1].PlayerData.metadata and candidates[1].PlayerData.metadata.injail) then
        closeRepPoster(c.playerTarget, 'jailed')
        return false
    end

    -- every candidate at the office is checked; the first one that is secured is the one turned in
    local here = {}
    for _, cand in ipairs(candidates) do
        local meta = cand.PlayerData.metadata
        local cped = GetPlayerPed(cand.PlayerData.source)
        local jailed = RepCfg.SkipJailed and flag(meta and meta.injail)
        if not jailed and cped and cped ~= 0 and #(GetEntityCoords(cped) - office.coords.xyz) <= Config.DeliverRadius then
            here[#here + 1] = cand
        end
    end
    if #here == 0 then
        notify(src, locale('target_not_here'), 'error')
        return false
    end
    local secs = os.time() - (c.startedAt or os.time())
    if huntTooFast(src, c, office, secs) then return false end

    local TPlayer, tsrc, condition
    for _, cand in ipairs(here) do
        local cond = repTargetCondition(cand.PlayerData.source, cand)
        if cond then TPlayer, tsrc, condition = cand, cand.PlayerData.source, cond break end
    end
    if not TPlayer then
        notify(src, locale('rep_not_secured'), 'error')
        return false
    end
    local targetCid = TPlayer.PlayerData.citizenid
    if not RSGCore.Functions.GetPlayerByCitizenId(targetCid) or Contracts[src] ~= c then return false end -- changed while waiting on the client

    if isRep then
        RepPosters[targetCid] = nil
        RepCooldowns[targetCid] = os.time() + (RepCfg.RepostCooldownMinutes or 120) * 60
    end
    local alive = condition == 'alive'
    local done = completeContract(src, Player, office, c, alive, secs)
    if not done then return false end
    if RepCfg.NotifyTarget ~= false then notify(tsrc, locale('rep_collected'), 'warning') end
    if Config.Telegram.Collected then telegram(targetCid, locale('tg_collected_subject'), locale('tg_collected_body')) end
    if alive and Config.Jail.Enabled and ((isRep and Config.Jail.Reputation) or (not isRep and Config.Jail.Sponsored)) then
        jailTarget(TPlayer, tsrc, src, c.poster.name)
    end
    return true
end

local function doTurnIn(src, officeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local office = getOffice(officeId)
    if not office then return false end
    if not nearOffice(src, office) then notify(src, locale('too_far'), 'error') return false end

    local c = Contracts[src]
    if not c then notify(src, locale('no_contract'), 'error') return false end
    if c.playerTarget or c.gangTarget then return turnInPlayer(src, Player, office, c) end
    if not c.netId then notify(src, locale('target_not_here'), 'error') return false end

    local ent = getTargetEntity(c)
    if not ent then
        notify(src, locale('target_lost'), 'error')
        BountyLog.Event('failed', src, BountyLog.ContractFields(c.poster), locale('wh_target_missing'))
        endContract(src, 'failed')
        return false
    end
    if #(GetEntityCoords(ent) - office.coords.xyz) > Config.DeliverRadius then
        notify(src, locale('target_not_here'), 'error')
        return false
    end
    local secs = os.time() - c.foundAt
    if huntTooFast(src, c, office, secs) then return false end

    local alive = GetEntityHealth(ent) > 0
    local cond = c.poster.condition
    if cond == 'alive' and not alive then -- nothing is paid for a corpse and it cannot be revived
        notify(src, locale('alive_only_failed'), 'error')
        BountyLog.Event('failed', src, BountyLog.ContractFields(c.poster), locale('alive_only_failed'))
        endContract(src, 'failed')
        return false
    elseif cond == 'dead' and alive then
        notify(src, locale('condition_dead_only'), 'error')
        return false
    end

    return completeContract(src, Player, office, c, alive, secs)
end

-- one turn-in per player at a time (the player path waits on the target's client)
local function turnIn(src, officeId)
    if TurnInBusy[src] then return false end
    TurnInBusy[src] = true
    local ok, res = pcall(doTurnIn, src, officeId)
    TurnInBusy[src] = nil
    if not ok then
        print(('^1[rsg-bountyhunter] turn-in error: %s^7'):format(tostring(res)))
        return false
    end
    return res
end

RSGCore.Functions.CreateCallback('rsg-bountyhunter:server:turnIn', function(src, cb, officeId)
    cb(turnIn(src, officeId))
end)

---------------------------------
-- commands
---------------------------------
if Config.AbandonCommand then
    RSGCore.Commands.Add(Config.AbandonCommand, locale('cmd_abandon'), {}, false, function(source)
        abandon(source)
    end)
end

---------------------------------
-- database: created automatically on start (install.sql kept as a manual fallback)
---------------------------------
MySQL.ready(function()
    if Config.AutoDatabase == false then return end -- manual install: import install.sql
    local ok = dbCall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `rsg_bountyhunter` (
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL DEFAULT '',
            `completed` INT NOT NULL DEFAULT 0,
            `alive` INT NOT NULL DEFAULT 0,
            `dead` INT NOT NULL DEFAULT 0,
            `earned` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    if ok then print('^2[rsg-bountyhunter] database table ready^7') end
end)

---------------------------------
-- main loop: expiry, lost targets, board refresh, tracking, reputation sweep
---------------------------------
local function tickContracts(now)
    for src, c in pairs(Contracts) do
        local left = c.expires - now
        if left <= 0 then
            notify(src, locale('expired', c.poster.name), 'error')
            BountyLog.Event('expired', src, BountyLog.ContractFields(c.poster))
            endContract(src, 'expired')
        else
            if not c.warned and left <= Config.WarnMinutes * 60 then
                c.warned = true
                notify(src, locale('time_warning', c.poster.name, math.ceil(left / 60)), 'warning')
            end
            -- a registered target that vanished (deleted, owner crashed) fails the contract instead of leaving it dangling
            if c.netId then
                if getTargetEntity(c) then
                    c.missing = 0
                else
                    c.missing = (c.missing or 0) + 1
                    if c.missing >= LOST_CHECKS then
                        notify(src, locale('target_lost'), 'error')
                        BountyLog.Event('failed', src, BountyLog.ContractFields(c.poster), locale('wh_target_missing'))
                        endContract(src, 'failed')
                    end
                end
            end
        end
    end
end

local function tickSponsored(now)
    for id, p in pairs(Board) do
        if p.sponsored and not p.taken and p.expiresAt <= now then
            Board[id] = nil
            if p.ref ~= nil then TriggerEvent('rsg-bountyhunter:server:posterClosed', p.ref, 'expired', 0) end
        end
    end
end

-- the hunter's search area follows the target (offset, so it never points at the exact spot);
-- covers reputation bounties and gang-sponsored player / gang bounties
local function tickTracking(now)
    for hsrc, c in pairs(Contracts) do
        if (c.playerTarget or c.gangTarget) and now >= (c.nextTrack or 0) then
            c.nextTrack = now + math.max(15, RepCfg.TrackSeconds or 30)
            -- re-roll the offset now and then so a hunter who once saw the target cannot read it back from the circle
            c.trackTicks = (c.trackTicks or 0) + 1
            local every = RepCfg.RerollEvery or 0
            if every > 0 and c.trackTicks % every == 0 then
                local r = math.floor((RepCfg.TrackRadius or 250.0) * 0.5)
                c.offX, c.offY = math.random(-r, r), math.random(-r, r)
            end
            local cands = targetCandidates(c)
            local TPlayer = cands[1] and cands[math.random(#cands)]
            local tped = TPlayer and GetPlayerPed(TPlayer.PlayerData.source)
            if tped and tped ~= 0 then
                local pos = GetEntityCoords(tped)
                TriggerClientEvent('rsg-bountyhunter:client:trackArea', hsrc,
                    { x = pos.x + c.offX, y = pos.y + c.offY, z = pos.z, radius = RepCfg.TrackRadius or 250.0 })
            end
        end
    end
end

-- re-check everyone: jail, honor decay and cooldown changes raise no honor event
local function tickReputation()
    for _, id in ipairs(GetPlayers()) do
        safe('reputation sweep', evaluateRep, tonumber(id))
    end
end

-- drop expired cooldowns and stale cached stats so the tables don't grow forever
local function tickPrune(now)
    for cid, untilAt in pairs(Cooldowns) do
        if untilAt <= now then Cooldowns[cid] = nil end
    end
    for cid, untilAt in pairs(RepCooldowns) do
        if untilAt <= now then RepCooldowns[cid] = nil end
    end
    for cid, st in pairs(Streaks) do
        if now - st.last > Config.Streak.WindowMinutes * 60 then Streaks[cid] = nil end
    end
    for cid, cached in pairs(StatsCache) do
        if now - cached.at >= Config.LeaderboardCache then StatsCache[cid] = nil end
    end
end

CreateThread(function()
    fillBoard(true)
    local lastRefresh = os.time()
    local lastSweep = os.time()
    while true do
        Wait(15000)
        local now = os.time()
        safe('contracts', tickContracts, now)
        safe('sponsored posters', tickSponsored, now)
        safe('tracking', tickTracking, now)
        safe('prune', tickPrune, now)
        if RepCfg.Enabled and now - lastSweep >= (RepCfg.SweepSeconds or 60) then
            lastSweep = now
            safe('reputation', tickReputation)
        end
        if now - lastRefresh >= Config.RefreshMinutes * 60 then
            lastRefresh = now
            fillBoard(true)
            BountyLog.Event('boardRefresh', nil, nil, locale('wh_board_refreshed', Config.BoardSize))
        end
    end
end)

-- rsg-skills: register the bounty hunting skill now and again whenever rsg-skills (re)starts
CreateThread(function()
    Wait(2000)
    registerSkill()
end)
AddEventHandler('rsg-skills:server:ready', registerSkill)

-- Server export: another resource sponsors a poster. The caller escrows the money and listens for
-- 'rsg-bountyhunter:server:posterClosed' (ref, 'completed' | 'expired', paid) to settle it.
-- opts = { ref = any unique value, reward = alive reward, sponsor = text shown on the poster, expireMinutes = n,
--          targetCitizenid = bounty on one player, OR targetGang = bounty on any online member of an rsg-gangs gang,
--          targetName = name shown on the board, sponsorGang = gang name that cannot take its own bounty }
exports('PostBounty', function(opts)
    if type(opts) ~= 'table' or opts.ref == nil then return nil end
    local reward = math.floor(tonumber(opts.reward) or 0)
    if reward < 1 then return nil end
    local poster = newPoster()
    local t = Config.Tiers[poster.tier]
    poster.condition = 'any'
    poster.ambush = false
    poster.rewardAlive = reward
    poster.rewardDead = math.floor(reward * t.deadMultiplier)
    poster.sponsored = true
    poster.sponsor = tostring(opts.sponsor or '?'):sub(1, 40)
    poster.ref = opts.ref
    poster.expiresAt = os.time() + math.max(1, tonumber(opts.expireMinutes) or 360) * 60
    if opts.targetCitizenid or opts.targetGang then
        -- the poster names a real target: one player, or any online member of a gang
        poster.tier = 3
        poster.rewardDead = math.floor(reward * Config.Tiers[3].deadMultiplier)
        poster.crime = 'crime_sponsored_bounty'
        poster.name = tostring(opts.targetName or '?'):sub(1, 60)
        poster.sponsorGang = opts.sponsorGang and tostring(opts.sponsorGang) or nil
        if opts.targetCitizenid then
            poster.playerTarget = tostring(opts.targetCitizenid)
        else
            poster.targetGang = tostring(opts.targetGang)
        end
    end
    Board[poster.id] = poster
    if poster.playerTarget and Config.Telegram.Posted then
        telegram(poster.playerTarget, locale('tg_posted_subject'), locale('tg_posted_body', reward))
    end
    return poster.id
end)

-- Server export: the sponsor withdraws a poster before it is taken or expires. A hunter holding it is told and
-- released without a cooldown. The caller refunds its own escrow; no posterClosed event is sent for a cancel.
-- Returns true when a poster with that ref was found.
exports('CancelBounty', function(ref)
    if ref == nil then return false end
    for id, p in pairs(Board) do
        if p.sponsored and p.ref ~= nil and p.ref == ref then
            for hsrc, c in pairs(Contracts) do
                if c.poster == p then
                    notify(hsrc, locale('poster_cancelled', p.name), 'warning')
                    endContract(hsrc, 'cancelled')
                end
            end
            Board[id] = nil
            return true
        end
    end
    return false
end)

---------------------------------
-- lifecycle
---------------------------------
-- character logout / switch / disconnect: the client loses its contract state, so drop it server-side too.
-- counts as an abandon (cooldown applies) so relogging can't be used to re-roll contracts.
local function dropRepPoster(src)
    for cid, e in pairs(RepPosters) do
        if e.src == src then closeRepPoster(cid, 'left') end
    end
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    endContract(src, 'abandoned', true)
    dropRepPoster(src)
    TurnInBusy[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    endContract(src, 'abandoned', true)
    dropRepPoster(src)
    BoardThrottle[src] = nil
    TurnInBusy[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, c in pairs(Contracts) do
        local ent = getTargetEntity(c)
        if ent then DeleteEntity(ent) end
    end
    -- the board lives in memory: tell every sponsor its poster is gone so it can refund its escrow
    for _, p in pairs(Board) do
        if p.sponsored and p.ref ~= nil then
            TriggerEvent('rsg-bountyhunter:server:posterClosed', p.ref, 'expired', 0)
        end
    end
end)

---------------------------------
-- reputation bounties: triggers and export
---------------------------------
-- server-side event from rsg-reputation (AddEventHandler, so clients cannot fire it)
AddEventHandler('rsg-reputation:server:honorChanged', function(src)
    safe('honor event', evaluateRep, src)
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then SetTimeout(5000, function() safe('player loaded', evaluateRep, src) end) end -- wait for rsg-reputation to load the character
end)

-- true while the character has a reputation poster on the board
exports('IsReputationWanted', function(citizenid)
    return RepPosters[citizenid] ~= nil
end)
