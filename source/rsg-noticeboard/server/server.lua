local RSGCore = exports['rsg-core']:GetCoreObject()

-- rsg-core callbacks answer with cb(...); keep the handlers' return style
local function registerCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        cb(fn(source, ...))
    end)
end

local Boards = {}
local Sessions = {} -- [src] = { pos, time } set when a player opens a board
local Busy = {}     -- [src] = true while a paid / state changing action is processing
local LastPost = {} -- [citizenid] = os.time() of last successful post
local LastOpen = {} -- [src] = GetGameTimer() of last board data request
local Throttle = {} -- [src] = { [key] = GetGameTimer() } light per-action rate limits
local LastReport = {} -- [citizenid] = os.time() of last report

local T_NOTICES, T_BOARDS = 'rsg_noticeboard_notices', 'rsg_noticeboard_boards'
local T_REPORTS, T_REMINDERS, T_BANS = 'rsg_noticeboard_reports', 'rsg_noticeboard_reminders', 'rsg_noticeboard_bans'

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

local function validReason(id)
    for _, r in ipairs(Config.Reports.Reasons) do
        if r == id then return true end
    end
    return false
end

local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('title'), description = desc, type = ntype or 'inform', duration = 7000 })
end

-- true when the player repeats an action faster than ms allows
local function throttled(src, key, ms)
    local t, now = Throttle[src], GetGameTimer()
    if not t then t = {} Throttle[src] = t end
    if t[key] and now - t[key] < ms then return true end
    t[key] = now
    return false
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

-- positive whole number id from client input, or nil
local function toId(v)
    local n = tonumber(v)
    if not n or n ~= math.floor(n) or n < 1 or n > 2147483647 then return nil end
    return math.floor(n)
end

-- cut a string to n characters without splitting a UTF-8 sequence
local function ucut(s, n)
    if ulen(s) <= n then return s end
    return s:sub(1, (utf8.offset(s, n + 1) or (#s + 1)) - 1)
end

-- strip control characters and invisible / direction-override characters people use to spoof text
local function cleanText(s, keepNewlines)
    s = tostring(s or '')
    if not utf8.len(s) then return nil end -- invalid UTF-8 would break JSON/NUI
    s = s:gsub('\226\128[\139-\143\170-\174]', '')  -- U+200B-200F, U+202A-202E
    s = s:gsub('\226\129[\160-\164\166-\169]', '')  -- U+2060-2064, U+2066-2069
    s = s:gsub('\239\187\191', '')                  -- U+FEFF
    if keepNewlines then
        s = s:gsub('[%c]', function(c) return (c == '\n') and c or '' end)
        s = s:gsub('\n\n\n+', '\n\n')
    else
        s = s:gsub('[%c]', ' ')
    end
    return trim(s)
end

-- player must have opened a board recently and still be standing near it
local function atBoard(src)
    local s = Sessions[src]
    if not s or os.time() - s.time > Config.SessionTimeout then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - s.pos) <= Config.SessionDistance
end

-- same character rules as the NUI (no quotes, brackets, spaces or angle brackets) so a link can never break out of the page
local function validImage(url)
    if url == '' then return not Config.RequireImage end
    if #url > 500 or not url:match('^https://[%w%-%._~:/%?#@!%$&%*%+,;=%%]+$') then return false end
    if #Config.AllowedImageHosts == 0 then return true end
    local host = url:match('^https://([^/%?#:@]+)')
    if not host then return false end
    host = host:lower()
    for _, allowed in ipairs(Config.AllowedImageHosts) do
        -- entries may be 'i.imgur.com' or 'https://i.imgur.com/'
        if host == allowed:lower():gsub('^https://', ''):gsub('/.*$', '') then return true end
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

-- title / text / image / category from the client, cleaned and checked. Returns the values or nil, errorLocaleKey
local function readContent(data)
    local title = cleanText(data.title)
    local body = cleanText(data.body, true)
    local image = trim(data.image)
    if not title or not body or title == '' or body == '' or ulen(title) > Config.TitleMaxLength
        or ulen(body) > Config.BodyMaxLength or not validCategory(data.category) then
        return nil, 'sv_invalid'
    end
    if not validImage(image) then return nil, 'sv_bad_image' end
    return title, body, image, data.category
end

---------------------------------
-- optional resources
---------------------------------
local function started(name) return GetResourceState(name) == 'started' end

-- share of a fee goes to the notice's town treasury (rsg-economy). DepositTreasury only credits the treasury
local function toTreasury(townId, amount)
    local E = Config.Economy
    if not (E and E.Enabled) or not townId or not started('rsg-economy') then return end
    local share = math.floor(amount * (E.Share or 1.0) * 100 + 0.5) / 100
    if share <= 0 then return end
    pcall(function() exports['rsg-economy']:DepositTreasury((E.Regions or {})[townId] or townId, share, 'noticeboard fee', 'rsg-noticeboard') end)
end

local function penalise(citizenid)
    local R = Config.Reputation
    if not (R and R.Enabled) or R.AbusePenalty <= 0 or not started('rsg-reputation') then return end
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then pcall(function() exports['rsg-reputation']:AddHonor(P.PlayerData.source, -R.AbusePenalty, 'noticeboard abuse') end) end
end

local function honorOk(src)
    local R = Config.Reputation
    if not (R and R.Enabled) or not started('rsg-reputation') then return true end
    local ok, res = pcall(function() return exports['rsg-reputation']:HasHonor(src, R.MinHonorToPost) end)
    return not ok or res ~= false
end

---------------------------------
-- bans
---------------------------------
local function getBan(citizenid)
    local row = MySQL.single.await('SELECT reason, expires_at FROM ' .. T_BANS .. ' WHERE citizenid = ?', { citizenid })
    if row and row.expires_at > os.time() then return row end
end

-- posting, editing and featuring need a clean record and enough honor; tells the player why not
local function mayPost(src, Player)
    local ban = getBan(Player.PlayerData.citizenid)
    if ban then notify(src, locale('sv_banned'):format(os.date('%Y-%m-%d', ban.expires_at)), 'error') return false end
    if not honorOk(src) then notify(src, locale('sv_low_honor'), 'error') return false end
    return true
end

---------------------------------
-- webhook helpers for the newer events
---------------------------------
local function logEvent(event, src, lists, image)
    local fields = Webhook.PlayerFields(src, src and RSGCore.Functions.GetPlayer(src) or nil)
    for _, list in ipairs(lists or {}) do
        for _, f in ipairs(list) do fields[#fields + 1] = f end
    end
    Webhook.Send(event, { fields = fields, image = image })
end

local function noticeFields(row)
    return Webhook.NoticeFields({ id = row.id, title = row.title, body = row.body, category = catLabel(row.category), town = townLabel(row.town),
        author = row.citizenid and ('%s (%s)'):format(row.author or '?', row.citizenid) or row.author, expires_at = row.expires_at })
end

---------------------------------
-- boards + database
---------------------------------
local function loadBoards()
    Boards = MySQL.query.await('SELECT * FROM ' .. T_BOARDS) or {}
    TriggerClientEvent('rsg-noticeboard:client:syncBoards', -1, Boards)
end

local function ensureColumn(tbl, col, ddl)
    local has = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tbl, col })
    if has == 0 then MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, ddl)) end
