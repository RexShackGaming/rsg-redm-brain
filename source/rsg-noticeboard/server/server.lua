local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local Boards = {}
local Sessions = {} -- [src] = { pos, time } set when a player opens a board
local Busy = {}     -- [src] = true while a paid action is processing
local LastPost = {} -- [citizenid] = os.time() of last successful post
local LastOpen = {} -- [src] = GetGameTimer() of last board data request
local postNotice

---------------------------------
-- helpers
---------------------------------
local function getDuration(id)
    for _, d in ipairs(Config.Durations) do
        if d.id == id then return d end
    end
end

local function validCategory(id)
    for _, c in ipairs(Config.Categories) do
        if c.id == id then return true end
    end
    return false
end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 7000 })
end

-- add a duration to a timestamp, calendar month aware
local function addDuration(from, dur)
    if dur.months then
        local t = os.date('*t', from)
        local targetMonth = t.month + dur.months
        local year = t.year + math.floor((targetMonth - 1) / 12)
        local month = ((targetMonth - 1) % 12) + 1
        local daysInMonth = os.date('*t', os.time({ year = year, month = month + 1, day = 0, hour = 12 })).day
        t.year, t.month, t.day = year, month, math.min(t.day, daysInMonth)
        return os.time(t)
    end
    return from + dur.seconds
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function ulen(s) return utf8.len(s) or #s end

-- player must have opened a board recently and still be standing near it
local function atBoard(src)
    local s = Sessions[src]
    if not s or os.time() - s.time > Config.SessionTimeout then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - s.pos) <= Config.SessionDistance
end

