-- Staff panel: every action is a single server callback ('rsg-gangs:server:admin') that is checked
-- against Config.Admin.permission before anything runs. The NUI only sends requests.
local RSGCore = exports['rsg-core']:GetCoreObject()

local function cfg()
    return Config.Admin or {}
end

local function isAdmin(src)
    local c = cfg()
    if not c.enabled then return false end
    return RSGCore.Functions.HasPermission(src, c.permission or 'admin') == true
end

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function fail(key, ...)
    return { ok = false, error = locale(key, ...) }
end

local function adminName(src)
    return GetPlayerName(src) or ('#' .. tostring(src))
end

-- Writes the action to the gang's activity log (shown as "Staff: ...") and to rsg-log.
local function audit(src, gang, text)
    RSGGangs.Log('Gang admin', ('%s (%s) on %s: %s'):format(adminName(src), src, gang and gang.name or '-', text))
    if gang and RSGGangs.Gangs[gang.name] then
        RSGGangs.AddLog(gang, nil, 'admin', text)
    end
end

local function done(src, gang, key, ...)
    local text = locale(key, ...)
    audit(src, gang, text)
    return { ok = true, message = text }
end

local function getGang(name)
    if type(name) ~= 'string' then return nil end
    return RSGGangs.Gangs[name]
end

local function hexColor(value)
    if type(value) ~= 'string' or not value:match('^#%x%x%x%x%x%x$') then return nil end
    return value:lower()
end

local function wholeNumber(value, min, max)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge or n ~= math.floor(n) then return nil end
    if n < min or n > max then return nil end
    return n
end

local function rankLabel(gang, level)
    local info = gang and RSGGangs.RankInfo(gang.name, level)
    return info and info.name or tostring(level)
end

local function playerBySource(id)
    id = wholeNumber(id, 1, 65535)
    return id and RSGCore.Functions.GetPlayer(id) or nil
end

---------------------------------------------------------------------
-- Payload builders
---------------------------------------------------------------------
local function turfCounts()
    local counts = {}
    for _, t in ipairs(RSGGangs.AdminTerritories and RSGGangs.AdminTerritories() or {}) do
        if t.owner then counts[t.owner] = (counts[t.owner] or 0) + 1 end
    end
    return counts
end

local function ownerName(gang)
    local member = gang.owner and gang.members[gang.owner]
    return member and (member.name or gang.owner) or nil
end

local function summary(gang, turf)
    local members, online, equipment = 0, 0, 0
    for _, m in pairs(gang.members) do
        members = members + 1
        if m.source then online = online + 1 end
    end
    for _, list in pairs(gang.equipment) do equipment = equipment + #list end
    return {
        name = gang.name, label = gang.label, color = gang.color, tag = gang.tag, bank = gang.bank,
        members = members, online = online, equipment = equipment, turf = turf[gang.name] or 0,
        owner = gang.owner, ownerName = ownerName(gang), stashTier = gang.stashTier or 'small',
        hasWagon = gang.wagon ~= nil,
    }
end

