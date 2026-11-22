local RSGCore = Soc.Core

local PendingInvites = {} -- [target src] = { society, from (src), fromName, level, expires }

-----------------------------------------------------------------------
-- Hierarchy rules
-----------------------------------------------------------------------
--- May an actor change a member who sits at targetLevel?
function Soc.CanManage(acc, targetLevel)
    if targetLevel < acc.level then return true end
    return Config.AllowEqualRank and acc.boss and targetLevel <= acc.level or false
end

--- Highest rank level an actor may hand out
function Soc.MaxAssignable(acc)
    if Config.AllowEqualRank and acc.boss then return acc.level end
    return acc.level - 1
end

-----------------------------------------------------------------------
-- rsg-core gang bridge: society owns gang membership, rsg-core just mirrors it
-----------------------------------------------------------------------
--- pushes the ranks of one gang society into rsg-core's shared gang table
function Soc.SyncGangDef(name)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' then return end
    local grades = {}
    for _, g in ipairs(Soc.Grades(name)) do
        grades[tostring(g.level)] = { name = g.name, payment = g.payment / 100, isboss = g.boss or nil }
    end
    pcall(function()
        exports['rsg-core']:SetGangs({ [name] = { label = s.label, grades = grades } })
    end)
end

--- puts one player's rsg-core gang in line with society membership (works for online players only)
function Soc.ApplyMember(cid)
    local Player = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if not Player then return end
    local gang = Soc.GangOf[cid]
    local current = Player.PlayerData.gang
    if gang then
        local m = Soc.Members[gang] and Soc.Members[gang][cid]
        if m and (not current or current.name ~= gang or tonumber(current.grade and current.grade.level) ~= m.level) then
            Player.Functions.SetGang(gang, m.level)
        end
    elseif current and current.name and current.name ~= 'none' and Soc.S[current.name] and Soc.S[current.name].type == 'gang' then
        Player.Functions.SetGang('none', 0)
    end
end

Soc.OnStart(20, function()
    for name, s in pairs(Soc.S) do
        if s.type == 'gang' then Soc.SyncGangDef(name) end
    end
    for _, src in ipairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(tonumber(src))
        if Player then Soc.ApplyMember(Player.PlayerData.citizenid) end
    end
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Soc.Ready or not Player then return end
    Soc.ApplyMember(Player.PlayerData.citizenid)
end)

-----------------------------------------------------------------------
-- Member list
-----------------------------------------------------------------------
--- members of a society with what the actor may do to each of them
function Soc.MemberRows(name, acc, myCid)
    local rows = {}
    for _, m in ipairs(Soc.GetMembers(name)) do
        rows[#rows + 1] = {
            cid = m.citizenid, name = m.name, level = m.level, grade = m.grade, boss = m.boss, online = m.online,
            self = m.citizenid == myCid,
            canManage = m.citizenid ~= myCid and Soc.CanManage(acc, m.level) or false,
        }
    end
    return rows
end

-----------------------------------------------------------------------
-- Changing members
-----------------------------------------------------------------------
local function gangMemberCount(name)
    local n = 0
    for _ in pairs(Soc.Members[name] or {}) do n = n + 1 end
    return n
end
Soc.GangMemberCount = gangMemberCount

--- Adds a player to a gang society at a level. Returns ok, reason.
function Soc.AddGangMember(name, cid, charName, level)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' then return false, 'sv_err_unknown' end
    if Soc.GangOf[cid] then return false, 'sv_err_in_gang' end
    if Config.Gang.MaxMembers > 0 and gangMemberCount(name) >= Config.Gang.MaxMembers then return false, 'sv_err_gang_full' end
    if not Soc.GradeOf(name, level) then return false, 'sv_err_bad_rank' end
    Soc.Members[name][cid] = { level = level, name = charName }
    Soc.GangOf[cid] = name
    MySQL.insert('INSERT INTO rsg_society_members (citizenid, society, level, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE society = VALUES(society), level = VALUES(level), name = VALUES(name)', { cid, name, level, Soc.Trunc(charName, 100) })
    Soc.ApplyMember(cid)
    TriggerEvent('rsg-society:server:memberJoined', name, cid, level)
    return true
end

