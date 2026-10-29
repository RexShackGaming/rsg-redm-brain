local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Board = {}        -- [posterId] = poster
local Contracts = {}    -- [src] = { poster, expires, warned, netId, foundAt }
local Cooldowns = {}    -- [src] = os.time() when the next accept is allowed
local nextPosterId = 0
local leaderboardCache = { rows = {}, at = 0 }

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 7000 })
end

local function pick(t) return t[math.random(#t)] end

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
        if not p.taken then
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
                name = p.name, crime = locale(p.crime), rewardAlive = p.rewardAlive, rewardDead = p.rewardDead,
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
local function endContract(src, reason)
    local c = Contracts[src]
    if not c then return end
    local ent = getTargetEntity(c)
    if ent then DeleteEntity(ent) end
    Board[c.poster.id] = nil
    Contracts[src] = nil
    Cooldowns[src] = reason ~= 'completed' and (os.time() + Config.AcceptCooldown) or nil
    TriggerClientEvent('rsg-bountyhunter:client:endContract', src, reason)
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

---------------------------------
-- callbacks
---------------------------------
lib.callback.register('rsg-bountyhunter:server:getBoard', function(src, officeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { error = 'board_error' } end
    local office = getOffice(officeId)
    if not office then
        print(('^1[rsg-bountyhunter] unknown office id: %s^7'):format(tostring(officeId)))
        return { error = 'board_error' }
    end
    if not nearOffice(src, office) then return { error = 'too_far' } end

    return {
        office = locale(office.label),
        posters = publicPosters(),
        contract = publicContract(Contracts[src]),
        stats = getStats(Player.PlayerData.citizenid),
        leaderboard = getLeaderboard(),
        canHunt = hasRequiredJob(Player),
    }
end)

lib.callback.register('rsg-bountyhunter:server:accept', function(src, officeId, posterId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local office = getOffice(officeId)
    posterId = tonumber(posterId)
    if not office or not posterId then return false end
    if not nearOffice(src, office) then notify(src, locale('too_far'), 'error') return false end
    if not hasRequiredJob(Player) then notify(src, locale('not_hunter'), 'error') return false end
    if Contracts[src] then notify(src, locale('already_active'), 'error') return false end

    local now = os.time()
    if Cooldowns[src] and Cooldowns[src] > now then
        notify(src, locale('cooldown', Cooldowns[src] - now), 'error')
        return false
    end

    local poster = Board[posterId]
    if not poster or poster.taken then notify(src, locale('poster_gone'), 'error') return false end
    poster.taken = true
    Contracts[src] = { poster = poster, expires = now + Config.ContractMinutes * 60 }
    fillBoard(false)

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
end)

lib.callback.register('rsg-bountyhunter:server:abandon', function(src)
    return abandon(src)
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

lib.callback.register('rsg-bountyhunter:server:turnIn', function(src, officeId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local office = getOffice(officeId)
    if not office then return false end
    if not nearOffice(src, office) then notify(src, locale('too_far'), 'error') return false end

    local c = Contracts[src]
    if not c then notify(src, locale('no_contract'), 'error') return false end
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
    if os.time() - (c.foundAt or 0) < Config.MinHuntSeconds then
        local secs = os.time() - (c.foundAt or 0)
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
        { name = locale('wh_hunt_time'), value = locale('wh_minutes', math.floor((os.time() - (c.foundAt or os.time())) / 60)) },
    })

    endContract(src, 'completed') -- clears the contract before paying so it can't be claimed twice
    Player.Functions.AddMoney(Config.MoneyType, amount, 'rsg-bountyhunter-reward')

    dbCall(MySQL.insert.await, [[
        INSERT INTO rsg_bountyhunter (citizenid, name, completed, alive, dead, earned) VALUES (?, ?, 1, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name), completed = completed + 1, alive = alive + VALUES(alive),
        dead = dead + VALUES(dead), earned = earned + VALUES(earned)
    ]], { cid, charName, alive and 1 or 0, alive and 0 or 1, amount })
    leaderboardCache.at = 0

    notify(src, locale(alive and 'paid_alive' or 'paid_dead', name, amount), 'success')
    BountyLog.Event('completed', src, logFields,
        locale(alive and 'wh_turned_in_alive' or 'wh_turned_in_dead', charName, cid, name, amount))
    return true
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
        if now - lastRefresh >= Config.RefreshMinutes * 60 then
            fillBoard(true)
            lastRefresh = now
            BountyLog.Event('boardRefresh', nil, nil, locale('wh_board_refreshed', Config.BoardSize))
        end
    end
end)

local function dropContract(src)
    local c = Contracts[src]
    if c then
        local ent = getTargetEntity(c)
        if ent then DeleteEntity(ent) end
        Board[c.poster.id] = nil
        Contracts[src] = nil
    end
end

-- character logout / switch: the client loses its contract state, so drop it server-side too
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    dropContract(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    dropContract(src)
    Cooldowns[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, c in pairs(Contracts) do
        local ent = getTargetEntity(c)
        if ent then DeleteEntity(ent) end
    end
end)
