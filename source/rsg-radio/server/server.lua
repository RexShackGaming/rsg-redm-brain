local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local connected    = {} -- [src] = frequency string the player tuned in with this radio
local cooldown     = {} -- [src] = GetGameTimer() when the next join/leave/cycle is allowed
local favCooldown  = {} -- [src] = GetGameTimer() when the next favorites change is allowed
local privCooldown = {} -- [src] = GetGameTimer() when the next private-channel change is allowed
local panelOpen    = {} -- [src] = true while the player has the panel open (gets live updates)
local unlocked     = {} -- [src] = { [freq string] = true } private channels unlocked this session
local wrongCodes   = {} -- [citizenid] = { count = n, lockUntil = GetGameTimer() } (survives reconnecting)
local staffMuted   = {} -- [citizenid] = os.time() when a staff block ends
local jobCache     = {} -- [src] = { list = {...}, expires = GetGameTimer() } jobs held (multi-job)
local private      = {} -- [freq string] = { owner = citizenid, name, code, last = os.time() }

local P = Config.Private or {}
local PRIV = false -- true once the private channel table is ready

-- Frequencies are numbers with Config.Frequency.Decimals decimal places. Everything the server stores or sends uses
-- the same fixed-format string (e.g. '446.0'), which is also the key rsg-voice uses for the channel.
local FREQ  = Config.Frequency
local DEC   = math.max(0, math.min(3, math.floor(tonumber(FREQ.Decimals) or 0)))
local SCALE = 10 ^ DEC
local FMT   = '%.' .. DEC .. 'f'
local UNIT  = FREQ.Unit or ''
local MIN_S = math.floor(FREQ.Min * SCALE + 0.5)
local MAX_S = math.floor(FREQ.Max * SCALE + 0.5)

local function fmtFreq(n) return FMT:format(n) end

-- '446.0 MHz' (or just '446.0' when no unit is configured)
local function withUnit(key) return UNIT ~= '' and (key .. ' ' .. UNIT) or key end

local CHECK_MS = math.max(1, tonumber(Config.CheckInterval) or 10) * 1000

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function notify(src, key, nType, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = locale(key, ...), type = nType, duration = 4000,
    })
end

local function hasRadio(src)
    return exports['rsg-inventory']:HasItem(src, Config.Item, 1) and true or false
end