--- Removes a player from a gang society. Returns true when they were a member.
function Soc.RemoveGangMember(name, cid)
    local list = Soc.Members[name]
    if not list or not list[cid] then return false end
    list[cid] = nil
    Soc.GangOf[cid] = nil
    MySQL.update('DELETE FROM rsg_society_members WHERE citizenid = ?', { cid })
    Soc.ApplyMember(cid)
    TriggerEvent('rsg-society:server:memberLeft', name, cid)
    return true
end

function Soc.SetGangLevel(name, cid, level)
    local m = Soc.Members[name] and Soc.Members[name][cid]
    if not m or not Soc.GradeOf(name, level) then return false end
    m.level = level
    MySQL.update('UPDATE rsg_society_members SET level = ? WHERE citizenid = ?', { level, cid })
    Soc.ApplyMember(cid)
    TriggerEvent('rsg-society:server:rankChanged', name, cid, level)
    return true
end

--- Gives a job to a player through rsg-core multi-job. Returns ok, reasonKey.
function Soc.AddJobMember(name, cid, level)
    local ok, reason = exports['rsg-core']:AddPlayerJob(cid, name, level)
    if not ok then
        if reason == 'max_jobs' then return false, 'sv_err_max_jobs' end
        if reason == 'invalid_grade' then return false, 'sv_err_bad_rank' end
        return false, 'sv_err_unknown'
    end
    local Player = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if Player and Player.PlayerData.job.name == 'unemployed' then
        Player.Functions.SetJob(name, level)
    end
    TriggerEvent('rsg-society:server:memberJoined', name, cid, level)
    return true
end

function Soc.RemoveJobMember(name, cid)
    local ok = exports['rsg-core']:RemovePlayerJob(cid, name)
    if ok then TriggerEvent('rsg-society:server:memberLeft', name, cid) end
    return ok
end

function Soc.SetJobLevel(name, cid, level)
    local ok = exports['rsg-core']:AddPlayerJob(cid, name, level)
    if ok then TriggerEvent('rsg-society:server:rankChanged', name, cid, level) end
    return ok
end

-----------------------------------------------------------------------
-- Invites
-----------------------------------------------------------------------
function Soc.SendInvite(src, targetSrc, name, level)
    local From = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetSrc)
    if not From or not Target then return false, 'sv_err_player' end
    local existing = PendingInvites[targetSrc]
    if existing and existing.expires > os.time() then return false, 'sv_err_invite_pending' end
    PendingInvites[targetSrc] = {
        society = name, from = src, fromName = Soc.PlayerName(From), level = level,
        expires = os.time() + Config.Gang.InviteExpireSeconds,
    }
    TriggerClientEvent('rsg-society:client:invite', targetSrc, { society = Soc.Label(name), from = Soc.PlayerName(From), seconds = Config.Gang.InviteExpireSeconds })
    return true
end

RegisterNetEvent('rsg-society:server:inviteReply', function(accepted)
    local src = source
    local invite = PendingInvites[src]
    PendingInvites[src] = nil
    if not invite then return end
    if invite.expires < os.time() then
        if accepted then Soc.Notify(src, Soc.Label(invite.society), locale('sv_err_invite_gone'), 'error') end
        return
    end
    local Target = RSGCore.Functions.GetPlayer(src)
    local s = Soc.S[invite.society]
    if not Target or not s then return end

    local From = RSGCore.Functions.GetPlayer(invite.from)
    if not accepted then
        if From then Soc.Notify(invite.from, Soc.Label(invite.society), locale('sv_invite_declined', Soc.PlayerName(Target)), 'error') end
        return
    end

    -- the inviter must still be here, still be allowed to invite, and still be allowed to hand out that rank
    local acc = From and Soc.Access(From.PlayerData.citizenid, invite.society, From)
    if not acc or not acc.perms.hire or invite.level > Soc.MaxAssignable(acc) then
        return Soc.Notify(src, Soc.Label(invite.society), locale('sv_err_invite_gone'), 'error')
    end
    local a, b = GetPlayerPed(invite.from), GetPlayerPed(src)
    if not a or a == 0 or not b or b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.HireDistance then
        return Soc.Notify(src, Soc.Label(invite.society), locale('sv_err_too_far'), 'error')
    end

    local cid = Target.PlayerData.citizenid
    local charName = Soc.PlayerName(Target)
    local ok, reason
    if s.type == 'gang' then
        ok, reason = Soc.AddGangMember(invite.society, cid, charName, invite.level)
    else
        ok, reason = Soc.AddJobMember(invite.society, cid, invite.level)
    end
    if not ok then
        Soc.Notify(src, Soc.Label(invite.society), locale(reason), 'error')
        Soc.Notify(invite.from, Soc.Label(invite.society), locale(reason), 'error')
        return
    end
    Soc.Audit(invite.society, From.PlayerData.citizenid, Soc.PlayerName(From), 'hire', Soc.GradeOf(invite.society, invite.level).name, cid, charName)
    Soc.Notify(src, Soc.Label(invite.society), locale('sv_you_joined', Soc.Label(invite.society)), 'success')
    Soc.Notify(invite.from, Soc.Label(invite.society), locale('sv_hired', charName), 'success')
end)

