local RSGCore = exports['rsg-core']:GetCoreObject()

local Queue      = {}  -- waiting entries
local Connecting = {}  -- [license] = expiry time (admitted, still loading in)
local Grace      = {}  -- [license] = expiry time (dropped recently)
local VipCache   = {}  -- [identifier] = { tier, name, expires }
local Ready      = false
local Maintenance = GetResourceKvpInt('maintenance') == 1
local AdmitTimes = {}  -- recent admit timestamps (os.time) for the wait estimate
local LastTier   = {}  -- [license] = tier the player was admitted with (for rewards)
local DiscordCache = {} -- [discord id] = { tier, expires }

local function dbg(...) if Config.Debug then print('^3[rsg-queue]^7', ...) end end

local function log(title, msg)
    if not Config.Log.enabled or GetResourceState('rsg-log') ~= 'started' then return end
    TriggerEvent('rsg-log:server:CreateLog', Config.Log.channel, title, 'white', msg)
end

local function notify(src, msg, ntype)
    if src == 0 then print('[rsg-queue] ' .. msg) return end
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('ui_title'), description = msg, type = ntype or 'inform' })
end

---------------------------------
-- database
---------------------------------
local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `rsg_queue_vip` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(80) NOT NULL,
    `name` VARCHAR(100) DEFAULT NULL,
    `tier` VARCHAR(30) NOT NULL,
    `expires_at` DATETIME DEFAULT NULL,
    `added_by` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local SCHEMA_REWARDS = [[
CREATE TABLE IF NOT EXISTS `rsg_queue_rewards` (
    `license` VARCHAR(80) NOT NULL,
    `last_claim` DATETIME NOT NULL,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local function ensureDatabase()
    local ok, err = pcall(function() MySQL.query.await(SCHEMA) MySQL.query.await(SCHEMA_REWARDS) end)
    if not ok then
        print('^1[rsg-queue] database setup failed: ' .. tostring(err) .. '^7')
        return false
    end
    print('^2[rsg-queue] database tables ready^7')
    return true
end

local function loadVips()
    local rows = MySQL.query.await([[SELECT identifier, name, tier, UNIX_TIMESTAMP(expires_at) AS expires
        FROM rsg_queue_vip WHERE expires_at IS NULL OR expires_at > NOW()]]) or {}
    local cache = {}
    for _, r in ipairs(rows) do
        if Config.Tiers[r.tier] then
            cache[r.identifier] = { tier = r.tier, name = r.name, expires = r.expires }
        end
    end
    VipCache = cache
    dbg(('loaded %d VIPs'):format(#rows))
    return true
end

---------------------------------
-- discord roles
---------------------------------
local function tierRank(tier)
    if tier == 'staff' then return Config.StaffPriority end
    return Config.Tiers[tier] and Config.Tiers[tier].priority or -1
end

-- returns the best tier key from the player's discord roles, or nil. blocks up to Config.Discord.timeout
local function getDiscordTier(src)
    local d = Config.Discord
    local token = GetConvar('rsgqueue_discord_token', '')
    if not d.enabled or token == '' or d.guildId == '' then return nil end
    local did = GetPlayerIdentifierByType(src, 'discord')
    did = did and did:gsub('^discord:', '')
    if not did or not did:match('^%d+$') then return nil end

    local c = DiscordCache[did]
    if c and c.expires > os.time() then return c.tier end

    local p = promise.new()
    PerformHttpRequest(('https://discord.com/api/v10/guilds/%s/members/%s'):format(d.guildId, did), function(status, body)
        local best
        if status == 200 and body then
            local ok, data = pcall(json.decode, body)
            if ok and data and data.roles then
                for _, role in ipairs(data.roles) do
                    local t = d.roles[role]
                    if t and tierRank(t) > tierRank(best) then best = t end
                end
            end
        elseif status ~= 404 then
            dbg(('discord lookup failed (%s)'):format(tostring(status)))
        end
        if p.state == 0 then p:resolve(best or false) end
    end, 'GET', '', { Authorization = 'Bot ' .. token })
    SetTimeout(d.timeout, function() if p.state == 0 then p:resolve(nil) end end)

    local res = Citizen.Await(p)
    if res == nil then return nil end -- timed out: do not cache
    DiscordCache[did] = { tier = res or nil, expires = os.time() + d.cacheMinutes * 60 }
    return res or nil
end

---------------------------------
-- priority & slots
---------------------------------
local function getPriority(src, license, discordTier)
    local info = { priority = 0, tier = nil, label = locale('card_standard'), reserved = false, grace = false }
    local now = os.time()

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        local vip = VipCache[id]
        if vip and (not vip.expires or vip.expires > now) then
            local t = Config.Tiers[vip.tier]
            if t and t.priority > info.priority then
                info.priority, info.tier, info.label, info.reserved = t.priority, vip.tier, t.label, t.reserved
            end
        end
    end

    if discordTier and discordTier ~= 'staff' then
        local t = Config.Tiers[discordTier]
        if t and t.priority > info.priority then
            info.priority, info.tier, info.label, info.reserved = t.priority, discordTier, t.label, t.reserved
        end
    end

    local isStaff = discordTier == 'staff' or (Config.StaffAce and IsPlayerAceAllowed(src, Config.StaffAce))
    if isStaff and Config.StaffPriority > info.priority then
        info.priority, info.tier, info.label, info.reserved = Config.StaffPriority, 'staff', locale('card_staff'), true
    end
    info.staff = isStaff


    if Config.Grace.enabled and Grace[license] then
        if Grace[license] > now then
            info.priority = info.priority + Config.Grace.priority
            info.grace = true
        else
            Grace[license] = nil
        end
    end
    return info
end

local function usedSlots()
    local n, now = #GetPlayers(), os.time()
    for lic, exp in pairs(Connecting) do
        if exp < now then Connecting[lic] = nil else n = n + 1 end
    end
    return n
end

local function hasSlot(entry)
    local max = GetConvarInt('sv_maxclients', 48)
    local limit = entry.reserved and max or (max - Config.ReservedSlots)
    return usedSlots() < limit
end

local function sortQueue()
    table.sort(Queue, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.joined < b.joined
    end)
end

local function removeEntry(entry)
    for i, e in ipairs(Queue) do
        if e == entry then table.remove(Queue, i) return end
    end
end

local function positionOf(entry)
    for i, e in ipairs(Queue) do if e == entry then return i end end
    return 0
end

local function fmtTime(sec)
    return ('%02d:%02d'):format(math.floor(sec / 60), sec % 60)
end

-- average seconds between recent admits, or nil when there is not enough data
local function admitInterval()
    local n = #AdmitTimes
    if n < 2 then return nil end
    return math.max(1, (AdmitTimes[n] - AdmitTimes[1]) / (n - 1))
end

local function recordAdmit()
    AdmitTimes[#AdmitTimes + 1] = os.time()
    while #AdmitTimes > math.max(2, Config.EstimateWindow) do table.remove(AdmitTimes, 1) end
end

-- players who joined before this entry but are behind it thanks to priority
local function skippedCount(entry)
    local n = 0
    for _, e in ipairs(Queue) do
        if e ~= entry and e.joined < entry.joined and e.priority < entry.priority then n = n + 1 end
    end
    return n
end

---------------------------------
-- adaptive card
---------------------------------
local function buildCard(entry)
    local body = {}
    local pos = positionOf(entry)
    local interval = admitInterval()
    local eta = entry.admit and fmtTime(0) or (interval and ('~' .. fmtTime(math.floor(interval * pos))) or locale('card_eta_unknown'))
    if Config.CardImage ~= '' then
        body[#body + 1] = { type = 'Image', url = Config.CardImage, horizontalAlignment = 'Center', size = 'Stretch' }
    end
    body[#body + 1] = { type = 'TextBlock', text = Config.ServerName, size = 'ExtraLarge', weight = 'Bolder', horizontalAlignment = 'Center', wrap = true }
    body[#body + 1] = { type = 'TextBlock', text = locale('card_title'):upper(), isSubtle = true, horizontalAlignment = 'Center', spacing = 'None' }
    body[#body + 1] = {
        type = 'TextBlock', size = 'Large', weight = 'Bolder', horizontalAlignment = 'Center', spacing = 'Medium',
        text = locale('card_position', pos, #Queue),
    }
    body[#body + 1] = {
        type = 'FactSet', spacing = 'Medium',
        facts = {
            { title = locale('card_tier_title'), value = entry.label },
            { title = locale('card_waited_title'), value = fmtTime(os.time() - entry.joined) },
            { title = locale('card_eta_title'), value = eta },
        },
    }
    if entry.grace then
        body[#body + 1] = { type = 'TextBlock', text = locale('card_grace'), color = 'Good', horizontalAlignment = 'Center', wrap = true }
    end
    local skipped = entry.tier and skippedCount(entry) or 0
    if skipped > 0 then
        body[#body + 1] = { type = 'TextBlock', text = locale('card_skipped', skipped), color = 'Good', horizontalAlignment = 'Center', wrap = true }
    end
    if not entry.tier then
        body[#body + 1] = { type = 'TextBlock', text = locale('tip_vip'), isSubtle = true, horizontalAlignment = 'Center', wrap = true, spacing = 'Medium' }
    end

    local actions = {}
    for _, l in ipairs(Config.Links) do
        actions[#actions + 1] = { type = 'Action.OpenUrl', title = l.title, url = l.url }
    end

    return json.encode({
        type = 'AdaptiveCard',
        ['$schema'] = 'http://adaptivecards.io/schemas/adaptive-card.json',
        version = '1.3',
        body = body,
        actions = actions,
    })
end

---------------------------------
-- connecting
---------------------------------
AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(locale('checking'))

    local waited = 0
    while not Ready and waited < 15000 do Wait(500) waited = waited + 500 end
    if not Ready then
        deferrals.done(locale('not_ready'))
        return
    end

    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then
        deferrals.done(locale('no_license'))
        return
    end

    -- drop any older entry for the same license (reconnect spam)
    for _, e in ipairs(Queue) do
        if e.license == license then e.replaced = true end
    end

    local info = getPriority(src, license, getDiscordTier(src))
    if not GetPlayerName(src) then return end -- left during the discord lookup

    if Maintenance and not (info.staff or (Config.Maintenance.allowVip and info.tier)) then
        deferrals.done(locale(Config.Maintenance.allowVip and 'maintenance_vip' or 'maintenance_staff'))
        return
    end

    local entry = {
        src = src, license = license, name = name, deferrals = deferrals, staff = info.staff,
        priority = info.priority, tier = info.tier, label = info.label,
        reserved = info.reserved, grace = info.grace, joined = os.time(),
    }
    Queue[#Queue + 1] = entry
    sortQueue()
    dbg(('%s queued (priority %d)'):format(name, entry.priority))

    local started    = GetGameTimer()
    local minCardMs  = math.max(0, (Config.MinCardTime or 0) * 1000)
    local nextCard   = 0

    local function freeHeldSlot()
        if entry.admit then Connecting[license] = nil end
    end

    while true do
        if entry.replaced then removeEntry(entry) freeHeldSlot() return end
        if Maintenance and not (entry.staff or (Config.Maintenance.allowVip and entry.tier)) then
            removeEntry(entry)
            freeHeldSlot()
            deferrals.done(locale(Config.Maintenance.allowVip and 'maintenance_vip' or 'maintenance_staff'))
            return
        end
        if entry.removed then
            removeEntry(entry)
            freeHeldSlot()
            deferrals.done(locale('removed_by_admin'))
            return
        end
        if not GetPlayerName(src) then -- left while waiting
            removeEntry(entry)
            freeHeldSlot()
            return
        end
        local now = GetGameTimer()
        -- admitted: let them in once the card has been on screen for MinCardTime
        if entry.admit and now - started >= minCardMs then
            removeEntry(entry)
            if entry.grace then Grace[license] = nil end
            LastTier[license] = entry.tier
            Connecting[license] = os.time() + Config.ConnectTimeout -- restart load-in timer from now
            deferrals.update(locale('joining'))
            Wait(500)
            deferrals.done()
            return
        end
        if now >= nextCard then
            deferrals.presentCard(buildCard(entry))
            nextCard = now + Config.UpdateInterval
        end
        Wait(250)
    end
end)

-- admit players while slots are free (fills every free slot each tick, highest priority first)
CreateThread(function()
    local lastSweep = 0
    while true do
        Wait(1000)
        if Ready and #Queue > 0 then
            sortQueue()
            for _, e in ipairs(Queue) do
                if not e.admit and not e.removed and not e.replaced and hasSlot(e) then
                    e.admit = true
                    Connecting[e.license] = os.time() + Config.ConnectTimeout
                    recordAdmit()
                    dbg(('admitting %s'):format(e.name))
                end
            end
        end
        -- sweep expired grace entries so the table does not grow forever
        local now = os.time()
        if now - lastSweep >= 60 then
            lastSweep = now
            for lic, exp in pairs(Grace) do if exp <= now then Grace[lic] = nil end end
        end
    end
end)

AddEventHandler('playerJoining', function()
    local license = GetPlayerIdentifierByType(source, 'license')
    if license then Connecting[license] = nil end
end)

AddEventHandler('playerDropped', function(reason)
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then return end
    Connecting[license] = nil
    -- no reconnect boost for players who quit on purpose or were kicked/banned
    reason = tostring(reason or ''):lower()
    local skip = reason:find('exiting') or reason:find('quit') or reason:find('kick') or reason:find('ban')
    if Config.Grace.enabled and not skip then
        Grace[license] = os.time() + Config.Grace.minutes * 60
    end
end)

---------------------------------
-- VIP rewards
---------------------------------
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local cfg = Config.VipRewards
    if not cfg.enabled or not Player then return end
    local src = Player.PlayerData.source
    local license = Player.PlayerData.license or GetPlayerIdentifierByType(src, 'license')
    local tier = license and LastTier[license]
    local reward = tier and cfg.tiers[tier]
    if not reward then return end
    local amount = math.floor(tonumber(reward.cash) or 0)
    if amount <= 0 then return end

    -- atomic cooldown: affectedRows is 1 (new row) or 2 (updated); 0 means still on cooldown
    local affected = MySQL.update.await([[INSERT INTO rsg_queue_rewards (license, last_claim) VALUES (?, NOW())
        ON DUPLICATE KEY UPDATE last_claim = IF(last_claim <= NOW() - INTERVAL ? HOUR, NOW(), last_claim)]],
        { license, math.max(1, math.floor(cfg.cooldownHours)) })
    if not affected or affected < 1 then return end

    Player.Functions.AddMoney('cash', amount, 'rsg-queue-vip-reward')
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('reward_title'), description = locale('reward_given', Config.Tiers[tier].label, amount), type = 'success', duration = 7000,
    })
    log('VIP Reward', ('%s (%s) received $%d for %s'):format(GetPlayerName(src) or '?', license, amount, tier))
end)

---------------------------------
-- maintenance
---------------------------------
local function setMaintenance(on, by)
    Maintenance = on and true or false
    SetResourceKvpInt('maintenance', Maintenance and 1 or 0)
    log('Maintenance', ('%s turned maintenance %s'):format(by, Maintenance and 'ON' or 'OFF'))
    return true, locale(Maintenance and 'maint_on' or 'maint_off')
end

---------------------------------
-- VIP management
---------------------------------
local function validIdentifier(id)
    return type(id) == 'string' and #id <= 80 and id:match('^%w+:%w+$') ~= nil
end

local function addVip(identifier, tier, days, name, by)
    if not validIdentifier(identifier) then return false, locale('invalid_target') end
    if not Config.Tiers[tier] then return false, locale('invalid_tier', tostring(tier)) end
    days = math.floor(tonumber(days) or 0)
    if days < 0 or days > 3650 then days = 0 end
    name = type(name) == 'string' and name:sub(1, 100) or nil
    if name == '' then name = nil end

    if days > 0 then
        MySQL.query.await([[INSERT INTO rsg_queue_vip (identifier, name, tier, expires_at, added_by)
            VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY), ?)
            ON DUPLICATE KEY UPDATE tier = VALUES(tier), expires_at = VALUES(expires_at),
            name = COALESCE(VALUES(name), name), added_by = VALUES(added_by)]],
            { identifier, name, tier, days, by })
    else
        MySQL.query.await([[INSERT INTO rsg_queue_vip (identifier, name, tier, expires_at, added_by)
            VALUES (?, ?, ?, NULL, ?)
            ON DUPLICATE KEY UPDATE tier = VALUES(tier), expires_at = NULL,
            name = COALESCE(VALUES(name), name), added_by = VALUES(added_by)]],
            { identifier, name, tier, by })
    end
    loadVips()
    log('VIP Added', ('%s set %s (%s) to %s for %s'):format(by, identifier, name or '-', tier, days > 0 and (days .. ' days') or 'permanent'))
    return true, locale('vip_added', identifier, Config.Tiers[tier].label)
end

local function removeVip(identifier, by)
    if not validIdentifier(identifier) then return false, locale('invalid_target') end
    local affected = MySQL.update.await('DELETE FROM rsg_queue_vip WHERE identifier = ?', { identifier })
    loadVips()
    if not affected or affected < 1 then return false, locale('vip_not_found', identifier) end
    log('VIP Removed', ('%s removed %s'):format(by or 'unknown', identifier))
    return true, locale('vip_removed', identifier)
end

-- server id -> license identifier + name, or pass an identifier through
local function resolveTarget(arg)
    local id = tonumber(arg)
    if id and GetPlayerName(id) then
        return GetPlayerIdentifierByType(id, 'license'), GetPlayerName(id)
    end
    if validIdentifier(arg) then return arg, nil end
    return nil
end

local function byName(src)
    if src == 0 then return 'console' end
    return GetPlayerName(src) or tostring(src)
end

---------------------------------
-- admin panel data
---------------------------------
local function getAdminData()
    sortQueue()
    local now, q = os.time(), {}
    for i, e in ipairs(Queue) do
        q[#q + 1] = { pos = i, src = e.src, license = e.license, tier = e.tier, name = e.name, label = e.label, priority = e.priority, waited = fmtTime(now - e.joined), grace = e.grace }
    end
    local rows = MySQL.query.await([[SELECT identifier, name, tier, DATE_FORMAT(expires_at, '%Y-%m-%d %H:%i') AS expires,
        (expires_at IS NOT NULL AND expires_at <= NOW()) AS expired, added_by FROM rsg_queue_vip ORDER BY tier, name]]) or {}
    local tiers = {}
    for k, t in pairs(Config.Tiers) do tiers[#tiers + 1] = { key = k, label = t.label, priority = t.priority } end
    table.sort(tiers, function(a, b) return a.priority > b.priority end)
    for _, r in ipairs(rows) do
        r.label = Config.Tiers[r.tier] and Config.Tiers[r.tier].label or r.tier
        r.expired = r.expired == 1 or r.expired == true
    end
    return {
        queue = q, vips = rows, tiers = tiers,
        online = #GetPlayers(), max = GetConvarInt('sv_maxclients', 48), reserved = Config.ReservedSlots,
        maintenance = Maintenance,
    }
end

RSGCore.Functions.CreateCallback('rsg-queue:server:getAdminData', function(source, cb)
    if not RSGCore.Functions.HasPermission(source, Config.AdminPermission) then return cb(nil) end
    cb(getAdminData())
end)

RSGCore.Functions.CreateCallback('rsg-queue:server:adminAction', function(source, cb, action, data)
    if not RSGCore.Functions.HasPermission(source, Config.AdminPermission) then
        return cb({ ok = false, msg = locale('no_permission') })
    end
    data = type(data) == 'table' and data or {}
    local ok, msg = false, locale('invalid_target')

    if action == 'vip_add' then
        ok, msg = addVip(data.identifier, data.tier, data.days, data.name, byName(source))
    elseif action == 'vip_remove' then
        ok, msg = removeVip(data.identifier, byName(source))
    elseif action == 'maintenance' then
        ok, msg = setMaintenance(not Maintenance, byName(source))
    elseif action == 'queue_front' or action == 'queue_remove' then
        local target = tonumber(data.src)
        for _, e in ipairs(Queue) do
            if e.src == target then
                if action == 'queue_front' then
                    local top = 0
                    for _, o in ipairs(Queue) do top = math.max(top, o.priority) end
                    e.priority, e.reserved = top + 1, true
                    ok, msg = true, locale('queue_moved')
                    log('Queue', ('%s moved %s to the front'):format(byName(source), e.name))
                else
                    e.removed = true
                    ok, msg = true, locale('queue_removed')
                    log('Queue', ('%s removed %s from the queue'):format(byName(source), e.name))
                end
                break
            end
        end
    end
    cb({ ok = ok, msg = msg, data = getAdminData() })
end)

---------------------------------
-- commands
---------------------------------
RSGCore.Commands.Add('queue', locale('cmd_queue'), {}, false, function(source)
    TriggerClientEvent('rsg-queue:client:openAdmin', source, getAdminData())
end, Config.AdminPermission)

RSGCore.Commands.Add('vipadd', locale('cmd_vipadd'), {
    { name = 'target', help = locale('arg_target') },
    { name = 'tier', help = locale('arg_tier') },
    { name = 'days', help = locale('arg_days') },
}, true, function(source, args)
    local identifier, name = resolveTarget(args[1])
    if not identifier then return notify(source, locale('invalid_target'), 'error') end
    local ok, msg = addVip(identifier, args[2], args[3], name, byName(source))
    notify(source, msg, ok and 'success' or 'error')
end, Config.AdminPermission)

RSGCore.Commands.Add('vipremove', locale('cmd_vipremove'), {
    { name = 'target', help = locale('arg_target') },
}, true, function(source, args)
    local identifier = resolveTarget(args[1])
    if not identifier then return notify(source, locale('invalid_target'), 'error') end
    local ok, msg = removeVip(identifier, byName(source))
    notify(source, msg, ok and 'success' or 'error')
end, Config.AdminPermission)

RSGCore.Commands.Add('queuemaint', locale('cmd_maint'), {
    { name = 'state', help = locale('arg_state') },
}, false, function(source, args)
    local a = args[1] and args[1]:lower()
    local on = (a == 'on') or (a ~= 'off' and not Maintenance)
    local _, msg = setMaintenance(on, byName(source))
    notify(source, msg, 'inform')
end, Config.AdminPermission)

-- console only (txAdmin / Tebex): queuevip add <identifier|id> <tier> [days] | queuevip remove <identifier|id>
RegisterCommand('queuevip', function(source, args)
    if source ~= 0 then return end
    local identifier, name = resolveTarget(args[2])
    if not identifier then return print('[rsg-queue] ' .. locale('invalid_target')) end
    local ok, msg
    if args[1] == 'add' then
        ok, msg = addVip(identifier, args[3], args[4], name, 'console')
    elseif args[1] == 'remove' then
        ok, msg = removeVip(identifier, 'console')
    else
        return print('[rsg-queue] usage: queuevip add <identifier|id> <tier> [days] | queuevip remove <identifier|id>')
    end
    print(('[rsg-queue] %s%s^7'):format(ok and '^2' or '^1', msg))
end, true)

---------------------------------
-- exports
---------------------------------
exports('AddVip', function(identifier, tier, days, name) return addVip(identifier, tier, days, name, GetInvokingResource() or 'export') end)
exports('RemoveVip', function(identifier) return removeVip(identifier, GetInvokingResource() or 'export') end)
exports('SetMaintenance', function(on) return setMaintenance(on, GetInvokingResource() or 'export') end)
exports('IsMaintenance', function() return Maintenance end)
exports('IsVip', function(identifier)
    local v = VipCache[identifier]
    if not v or (v.expires and v.expires <= os.time()) then return false end
    return true, v.tier, v.expires
end)
exports('GetQueueSize', function() return #Queue end)
exports('GetQueue', function()
    local q = {}
    for i, e in ipairs(Queue) do q[i] = { name = e.name, tier = e.tier, priority = e.priority, joined = e.joined } end
    return q
end)

-- tell waiting players the queue is restarting instead of leaving them on a frozen card
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in ipairs(Queue) do
        if e.deferrals then pcall(e.deferrals.done, locale('restarting')) end
    end
end)

---------------------------------
-- startup
---------------------------------
CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    local ok, err = pcall(loadVips)
    if not ok then return print('^1[rsg-queue] could not load VIPs: ' .. tostring(err) .. '^7') end
    Ready = true
    while true do
        Wait(Config.VipRefresh * 1000)
        loadVips()
    end
end)