local function inList(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end

-- Accepts a number with at most Decimals decimal places inside the configured range. Returns the freq string or nil.
local function parseFreq(value)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return nil end
    local scaled = value * SCALE
    local whole  = math.floor(scaled + 0.5)
    if math.abs(scaled - whole) > 1e-6 then return nil end -- too many decimals
    if whole < MIN_S or whole > MAX_S then return nil end
    return fmtFreq(whole / SCALE)
end

-- Restricted channels from the config, validated once at start. Invalid entries are skipped with a console warning.
local restricted = {} -- [freq string] = channel definition
local channels   = {} -- ordered list of { key = freq string, def = channel definition }
for _, ch in ipairs(Config.Channels) do
    local key = parseFreq(ch.freq)
    if not key then
        print(('^1[rsg-radio]^7 Config.Channels: %s is not a valid frequency (allowed %s to %s with %d decimals), channel skipped'):format(
            tostring(ch.freq), FREQ.Min, FREQ.Max, DEC))
    elseif restricted[key] then
        print(('^1[rsg-radio]^7 Config.Channels: %s is listed twice, the second entry is skipped'):format(key))
    else
        restricted[key] = ch
        channels[#channels + 1] = { key = key, def = ch }
    end
end
if FREQ.Min > FREQ.Max then print('^1[rsg-radio]^7 Config.Frequency.Min is higher than Max, nobody can tune in') end

local function rateLimit(store, src, ms)
    local now = GetGameTimer()
    if (store[src] or 0) > now then return true end
    store[src] = now + ms
    return false
end
local function tooFast(src) return rateLimit(cooldown, src, 500) end
local function favTooFast(src) return rateLimit(favCooldown, src, 300) end
local function privTooFast(src) return rateLimit(privCooldown, src, 1000) end

---------------------------------------------------------------------
-- Access rules (jobs, grades, multi-job, gangs, on duty)
---------------------------------------------------------------------
local function gradeOk(def, level)
    return not def.minGrade or (tonumber(level) or 0) >= def.minGrade
end

-- Jobs the player holds (rsg-core multi-job), cached because the export reads the database
local function heldJobs(src)
    local c = jobCache[src]
    local now = GetGameTimer()
    if c and c.expires > now then return c.list end
    local list = {}
    local ok, rows = pcall(function() return exports['rsg-core']:GetPlayerJobs(src) end)
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            local okDef, def = pcall(function() return exports['rsg-core']:GetJobDefinition(r.job) end)
            list[#list + 1] = { name = r.job, type = okDef and def and def.type or nil, grade = tonumber(r.grade) or 0 }
        end
    end
    jobCache[src] = { list = list, expires = now + 30000 }
    return list
end

local function canAccess(src, Player, def)
    if not def then return true end
    local rules = #(def.jobs or {}) + #(def.jobtypes or {}) + #(def.gangs or {})
    if rules == 0 then return true end -- named but open channel
    local job, gang = Player.PlayerData.job or {}, Player.PlayerData.gang or {}
    local duty = not def.onduty or job.onduty

    -- the job the player is working now
    if duty and (inList(def.jobs, job.name) or inList(def.jobtypes, job.type)) and gradeOk(def, job.grade and job.grade.level) then
        return true
    end
    if duty and inList(def.gangs, gang.name) and gradeOk(def, gang.grade and gang.grade.level) then
        return true
    end
    -- jobs the player holds but is not working (never for on-duty channels: only the active job can be on duty)
    if Config.MultiJob and not def.onduty and (#(def.jobs or {}) + #(def.jobtypes or {})) > 0 then
        for _, h in ipairs(heldJobs(src)) do
            if (inList(def.jobs, h.name) or inList(def.jobtypes, h.type)) and gradeOk(def, h.grade) then return true end
        end
    end
    return false
end

-- May this player use the frequency right now without typing a passcode?
local function canUse(src, Player, key)
    if restricted[key] then return canAccess(src, Player, restricted[key]) end
    local ch = private[key]
    if ch then
        return ch.owner == Player.PlayerData.citizenid or (unlocked[src] and unlocked[src][key]) or false
    end
    return true
end

-- Minutes left of a staff radio block, or nil
local function muteLeft(Player)
    local cid = Player.PlayerData.citizenid
    local untilT = staffMuted[cid]
    if not untilT then return nil end
    local left = untilT - os.time()
    if left <= 0 then staffMuted[cid] = nil return nil end
    return math.ceil(left / 60)
end

---------------------------------------------------------------------
-- Favorites (stored per character in metadata 'radiofavs' = { { freq = '446.0', label = 'Camp' }, ... })
---------------------------------------------------------------------
local function cleanLabel(label, maxLen)
    if type(label) ~= 'string' then return '' end
    label = label:sub(1, maxLen * 4) -- bound the work first (a character is at most 4 bytes)
    label = label:gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
    local ok, cut = pcall(utf8.offset, label, maxLen + 1)
    if ok and cut then label = label:sub(1, cut - 1) end
    return label
end

local function getFavorites(Player)
    local stored = Player.PlayerData.metadata and Player.PlayerData.metadata.radiofavs
    local list = {}
    if type(stored) == 'table' then
        for _, f in ipairs(stored) do
            if type(f) == 'table' and f.freq then
                list[#list + 1] = { freq = tostring(f.freq), label = cleanLabel(f.label, Config.FavoriteLabelLength) }
            end
        end
    end
    return list
end

---------------------------------------------------------------------
-- State for the NUI (nil when the player has no radio)
---------------------------------------------------------------------
local function numericSort(a, b) return tonumber(a) < tonumber(b) end

local function buildState(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasRadio(src) then return nil end
    local cid = Player.PlayerData.citizenid

    local list, reserved = {}, {}
    for _, c in ipairs(channels) do
        if canAccess(src, Player, c.def) then
            local m = exports['rsg-voice']:GetRadioMembers(c.key)
            list[#list + 1] = { freq = c.key, label = locale(c.def.label), count = m and #m or 0 }
        else
            reserved[#reserved + 1] = c.key -- restricted and not available to this player
        end
    end

    local favorites = getFavorites(Player)
    for _, f in ipairs(favorites) do
        -- a favorite stays in the list if the range or the player's access changed; a private one asks for the passcode
        local key = parseFreq(tonumber(f.freq))
        local use = key ~= nil and canUse(src, Player, key)
        f.locked = key ~= nil and not use and private[key] ~= nil
        f.usable = use or f.locked
    end

    local priv
    if PRIV then
        local keys = {}
        for key in pairs(private) do keys[#keys + 1] = key end
        table.sort(keys, numericSort)
        local mine, usable, locked = 0, {}, {}
        for _, key in ipairs(keys) do
            local ch = private[key]
            local owner = ch.owner == cid
            if owner then mine = mine + 1 end
            if owner or (unlocked[src] and unlocked[src][key]) then
                local m = exports['rsg-voice']:GetRadioMembers(key)
                usable[#usable + 1] = { freq = key, name = ch.name, owner = owner, count = m and #m or 0 }
            else
                locked[#locked + 1] = key
            end
        end
        priv = {
            list = usable, locked = locked, mine = mine, maxPerPlayer = P.MaxPerPlayer,
            codeMin = P.CodeMin, codeMax = P.CodeMax, nameLen = P.NameLength, cost = tonumber(P.Cost) or 0,
        }
    end

    local freq = connected[src]
    local members = freq and exports['rsg-voice']:GetRadioMembers(freq)
    return {
        freq = freq, channels = list, reserved = reserved, count = members and #members or 0,
        favorites = favorites, maxFavorites = Config.MaxFavorites, priv = priv,
        min = FREQ.Min, max = FREQ.Max, dec = DEC, unit = UNIT,
    }
end

local function pushState(src)
    TriggerClientEvent('rsg-radio:client:state', src, buildState(src))
end

-- Live member counts: whenever a channel changes, panels that are open get fresh data (batched)
local flushPending = false
local function markDirty()
    if flushPending then return end
    flushPending = true
    SetTimeout(math.max(100, tonumber(Config.LiveUpdateDelay) or 500), function()
        flushPending = false
        for src in pairs(panelOpen) do
            if GetPlayerName(src) then pushState(src) else panelOpen[src] = nil end
        end
    end)
end

local function dropFromRadio(src)
    connected[src] = nil
    exports['rsg-voice']:LeaveRadio(src)
end

---------------------------------------------------------------------
-- Database (private channels)
---------------------------------------------------------------------
local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `rsg_radio_private` (
  `freq` VARCHAR(16) NOT NULL,
  `owner` VARCHAR(50) NOT NULL,
  `name` VARCHAR(32) NOT NULL DEFAULT '',
  `code` VARCHAR(32) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`freq`),
  KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

local function ensureDatabase()
    if not Config.AutoDatabase then return true end
    local ok, err = pcall(function() return MySQL.query.await(SCHEMA) end)
    if not ok then
        print(('^1[rsg-radio]^7 could not create the rsg_radio_private table: %s'):format(tostring(err)))
        return false
    end
    print('^2[rsg-radio]^7 database table ready')
    return true
end

local function loadPrivate()
    local rows = MySQL.query.await('SELECT freq, owner, name, code, UNIX_TIMESTAMP(last_used) AS last FROM rsg_radio_private') or {}
    for _, r in ipairs(rows) do
        local key = parseFreq(tonumber(r.freq))
        -- rows that no longer fit the frequency range or collide with a configured channel are ignored (left in the table)
        if key and not restricted[key] and not private[key] then
            private[key] = { owner = r.owner, name = r.name or '', code = r.code, last = tonumber(r.last) or os.time() }
        end
    end
end

local function membersOn(key)
    local m = exports['rsg-voice']:GetRadioMembers(key)
    return m and #m > 0
end

-- Remove everyone from a private channel (optionally keeping one owner), forget their unlock and tell them why
local function kickFrom(key, exceptCid, msgKey)
    local list = {}
    for i, m in ipairs(exports['rsg-voice']:GetRadioMembers(key) or {}) do list[i] = m end -- copy: leaving changes the original
    for _, m in ipairs(list) do
        local mp = RSGCore.Functions.GetPlayer(m)
        if not (exceptCid and mp and mp.PlayerData.citizenid == exceptCid) then
            dropFromRadio(m)
            notify(m, msgKey, 'error')
            pushState(m)
        end
    end
    for _, u in pairs(unlocked) do u[key] = nil end
end

local function removePrivate(key)
    kickFrom(key, nil, 'sv_priv_removed')
    private[key] = nil
    MySQL.update('DELETE FROM rsg_radio_private WHERE freq = ?', { key })
    markDirty()
end

local function touchPrivate(key)
    local ch = private[key]
    if ch and os.time() - ch.last > 3600 then -- at most one write an hour per channel
        ch.last = os.time()
        MySQL.update('UPDATE rsg_radio_private SET last_used = NOW() WHERE freq = ?', { key })
    end
end

local function purgeExpired()
    local days = tonumber(P.ExpireDays) or 0
    if days <= 0 then return end
    local limit = os.time() - days * 86400
    for key, ch in pairs(private) do
        if ch.last < limit and not membersOn(key) then removePrivate(key) end
    end
end

---------------------------------------------------------------------
-- Joining
---------------------------------------------------------------------
-- Returns true, or false + reason (+ extra: minutes or seconds for 'muted' / 'locked_out')
local function tryJoin(src, Player, key, code)
    local left = muteLeft(Player)
    if left then return false, 'muted', left end

    if restricted[key] then
        if not canAccess(src, Player, restricted[key]) then return false, 'no_access' end
    elseif private[key] then
        local ch = private[key]
        if not (ch.owner == Player.PlayerData.citizenid or (unlocked[src] and unlocked[src][key])) then
            local cid = Player.PlayerData.citizenid
            local w = wrongCodes[cid]
            local now = GetGameTimer()
            if w and (w.lockUntil or 0) > now then return false, 'locked_out', math.ceil((w.lockUntil - now) / 1000) end
            if type(code) ~= 'string' or code ~= ch.code then
                w = w or { count = 0 }
                w.count = w.count + 1
                if w.count >= (tonumber(P.MaxWrongCodes) or 3) then
                    w.count = 0
                    w.lockUntil = now + (tonumber(P.LockoutSeconds) or 60) * 1000
                end
                wrongCodes[cid] = w
                return false, 'bad_code'
            end
            unlocked[src] = unlocked[src] or {}
            unlocked[src][key] = true
            wrongCodes[cid] = nil
        end
    end

    local ok, reason = exports['rsg-voice']:JoinRadio(src, key)
    if not ok then return false, reason == 'full' and 'full' or 'invalid' end
    connected[src] = key
    touchPrivate(key)
    return true
end

local JOIN_FAIL = { no_access = 'sv_no_access', full = 'sv_full', invalid = 'sv_invalid_freq', bad_code = 'sv_priv_bad_code' }
local function failJoin(src, reason, extra)
    if reason == 'muted' then return notify(src, 'sv_staff_muted_left', 'error', extra) end
    if reason == 'locked_out' then return notify(src, 'sv_priv_locked_out', 'error', extra) end
    notify(src, JOIN_FAIL[reason] or 'sv_invalid_freq', 'error')
end

---------------------------------------------------------------------
-- Item and startup
---------------------------------------------------------------------
CreateThread(function()
    if P.Enabled then
        if ensureDatabase() then
            local ok, err = pcall(loadPrivate)
            if ok then
                PRIV = true
                purgeExpired()
            else
                print(('^1[rsg-radio]^7 could not read private channels, they are disabled: %s'):format(tostring(err)))
            end
        else
            print('^1[rsg-radio]^7 private channels are disabled until the database table exists')
        end
    end

    if Config.RegisterItem and not RSGCore.Shared.Items[Config.Item] then
        local def = { name = Config.Item }
        for k, v in pairs(Config.ItemDefinition) do def[k] = v end
        exports['rsg-core']:AddItem(Config.Item, def)
    end
    RSGCore.Functions.CreateUseableItem(Config.Item, function(source)
        TriggerClientEvent('rsg-radio:client:open', source)
    end)

    -- Adopt players already on a channel (rsg-radio restarted while rsg-voice kept running)
    if GetResourceState('rsg-voice') == 'started' then
        for _, id in ipairs(GetPlayers()) do
            id = tonumber(id)
            local f = exports['rsg-voice']:GetPlayerRadio(id)
            if f then connected[id] = f end
        end
    end

    while true do -- remove private channels nobody uses any more
        Wait(3600 * 1000)
        if PRIV then purgeExpired() end
        local now = GetGameTimer()
        for cid, w in pairs(wrongCodes) do -- forget old failed attempts
            if (w.lockUntil or 0) < now then wrongCodes[cid] = nil end
        end
    end
end)

---------------------------------------------------------------------
-- Callbacks and events
---------------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-radio:server:getState', function(src, cb)
    local state = buildState(src)
    panelOpen[src] = state and true or nil
    cb(state)
end)

RegisterNetEvent('rsg-radio:server:panelClosed', function()
    panelOpen[source] = nil
end)

RegisterNetEvent('rsg-radio:server:join', function(freq, code)
    local src = source
    if tooFast(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not hasRadio(src) then return notify(src, 'cl_no_radio', 'error') end

    local key = parseFreq(freq)
    if not key then return notify(src, 'sv_invalid_freq', 'error') end
    if type(code) == 'string' then code = code:sub(1, 32) else code = nil end

    local ok, reason, extra = tryJoin(src, Player, key, code)
    if not ok then return failJoin(src, reason, extra) end
    notify(src, 'sv_joined', 'success', withUnit(key))
    pushState(src)
end)

-- Hotkeys: jump to the next (dir = 1) or previous (dir = -1) favorite the player can use
RegisterNetEvent('rsg-radio:server:cycleFavorite', function(dir)
    local src = source
    if dir ~= 1 and dir ~= -1 then return end
    if favTooFast(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not hasRadio(src) then return notify(src, 'cl_no_radio', 'error') end

    local usable = {}
    for _, f in ipairs(getFavorites(Player)) do
        local key = parseFreq(tonumber(f.freq))
        if key and canUse(src, Player, key) then usable[#usable + 1] = key end
    end
    if #usable == 0 then return notify(src, 'sv_fav_none', 'inform') end

    local idx = 0
    for i, k in ipairs(usable) do if k == connected[src] then idx = i end end
    local nextIdx = idx == 0 and (dir == 1 and 1 or #usable) or ((idx - 1 + dir) % #usable) + 1
    local key = usable[nextIdx]
    if key == connected[src] then return end

    local ok, reason, extra = tryJoin(src, Player, key)
    if not ok then return failJoin(src, reason, extra) end
    notify(src, 'sv_joined', 'success', withUnit(key))
    pushState(src)
end)

RegisterNetEvent('rsg-radio:server:addFavorite', function(freq, label)
    local src = source
    if favTooFast(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasRadio(src) then return end
    local key = parseFreq(freq)
    if not key then return notify(src, 'sv_invalid_freq', 'error') end
    if not canUse(src, Player, key) then return notify(src, 'sv_no_access', 'error') end

    local favs, found = getFavorites(Player), false
    label = cleanLabel(label, Config.FavoriteLabelLength)
    for _, f in ipairs(favs) do
        if f.freq == key then f.label = label found = true break end -- already saved: just update the name
    end
    if not found then
        if #favs >= Config.MaxFavorites then return notify(src, 'sv_fav_full', 'error') end
        favs[#favs + 1] = { freq = key, label = label }
    end
    Player.Functions.SetMetaData('radiofavs', favs)
    notify(src, 'sv_fav_added', 'success', withUnit(key))
    pushState(src)
end)

RegisterNetEvent('rsg-radio:server:removeFavorite', function(freq)
    local src = source
    if favTooFast(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = parseFreq(freq)
    if not key then return end
    local favs, kept = getFavorites(Player), {}
    for _, f in ipairs(favs) do
        if f.freq ~= key then kept[#kept + 1] = f end
    end
    if #kept == #favs then return end
    Player.Functions.SetMetaData('radiofavs', kept)
    notify(src, 'sv_fav_removed', 'inform', withUnit(key))
    pushState(src)
end)

RegisterNetEvent('rsg-radio:server:leave', function()
    local src = source
    if tooFast(src) or not connected[src] then return end
    dropFromRadio(src)
    notify(src, 'sv_left', 'inform')
    pushState(src)
end)

---------------------------------------------------------------------
-- Private channels (create / update / delete)
---------------------------------------------------------------------
local function ownedCount(cid)
    local n = 0
    for _, ch in pairs(private) do if ch.owner == cid then n = n + 1 end end
    return n
end

local function totalPrivate()
    local n = 0
    for _ in pairs(private) do n = n + 1 end
    return n
end

RegisterNetEvent('rsg-radio:server:savePrivate', function(freq, name, code)
    local src = source
    if not PRIV or privTooFast(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not hasRadio(src) then return end
    local cid = Player.PlayerData.citizenid

    local key = parseFreq(freq)
    if not key then return notify(src, 'sv_invalid_freq', 'error') end
    if restricted[key] then return notify(src, 'sv_priv_reserved', 'error') end
    name = cleanLabel(name, P.NameLength)
    if type(code) ~= 'string' or #code < P.CodeMin or #code > P.CodeMax or not code:match('^%w+$') then
        return notify(src, 'sv_priv_bad_format', 'error', P.CodeMin, P.CodeMax)
    end

    local ch = private[key]
    if ch then
        if ch.owner ~= cid then return notify(src, 'sv_priv_taken', 'error') end
        local codeChanged = ch.code ~= code
        ch.name, ch.code = name, code
        MySQL.update('UPDATE rsg_radio_private SET name = ?, code = ? WHERE freq = ?', { name, code, key })
        if codeChanged then kickFrom(key, cid, 'sv_priv_code_changed') end -- others must enter the new passcode
        notify(src, 'sv_priv_updated', 'success', withUnit(key))
    else
        if ownedCount(cid) >= P.MaxPerPlayer then return notify(src, 'sv_priv_limit', 'error', P.MaxPerPlayer) end
        if totalPrivate() >= P.MaxChannels then return notify(src, 'sv_priv_limit_server', 'error') end
        if membersOn(key) then return notify(src, 'sv_priv_in_use', 'error') end
        local cost, account = math.max(0, math.floor(tonumber(P.Cost) or 0)), P.MoneyType or 'cash'
        if cost > 0 and Player.Functions.GetMoney(account) < cost then return notify(src, 'sv_priv_no_money', 'error', cost) end
        private[key] = { owner = cid, name = name, code = code, last = os.time() } -- reserve before the awaits below
        if cost > 0 and not Player.Functions.RemoveMoney(account, cost, 'radio-private-channel') then
            private[key] = nil
            return notify(src, 'sv_priv_no_money', 'error', cost)
        end
        local ok = pcall(function()
            MySQL.insert.await('INSERT INTO rsg_radio_private (freq, owner, name, code) VALUES (?, ?, ?, ?)', { key, cid, name, code })
        end)
        if not ok then
            private[key] = nil
            if cost > 0 then Player.Functions.AddMoney(account, cost, 'radio-private-channel-refund') end
            return notify(src, 'sv_invalid_freq', 'error')
        end
        notify(src, 'sv_priv_created', 'success', withUnit(key))
    end
    markDirty()
    pushState(src)
end)

RegisterNetEvent('rsg-radio:server:deletePrivate', function(freq)
    local src = source
    if not PRIV or privTooFast(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local key = parseFreq(freq)
    local ch = key and private[key]
    if not ch or ch.owner ~= Player.PlayerData.citizenid then return end
    removePrivate(key)
    notify(src, 'sv_priv_deleted', 'inform', withUnit(key))
    pushState(src)
end)

---------------------------------------------------------------------
-- Channel changes, restarts, cleanup
---------------------------------------------------------------------
-- Another resource (or rsg-voice itself) changed a player's channel
AddEventHandler('rsg-voice:server:radioChanged', function(src, newFreq)
    if newFreq == nil and connected[src] then
        connected[src] = nil
        if GetPlayerName(src) then pushState(src) end
    end
    markDirty()
end)

-- rsg-voice restarted: channels were lost, put everyone back
AddEventHandler('onResourceStart', function(res)
    if res ~= 'rsg-voice' then return end
    SetTimeout(1500, function()
        for src, freq in pairs(connected) do
            if GetPlayerName(src) then exports['rsg-voice']:JoinRadio(src, freq) else connected[src] = nil end
        end
    end)
end)

local function cleanup(src)
    connected[src] = nil
    cooldown[src], favCooldown[src], privCooldown[src] = nil, nil, nil
    panelOpen[src], unlocked[src], jobCache[src] = nil, nil, nil
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', cleanup)
AddEventHandler('RSGCore:Server:OnJobUpdate', function(src) jobCache[src] = nil end)

-- Radio lost (dropped, stolen, sold) or access lost (job change, off duty): leave the channel
CreateThread(function()
    while true do
        Wait(CHECK_MS)
        for src, freq in pairs(connected) do
            local Player = RSGCore.Functions.GetPlayer(src)
            local reason
            if not Player then
                reason = false
            elseif not hasRadio(src) then
                reason = 'sv_lost_radio'
            elseif not canUse(src, Player, freq) then
                reason = 'sv_lost_access'
            end
            if reason ~= nil then
                dropFromRadio(src)
                if reason then
                    notify(src, reason, 'error')
                    pushState(src)
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Staff actions (shared by the chat commands and the admin panel)
---------------------------------------------------------------------
local perm = Config.Staff.Permission or 'admin'
local adminCooldown = {} -- [src] = GetGameTimer() when the next admin panel action is allowed
local staffLog = {}      -- newest last, kept in memory (restart clears it)
local LOG_MAX = 50

local function isStaff(src)
    return src == 0 or RSGCore.Functions.HasPermission(src, perm) and true or false
end

local function reply(src, text)
    if src == 0 then return print(('[rsg-radio] %s'):format(text)) end
    TriggerClientEvent('chat:addMessage', src, { color = { 255, 200, 0 }, multiline = true, args = { locale('notify_title'), text } })
end

-- Remember an action for the panel's log tab and optionally post it to Discord (never passcodes)
local function logStaff(src, text)
    local who = src == 0 and 'console' or (GetPlayerName(src) or tostring(src))
    staffLog[#staffLog + 1] = { time = os.date('%H:%M:%S'), who = who, text = text }
    if #staffLog > LOG_MAX then table.remove(staffLog, 1) end
    local url = Config.Staff.Webhook
    if type(url) ~= 'string' or not url:find('^https?://') then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'rsg-radio',
        embeds = { { title = 'rsg-radio staff action', description = text, footer = { text = who }, color = 16753920 } },
    }), { ['Content-Type'] = 'application/json' })
end

local function targetPlayer(arg)
    local id = tonumber(arg)
    if not id then return nil end
    return id, RSGCore.Functions.GetPlayer(id)
end

local function describe(id, Player)
    return ('[%s] %s'):format(id, GetPlayerName(id) or Player.PlayerData.citizenid)
end

local function doKick(src, id, Player)
    dropFromRadio(id)
    notify(id, 'sv_staff_kicked', 'error')
    pushState(id)
    logStaff(src, ('Removed %s from the radio'):format(describe(id, Player)))
end

local function doMute(src, id, Player, minutes)
    minutes = math.max(1, math.min(1440, math.floor(tonumber(minutes) or Config.Staff.MuteMinutes or 10)))
    staffMuted[Player.PlayerData.citizenid] = os.time() + minutes * 60
    dropFromRadio(id)
    notify(id, 'sv_staff_muted', 'error', minutes)
    pushState(id)
    logStaff(src, ('Blocked %s from the radio for %d minutes'):format(describe(id, Player), minutes))
    return minutes
end

local function doUnmute(src, cid)
    staffMuted[cid] = nil
    logStaff(src, ('Unblocked citizen %s'):format(cid))
end

local function doDeletePrivate(src, key)
    removePrivate(key)
    logStaff(src, ('Deleted the private channel %s'):format(withUnit(key)))
end

local function doClearChannel(src, key)
    local list, n = {}, 0
    for i, m in ipairs(exports['rsg-voice']:GetRadioMembers(key) or {}) do list[i] = m end
    for _, m in ipairs(list) do
        dropFromRadio(m)
        notify(m, 'sv_staff_kicked', 'error')
        pushState(m)
        n = n + 1
    end
    logStaff(src, ('Cleared %s (%d removed)'):format(withUnit(key), n))
    return n
end

---------------------------------------------------------------------
-- Staff commands
---------------------------------------------------------------------
RSGCore.Commands.Add('radioadmin', locale('staff_cmd_admin'), {}, false, function(src)
    if src ~= 0 then TriggerClientEvent('rsg-radio:client:admin:open', src) end
end, perm)

RSGCore.Commands.Add('radiolist', locale('staff_cmd_list'), { { name = 'freq', help = '' } }, false, function(src, args)
    if args[1] then
        local key = parseFreq(tonumber(args[1]))
        if not key then return reply(src, locale('staff_bad_freq')) end
        local members = exports['rsg-voice']:GetRadioMembers(key) or {}
        if #members == 0 then return reply(src, locale('staff_empty')) end
        reply(src, locale('staff_list_header', withUnit(key)))
        for _, m in ipairs(members) do
            local mp = RSGCore.Functions.GetPlayer(m)
            reply(src, locale('staff_member_row', m, GetPlayerName(m) or '?', mp and mp.PlayerData.citizenid or '?',
                mp and mp.PlayerData.job and mp.PlayerData.job.label or '?'))
        end
        return
    end
    local counts, keys = {}, {}
    for _, key in pairs(connected) do
        if not counts[key] then counts[key] = 0 keys[#keys + 1] = key end
        counts[key] = counts[key] + 1
    end
    if #keys == 0 then return reply(src, locale('staff_empty')) end
    table.sort(keys, numericSort)
    reply(src, locale('staff_list_header', ''))
    for _, key in ipairs(keys) do
        reply(src, locale('staff_list_row', withUnit(key), counts[key], private[key] and (' · ' .. private[key].name) or ''))
    end
end, perm)

RSGCore.Commands.Add('radiokick', locale('staff_cmd_kick'), { { name = 'id', help = '' } }, true, function(src, args)
    local id, Player = targetPlayer(args[1])
    if not Player then return reply(src, locale('staff_not_found')) end
    doKick(src, id, Player)
    reply(src, locale('staff_kicked_done', describe(id, Player)))
end, perm)

RSGCore.Commands.Add('radiomute', locale('staff_cmd_mute'), { { name = 'id', help = '' }, { name = 'minutes', help = '' } }, true, function(src, args)
    local id, Player = targetPlayer(args[1])
    if not Player then return reply(src, locale('staff_not_found')) end
    local minutes = doMute(src, id, Player, args[2])
    reply(src, locale('staff_muted_done', describe(id, Player), minutes))
end, perm)

RSGCore.Commands.Add('radiounmute', locale('staff_cmd_unmute'), { { name = 'id', help = '' } }, true, function(src, args)
    local id, Player = targetPlayer(args[1])
    if not Player then return reply(src, locale('staff_not_found')) end
    doUnmute(src, Player.PlayerData.citizenid)
    reply(src, locale('staff_unmuted_done', describe(id, Player)))
end, perm)

RSGCore.Commands.Add('radiodeleteprivate', locale('staff_cmd_delete'), { { name = 'freq', help = '' } }, true, function(src, args)
    local key = parseFreq(tonumber(args[1]))
    if not key then return reply(src, locale('staff_bad_freq')) end
    if not private[key] then return reply(src, locale('staff_private_none', withUnit(key))) end
    doDeletePrivate(src, key)
    reply(src, locale('staff_private_deleted', withUnit(key)))
end, perm)

---------------------------------------------------------------------
-- Admin panel (NUI). Every call re-checks the staff permission on the server.
---------------------------------------------------------------------
local function adminData()
    local online, byFreq, onAir = {}, {}, 0 -- online: [citizenid] = { id, name }
    for _, idStr in ipairs(GetPlayers()) do
        local id = tonumber(idStr)
        local mp = RSGCore.Functions.GetPlayer(id)
        local cid = mp and mp.PlayerData.citizenid
        if cid then online[cid] = { id = id, name = GetPlayerName(id) or '?' } end
        local f = exports['rsg-voice']:GetPlayerRadio(id)
        if f then
            byFreq[f] = byFreq[f] or {}
            byFreq[f][#byFreq[f] + 1] = {
                id = id, name = GetPlayerName(id) or '?', cid = cid or '?',
                job = mp and mp.PlayerData.job and mp.PlayerData.job.label or '?', blocked = mp and muteLeft(mp) or nil,
            }
            onAir = onAir + 1
        end
    end

    local keys, seen = {}, {}
    for _, c in ipairs(channels) do keys[#keys + 1] = c.key seen[c.key] = true end -- configured channels always show
    for key in pairs(byFreq) do if not seen[key] then keys[#keys + 1] = key end end
    table.sort(keys, numericSort)

    local chans = {}
    for _, key in ipairs(keys) do
        local kind, label = 'public', ''
        if restricted[key] then kind, label = 'restricted', locale(restricted[key].label)
        elseif private[key] then kind, label = 'private', private[key].name end
        chans[#chans + 1] = { freq = key, kind = kind, label = label, members = byFreq[key] or {} }
    end

    local privList, pKeys = {}, {}
    for key in pairs(private) do pKeys[#pKeys + 1] = key end
    table.sort(pKeys, numericSort)
    for _, key in ipairs(pKeys) do
        local ch, o = private[key], online[private[key].owner]
        privList[#privList + 1] = {
            freq = key, name = ch.name, owner = ch.owner, ownerName = o and o.name or nil,
            count = byFreq[key] and #byFreq[key] or 0, days = math.floor((os.time() - ch.last) / 86400),
        }
    end

    local mutes, now = {}, os.time()
    for cid, untilT in pairs(staffMuted) do
        if untilT > now then
            mutes[#mutes + 1] = { cid = cid, name = online[cid] and online[cid].name or nil, minutes = math.ceil((untilT - now) / 60) }
        else
            staffMuted[cid] = nil
        end
    end
    table.sort(mutes, function(a, b) return a.minutes > b.minutes end)

    local log = {}
    for i = #staffLog, 1, -1 do log[#log + 1] = staffLog[i] end -- newest first

    return {
        stats = { onAir = onAir, channels = #chans, private = #privList, blocks = #mutes },
        channels = chans, private = privList, mutes = mutes, log = log,
        unit = UNIT, muteDefault = Config.Staff.MuteMinutes or 10,
    }
end

RSGCore.Functions.CreateCallback('rsg-radio:server:admin:getData', function(src, cb)
    cb(isStaff(src) and adminData() or nil)
end)

-- Wraps an admin event: permission, cooldown, then the action; the panel gets fresh data afterwards
local function adminEvent(name, handler)
    RegisterNetEvent('rsg-radio:server:admin:' .. name, function(...)
        local src = source
        if src == 0 or not isStaff(src) or rateLimit(adminCooldown, src, 300) then return end
        if handler(src, ...) ~= false then
            markDirty()
            TriggerClientEvent('rsg-radio:client:admin:data', src, adminData())
        end
    end)
end

adminEvent('kick', function(src, id)
    local pid, Player = targetPlayer(id)
    if not Player then return notify(src, 'staff_not_found', 'error') end
    doKick(src, pid, Player)
end)

adminEvent('mute', function(src, id, minutes)
    local pid, Player = targetPlayer(id)
    if not Player then return notify(src, 'staff_not_found', 'error') end
    doMute(src, pid, Player, minutes)
end)

adminEvent('unmute', function(src, cid)
    if type(cid) ~= 'string' or #cid > 50 then return false end
    doUnmute(src, cid)
end)

adminEvent('deletePrivate', function(src, freq)
    local key = parseFreq(freq)
    if not key or not private[key] then return false end
    doDeletePrivate(src, key)
end)

adminEvent('clearChannel', function(src, freq)
    local key = parseFreq(freq)
    if not key then return false end
    doClearChannel(src, key)
end)

AddEventHandler('playerDropped', function() adminCooldown[source] = nil end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
-- exports['rsg-radio']:GetFrequency(src) -> frequency string or nil
exports('GetFrequency', function(src) return connected[tonumber(src)] end)