AddEventHandler('playerDropped', function()
    PendingInvites[source] = nil
end)

-----------------------------------------------------------------------
-- Gang lifecycle
-----------------------------------------------------------------------
local function slug(label)
    local s = tostring(label):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    return s:sub(1, 40)
end

local function cleanLabel(label)
    if type(label) ~= 'string' then return nil end
    label = label:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    -- count characters, not bytes, so names in Cyrillic, Greek or Japanese get the same room as English ones
    local len = utf8.len(label)
    if not len or len < Config.Gang.MinNameLength or len > Config.Gang.MaxNameLength then return nil end
    return label
end
Soc.CleanLabel = cleanLabel

function Soc.LabelTaken(label, exceptName)
    for name, s in pairs(Soc.S) do
        if name ~= exceptName and s.label and s.label:lower() == label:lower() then return true end
    end
    return false
end

--- Writes the rank list of a gang society (cache and database). defs: { { name, payment (dollars), perms = {...}, boss } } lowest first.
--- await = true waits for every insert (used by the migration). Returns the highest level.
function Soc.SeedRanks(name, defs, await)
    local insert = await and MySQL.insert.await or MySQL.insert
    Soc.Ranks[name], Soc.Perms[name] = {}, {}
    local top = 0
    for i, r in ipairs(defs) do
        local level = i - 1
        top = level
        local cents = math.floor((r.payment or 0) * 100 + 0.5)
        Soc.Ranks[name][level] = { name = r.name, payment = cents, boss = r.boss == true }
        insert('INSERT INTO rsg_society_ranks (society, level, name, payment_cents, is_boss) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)', { name, level, r.name, cents, r.boss and 1 or 0 })
        if not r.boss then
            local set = Soc.ToSet(r.perms, 'gang')
            Soc.Perms[name][level] = set
            local list = {}
            for p in pairs(set) do list[#list + 1] = p end
            table.sort(list)
            insert('INSERT INTO rsg_society_perms (society, level, perms) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE perms = VALUES(perms)', { name, level, json.encode(list) })
        end
    end
    return top
end

--- Creates a gang society with the default ranks. Returns ok, nameOrReasonKey.
function Soc.CreateGang(label, ownerCid, ownerName, opts)
    opts = opts or {}
    label = cleanLabel(label)
    if not label then return false, 'sv_err_gang_name' end
    if Soc.LabelTaken(label) then return false, 'sv_err_gang_taken' end

    local base = slug(label)
    if base == '' then base = 'gang' end -- a name with no latin letters or digits still gets an internal id (gang, gang_2, ...)
    local name, n = base, 1
    while Soc.S[name] or RSGCore.Shared.Gangs[name] or Soc.JobDef(name) or name == 'none' do
        n = n + 1
        name = ('%s_%d'):format(base:sub(1, 36), n)
    end

    local color = opts.color or Config.Gang.Colors[1]
    Soc.RegisterRow(name, 'gang', label, { color = color, owner = ownerCid, payroll = Config.Payroll.DefaultGangPayroll })
    Soc.Members[name] = {}
    local top = Soc.SeedRanks(name, Config.Gang.DefaultRanks)

    Soc.SyncGangDef(name)
    if ownerCid then
        local ok, reason = Soc.AddGangMember(name, ownerCid, ownerName, top)
        if not ok then return false, reason end
    end
    Soc.Audit(name, ownerCid, ownerName, 'create', label)
    TriggerEvent('rsg-society:server:gangCreated', name, ownerCid)
    return true, name
end

--- Changes the label, colour and/or tag of a gang society (data = { label?, color?, tag? }).
--- Returns ok, reasonKey. The key is 'sv_settings_saved' or 'sv_nothing_changed' on success.
function Soc.SetInfo(name, data, actorCid, actorName)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' or type(data) ~= 'table' then return false, 'sv_err_unknown' end
    local changes = {}

    if data.label ~= nil then
        local label = Soc.CleanLabel(data.label)
        if not label then return false, 'sv_err_gang_name' end
        if label ~= s.label then
            if Soc.LabelTaken(label, name) then return false, 'sv_err_gang_taken' end
            s.label = label
            MySQL.update('UPDATE rsg_societies SET label = ? WHERE name = ?', { label, name })
            changes[#changes + 1] = label
        end
    end
    if data.color ~= nil then
        local color = tostring(data.color)
        local allowed = false
        for _, c in ipairs(Config.Gang.Colors) do if c == color then allowed = true end end
        if not allowed then return false, 'sv_err_color' end
        if color ~= s.color then
            s.color = color
            MySQL.update('UPDATE rsg_societies SET color = ? WHERE name = ?', { color, name })
            changes[#changes + 1] = color
        end
    end
    if data.tag ~= nil then
        local tag = tostring(data.tag):upper():gsub('[^%w]', '')
        if #tag > Config.Gang.MaxTagLength then return false, 'sv_err_tag' end
        tag = tag ~= '' and tag or nil
        if tag ~= s.tag then
            s.tag = tag
            MySQL.update('UPDATE rsg_societies SET tag = ? WHERE name = ?', { tag, name })
            changes[#changes + 1] = tag or '-'
        end
    end

    if #changes == 0 then return true, 'sv_nothing_changed' end
    Soc.SyncGangDef(name)
    Soc.Audit(name, actorCid, actorName, 'settings', table.concat(changes, ', '))
    TriggerEvent('rsg-society:server:gangUpdated', name)
    return true, 'sv_settings_saved'
end

--- Deletes a gang society. Members drop to no gang. Returns the balance (cents) that was in the account.
function Soc.DisbandGang(name)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' then return nil end
    local balance = s.balance
    local members = {}
    for cid in pairs(Soc.Members[name] or {}) do members[#members + 1] = cid end
    for _, cid in ipairs(members) do Soc.RemoveGangMember(name, cid) end

    MySQL.update('DELETE FROM rsg_society_ranks WHERE society = ?', { name })
    MySQL.update('DELETE FROM rsg_society_perms WHERE society = ?', { name })
    MySQL.update('DELETE FROM rsg_society_members WHERE society = ?', { name })
    MySQL.update('DELETE FROM rsg_society_locations WHERE society = ?', { name })
    MySQL.update('DELETE FROM rsg_societies WHERE name = ?', { name })
    MySQL.update('DELETE FROM rsg_society_meta WHERE k = ?', { 'motd:' .. name })
    -- the internal name can be handed out again, so nothing of the old gang may be left behind for the new one to inherit
    MySQL.update('DELETE FROM rsg_society_ledger WHERE society = ?', { name })
    MySQL.update('DELETE FROM rsg_society_audit WHERE society = ?', { name })
    MySQL.update('DELETE FROM rsg_society_fines WHERE society = ?', { name })
    pcall(function() exports['rsg-core']:RemoveGang(name) end)
    pcall(function() exports['rsg-inventory']:DeleteInventory('society_' .. name) end)

    Soc.S[name], Soc.Ranks[name], Soc.Perms[name], Soc.Members[name] = nil, nil, nil, nil
    for id, loc in pairs(Soc.Locations) do
        if loc.society == name then Soc.Locations[id] = nil end
    end
    TriggerEvent('rsg-society:server:gangDisbanded', name, members)
    return balance
end

-----------------------------------------------------------------------
-- Exports
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- Gang ranks: the level is the position, so adding or removing a rank shifts the ones above it
-----------------------------------------------------------------------
local function sortedLevels(name)
    local levels = {}
    for level in pairs(Soc.Ranks[name] or {}) do levels[#levels + 1] = level end
    table.sort(levels)
    return levels
end

--- pushes the new rank list to rsg-core and re-applies every online member (their level may have moved)
local function resyncGang(name)
    Soc.SyncGangDef(name)
    for cid in pairs(Soc.Members[name] or {}) do Soc.ApplyMember(cid) end
end

--- Adds a rank just below the lowest boss rank, so it can never outrank a boss. Returns ok, level | reasonKey.
function Soc.AddRank(name, rankName)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' then return false, 'sv_err_unknown' end
    local levels = sortedLevels(name)
    if #levels >= (Config.Gang.MaxRanks or 10) then return false, 'sv_err_rank_limit' end
    local at = (levels[#levels] or -1) + 1
    for _, l in ipairs(levels) do
        if Soc.Ranks[name][l].boss then at = l break end
    end

    -- memory first (no yield), so nothing can read half-shifted ranks
    local ranks, perms = {}, {}
    for l, r in pairs(Soc.Ranks[name]) do ranks[l >= at and l + 1 or l] = r end
    for l, p in pairs(Soc.Perms[name] or {}) do perms[l >= at and l + 1 or l] = p end
    ranks[at] = { name = rankName, payment = 0, boss = false }
    perms[at] = Soc.ToSet({ 'members' }, 'gang')
    Soc.Ranks[name], Soc.Perms[name] = ranks, perms
    for _, m in pairs(Soc.Members[name] or {}) do
        if m.level >= at then m.level = m.level + 1 end
    end

    MySQL.update.await('UPDATE rsg_society_ranks SET level = level + 1 WHERE society = ? AND level >= ? ORDER BY level DESC', { name, at })
    MySQL.update.await('UPDATE rsg_society_perms SET level = level + 1 WHERE society = ? AND level >= ? ORDER BY level DESC', { name, at })
    MySQL.update.await('UPDATE rsg_society_members SET level = level + 1 WHERE society = ? AND level >= ?', { name, at })
    MySQL.insert.await('INSERT INTO rsg_society_ranks (society, level, name, payment_cents, is_boss) VALUES (?, ?, ?, 0, 0)', { name, at, rankName })
    MySQL.insert.await('INSERT INTO rsg_society_perms (society, level, perms) VALUES (?, ?, ?)', { name, at, json.encode({ 'members' }) })
    resyncGang(name)
    return true, at
end

--- Deletes a rank. Its members move one rank down (the lowest rank moves them up). Returns ok, rankName | reasonKey.
function Soc.RemoveRank(name, level)
    local s = Soc.S[name]
    local rank = s and s.type == 'gang' and Soc.Ranks[name] and Soc.Ranks[name][level]
    if not rank or rank.boss then return false, 'sv_err_bad_rank' end
    if #sortedLevels(name) <= 2 then return false, 'sv_err_rank_last' end
    local into = level > 0 and level - 1 or 1

    for _, m in pairs(Soc.Members[name] or {}) do
        if m.level == level then m.level = into end
    end
    for _, m in pairs(Soc.Members[name] or {}) do
        if m.level > level then m.level = m.level - 1 end
    end
    local ranks, perms = {}, {}
    for l, r in pairs(Soc.Ranks[name]) do
        if l < level then ranks[l] = r elseif l > level then ranks[l - 1] = r end
    end
    for l, p in pairs(Soc.Perms[name] or {}) do
        if l < level then perms[l] = p elseif l > level then perms[l - 1] = p end
    end
    Soc.Ranks[name], Soc.Perms[name] = ranks, perms

    MySQL.update.await('DELETE FROM rsg_society_ranks WHERE society = ? AND level = ?', { name, level })
    MySQL.update.await('DELETE FROM rsg_society_perms WHERE society = ? AND level = ?', { name, level })
    MySQL.update.await('UPDATE rsg_society_members SET level = ? WHERE society = ? AND level = ?', { into, name, level })
    MySQL.update.await('UPDATE rsg_society_members SET level = level - 1 WHERE society = ? AND level > ?', { name, level })
    MySQL.update.await('UPDATE rsg_society_ranks SET level = level - 1 WHERE society = ? AND level > ? ORDER BY level ASC', { name, level })
    MySQL.update.await('UPDATE rsg_society_perms SET level = level - 1 WHERE society = ? AND level > ? ORDER BY level ASC', { name, level })
    resyncGang(name)
    return true, rank.name
end

--- AddRank(name, rankName) -> ok, level | reasonKey      RemoveRank(name, level) -> ok, rankName | reasonKey   (gangs only)
exports('AddRank', function(name, rankName) return Soc.AddRank(name, rankName) end)
exports('RemoveRank', function(name, level) return Soc.RemoveRank(name, math.floor(tonumber(level) or -1)) end)

--- SetGangInfo(name, { label?, color?, tag? }) -> ok, reasonKey
exports('SetGangInfo', function(name, data)
    return Soc.SetInfo(name, data, nil, GetInvokingResource() or 'api')
end)

--- DisbandGang(name) -> ok, balance. Members drop to no gang and the society is deleted. The balance
--- (dollars) is NOT paid out: the caller decides what to do with it (rsg-society's own menu pays the leader).
exports('DisbandGang', function(name)
    if type(name) ~= 'string' or not Soc.S[name] or Soc.S[name].type ~= 'gang' then return false, 0 end
    local cents = Soc.DisbandGang(name)
    if cents == nil then return false, 0 end
    return true, cents / 100
end)

--- SetGangOwner(name, citizenid) -> ok. Only changes the recorded founder/owner; ranks are changed with SetMemberLevel.
exports('SetGangOwner', function(name, cid)
    local s = Soc.S[name]
    if not s or s.type ~= 'gang' or type(cid) ~= 'string' or not (Soc.Members[name] and Soc.Members[name][cid]) then return false end
    s.owner = cid
    MySQL.update('UPDATE rsg_societies SET owner = ? WHERE name = ?', { cid, name })
    TriggerEvent('rsg-society:server:gangUpdated', name)
    return true
end)

--- GetRanks(name) -> { { level, name, boss }, ... } lowest first
exports('GetRanks', function(name)
    local out = {}
    for _, g in ipairs(Soc.Grades(name)) do out[#out + 1] = { level = g.level, name = g.name, boss = g.boss } end
    return out
end)

exports('GetPlayerGang', function(id)
    local cid = Soc.ResolveCid(id)
    local name = cid and Soc.GangOf[cid]
    if not name then return nil end
    local m = Soc.Members[name][cid]
    local g = Soc.GradeOf(name, m.level)
    return { name = name, label = Soc.Label(name), level = m.level, grade = g and g.name or '?', boss = g and g.boss or false, tag = Soc.S[name].tag, color = Soc.S[name].color }
end)

--- CreateGang(label, ownerCitizenid?) -> ok, societyName | reason
exports('CreateGang', function(label, ownerCid)
    local name
    if ownerCid then
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { ownerCid })
        if not row then return false, 'sv_err_player' end
        local ok, info = pcall(json.decode, row.charinfo)
        name = Soc.FullName(ok and info or nil)
    end
    return Soc.CreateGang(label, ownerCid, name)
end)

exports('AddMember', function(name, id, level)
    local cid, Player = Soc.ResolveCid(id)
    local s = Soc.S[name]
    if not cid or not s then return false, 'sv_err_unknown' end
    level = math.floor(tonumber(level) or 0)
    if s.type == 'gang' then
        local charName = Player and Soc.PlayerName(Player)
        if not charName then
            local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { cid })
            if not row then return false, 'sv_err_player' end
            local ok, info = pcall(json.decode, row.charinfo)
            charName = Soc.FullName(ok and info or nil)
        end
        return Soc.AddGangMember(name, cid, charName, level)
    end
    return Soc.AddJobMember(name, cid, level)
end)

exports('RemoveMember', function(name, id)
    local cid = Soc.ResolveCid(id)
    local s = Soc.S[name]
    if not cid or not s then return false end
    if s.type == 'gang' then return Soc.RemoveGangMember(name, cid) end
    return Soc.RemoveJobMember(name, cid)
end)

exports('SetMemberLevel', function(name, id, level)
    local cid = Soc.ResolveCid(id)
    local s = Soc.S[name]
    level = math.floor(tonumber(level) or -1)
    if not cid or not s then return false end
    if s.type == 'gang' then return Soc.SetGangLevel(name, cid, level) end
    return Soc.SetJobLevel(name, cid, level)
end)
