local RSGCore = exports['rsg-core']:GetCoreObject()

local Board = {}        -- [posterId] = poster
local Contracts = {}    -- [src] = { poster, expires, warned, netId, foundAt }
local Cooldowns = {}    -- [citizenid] = os.time() when the next accept is allowed (by citizenid so relogging can't skip it)
local BoardThrottle = {} -- [src] = GetGameTimer() of the last board request
local nextPosterId = 0
local RepCfg = Config.ReputationBounty or { Enabled = false }
local RepPosters = {}   -- [citizenid] = { id = posterId, src = source } reputation posters currently on the board
local RepCooldowns = {} -- [citizenid] = os.time() until which no new reputation poster is made
local leaderboardCache = { rows = {}, at = 0 }

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

local function hasRequiredJob(Player)
    if not Config.RequiredJob then return true end
    return Player.PlayerData.job and Player.PlayerData.job.name == Config.RequiredJob
end

local function dbCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        print('^1[rsg-bountyhunter] database error: ' .. tostring(res) .. '^7')
        return nil
    end
    return res
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
-- board
---------------------------------
local function newPoster()
    nextPosterId = nextPosterId + 1
    local tier = math.random(#Config.Tiers)
    local t = Config.Tiers[tier]
    local reward = math.random(t.rewardAlive[1], t.rewardAlive[2])
    return {
        id = nextPosterId,
        tier = tier,
        name = ('%s %s'):format(pick(Config.FirstNames), pick(Config.LastNames)),
        crime = pick(Config.Crimes[tier]),
        rewardAlive = reward,
        rewardDead = math.floor(reward * t.deadMultiplier),
        model = pick(t.models),
        hideout = math.random(#Config.Hideouts),
        gang = math.random(t.gang[1], t.gang[2]),
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

local function publicPosters()
    local out = {}
    for _, p in pairs(Board) do
        if not p.taken then
            out[#out + 1] = {
                id = p.id, tier = p.tier, tierLabel = locale(Config.Tiers[p.tier].label),
                name = p.name, crime = (p.sponsored and p.ref) and ('%s (%s)'):format(locale(p.crime), p.sponsor) or locale(p.crime), rewardAlive = p.rewardAlive, rewardDead = p.rewardDead,
            }
        end
    end
    table.sort(out, function(a, b) return a.rewardAlive > b.rewardAlive end)
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
    return dbCall(MySQL.single.await, 'SELECT completed, alive, dead, earned FROM rsg_bountyhunter WHERE citizenid = ?', { cid })
        or { completed = 0, alive = 0, dead = 0, earned = 0 }
end

local function getLeaderboard()
    local now = os.time()
    if now - leaderboardCache.at >= Config.LeaderboardCache then
        local rows = dbCall(MySQL.query.await, 'SELECT name, completed, earned FROM rsg_bountyhunter ORDER BY earned DESC LIMIT ?', { Config.LeaderboardSize })
        if rows then leaderboardCache = { rows = rows, at = now } end
    end
    return leaderboardCache.rows
end

local function recordStats(cid, charName, alive, amount)
    dbCall(MySQL.insert.await, [[
        INSERT INTO rsg_bountyhunter (citizenid, name, completed, alive, dead, earned) VALUES (?, ?, 1, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), completed = completed + 1, alive = alive + VALUES(alive),
        dead = dead + VALUES(dead), earned = earned + VALUES(earned)
    ]], { cid, charName, alive and 1 or 0, alive and 0 or 1, amount })
    leaderboardCache.at = 0
end

---------------------------------
-- callbacks
---------------------------------
RSGCore.Functions.CreateCallback('rsg-bountyhunter:server:getBoard', function(src, cb, officeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb({ error = 'board_error' }) end
    local now = GetGameTimer()
    if BoardThrottle[src] and now - BoardThrottle[src] < 1000 then return cb(nil) end -- anti-spam (DB reads)
    BoardThrottle[src] = now
    local office = getOffice(officeId)
    if not office then
        print(('^1[rsg-bountyhunter] unknown office id: %s^7'):format(tostring(officeId)))
        return cb({ error = 'board_error' })
    end
    if not nearOffice(src, office) then return cb({ error = 'too_far' }) end

    cb({
        office = locale(office.label),
        posters = publicPosters(),
        contract = publicContract(Contracts[src]),
        stats = getStats(Player.PlayerData.citizenid),
        leaderboard = getLeaderboard(),
        canHunt = hasRequiredJob(Player),
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

    -- player / gang poster: the target is a real player (reputation bounty or a gang-sponsored bounty)
    local targetPlayer
    local hunterGang = gangNameOf(Player)
    if poster.sponsorGang and hunterGang == poster.sponsorGang then
        notify(src, locale('gang_own_bounty'), 'error')
        return false
    end
    if poster.playerTarget then
        if poster.playerTarget == cid then notify(src, locale('rep_own_bounty'), 'error') return false end
        targetPlayer = RSGCore.Functions.GetPlayerByCitizenId(poster.playerTarget)
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
    Contracts[src] = { poster = poster, cid = cid, expires = now + Config.ContractMinutes * 60 }
    fillBoard(false)

    if poster.playerTarget or poster.targetGang then
        local c = Contracts[src]
        local r = math.floor((RepCfg.TrackRadius or 250.0) * 0.5)
        c.playerTarget = poster.playerTarget
        c.gangTarget = poster.targetGang
        c.startedAt = now
        c.offX, c.offY = math.random(-r, r), math.random(-r, r) -- fixed offset so the area isn't centred on the target
        c.nextTrack = 0 -- the expiry loop sends the first search area within a few seconds
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
        hideout = Config.Hideouts[poster.hideout],
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

-- the hunter's client spawns the networked target and registers it here.
-- server verifies the model, that the ped is at the hideout and that the hunter is actually there.
RegisterNetEvent('rsg-bountyhunter:server:registerTarget', function(netId)
    local src = source
    local c = Contracts[src]
    if not c or c.netId then return end
    netId = tonumber(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end

    local hideout = Config.Hideouts[c.poster.hideout]
    local reason
    if GetEntityModel(ent) ~= joaat(c.poster.model) then
        reason = locale('wh_reason_wrong_model')
    elseif #(GetEntityCoords(ent) - hideout) > 50.0 then
        reason = locale('wh_reason_ped_far', math.floor(#(GetEntityCoords(ent) - hideout)))
    elseif playerDistance(src, hideout) > Config.SpawnDistance + 50.0 then
        reason = locale('wh_reason_player_far', math.floor(playerDistance(src, hideout)))
    end
    if reason then
        BountyLog.Event('exploit', src, { { name = locale('wh_check'), value = locale('wh_check_registration') }, { name = locale('wh_target'), value = c.poster.name } }, reason)
        return
    end

    c.netId = netId
    c.foundAt = os.time()
end)

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
    nextPosterId = nextPosterId + 1
    Board[nextPosterId] = {
        id = nextPosterId, tier = 3, name = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''):gsub('%s+$', ''),
        crime = 'crime_reputation', rewardAlive = alive, rewardDead = dead,
        sponsored = true, expiresAt = math.huge, playerTarget = cid, -- sponsored: survives board re-rolls, returns when abandoned
    }
    RepPosters[cid] = { id = nextPosterId, src = src }
    if RepCfg.NotifyTarget then notify(src, locale('rep_posted'), 'warning') end
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
        local csrc = cand.PlayerData.source
        local cped = GetPlayerPed(csrc)
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
    if secs < Config.MinHuntSeconds then
        BountyLog.Event('exploit', src, { { name = locale('wh_check'), value = locale('wh_check_min_hunt') }, { name = locale('wh_target'), value = c.poster.name } },
            locale('wh_reason_instant', secs, Config.MinHuntSeconds))
        notify(src, locale('target_not_here'), 'error')
        return false
    end
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

    local alive = condition == 'alive'
    local amount = alive and c.poster.rewardAlive or c.poster.rewardDead
    local name = c.poster.name
    local cid = Player.PlayerData.citizenid
    local charName = ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    local logFields = BountyLog.ContractFields(c.poster, {
        { name = locale('wh_condition'), value = locale(alive and 'ui_alive' or 'ui_dead') },
        { name = locale('wh_paid'), value = ('$%s (%s)'):format(amount, Config.MoneyType) },
        { name = locale('wh_office'), value = locale(office.label) },
        { name = locale('wh_hunt_time'), value = locale('wh_minutes', math.floor(secs / 60)) },
    })

    local closedPoster = c.poster
    endContract(src, 'completed') -- clears the contract and the poster before paying so it can't be claimed twice
    if isRep then
        RepPosters[targetCid] = nil
        RepCooldowns[targetCid] = os.time() + (RepCfg.RepostCooldownMinutes or 120) * 60
    end
    Player.Functions.AddMoney(Config.MoneyType, amount, 'rsg-bountyhunter-reward')
    if closedPoster.ref then TriggerEvent('rsg-bountyhunter:server:posterClosed', closedPoster.ref, 'completed', amount) end
    recordStats(cid, charName, alive, amount)
    notify(src, locale(alive and 'paid_alive' or 'paid_dead', name, amount), 'success')
    if RepCfg.NotifyTarget ~= false then notify(tsrc, locale('rep_collected'), 'warning') end

    if Config.Reputation.Enabled and GetResourceState('rsg-reputation') == 'started' then
        exports['rsg-reputation']:ApplyAction(src, Config.Reputation.Action, Config.Reputation.Regions[office.id] or office.id)
    end
    BountyLog.Event('completed', src, logFields,
        locale(alive and 'wh_turned_in_alive' or 'wh_turned_in_dead', charName, cid, name, amount))
    return true
end

local function turnIn(src, officeId)
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
    if secs < Config.MinHuntSeconds then
        print(('^3[rsg-bountyhunter] %s turned in a target %ss after finding it (possible teleport exploit)^7'):format(src, secs))
        BountyLog.Event('exploit', src, { { name = locale('wh_check'), value = locale('wh_check_min_hunt') }, { name = locale('wh_target'), value = c.poster.name } },
            locale('wh_reason_instant', secs, Config.MinHuntSeconds))
        notify(src, locale('target_not_here'), 'error')
        return false
    end

    local alive = GetEntityHealth(ent) > 0
    local amount = alive and c.poster.rewardAlive or c.poster.rewardDead
    local name = c.poster.name
    local cid = Player.PlayerData.citizenid
    local charName = ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    local logFields = BountyLog.ContractFields(c.poster, {
        { name = locale('wh_condition'), value = locale(alive and 'ui_alive' or 'ui_dead') },
        { name = locale('wh_paid'), value = ('$%s (%s)'):format(amount, Config.MoneyType) },
        { name = locale('wh_office'), value = locale(office.label) },
        { name = locale('wh_hunt_time'), value = locale('wh_minutes', math.floor(secs / 60)) },
    })

    local closedPoster = c.poster
    endContract(src, 'completed') -- clears the contract before paying so it can't be claimed twice
    Player.Functions.AddMoney(Config.MoneyType, amount, 'rsg-bountyhunter-reward')
    if closedPoster.ref then TriggerEvent('rsg-bountyhunter:server:posterClosed', closedPoster.ref, 'completed', amount) end

    recordStats(cid, charName, alive, amount)

    notify(src, locale(alive and 'paid_alive' or 'paid_dead', name, amount), 'success')

    -- rsg-reputation (optional): honor and standing in the town of the office
    if Config.Reputation.Enabled and GetResourceState('rsg-reputation') == 'started' then
        exports['rsg-reputation']:ApplyAction(src, Config.Reputation.Action, Config.Reputation.Regions[office.id] or office.id)
    end
    BountyLog.Event('completed', src, logFields,
        locale(alive and 'wh_turned_in_alive' or 'wh_turned_in_dead', charName, cid, name, amount))
    return true
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
-- expiry, board refresh, lifecycle
---------------------------------
CreateThread(function()
    fillBoard(true)
    local lastRefresh = os.time()
    local lastSweep = os.time()
    while true do
        Wait(15000)
        local now = os.time()
        for src, c in pairs(Contracts) do
            local left = c.expires - now
            if left <= 0 then
                notify(src, locale('expired', c.poster.name), 'error')
                BountyLog.Event('expired', src, BountyLog.ContractFields(c.poster))
                endContract(src, 'expired')
            elseif not c.warned and left <= Config.WarnMinutes * 60 then
                c.warned = true
                notify(src, locale('time_warning', c.poster.name, math.ceil(left / 60)), 'warning')
            end
        end
        for id, p in pairs(Board) do
            if p.sponsored and not p.taken and p.expiresAt <= now then
                Board[id] = nil
                TriggerEvent('rsg-bountyhunter:server:posterClosed', p.ref, 'expired', 0)
            end
        end
        -- the hunter's search area follows the target (offset, so it never points at the exact spot);
        -- covers reputation bounties and gang-sponsored player / gang bounties
        for hsrc, c in pairs(Contracts) do
            if (c.playerTarget or c.gangTarget) and now >= (c.nextTrack or 0) then
                c.nextTrack = now + math.max(15, RepCfg.TrackSeconds or 30)
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
        if RepCfg.Enabled then
            -- re-check everyone: jail, honor decay and cooldown changes raise no honor event
            if now - lastSweep >= (RepCfg.SweepSeconds or 60) then
                lastSweep = now
                for _, id in ipairs(GetPlayers()) do evaluateRep(tonumber(id)) end
            end
        end
        if now - lastRefresh >= Config.RefreshMinutes * 60 then
            fillBoard(true)
            lastRefresh = now
            BountyLog.Event('boardRefresh', nil, nil, locale('wh_board_refreshed', Config.BoardSize))
        end
    end
end)

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
    return poster.id
end)

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
end)

AddEventHandler('playerDropped', function()
    local src = source
    endContract(src, 'abandoned', true)
    dropRepPoster(src)
    BoardThrottle[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, c in pairs(Contracts) do
        local ent = getTargetEntity(c)
        if ent then DeleteEntity(ent) end
    end
end)

---------------------------------
-- reputation bounties: triggers and export
---------------------------------
-- server-side event from rsg-reputation (AddEventHandler, so clients cannot fire it)
AddEventHandler('rsg-reputation:server:honorChanged', function(src)
    evaluateRep(src)
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then SetTimeout(5000, function() evaluateRep(src) end) end -- wait for rsg-reputation to load the character
end)

-- true while the character has a reputation poster on the board
exports('IsReputationWanted', function(citizenid)
    return RepPosters[citizenid] ~= nil
end)