local function tierList()
    local out = {}
    for _, tier in ipairs((Config.GangStash and Config.GangStash.tiers) or {}) do
        out[#out + 1] = { id = tier.id, label = tier.label }
    end
    return out
end

local function rankList()
    local out = {}
    for _, rank in ipairs(Config.Ranks) do
        out[#out + 1] = { name = tostring(rank.weight), label = rank.label, weight = rank.weight, isLeader = rank.isLeader == true }
    end
    return out
end

local function snapshot()
    local turf = turfCounts()
    local gangs, members, online, bank = {}, 0, 0, 0
    for _, gang in pairs(RSGGangs.Gangs) do
        local row = summary(gang, turf)
        gangs[#gangs + 1] = row
        members, online, bank = members + row.members, online + row.online, bank + (gang.bank or 0)
    end
    table.sort(gangs, function(a, b) return a.label:lower() < b.label:lower() end)

    local tags = Config.Tags or {}
    return {
        ok = true,
        gangs = gangs,
        stats = { gangs = #gangs, members = members, online = online, bank = bank },
        territories = (Config.Territories and Config.Territories.enabled and RSGGangs.AdminTerritories) and RSGGangs.AdminTerritories() or nil,
        ranks = rankList(),
        tiers = tierList(),
        colors = Config.GangColors,
        limits = {
            maxMembers = Config.MaxMembers, minName = Config.MinNameLength, maxName = Config.MaxNameLength,
            maxBank = Config.MaxBankBalance, tagsEnabled = tags.enabled == true,
            tagMin = tags.minLength or 2, tagMax = tags.maxLength or 5,
            upkeepEnabled = Config.Upkeep ~= nil and Config.Upkeep.enabled == true,
        },
    }
end

local function detail(gang)
    local turf = turfCounts()
    local out = summary(gang, turf)

    local members = {}
    for citizenid, m in pairs(gang.members) do
        local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
        m.source = Player and Player.PlayerData.source or nil
        local info = RSGGangs.RankInfo(gang.name, m.level)
        members[#members + 1] = {
            citizenid = citizenid, name = m.name or citizenid, rank = tostring(m.level), rankLabel = info and info.name or tostring(m.level),
            weight = m.level, isLeader = info ~= nil and info.boss == true,
            online = m.source ~= nil, source = m.source, isOwner = citizenid == gang.owner,
        }
    end
    table.sort(members, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.name:lower() < b.name:lower()
    end)
    out.memberList = members

    local equipment = {}
    for _, item in ipairs(Config.GangEquipment or {}) do
        local list = gang.equipment[item.id]
        equipment[#equipment + 1] = { id = item.id, label = item.label, count = list and #list or 0, max = item.maxDeployed or 1 }
    end
    out.equipmentList = equipment

    local owned = {}
    for _, t in ipairs(RSGGangs.AdminTerritories and RSGGangs.AdminTerritories() or {}) do
        if t.owner == gang.name then owned[#owned + 1] = { id = t.id, label = t.label } end
    end
    out.territoryList = owned

    local up = Config.Upkeep
    out.upkeep = (up and up.enabled) and {
        due = gang.upkeepDue, missed = gang.upkeepMissed or 0, cost = up.cost, maxMissed = up.maxMissed,
    } or nil

    local stashLabel
    for _, tier in ipairs((Config.GangStash and Config.GangStash.tiers) or {}) do
        if tier.id == gang.stashTier then stashLabel = tier.label end
    end
    out.stashLabel = stashLabel
    return out
end

---------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------
local H = {}

H.snapshot = function()
    return snapshot()
end

H.gang = function(_, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end

    local rows = MySQL.query.await(
        'SELECT actor, action, detail, UNIX_TIMESTAMP(created_at) AS ts FROM rsg_gang_logs WHERE gang_name = ? ORDER BY id DESC LIMIT ?',
        { gang.name, math.max(1, math.min(cfg().logLines or 100, 500)) }) or {}
    return { ok = true, gang = detail(gang), logs = rows }
end

H.players = function()
    local out = {}
    for src, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        local citizenid = Player.PlayerData.citizenid
        local gang = RSGGangs.FindGangByMember(citizenid)
        out[#out + 1] = {
            id = src, citizenid = citizenid, name = RSGGangs.CharName(Player),
            gang = gang and gang.name or nil, gangLabel = gang and gang.label or nil,
            rank = gang and tostring(gang.members[citizenid].level) or nil,
            rankLabel = gang and rankLabel(gang, gang.members[citizenid].level) or nil,
        }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return { ok = true, players = out }
end

H.createGang = function(src, p)
    local label = RSGGangs.CleanLabel(p.label)
    if not label then return fail('error_invalid_name', Config.MinNameLength, Config.MaxNameLength) end

    local color = hexColor(p.color) or Config.GangColors[1]

    local leader, owner
    if p.leader ~= nil and p.leader ~= '' then
        leader = playerBySource(p.leader)
        if not leader then return fail('error_player_not_found') end
        if RSGGangs.FindGangByMember(leader.PlayerData.citizenid) then return fail('error_player_already_gang') end
        owner = leader.PlayerData.citizenid
    end

    -- rsg-society creates the gang; its id is made from the label
    local gang, reason = RSGGangs.CreateGangRecord(label, color, owner)
    if not gang then
        if reason == 'sv_err_gang_taken' then return fail('error_gang_exists') end
        return fail('error_generic')
    end

    if leader then
        RSGGangs.Notify(leader.PlayerData.source, locale('success_gang_created', label), 'success')
        RSGGangs.AddLog(gang, owner, 'created')
    end
    RSGGangs.BroadcastGangUpdate(gang)
    local res = done(src, gang, 'admin_created', label)
    res.name = gang.name
    return res
end

H.deleteGang = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local label, name = gang.label, gang.name
    if not RSGGangs.DestroyGang(gang, 'notify_admin_outfit_disbanded', 'inform') then return fail('error_generic') end
    if RSGGangs.PushTerritories then RSGGangs.PushTerritories() end
    local text = locale('admin_deleted', label)
    RSGGangs.Log('Gang admin', ('%s (%s) disbanded %s'):format(adminName(src), src, name))
    return { ok = true, message = text, removed = name }
end

H.renameGang = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local label = RSGGangs.CleanLabel(p.label)
    if not label then return fail('error_invalid_name', Config.MinNameLength, Config.MaxNameLength) end
    local saved, reason = RSGGangs.SetGangInfo(gang, { label = label })
    if not saved then return fail(reason == 'sv_err_gang_taken' and 'error_gang_exists' or 'error_generic') end
    if RSGGangs.PushTerritories then RSGGangs.PushTerritories() end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_renamed', label)
end

H.setTag = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local tags = Config.Tags
    if not (tags and tags.enabled) then return fail('admin_err_disabled') end
    local tag = type(p.tag) == 'string' and p.tag:upper():gsub('[^%w]', '') or ''
    if tag ~= '' and (#tag < (tags.minLength or 2) or #tag > (tags.maxLength or 5)) then
        return fail('error_tag_invalid', tags.minLength or 2, tags.maxLength or 5)
    end
    local value = tag ~= '' and tag or nil
    if not RSGGangs.SetGangInfo(gang, { tag = value or '' }) then return fail('error_generic') end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_tag_set', value or '-')
end

H.setColor = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local color = hexColor(p.color)
    if not color then return fail('admin_err_color') end
    -- rsg-society only accepts the colours from its own palette
    if not RSGGangs.SetGangInfo(gang, { color = color }) then return fail('admin_err_color') end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_color_set')
end

H.bank = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local mode = p.mode
    local amount = wholeNumber(p.amount, mode == 'set' and 0 or 1, Config.MaxBankBalance)
    if not amount or (mode ~= 'add' and mode ~= 'remove' and mode ~= 'set') then return fail('error_invalid_amount') end

    local delta = mode == 'add' and amount or mode == 'remove' and -amount or (amount - gang.bank)
    if delta ~= 0 and not RSGGangs.AdjustBank(gang, delta) then return fail('admin_err_bank') end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_bank_set', gang.bank)
end

H.setStash = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    if not (Config.GangStash and Config.GangStash.enabled) then return fail('admin_err_disabled') end
    local index = type(p.tier) == 'string' and RSGGangs.StashTierIndex(p.tier)
    if not index then return fail('error_generic') end
    local tier = Config.GangStash.tiers[index]
    if not RSGGangs.DbOk('UPDATE rsg_gangs SET stash_tier = ? WHERE name = ?', { tier.id, gang.name }) then return fail('error_generic') end
    gang.stashTier = tier.id
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_stash_set', tier.label)
end

H.resetUpkeep = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    if not (Config.Upkeep and Config.Upkeep.enabled) then return fail('admin_err_disabled') end
    if not RSGGangs.DbOk('UPDATE rsg_gangs SET upkeep_due = NULL, upkeep_missed = 0 WHERE name = ?', { gang.name }) then
        return fail('error_generic')
    end
    gang.upkeepDue, gang.upkeepMissed = nil, 0 -- the upkeep loop sets a fresh due date within a minute
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_upkeep_reset')
end

H.addMember = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local Player = playerBySource(p.serverId)
    if not Player then return fail('error_player_not_found') end

    local level = RSGGangs.ResolveLevel(gang.name, p.rank)
    if not level then return fail('error_invalid_rank') end
    local top = RSGGangs.TopLevels(gang.name)
    if top and level >= top then return fail('admin_err_leader_rank') end
    if RSGGangs.FindGangByMember(Player.PlayerData.citizenid) then return fail('error_player_already_gang') end
    if Config.MaxMembers > 0 and RSGGangs.MemberCount(gang) >= Config.MaxMembers then return fail('error_max_members') end

    if not RSGGangs.InsertMember(gang, Player, level) then return fail('error_generic') end
    local target = Player.PlayerData.source
    RSGGangs.Notify(target, locale('success_joined_gang', gang.label), 'success')
    RSGGangs.AddLog(gang, Player.PlayerData.citizenid, 'joined')
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'notify_admin_member_added', RSGGangs.CharName(Player), gang.label)
end

H.removeMember = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local citizenid = p.citizenid
    local member = type(citizenid) == 'string' and gang.members[citizenid]
    if not member then return fail('error_target_not_in_gang') end

    if not RSGGangs.RemoveMember(gang, citizenid) then return fail('error_generic') end

    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        local target = Player.PlayerData.source
        RSGGangs.Notify(target, locale('success_kicked'), 'inform')
        TriggerClientEvent('rsg-gangs:client:setState', target, { inGang = false })
    end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_member_removed', member.name or citizenid)
end

H.setRank = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local member = type(p.citizenid) == 'string' and gang.members[p.citizenid]
    if not member then return fail('error_target_not_in_gang') end

    local level = RSGGangs.ResolveLevel(gang.name, p.rank)
    local newInfo = level and RSGGangs.RankInfo(gang.name, level)
    if not newInfo then return fail('error_invalid_rank') end
    if newInfo.boss then return fail('admin_err_leader_rank') end
    local current = RSGGangs.RankInfo(gang.name, member.level)
    if current and current.boss then return fail('admin_err_leader_locked') end
    if member.level == level then return { ok = true, message = locale('admin_rank_set', member.name or p.citizenid, newInfo.name) } end

    local ok, res = pcall(function() return exports['rsg-society']:SetMemberLevel(gang.name, p.citizenid, level) end)
    if not ok or not res then return fail('error_generic') end
    RSGGangs.SyncMembers(gang)

    local Player = RSGCore.Functions.GetPlayerByCitizenId(p.citizenid)
    if Player then RSGGangs.Notify(Player.PlayerData.source, locale('admin_notify_rank', newInfo.name), 'inform') end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_rank_set', member.name or p.citizenid, newInfo.name)
end

H.transferLeader = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local member = type(p.citizenid) == 'string' and gang.members[p.citizenid]
    if not member then return fail('error_target_not_in_gang') end

    local top, below = RSGGangs.TopLevels(gang.name)
    if not top or not below then return fail('error_rank_limit') end
    if member.level == top and gang.owner == p.citizenid then return fail('error_generic') end

    local ok, errKey = RSGGangs.HandOverLeadership(gang, p.citizenid, nil)
    if not ok then return fail(errKey) end
    -- anyone else still on the top rank steps down one rank
    for citizenid, m in pairs(gang.members) do
        if citizenid ~= p.citizenid and m.level == top then
            pcall(function() exports['rsg-society']:SetMemberLevel(gang.name, citizenid, below) end)
        end
    end
    RSGGangs.SyncMembers(gang)

    local Player = RSGCore.Functions.GetPlayerByCitizenId(p.citizenid)
    if Player then RSGGangs.Notify(Player.PlayerData.source, locale('notify_now_leader', gang.label), 'inform') end
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_leader_set', member.name or p.citizenid)
end

H.setWagonHere = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return fail('error_generic') end
    if not RSGGangs.SetWagonLocation(gang, GetEntityCoords(ped), GetEntityHeading(ped)) then return fail('error_generic') end
    RSGGangs.DeleteGangWagon(gang.name) -- respawns at the new spot when someone is near
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'notify_admin_wagon_set', gang.label)
end

H.clearWagon = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    if not gang.wagon then return fail('admin_err_no_wagon') end
    if not RSGGangs.DbOk('UPDATE rsg_gangs SET wagon_x = NULL, wagon_y = NULL, wagon_z = NULL, wagon_heading = NULL WHERE name = ?', { gang.name }) then
        return fail('error_generic')
    end
    gang.wagon = nil
    RSGGangs.DeleteGangWagon(gang.name)
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_wagon_cleared')
end

H.packEquipment = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    local removed = RSGGangs.AdminClearEquipment(gang.name)
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_equipment_packed', removed)
end

H.clearRivals = function(src, p)
    local gang = getGang(p.name)
    if not gang then return fail('error_gang_not_found') end
    if RSGGangs.ClearRivals then RSGGangs.ClearRivals(gang.name) end
    RSGGangs.DbOk('DELETE FROM rsg_gang_rivals WHERE gang_name = ? OR rival_name = ?', { gang.name, gang.name })
    RSGGangs.BroadcastGangUpdate(gang)
    return done(src, gang, 'admin_rivals_cleared')
end

H.setTerritory = function(src, p)
    if not (Config.Territories and Config.Territories.enabled) then return fail('admin_err_disabled') end
    local id = type(p.id) == 'string' and p.id or nil
    local label
    for _, t in ipairs(RSGGangs.AdminTerritories()) do
        if t.id == id then label = t.label end
    end
    if not label then return fail('admin_err_territory') end

    local gang
    if p.gang ~= nil and p.gang ~= '' then
        gang = getGang(p.gang)
        if not gang then return fail('error_gang_not_found') end
    end
    if not RSGGangs.AdminSetTerritory(id, gang and gang.name or nil) then return fail('error_generic') end

    for _, g in pairs(RSGGangs.Gangs) do RSGGangs.BroadcastGangUpdate(g) end
    if gang then return done(src, gang, 'admin_territory_set', label, gang.label) end
    local text = locale('admin_territory_freed', label)
    RSGGangs.Log('Gang admin', ('%s (%s): %s'):format(adminName(src), src, text))
    return { ok = true, message = text }
end

H.teleport = function(src, p)
    local x, y, z
    if p.kind == 'wagon' then
        local gang = getGang(p.name)
        if not gang then return fail('error_gang_not_found') end
        if not gang.wagon then return fail('admin_err_no_wagon') end
        x, y, z = gang.wagon.x, gang.wagon.y, gang.wagon.z
    elseif p.kind == 'territory' then
        for _, t in ipairs(RSGGangs.AdminTerritories()) do
            if t.id == p.id then x, y, z = t.x, t.y, t.z end
        end
        if not x then return fail('admin_err_territory') end
    else
        return fail('error_generic')
    end
    TriggerClientEvent('rsg-gangs:client:adminTeleport', src, x, y, z)
    return { ok = true, message = locale('admin_teleported') }
end

local READ_ONLY = { snapshot = true, gang = true, players = true }

---------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-gangs:server:admin', function(src, cb, action, payload)
    if not isAdmin(src) then
        cb({ ok = false, error = locale('error_no_permission') })
        return
    end
    local handler = type(action) == 'string' and H[action] or nil
    if not handler then
        cb(fail('error_generic'))
        return
    end
    if RSGGangs.OnCooldown(src, 'admin:' .. action, READ_ONLY[action] and 150 or 500) then
        cb(fail('error_generic'))
        return
    end

    local ok, result = pcall(handler, src, type(payload) == 'table' and payload or {})
    if not ok then
        print(('^1[rsg-gangs] staff panel action "%s" failed: %s^7'):format(action, tostring(result)))
        result = fail('error_generic')
    end
    cb(result)
end)

if cfg().enabled then
    RSGCore.Commands.Add(cfg().command or 'gangadmin', locale('cmd_admin_help'), {}, false, function(source)
        TriggerClientEvent('rsg-gangs:client:openAdmin', source)
    end, cfg().permission or 'admin')
end