local function validImage(url)
    if url == '' then return not Config.RequireImage end
    if #url > 500 or not url:match('^https://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$') then return false end
    if #Config.AllowedImageHosts == 0 then return true end
    for _, host in ipairs(Config.AllowedImageHosts) do
        if url:sub(1, #host) == host then return true end
    end
    return false
end

-- nearest town to a position (used for boards outside a town too)
local function nearestTown(pos)
    local best, bestDist
    for _, t in ipairs(Config.Towns) do
        local d = #(vector3(pos.x, pos.y, pos.z) - t.coords)
        if not bestDist or d < bestDist then best, bestDist = t, d end
    end
    return best
end

-- town is always worked out from the player's real position, never from client data
local function playerTown(src)
    if not Config.SeparateTowns then return nil end
    return nearestTown(GetEntityCoords(GetPlayerPed(src)))
end

local function townLabel(id)
    for _, t in ipairs(Config.Towns) do if t.id == id then return t.label end end
    return id
end

-- localized config lists are built once and reused
local CatList = Config.Localize('cat_', Config.Categories)
local DurList = Config.Localize('dur_', Config.Durations)
local CatLabels, DurLabels = {}, {}
for _, c in ipairs(CatList) do CatLabels[c.id] = c.label end
for _, d in ipairs(DurList) do DurLabels[d.id] = d.label end

local function catLabel(id) return CatLabels[id] or id end
local function durLabel(dur) return DurLabels[dur.id] or dur.label end

local function charName(Player)
    local ci = Player.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

---------------------------------
-- boards
---------------------------------
local function loadBoards()
    Boards = MySQL.query.await('SELECT * FROM rsg_noticeboard_boards') or {}
    TriggerClientEvent('rsg-noticeboard:client:syncBoards', -1, Boards)
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_boards` (
        `id` INT NOT NULL AUTO_INCREMENT, `label` VARCHAR(64) NOT NULL DEFAULT 'Notice Board',
        `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `heading` DOUBLE NOT NULL DEFAULT 0,
        `created_by` VARCHAR(64) DEFAULT NULL, `created_at` INT NOT NULL DEFAULT 0, PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_notices` (
        `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(64) NOT NULL, `author` VARCHAR(128) NOT NULL,
        `title` VARCHAR(128) NOT NULL, `body` TEXT NOT NULL, `image` VARCHAR(512) DEFAULT NULL,
        `category` VARCHAR(32) NOT NULL, `duration` VARCHAR(16) NOT NULL, `created_at` INT NOT NULL,
        `expires_at` INT NOT NULL, `warned` TINYINT(1) NOT NULL DEFAULT 0, PRIMARY KEY (`id`),
        KEY `idx_citizenid` (`citizenid`), KEY `idx_expires` (`expires_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    local hasTown = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_noticeboard_notices' AND COLUMN_NAME = 'town']])
    if hasTown == 0 then
        MySQL.query.await('ALTER TABLE rsg_noticeboard_notices ADD COLUMN `town` VARCHAR(32) DEFAULT NULL AFTER `category`, ADD KEY `idx_town` (`town`)')
    end
    loadBoards()
end)

lib.callback.register('rsg-noticeboard:server:getBoards', function()
    return Boards
end)

---------------------------------
-- player data
---------------------------------
lib.callback.register('rsg-noticeboard:server:getBoardData', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    -- throttle: this runs a DB query, ignore spam faster than twice a second
    local t = GetGameTimer()
    if LastOpen[source] and t - LastOpen[source] < 500 then return nil end
    LastOpen[source] = t
    local now = os.time()
    Sessions[source] = { pos = GetEntityCoords(GetPlayerPed(source)), time = now }
    local town = playerTown(source)
    local notices
    if town then
        -- notices posted before towns were enabled (town NULL) show everywhere
        notices = MySQL.query.await(
            'SELECT id, author, title, body, image, category, town, created_at, expires_at, citizenid FROM rsg_noticeboard_notices WHERE expires_at > ? AND (town = ? OR town IS NULL) ORDER BY created_at DESC',
            { now, town.id }) or {}
    else
        notices = MySQL.query.await(
            'SELECT id, author, title, body, image, category, town, created_at, expires_at, citizenid FROM rsg_noticeboard_notices WHERE expires_at > ? ORDER BY created_at DESC',
            { now }) or {}
    end
    local cid = Player.PlayerData.citizenid
    for _, n in ipairs(notices) do
        n.mine = (n.citizenid == cid)
        n.citizenid = nil
    end
    return {
        notices = notices,
        now = now,
        town = town and town.label or nil,
        cash = Player.PlayerData.money[Config.MoneyType] or 0,
        config = {
            durations = DurList,
            categories = CatList,
            titleMax = Config.TitleMaxLength,
            bodyMax = Config.BodyMaxLength,
            maxNotices = Config.MaxNoticesPerPlayer,
            requireImage = Config.RequireImage,
            warnBefore = Config.WarnBeforeExpiry,
        }
    }
end)

lib.callback.register('rsg-noticeboard:server:createNotice', function(source, data)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or type(data) ~= 'table' or Busy[source] then return false end
    if not atBoard(source) then
        notify(source, locale('sv_too_far'), 'error')
        local fields = Webhook.PlayerFields(source, Player)
        local s = Sessions[source]
        fields[#fields + 1] = { name = locale('wh_reason'), value = s and locale('wh_reason_away') or locale('wh_reason_noboard') }
        Webhook.Send('exploit', { description = locale('wh_exploit_desc'), fields = fields,
            cooldownKey = 'exploit:' .. Player.PlayerData.citizenid })
        return false
    end
    local title = trim(tostring(data.title or ''):gsub('[%c]', ' '))
    local body = trim(tostring(data.body or ''):gsub('[%z\1-\9\11-\31]', ''))
    local image = trim(data.image)
    local dur = getDuration(data.duration)
    if title == '' or body == '' or ulen(title) > Config.TitleMaxLength or ulen(body) > Config.BodyMaxLength
        or not dur or not validCategory(data.category) then
        notify(source, locale('sv_invalid'), 'error') return false
    end
    if not validImage(image) then notify(source, locale('sv_bad_image'), 'error') return false end
    Busy[source] = true
    local ok, res = pcall(postNotice, source, Player, title, body, image, data.category, dur)
    Busy[source] = nil
    return ok and res
end)

postNotice = function(source, Player, title, body, image, category, dur)
    local cid = Player.PlayerData.citizenid
    local now = os.time()
    if LastPost[cid] and now - LastPost[cid] < Config.PostCooldown then
        notify(source, locale('sv_cooldown'):format(Config.PostCooldown - (now - LastPost[cid])), 'error') return false
    end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_noticeboard_notices WHERE citizenid = ? AND expires_at > ?', { cid, now }) or 0
    if count >= Config.MaxNoticesPerPlayer then notify(source, locale('sv_max_notices'), 'error') return false end

    if not Player.Functions.RemoveMoney(Config.MoneyType, dur.price, 'noticeboard-post') then
        notify(source, locale('sv_no_money'):format(dur.price), 'error') return false
    end

    LastPost[cid] = now
    local town = playerTown(source)
    local expires = addDuration(now, dur)
    local id = MySQL.insert.await(
        'INSERT INTO rsg_noticeboard_notices (citizenid, author, title, body, image, category, town, duration, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, charName(Player), title, body, image ~= '' and image or nil, category, town and town.id or nil, dur.id, now, expires })
    if not id then
        -- insert failed (db issue): give the fee back rather than charge for nothing
        Player.Functions.AddMoney(Config.MoneyType, dur.price, 'noticeboard-refund')
        LastPost[cid] = nil
        notify(source, locale('sv_invalid'), 'error')
        return false
    end
    notify(source, locale('sv_posted'):format(dur.price), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    for _, f in ipairs(Webhook.NoticeFields({ id = id, title = title, body = body, category = catLabel(category),
        town = town and town.label or locale('sv_all_towns'), expires_at = expires })) do fields[#fields + 1] = f end
    fields[#fields + 1] = { name = locale('wh_period_fee'), value = ('%s / $%.2f'):format(durLabel(dur), dur.price), inline = true }
    Webhook.Send('noticePosted', { fields = fields, image = image ~= '' and image or nil })
    return true
end

local function renewNotice(source, noticeId, durationId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not tonumber(noticeId) then return false end
    local dur = getDuration(durationId)
    if not dur then return false end
    local row = MySQL.single.await('SELECT id, title, category, town, expires_at FROM rsg_noticeboard_notices WHERE id = ? AND citizenid = ?',
        { tonumber(noticeId), Player.PlayerData.citizenid })
    if not row then notify(source, locale('sv_not_found'), 'error') return false end
    if not Player.Functions.RemoveMoney(Config.MoneyType, dur.price, 'noticeboard-renew') then
        notify(source, locale('sv_no_money'):format(dur.price), 'error') return false
    end
    local newExpiry = addDuration(math.max(row.expires_at, os.time()), dur)
    MySQL.update.await('UPDATE rsg_noticeboard_notices SET expires_at = ?, duration = ?, warned = 0 WHERE id = ?',
        { newExpiry, dur.id, row.id })
    notify(source, locale('sv_renewed'):format(dur.price), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, category = catLabel(row.category),
        town = townLabel(row.town), expires_at = newExpiry })) do fields[#fields + 1] = f end
    fields[#fields + 1] = { name = locale('wh_period_fee'), value = ('%s / $%.2f'):format(durLabel(dur), dur.price), inline = true }
    Webhook.Send('noticeRenewed', { fields = fields })
    return true
end

-- renewing is allowed anywhere (e.g. from the expiry popup), it only extends the player's own notice
lib.callback.register('rsg-noticeboard:server:renewNotice', function(source, noticeId, durationId)
    if Busy[source] then return false end
    Busy[source] = true
    local ok, res = pcall(renewNotice, source, noticeId, durationId)
    Busy[source] = nil
    return ok and res
end)

lib.callback.register('rsg-noticeboard:server:deleteOwnNotice', function(source, noticeId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not tonumber(noticeId) then return false end
    local row = MySQL.single.await('SELECT id, title, body, category, town FROM rsg_noticeboard_notices WHERE id = ? AND citizenid = ?',
        { tonumber(noticeId), Player.PlayerData.citizenid })
    if not row then return false end
    MySQL.query.await('DELETE FROM rsg_noticeboard_notices WHERE id = ?', { row.id })
    notify(source, locale('sv_removed'), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, body = row.body, category = catLabel(row.category),
        town = townLabel(row.town) })) do fields[#fields + 1] = f end
    Webhook.Send('noticeRemoved', { fields = fields })
    return true
end)

---------------------------------
-- expiry checks
---------------------------------
local function warnPlayer(src, n)
    TriggerClientEvent('rsg-noticeboard:client:expiryWarning', src, { id = n.id, title = n.title, expires_at = n.expires_at, now = os.time() })
end

CreateThread(function()
    while true do
        Wait(Config.CheckInterval * 1000)
        local now = os.time()

        -- expire
        local expired = MySQL.query.await('SELECT id, citizenid, author, title, town FROM rsg_noticeboard_notices WHERE expires_at <= ?', { now }) or {}
        if #expired > 0 then
            local ids = {}
            for _, n in ipairs(expired) do
                ids[#ids + 1] = n.id
                local P = RSGCore.Functions.GetPlayerByCitizenId(n.citizenid)
                if P then notify(P.PlayerData.source, locale('sv_expired'):format(n.title), 'error') end
            end
            MySQL.query.await(('DELETE FROM rsg_noticeboard_notices WHERE id IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)
            -- one summary embed per check instead of one per notice
            local lines = {}
            for i, n in ipairs(expired) do
                if i > 20 then lines[#lines + 1] = locale('wh_more'):format(#expired - 20) break end
                lines[#lines + 1] = locale('wh_expired_line'):format(n.id, n.title, n.author, n.citizenid, townLabel(n.town) or locale('sv_all_towns'))
            end
            Webhook.Send('noticeExpired', { description = table.concat(lines, '\n') })
        end

        -- warn (only mark warned when the owner is online to receive it)
        local soon = MySQL.query.await('SELECT id, citizenid, title, expires_at FROM rsg_noticeboard_notices WHERE warned = 0 AND expires_at > ? AND expires_at <= ?',
            { now, now + Config.WarnBeforeExpiry }) or {}
        for _, n in ipairs(soon) do
            local P = RSGCore.Functions.GetPlayerByCitizenId(n.citizenid)
            if P then
                warnPlayer(P.PlayerData.source, n)
                MySQL.update('UPDATE rsg_noticeboard_notices SET warned = 1 WHERE id = ?', { n.id })
            end
        end
    end
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(LoadedPlayer)
    local src = LoadedPlayer.PlayerData.source
    SetTimeout(15000, function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local now = os.time()
        local soon = MySQL.query.await('SELECT id, title, expires_at FROM rsg_noticeboard_notices WHERE citizenid = ? AND warned = 0 AND expires_at > ? AND expires_at <= ?',
            { Player.PlayerData.citizenid, now, now + Config.WarnBeforeExpiry }) or {}
        for _, n in ipairs(soon) do
            warnPlayer(src, n)
            MySQL.update('UPDATE rsg_noticeboard_notices SET warned = 1 WHERE id = ?', { n.id })
        end
    end)
end)

AddEventHandler('playerDropped', function()
    Sessions[source] = nil
    Busy[source] = nil
    LastOpen[source] = nil
end)

---------------------------------
-- admin
---------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('sv_cmd_help'), {}, false, function(source)
    TriggerClientEvent('rsg-noticeboard:client:openAdmin', source)
end, Config.AdminPermission)

lib.callback.register('rsg-noticeboard:server:getAdminData', function(source)
    if not isAdmin(source) then return nil end
    local notices = MySQL.query.await('SELECT id, citizenid, author, title, body, image, category, town, duration, created_at, expires_at FROM rsg_noticeboard_notices ORDER BY expires_at ASC') or {}
    local towns, boards = {}, {}
    for _, t in ipairs(Config.Towns) do towns[#towns + 1] = { id = t.id, label = t.label } end
    for i, b in ipairs(Boards) do
        local t = nearestTown(b)
        boards[i] = { id = b.id, label = b.label, x = b.x, y = b.y, z = b.z, heading = b.heading, town = t and t.id or nil }
    end
    return { boards = boards, notices = notices, now = os.time(), separateTowns = Config.SeparateTowns,
        config = { durations = DurList, categories = CatList, towns = towns } }
end)

lib.callback.register('rsg-noticeboard:server:saveBoard', function(source, data)
    if not isAdmin(source) then notify(source, locale('sv_no_permission'), 'error') return false end
    if type(data) ~= 'table' or not tonumber(data.x) or not tonumber(data.y) or not tonumber(data.z) then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    local label = trim(data.label); if label == '' then label = locale('sv_default_board') end
    local boardId = MySQL.insert.await('INSERT INTO rsg_noticeboard_boards (label, x, y, z, heading, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { label:sub(1, 64), data.x + 0.0, data.y + 0.0, data.z + 0.0, (tonumber(data.heading) or 0) + 0.0,
          Player and Player.PlayerData.citizenid or 'console', os.time() })
    loadBoards()
    notify(source, locale('sv_board_saved'), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    local t = nearestTown(data)
    fields[#fields + 1] = { name = locale('wh_board'), value = ('#%s %s'):format(boardId, label:sub(1, 64)), inline = true }
    fields[#fields + 1] = { name = locale('wh_nearest_town'), value = t and t.label or locale('wh_na'), inline = true }
    fields[#fields + 1] = { name = locale('wh_coords'), value = ('%.2f, %.2f, %.2f (h %.1f)'):format(data.x, data.y, data.z, tonumber(data.heading) or 0), inline = false }
    Webhook.Send('boardPlaced', { fields = fields })
    return true
end)

lib.callback.register('rsg-noticeboard:server:renameBoard', function(source, id, label)
    if not isAdmin(source) or not tonumber(id) then return false end
    label = trim(label); if label == '' then return false end
    local oldLabel = MySQL.scalar.await('SELECT label FROM rsg_noticeboard_boards WHERE id = ?', { tonumber(id) })
    if not oldLabel then return false end
    MySQL.update.await('UPDATE rsg_noticeboard_boards SET label = ? WHERE id = ?', { label:sub(1, 64), tonumber(id) })
    loadBoards()
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    fields[#fields + 1] = { name = locale('wh_board'), value = ('#%s'):format(id), inline = true }
    fields[#fields + 1] = { name = locale('wh_renamed'), value = ('%s -> %s'):format(oldLabel, label:sub(1, 64)), inline = false }
    Webhook.Send('boardRenamed', { fields = fields })
    return true
end)

lib.callback.register('rsg-noticeboard:server:deleteBoard', function(source, id)
    if not isAdmin(source) or not tonumber(id) then return false end
    local board = MySQL.single.await('SELECT * FROM rsg_noticeboard_boards WHERE id = ?', { tonumber(id) })
    if not board then return false end
    MySQL.query.await('DELETE FROM rsg_noticeboard_boards WHERE id = ?', { board.id })
    loadBoards()
    notify(source, locale('sv_board_deleted'), 'success')
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    fields[#fields + 1] = { name = locale('wh_board'), value = ('#%s %s'):format(board.id, board.label), inline = true }
    fields[#fields + 1] = { name = locale('wh_coords'), value = ('%.2f, %.2f, %.2f'):format(board.x, board.y, board.z), inline = false }
    Webhook.Send('boardDeleted', { fields = fields })
    return true
end)

lib.callback.register('rsg-noticeboard:server:adminDeleteNotice', function(source, id)
    if not isAdmin(source) or not tonumber(id) then return false end
    local row = MySQL.single.await('SELECT * FROM rsg_noticeboard_notices WHERE id = ?', { tonumber(id) })
    if not row then return false end
    MySQL.query.await('DELETE FROM rsg_noticeboard_notices WHERE id = ?', { row.id })
    notify(source, locale('sv_removed'), 'success')
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, body = row.body, category = catLabel(row.category),
        town = townLabel(row.town), author = ('%s (%s)'):format(row.author, row.citizenid) })) do fields[#fields + 1] = f end
    Webhook.Send('adminDelete', { fields = fields, image = row.image })
    return true
end)

lib.callback.register('rsg-noticeboard:server:adminExtendNotice', function(source, id, durationId)
    if not isAdmin(source) or not tonumber(id) then return false end
    local dur = getDuration(durationId)
    local row = MySQL.single.await('SELECT id, title, author, citizenid, category, town, expires_at FROM rsg_noticeboard_notices WHERE id = ?', { tonumber(id) })
    if not dur or not row then return false end
    local newExpiry = addDuration(math.max(row.expires_at, os.time()), dur)
    MySQL.update.await('UPDATE rsg_noticeboard_notices SET expires_at = ?, warned = 0 WHERE id = ?', { newExpiry, row.id })
    notify(source, locale('sv_extended'), 'success')
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, category = catLabel(row.category), town = townLabel(row.town),
        author = ('%s (%s)'):format(row.author, row.citizenid), expires_at = newExpiry })) do fields[#fields + 1] = f end
    fields[#fields + 1] = { name = locale('wh_extended_by'), value = durLabel(dur), inline = true }
    Webhook.Send('adminExtend', { fields = fields })
    return true
end)