end

-- same schema as install.sql; only ever creates / adds, never drops
local function ensureDatabase()
    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_boards` (
            `id` INT NOT NULL AUTO_INCREMENT, `label` VARCHAR(64) NOT NULL DEFAULT 'Notice Board',
            `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL, `z` DOUBLE NOT NULL, `heading` DOUBLE NOT NULL DEFAULT 0,
            `created_by` VARCHAR(64) DEFAULT NULL, `created_at` INT NOT NULL DEFAULT 0, PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_notices` (
            `id` INT NOT NULL AUTO_INCREMENT, `citizenid` VARCHAR(64) NOT NULL, `author` VARCHAR(128) NOT NULL,
            `title` VARCHAR(128) NOT NULL, `body` TEXT NOT NULL, `image` VARCHAR(512) DEFAULT NULL,
            `category` VARCHAR(32) NOT NULL, `town` VARCHAR(32) DEFAULT NULL, `duration` VARCHAR(16) NOT NULL,
            `created_at` INT NOT NULL, `expires_at` INT NOT NULL, `warned` TINYINT(1) NOT NULL DEFAULT 0,
            `featured` TINYINT(1) NOT NULL DEFAULT 0, `hidden` TINYINT(1) NOT NULL DEFAULT 0, `edited_at` INT DEFAULT NULL,
            `pin_x` DOUBLE DEFAULT NULL, `pin_y` DOUBLE DEFAULT NULL, PRIMARY KEY (`id`),
            KEY `idx_citizenid` (`citizenid`), KEY `idx_expires` (`expires_at`), KEY `idx_town` (`town`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_reports` (
            `id` INT NOT NULL AUTO_INCREMENT, `notice_id` INT NOT NULL, `reporter` VARCHAR(64) NOT NULL,
            `reason` VARCHAR(16) NOT NULL, `created_at` INT NOT NULL, PRIMARY KEY (`id`),
            UNIQUE KEY `uq_notice_reporter` (`notice_id`, `reporter`), KEY `idx_reporter` (`reporter`, `created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_reminders` (
            `notice_id` INT NOT NULL, `citizenid` VARCHAR(64) NOT NULL, PRIMARY KEY (`notice_id`, `citizenid`),
            KEY `idx_citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `rsg_noticeboard_bans` (
            `citizenid` VARCHAR(64) NOT NULL, `name` VARCHAR(128) NOT NULL DEFAULT '', `reason` VARCHAR(64) NOT NULL DEFAULT '',
            `banned_by` VARCHAR(64) DEFAULT NULL, `created_at` INT NOT NULL, `expires_at` INT NOT NULL, PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        -- tables made by older versions miss these columns
        if MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rsg_noticeboard_notices' AND COLUMN_NAME = 'town']]) == 0 then
            MySQL.query.await('ALTER TABLE rsg_noticeboard_notices ADD COLUMN `town` VARCHAR(32) DEFAULT NULL AFTER `category`, ADD KEY `idx_town` (`town`)')
        end
        ensureColumn(T_NOTICES, 'featured', 'TINYINT(1) NOT NULL DEFAULT 0')
        ensureColumn(T_NOTICES, 'hidden', 'TINYINT(1) NOT NULL DEFAULT 0')
        ensureColumn(T_NOTICES, 'edited_at', 'INT DEFAULT NULL')
        ensureColumn(T_NOTICES, 'pin_x', 'DOUBLE DEFAULT NULL')
        ensureColumn(T_NOTICES, 'pin_y', 'DOUBLE DEFAULT NULL')
    end)
    if not ok then
        print(('^1[rsg-noticeboard] database setup failed: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-noticeboard] database tables ready^7')
    return true
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    loadBoards()
end)

registerCallback('rsg-noticeboard:server:getBoards', function()
    return Boards
end)

---------------------------------
-- browsing (paged, searchable)
---------------------------------
local SORTS = {
    new      = 'created_at DESC',
    expiring = 'expires_at ASC',
    title    = 'title ASC',
}

local LIST_COLS = 'id, author, title, image, category, town, featured, edited_at, created_at, expires_at, citizenid, (pin_x IS NOT NULL) AS pinned'

local function shapeRows(rows, cid)
    for _, n in ipairs(rows) do
        n.mine = (n.citizenid == cid)
        n.citizenid = nil
        n.featured = n.featured == 1
        n.pinned = n.pinned == 1
    end
    return rows
end

-- one page of the visible notices for this player's town
local function queryNotices(src, Player, q)
    q = type(q) == 'table' and q or {}
    local now = os.time()
    local where, params = { 'expires_at > ?', 'hidden = 0' }, { now }
    local town = playerTown(src)
    if town then where[#where + 1] = '(town = ? OR town IS NULL)' params[#params + 1] = town.id end
    local base, baseParams = table.concat(where, ' AND '), { table.unpack(params) }

    local counts = {}
    for _, r in ipairs(MySQL.query.await(('SELECT category, COUNT(*) AS c FROM %s WHERE %s GROUP BY category'):format(T_NOTICES, base), baseParams) or {}) do
        counts[r.category] = r.c
    end

    local category = validCategory(q.category) and q.category or nil
    if category then where[#where + 1] = 'category = ?' params[#params + 1] = category end
    local search = type(q.search) == 'string' and cleanText(ucut(q.search, Config.SearchMaxLength)) or ''
    if search and search ~= '' then
        local like = '%' .. search:gsub('[\\%%_]', '\\%0') .. '%'
        where[#where + 1] = '(title LIKE ? OR body LIKE ? OR author LIKE ?)'
        params[#params + 1] = like params[#params + 1] = like params[#params + 1] = like
    end
    local whereSql = table.concat(where, ' AND ')

    local total = MySQL.scalar.await(('SELECT COUNT(*) FROM %s WHERE %s'):format(T_NOTICES, whereSql), params) or 0
    local pages = math.max(1, math.ceil(total / Config.PageSize))
    local page = math.min(toId(q.page) or 1, pages)

    local order = SORTS[q.sort] or SORTS.new
    local listParams = { table.unpack(params) }
    listParams[#listParams + 1] = Config.PageSize
    listParams[#listParams + 1] = (page - 1) * Config.PageSize
    local rows = MySQL.query.await(('SELECT %s FROM %s WHERE %s ORDER BY featured DESC, %s LIMIT ? OFFSET ?')
        :format(LIST_COLS, T_NOTICES, whereSql, order), listParams) or {}

    return { notices = shapeRows(rows, Player.PlayerData.citizenid), total = total, page = page, pages = pages, counts = counts, now = now,
        cash = Player.PlayerData.money[Config.MoneyType] or 0 }
end

registerCallback('rsg-noticeboard:server:getNotices', function(source, q)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or throttled(source, 'list', 250) then return nil end
    return queryNotices(source, Player, q)
end)

-- the text, pin and reminder state of one notice (only fetched when it is opened)
registerCallback('rsg-noticeboard:server:getNotice', function(source, id)
    local Player = RSGCore.Functions.GetPlayer(source)
    id = toId(id)
    if not Player or not id or throttled(source, 'detail', 150) then return nil end
    local cid = Player.PlayerData.citizenid
    local row = MySQL.single.await('SELECT id, citizenid, body, town, hidden, pin_x, pin_y FROM ' .. T_NOTICES .. ' WHERE id = ? AND expires_at > ?', { id, os.time() })
    if not row then return nil end
    local mine = row.citizenid == cid
    if not mine and not isAdmin(source) then
        if row.hidden == 1 then return nil end
        local town = playerTown(source)
        if town and row.town and row.town ~= town.id then return nil end
    end
    local reminded = Config.Reminders.Enabled and (MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_REMINDERS .. ' WHERE notice_id = ? AND citizenid = ?', { id, cid }) or 0) > 0
    return {
        id = id, body = row.body, mine = mine, reminded = reminded or false,
        pin = (row.pin_x and row.pin_y) and { x = row.pin_x, y = row.pin_y } or nil,
    }
end)

registerCallback('rsg-noticeboard:server:getMyNotices', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    local rows = MySQL.query.await('SELECT id, title, image, category, town, duration, created_at, expires_at, featured, hidden, edited_at, (pin_x IS NOT NULL) AS pinned FROM '
        .. T_NOTICES .. ' WHERE citizenid = ? AND expires_at > ? ORDER BY created_at DESC', { Player.PlayerData.citizenid, os.time() }) or {}
    for _, n in ipairs(rows) do n.featured, n.hidden, n.pinned = n.featured == 1, n.hidden == 1, n.pinned == 1 end
    return { notices = rows, now = os.time() }
end)

registerCallback('rsg-noticeboard:server:getBoardData', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    -- throttle: this runs database queries, ignore spam faster than twice a second
    local t = GetGameTimer()
    if LastOpen[source] and t - LastOpen[source] < 500 then return nil end
    LastOpen[source] = t
    Sessions[source] = { pos = GetEntityCoords(GetPlayerPed(source)), time = os.time() }
    local town = playerTown(source)
    local page = queryNotices(source, Player, {})
    local R = Config.Reports
    return {
        notices = page.notices, total = page.total, page = page.page, pages = page.pages, counts = page.counts, now = page.now,
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
            searchMax = Config.SearchMaxLength,
            canEdit = Config.AllowEdit,
            canPin = Config.AllowPins,
            canRemind = Config.Reminders.Enabled,
            featured = Config.Featured.Enabled and Config.Featured.Price or nil,
            reportReasons = R.Enabled and R.Reasons or nil,
        }
    }
end)

---------------------------------
-- posting
---------------------------------
local function featuredFull(townId)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_NOTICES .. ' WHERE featured = 1 AND expires_at > ? AND ((? IS NULL AND town IS NULL) OR town = ?)',
        { os.time(), townId, townId }) or 0
    return count >= Config.Featured.MaxPerTown
end

local postNotice
registerCallback('rsg-noticeboard:server:createNotice', function(source, data)
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
    local title, body, image, category = readContent(data)
    local dur = getDuration(data.duration)
    if not title or not dur then notify(source, locale(body or 'sv_invalid'), 'error') return false end
    if not mayPost(source, Player) then return false end
    Busy[source] = true
    local ok, res = pcall(postNotice, source, Player, title, body, image, category, dur, data.featured == true)
    Busy[source] = nil
    return ok and res
end)

postNotice = function(source, Player, title, body, image, category, dur, featured)
    local cid = Player.PlayerData.citizenid
    local now = os.time()
    if LastPost[cid] and now - LastPost[cid] < Config.PostCooldown then
        notify(source, locale('sv_cooldown'):format(Config.PostCooldown - (now - LastPost[cid])), 'error') return false
    end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_NOTICES .. ' WHERE citizenid = ? AND expires_at > ?', { cid, now }) or 0
    if count >= Config.MaxNoticesPerPlayer then notify(source, locale('sv_max_notices'), 'error') return false end

    -- work everything out before taking the fee so an error can never leave a player charged for nothing
    local town = playerTown(source)
    local townId = town and town.id or nil
    local expires = addDuration(now, dur)
    featured = featured and Config.Featured.Enabled
    if featured and featuredFull(townId) then notify(source, locale('sv_feature_full'), 'error') return false end
    local fee = dur.price + (featured and Config.Featured.Price or 0)

    if not Player.Functions.RemoveMoney(Config.MoneyType, fee, 'noticeboard-post') then
        notify(source, locale('sv_no_money'):format(fee), 'error') return false
    end

    LastPost[cid] = now
    local id = MySQL.insert.await(
        'INSERT INTO ' .. T_NOTICES .. ' (citizenid, author, title, body, image, category, town, duration, created_at, expires_at, featured) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, charName(Player), title, body, image ~= '' and image or nil, category, townId, dur.id, now, expires, featured and 1 or 0 })
    if not id then
        -- insert failed (db issue): give the fee back rather than charge for nothing
        Player.Functions.AddMoney(Config.MoneyType, fee, 'noticeboard-refund')
        LastPost[cid] = nil
        notify(source, locale('sv_invalid'), 'error')
        return false
    end
    toTreasury(townId, fee)
    notify(source, locale('sv_posted'):format(fee), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    for _, f in ipairs(Webhook.NoticeFields({ id = id, title = title, body = body, category = catLabel(category),
        town = town and town.label or locale('sv_all_towns'), expires_at = expires })) do fields[#fields + 1] = f end
    fields[#fields + 1] = { name = locale('wh_period_fee'), value = ('%s / $%.2f'):format(durLabel(dur), fee), inline = true }
    Webhook.Send('noticePosted', { fields = fields, image = image ~= '' and image or nil })
    return true
end

-- runs fn(source, Player, ...) under the per-player lock; false when the player is unknown or busy
local function locked(source, fn, ...)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or Busy[source] then return false end
    Busy[source] = true
    local ok, res = pcall(fn, source, Player, ...)
    Busy[source] = nil
    if not ok then print(('^1[rsg-noticeboard] %s^7'):format(tostring(res))) end
    return ok and res
end

local function renewNotice(source, Player, noticeId, durationId)
    noticeId = toId(noticeId)
    if not noticeId then return false end
    local dur = getDuration(durationId)
    if not dur then return false end
    local row = MySQL.single.await('SELECT id, title, category, town, expires_at FROM ' .. T_NOTICES .. ' WHERE id = ? AND citizenid = ?',
        { noticeId, Player.PlayerData.citizenid })
    if not row then notify(source, locale('sv_not_found'), 'error') return false end
    if not Player.Functions.RemoveMoney(Config.MoneyType, dur.price, 'noticeboard-renew') then
        notify(source, locale('sv_no_money'):format(dur.price), 'error') return false
    end
    local newExpiry = addDuration(math.max(row.expires_at, os.time()), dur)
    MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET expires_at = ?, duration = ?, warned = 0 WHERE id = ?', { newExpiry, dur.id, row.id })
    toTreasury(row.town, dur.price)
    notify(source, locale('sv_renewed'):format(dur.price), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, category = catLabel(row.category),
        town = townLabel(row.town), expires_at = newExpiry })) do fields[#fields + 1] = f end
    fields[#fields + 1] = { name = locale('wh_period_fee'), value = ('%s / $%.2f'):format(durLabel(dur), dur.price), inline = true }
    Webhook.Send('noticeRenewed', { fields = fields })
    return true
end

-- renewing is allowed anywhere (e.g. from the expiry popup), it only extends the player's own notice
registerCallback('rsg-noticeboard:server:renewNotice', function(source, noticeId, durationId)
    return locked(source, renewNotice, noticeId, durationId)
end)

registerCallback('rsg-noticeboard:server:deleteOwnNotice', function(source, noticeId)
    local Player = RSGCore.Functions.GetPlayer(source)
    noticeId = toId(noticeId)
    if not Player or not noticeId then return false end
    local row = MySQL.single.await('SELECT id, title, body, category, town FROM ' .. T_NOTICES .. ' WHERE id = ? AND citizenid = ?',
        { noticeId, Player.PlayerData.citizenid })
    if not row then return false end
    MySQL.query.await('DELETE FROM ' .. T_NOTICES .. ' WHERE id = ?', { row.id })
    notify(source, locale('sv_removed'), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, body = row.body, category = catLabel(row.category),
        town = townLabel(row.town) })) do fields[#fields + 1] = f end
    Webhook.Send('noticeRemoved', { fields = fields })
    return true
end)

---------------------------------
-- edit, feature, pin, remind
---------------------------------
local function ownNotice(Player, id, cols)
    return MySQL.single.await(('SELECT %s FROM %s WHERE id = ? AND citizenid = ? AND expires_at > ?'):format(cols, T_NOTICES),
        { id, Player.PlayerData.citizenid, os.time() })
end

local function editNotice(source, Player, id, data)
    id = toId(id)
    if not Config.AllowEdit or not id or type(data) ~= 'table' then return false end
    local row = ownNotice(Player, id, 'id, citizenid, author, title, category, town, expires_at')
    if not row then notify(source, locale('sv_not_found'), 'error') return false end
    local title, body, image, category = readContent(data)
    if not title then notify(source, locale(body or 'sv_invalid'), 'error') return false end
    if not mayPost(source, Player) then return false end
    MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET title = ?, body = ?, image = ?, category = ?, edited_at = ? WHERE id = ?',
        { title, body, image ~= '' and image or nil, category, os.time(), id })
    notify(source, locale('sv_edited'), 'success')
    logEvent('noticeEdited', source, { noticeFields({ id = id, title = title, body = body, category = category, town = row.town,
        expires_at = row.expires_at }) }, image ~= '' and image or nil)
    return true
end

registerCallback('rsg-noticeboard:server:editNotice', function(source, id, data)
    return locked(source, editNotice, id, data)
end)

local function featureNotice(source, Player, id)
    id = toId(id)
    if not Config.Featured.Enabled or not id then return false end
    local row = ownNotice(Player, id, 'id, title, category, town, expires_at, featured, hidden')
    if not row then notify(source, locale('sv_not_found'), 'error') return false end
    if row.featured == 1 then notify(source, locale('sv_already_featured'), 'error') return false end
    if not mayPost(source, Player) then return false end
    if featuredFull(row.town) then notify(source, locale('sv_feature_full'), 'error') return false end
    local fee = Config.Featured.Price
    if not Player.Functions.RemoveMoney(Config.MoneyType, fee, 'noticeboard-feature') then
        notify(source, locale('sv_no_money'):format(fee), 'error') return false
    end
    MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET featured = 1 WHERE id = ?', { id })
    toTreasury(row.town, fee)
    notify(source, locale('sv_featured'):format(fee), 'success')
    logEvent('noticeFeatured', source, { noticeFields(row), { { name = locale('wh_period_fee'), value = ('$%.2f'):format(fee), inline = true } } })
    return true
end

registerCallback('rsg-noticeboard:server:featureNotice', function(source, id)
    return locked(source, featureNotice, id)
end)

-- pins the poster's real (server side) position, so a modified client cannot pin anywhere it likes
registerCallback('rsg-noticeboard:server:setPin', function(source, id, enable)
    local Player = RSGCore.Functions.GetPlayer(source)
    id = toId(id)
    if not Config.AllowPins or not Player or not id or throttled(source, 'pin', 2000) then return false end
    if not ownNotice(Player, id, 'id') then notify(source, locale('sv_not_found'), 'error') return false end
    if enable == true then
        local pos = GetEntityCoords(GetPlayerPed(source))
        MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET pin_x = ?, pin_y = ? WHERE id = ?', { pos.x + 0.0, pos.y + 0.0, id })
        notify(source, locale('sv_pin_set'), 'success')
    else
        MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET pin_x = NULL, pin_y = NULL WHERE id = ?', { id })
        notify(source, locale('sv_pin_cleared'), 'success')
    end
    return true
end)

-- returns 'on' / 'off' (or false)
registerCallback('rsg-noticeboard:server:toggleReminder', function(source, id)
    local Player = RSGCore.Functions.GetPlayer(source)
    id = toId(id)
    if not Config.Reminders.Enabled or not Player or not id or throttled(source, 'remind', 500) then return false end
    local cid = Player.PlayerData.citizenid
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_REMINDERS .. ' WHERE notice_id = ? AND citizenid = ?', { id, cid }) or 0
    if exists > 0 then
        MySQL.update.await('DELETE FROM ' .. T_REMINDERS .. ' WHERE notice_id = ? AND citizenid = ?', { id, cid })
        notify(source, locale('sv_remind_off'), 'success')
        return 'off'
    end
    local row = MySQL.single.await('SELECT town, hidden FROM ' .. T_NOTICES .. ' WHERE id = ? AND expires_at > ?', { id, os.time() })
    if not row or row.hidden == 1 then notify(source, locale('sv_not_found'), 'error') return false end
    local town = playerTown(source)
    if town and row.town and row.town ~= town.id then notify(source, locale('sv_not_found'), 'error') return false end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_REMINDERS .. ' WHERE citizenid = ?', { cid }) or 0) >= Config.Reminders.MaxPerPlayer then
        notify(source, locale('sv_remind_max'), 'error') return false
    end
    MySQL.update.await('INSERT IGNORE INTO ' .. T_REMINDERS .. ' (notice_id, citizenid) VALUES (?, ?)', { id, cid })
    notify(source, locale('sv_remind_on'), 'success')
    return 'on'
end)

---------------------------------
-- reports
---------------------------------
registerCallback('rsg-noticeboard:server:reportNotice', function(source, id, reason)
    local Player = RSGCore.Functions.GetPlayer(source)
    id = toId(id)
    local R = Config.Reports
    if not R.Enabled or not Player or not id or not validReason(reason) then return false end
    local cid, now = Player.PlayerData.citizenid, os.time()
    if LastReport[cid] and now - LastReport[cid] < R.Cooldown then notify(source, locale('sv_report_wait'), 'error') return false end
    local row = MySQL.single.await('SELECT id, citizenid, author, title, category, town, hidden, expires_at FROM ' .. T_NOTICES .. ' WHERE id = ? AND expires_at > ?', { id, now })
    if not row or row.hidden == 1 then notify(source, locale('sv_not_found'), 'error') return false end
    local town = playerTown(source)
    if town and row.town and row.town ~= town.id then notify(source, locale('sv_not_found'), 'error') return false end
    if row.citizenid == cid then notify(source, locale('sv_report_own'), 'error') return false end
    if (MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_REPORTS .. ' WHERE reporter = ? AND created_at > ?', { cid, now - 86400 }) or 0) >= R.MaxPerDay then
        notify(source, locale('sv_report_limit'), 'error') return false
    end
    LastReport[cid] = now
    local inserted = MySQL.update.await('INSERT IGNORE INTO ' .. T_REPORTS .. ' (notice_id, reporter, reason, created_at) VALUES (?, ?, ?, ?)', { id, cid, reason, now })
    if (inserted or 0) == 0 then notify(source, locale('sv_report_dup'), 'error') return false end
    notify(source, locale('sv_reported'), 'success')
    local total = MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T_REPORTS .. ' WHERE notice_id = ?', { id }) or 0
    logEvent('noticeReported', source, { noticeFields(row),
        { { name = locale('wh_reason'), value = reason, inline = true }, { name = locale('wh_reports'), value = tostring(total), inline = true } } })
    if total >= R.HideAt then
        MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET hidden = 1 WHERE id = ?', { id })
        local owner = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
        if owner then notify(owner.PlayerData.source, locale('sv_hidden_notice'):format(row.title), 'warning') end
        logEvent('noticeHidden', nil, { noticeFields(row), { { name = locale('wh_reports'), value = tostring(total), inline = true } } })
    end
    return true
end)

---------------------------------
-- expiry, reminders
---------------------------------
local function warnPlayer(src, n)
    TriggerClientEvent('rsg-noticeboard:client:expiryWarning', src, { id = n.id, title = n.title, expires_at = n.expires_at, now = os.time() })
end

local function expireNotices(now)
    local expired = MySQL.query.await('SELECT id, citizenid, author, title, town FROM ' .. T_NOTICES .. ' WHERE expires_at <= ?', { now }) or {}
    if #expired == 0 then return end
    local ids = {}
    for i, n in ipairs(expired) do ids[i] = n.id end
    local marks = ('?,'):rep(#ids):sub(1, -2)
    -- the expires_at guard keeps a notice that was renewed after the SELECT above
    local params = { table.unpack(ids) }
    params[#params + 1] = now
    local removed = MySQL.update.await(('DELETE FROM %s WHERE id IN (%s) AND expires_at <= ?'):format(T_NOTICES, marks), params) or 0
    if removed ~= #ids then
        local alive = {}
        for _, r in ipairs(MySQL.query.await(('SELECT id FROM %s WHERE id IN (%s)'):format(T_NOTICES, marks), ids) or {}) do alive[r.id] = true end
        local gone = {}
        for _, n in ipairs(expired) do if not alive[n.id] then gone[#gone + 1] = n end end
        expired = gone
    end
    local lines = {}
    for i, n in ipairs(expired) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(n.citizenid)
        if P then notify(P.PlayerData.source, locale('sv_expired'):format(n.title), 'error') end
        if i <= 20 then
            lines[#lines + 1] = locale('wh_expired_line'):format(n.id, n.title, n.author, n.citizenid, townLabel(n.town) or locale('sv_all_towns'))
        end
    end
    if #expired > 20 then lines[#lines + 1] = locale('wh_more'):format(#expired - 20) end
    -- one summary embed per check instead of one per notice
    if #lines > 0 then Webhook.Send('noticeExpired', { description = table.concat(lines, '\n') }) end
end

-- only marks a notice as warned when its owner is online to receive the warning
local function warnExpiring(now)
    local soon = MySQL.query.await('SELECT id, citizenid, title, expires_at FROM ' .. T_NOTICES .. ' WHERE warned = 0 AND expires_at > ? AND expires_at <= ?',
        { now, now + Config.WarnBeforeExpiry }) or {}
    for _, n in ipairs(soon) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(n.citizenid)
        if P then
            warnPlayer(P.PlayerData.source, n)
            MySQL.update('UPDATE ' .. T_NOTICES .. ' SET warned = 1 WHERE id = ?', { n.id })
        end
    end
end

-- telegram first (works while the player is offline), notification as the fallback
local function sendReminder(citizenid, title)
    local text = locale('sv_reminder_text'):format(title)
    if started('rsg-telegram') then
        local ok, sent = pcall(function() return exports['rsg-telegram']:SendTelegram(citizenid, locale('sv_reminder_subject'), text, { senderName = locale('title') }) end)
        if ok and sent then return true end
    end
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then notify(P.PlayerData.source, text, 'inform') return true end
    return false
end

local function sendReminders(now)
    if not Config.Reminders.Enabled then return end
    local due = MySQL.query.await(('SELECT r.notice_id, r.citizenid, n.title FROM %s r JOIN %s n ON n.id = r.notice_id WHERE n.expires_at > ? AND n.expires_at <= ? LIMIT 100')
        :format(T_REMINDERS, T_NOTICES), { now, now + Config.Reminders.Before }) or {}
    for _, r in ipairs(due) do
        if sendReminder(r.citizenid, r.title) then
            MySQL.update.await('DELETE FROM ' .. T_REMINDERS .. ' WHERE notice_id = ? AND citizenid = ?', { r.notice_id, r.citizenid })
        end
    end
end

-- reports / reminders of notices that no longer exist, and finished bans
local function cleanOrphans()
    MySQL.update(('DELETE r FROM %s r LEFT JOIN %s n ON n.id = r.notice_id WHERE n.id IS NULL'):format(T_REMINDERS, T_NOTICES))
    MySQL.update(('DELETE r FROM %s r LEFT JOIN %s n ON n.id = r.notice_id WHERE n.id IS NULL'):format(T_REPORTS, T_NOTICES))
    MySQL.update('DELETE FROM ' .. T_BANS .. ' WHERE expires_at <= ?', { os.time() })
end

CreateThread(function()
    while true do
        Wait(Config.CheckInterval * 1000)
        local now = os.time()
        -- a database hiccup must not kill the loop
        local ok, err = pcall(function() expireNotices(now) warnExpiring(now) sendReminders(now) cleanOrphans() end)
        if not ok then print(('^1[rsg-noticeboard] expiry check failed: %s^7'):format(tostring(err))) end
    end
end)

AddEventHandler('playerDropped', function()
    Sessions[source] = nil
    Busy[source] = nil
    LastOpen[source] = nil
    Throttle[source] = nil
end)

---------------------------------
-- admin
---------------------------------
RSGCore.Commands.Add(Config.AdminCommand, locale('sv_cmd_help'), {}, false, function(source)
    TriggerClientEvent('rsg-noticeboard:client:openAdmin', source)
end, Config.AdminPermission)

registerCallback('rsg-noticeboard:server:getAdminData', function(source)
    if not isAdmin(source) then return nil end
    local now = os.time()
    local notices = MySQL.query.await(('SELECT id, citizenid, author, title, image, category, town, duration, featured, hidden, created_at, expires_at FROM %s ORDER BY expires_at ASC LIMIT ?')
        :format(T_NOTICES), { Config.AdminListLimit }) or {}
    local reports = MySQL.query.await(([[SELECT n.id, n.citizenid, n.author, n.title, n.image, n.category, n.town, n.hidden, n.expires_at,
        COUNT(r.id) AS reports, GROUP_CONCAT(DISTINCT r.reason) AS reasons
        FROM %s r JOIN %s n ON n.id = r.notice_id
        GROUP BY n.id, n.citizenid, n.author, n.title, n.image, n.category, n.town, n.hidden, n.expires_at
        ORDER BY reports DESC LIMIT 100]]):format(T_REPORTS, T_NOTICES)) or {}
    local bans = MySQL.query.await('SELECT citizenid, name, reason, created_at, expires_at FROM ' .. T_BANS .. ' WHERE expires_at > ? ORDER BY expires_at ASC', { now }) or {}
    for _, n in ipairs(notices) do n.featured, n.hidden = n.featured == 1, n.hidden == 1 end
    for _, n in ipairs(reports) do n.hidden = n.hidden == 1 end
    local towns, boards = {}, {}
    for _, t in ipairs(Config.Towns) do towns[#towns + 1] = { id = t.id, label = t.label } end
    for i, b in ipairs(Boards) do
        local t = nearestTown(b)
        boards[i] = { id = b.id, label = b.label, x = b.x, y = b.y, z = b.z, heading = b.heading, town = t and t.id or nil }
    end
    return { boards = boards, notices = notices, reports = reports, bans = bans, now = now, separateTowns = Config.SeparateTowns,
        config = { durations = DurList, categories = CatList, towns = towns, banDays = Config.Reports.BanDays } }
end)

registerCallback('rsg-noticeboard:server:saveBoard', function(source, data)
    if not isAdmin(source) then notify(source, locale('sv_no_permission'), 'error') return false end
    if type(data) ~= 'table' then return false end
    local pos = vector3(tonumber(data.x) or 0 / 0, tonumber(data.y) or 0 / 0, tonumber(data.z) or 0 / 0)
    -- the board must be where the admin actually is (also rejects NaN / infinite numbers)
    if not exports['rsg-gizmo']:IsPlacementValid(source, pos, Config.PlaceMaxDistance) then return false end
    local heading = exports['rsg-gizmo']:SanitiseRotation(vector3(0.0, 0.0, tonumber(data.heading) or 0.0)).z
    local Player = RSGCore.Functions.GetPlayer(source)
    local label = ucut(cleanText(data.label) or '', 64); if label == '' then label = locale('sv_default_board') end
    local boardId = MySQL.insert.await('INSERT INTO ' .. T_BOARDS .. ' (label, x, y, z, heading, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { label, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, heading + 0.0,
          Player and Player.PlayerData.citizenid or 'console', os.time() })
    loadBoards()
    notify(source, locale('sv_board_saved'), 'success')
    local fields = Webhook.PlayerFields(source, Player)
    local t = nearestTown(pos)
    fields[#fields + 1] = { name = locale('wh_board'), value = ('#%s %s'):format(boardId, label), inline = true }
    fields[#fields + 1] = { name = locale('wh_nearest_town'), value = t and t.label or locale('wh_na'), inline = true }
    fields[#fields + 1] = { name = locale('wh_coords'), value = ('%.2f, %.2f, %.2f (h %.1f)'):format(pos.x, pos.y, pos.z, heading), inline = false }
    Webhook.Send('boardPlaced', { fields = fields })
    return true
end)

registerCallback('rsg-noticeboard:server:renameBoard', function(source, id, label)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    label = ucut(cleanText(label) or '', 64); if label == '' then return false end
    local oldLabel = MySQL.scalar.await('SELECT label FROM ' .. T_BOARDS .. ' WHERE id = ?', { id })
    if not oldLabel then return false end
    MySQL.update.await('UPDATE ' .. T_BOARDS .. ' SET label = ? WHERE id = ?', { label, id })
    loadBoards()
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    fields[#fields + 1] = { name = locale('wh_board'), value = ('#%s'):format(id), inline = true }
    fields[#fields + 1] = { name = locale('wh_renamed'), value = ('%s -> %s'):format(oldLabel, label), inline = false }
    Webhook.Send('boardRenamed', { fields = fields })
    return true
end)

registerCallback('rsg-noticeboard:server:deleteBoard', function(source, id)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    local board = MySQL.single.await('SELECT * FROM ' .. T_BOARDS .. ' WHERE id = ?', { id })
    if not board then return false end
    MySQL.query.await('DELETE FROM ' .. T_BOARDS .. ' WHERE id = ?', { board.id })
    loadBoards()
    notify(source, locale('sv_board_deleted'), 'success')
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    fields[#fields + 1] = { name = locale('wh_board'), value = ('#%s %s'):format(board.id, board.label), inline = true }
    fields[#fields + 1] = { name = locale('wh_coords'), value = ('%.2f, %.2f, %.2f'):format(board.x, board.y, board.z), inline = false }
    Webhook.Send('boardDeleted', { fields = fields })
    return true
end)

registerCallback('rsg-noticeboard:server:adminDeleteNotice', function(source, id)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    local row = MySQL.single.await('SELECT * FROM ' .. T_NOTICES .. ' WHERE id = ?', { id })
    if not row then return false end
    MySQL.query.await('DELETE FROM ' .. T_NOTICES .. ' WHERE id = ?', { row.id })
    notify(source, locale('sv_removed'), 'success')
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, body = row.body, category = catLabel(row.category),
        town = townLabel(row.town), author = ('%s (%s)'):format(row.author, row.citizenid) })) do fields[#fields + 1] = f end
    Webhook.Send('adminDelete', { fields = fields, image = row.image })
    return true
end)

registerCallback('rsg-noticeboard:server:adminExtendNotice', function(source, id, durationId)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    local dur = getDuration(durationId)
    local row = MySQL.single.await('SELECT id, title, author, citizenid, category, town, expires_at FROM ' .. T_NOTICES .. ' WHERE id = ?', { id })
    if not dur or not row then return false end
    local newExpiry = addDuration(math.max(row.expires_at, os.time()), dur)
    MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET expires_at = ?, warned = 0 WHERE id = ?', { newExpiry, row.id })
    notify(source, locale('sv_extended'), 'success')
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    for _, f in ipairs(Webhook.NoticeFields({ id = row.id, title = row.title, category = catLabel(row.category), town = townLabel(row.town),
        author = ('%s (%s)'):format(row.author, row.citizenid), expires_at = newExpiry })) do fields[#fields + 1] = f end
    fields[#fields + 1] = { name = locale('wh_extended_by'), value = durLabel(dur), inline = true }
    Webhook.Send('adminExtend', { fields = fields })
    return true
end)

-- ban a character from posting and remove everything they have up
local function banCitizen(src, citizenid, name, reason)
    local now = os.time()
    local days = Config.Reports.BanDays
    MySQL.update.await('INSERT INTO ' .. T_BANS .. ' (citizenid, name, reason, banned_by, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), reason = VALUES(reason), banned_by = VALUES(banned_by), created_at = VALUES(created_at), expires_at = VALUES(expires_at)',
        { citizenid, name or '', reason or '', tostring(src), now, now + days * 86400 })
    MySQL.update.await('DELETE FROM ' .. T_NOTICES .. ' WHERE citizenid = ?', { citizenid })
    local P = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if P then notify(P.PlayerData.source, locale('sv_banned'):format(os.date('%Y-%m-%d', now + days * 86400)), 'error') end
    logEvent('playerBanned', src, { { { name = locale('wh_citizenid'), value = citizenid, inline = true },
        { name = locale('wh_ban_days'), value = tostring(days), inline = true }, { name = locale('wh_author'), value = name or '', inline = true } } })
end

-- admin: dismiss the reports of a notice (and show it again)
registerCallback('rsg-noticeboard:server:adminDismissReports', function(source, id)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    local row = MySQL.single.await('SELECT id, citizenid, author, title, category, town, expires_at FROM ' .. T_NOTICES .. ' WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM ' .. T_REPORTS .. ' WHERE notice_id = ?', { id })
    MySQL.update.await('UPDATE ' .. T_NOTICES .. ' SET hidden = 0 WHERE id = ?', { id })
    notify(source, locale('sv_dismissed'), 'success')
    if row then logEvent('reportsDismissed', source, { noticeFields(row) }) end
    return true
end)

-- admin: remove a reported notice, penalise the poster and optionally ban them
registerCallback('rsg-noticeboard:server:adminRemoveReported', function(source, id, ban)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    local row = MySQL.single.await('SELECT * FROM ' .. T_NOTICES .. ' WHERE id = ?', { id })
    if not row then return false end
    MySQL.query.await('DELETE FROM ' .. T_NOTICES .. ' WHERE id = ?', { id })
    penalise(row.citizenid)
    local fields = Webhook.PlayerFields(source, RSGCore.Functions.GetPlayer(source))
    for _, f in ipairs(noticeFields(row)) do fields[#fields + 1] = f end
    Webhook.Send('adminDelete', { fields = fields, image = row.image })
    if ban == true then banCitizen(source, row.citizenid, row.author, 'reported notice') end
    notify(source, locale('sv_removed'), 'success')
    return true
end)

registerCallback('rsg-noticeboard:server:adminBanPoster', function(source, id)
    id = toId(id)
    if not isAdmin(source) or not id then return false end
    local row = MySQL.single.await('SELECT citizenid, author FROM ' .. T_NOTICES .. ' WHERE id = ?', { id })
    if not row then return false end
    banCitizen(source, row.citizenid, row.author, 'banned by admin')
    notify(source, locale('sv_ban_done'), 'success')
    return true
end)

registerCallback('rsg-noticeboard:server:adminUnban', function(source, citizenid)
    if not isAdmin(source) or type(citizenid) ~= 'string' or #citizenid > 64 then return false end
    local ban = MySQL.single.await('SELECT name FROM ' .. T_BANS .. ' WHERE citizenid = ?', { citizenid })
    if not ban then return false end
    MySQL.update.await('DELETE FROM ' .. T_BANS .. ' WHERE citizenid = ?', { citizenid })
    notify(source, locale('sv_unbanned'), 'success')
    logEvent('playerUnbanned', source, { { { name = locale('wh_citizenid'), value = citizenid, inline = true }, { name = locale('wh_author'), value = ban.name, inline = true } } })
    return true
end)
