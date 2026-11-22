-- ============================================
-- ADMIN PANEL BACKEND (/storeadmin > Overview, store management, Settings)
-- Loaded AFTER server.lua: uses StoresAPI (set at the end of server.lua) for the store cache and helpers.
-- Every callback checks admin permission on the server, rate-limits, validates its input and is written
-- to the `admin` Discord channel. Money moves only through the same till functions the shop uses.
-- ============================================
local RSGCore = exports['rsg-core']:GetCoreObject()
local A = StoresAPI

local PANEL = Config.AdminPanel or {}
local MAX_ADJUST = tonumber(PANEL.MaxAdjust) or 100000
local ACTIVITY   = tonumber(PANEL.Activity) or 25
local PAGE       = tonumber(PANEL.LedgerPage) or 40
local LEDGER_KINDS = { sale = true, buyback = true, wholesale = true, upkeep = true, withdraw = true, admin = true, bought = true }

-- Changes an admin makes are written to the audit trail when they succeed.
local AUDITED = { adminRunUpkeep = true, adminTill = true, adminUpkeep = true, adminStaff = true, adminTransfer = true,
    adminCloseStore = true, adminSettingsSave = true, adminSettingsReset = true }
local function registerCallback(name, fn)
    local short = name:match(':([^:]+)$')
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...)
        local res = fn(source, ...)
        if AUDITED[short] and type(res) == 'table' and res.ok then
            local args, npcId, parts = { ... }, nil, {}
            if short ~= 'adminRunUpkeep' and not short:find('Settings') then npcId = tonumber(args[1]) end
            for i = (npcId and 2 or 1), 4 do
                local v = args[i]
                if type(v) == 'string' or type(v) == 'number' then parts[#parts + 1] = tostring(v) end
            end
            A.audit(source, short, npcId, table.concat(parts, ' '))
        end
        cb(res)
    end)
end

local function fail(err, args) return { ok = false, err = err, errArgs = args } end

-- Admin + database ready. Returns a failure table to hand straight back, or nil.
local function gate(src, action)
    if A.denyIfNotAdmin(src, action) then return fail('sv_admin_only') end
    if not A.ready() then return fail('sv_try_again') end
end

local lastCall = {}
local function busy(src)
    local now = GetGameTimer()
    if lastCall[src] and now - lastCall[src] < 400 then return true end
    lastCall[src] = now
    return false
end
AddEventHandler('playerDropped', function() lastCall[source] = nil end)

local function clean(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return nil end
    return v:sub(1, max or 100)
end

local function playerStore(npcId)
    local npc = A.findNpc(npcId)
    if not npc or npc.kind ~= 'player' or not npc.shop then return nil end
    return npc
end

local function adminName(src) return A.charName(RSGCore.Functions.GetPlayer(src)) end

local function log(src, npc, title, fields)
    local out = A.shopFields(npc)
    for _, f in ipairs(fields or {}) do out[#out + 1] = f end
    Webhook.Send('admin', title, nil, src, out)
end

local function statusOf(npc)
    if npc.packed then return 'packed' end
    if not npc.owner then return 'closed' end
    if (npc.upkeepOwed or 0) > 0 then return 'overdue' end
    return 'open'
end

local function ownerOnline(npc)
    return npc.owner ~= nil and RSGCore.Functions.GetPlayerByCitizenId(npc.owner.citizenid) ~= nil
end

local function ledgerRows(rows)
    for _, r in ipairs(rows) do
        r.amount, r.qty, r.ts = tonumber(r.amount) or 0, tonumber(r.qty) or 0, tonumber(r.ts) or 0
    end
    return rows
end

-- ============================================
-- OVERVIEW
-- ============================================
registerCallback('rsg-stores:server:adminOverview', function(source)
    local g = gate(source, 'adminOverview'); if g then return g end

    local stats = { stores = 0, npcShops = 0, owned = 0, vacant = 0, overdue = 0, packed = 0, tills = 0, owed = 0, staff = 0 }
    local rows = {}
    for _, npc in ipairs(A.npcs()) do
        if npc.kind ~= 'player' then
            stats.npcShops = stats.npcShops + 1
        else
            local status = statusOf(npc)
            local till = A.round2(A.getBalance(npc.id))
            local staff = 0
            for _ in pairs(npc.staff or {}) do staff = staff + 1 end
            stats.stores, stats.tills, stats.staff = stats.stores + 1, stats.tills + till, stats.staff + staff
            stats.owed = stats.owed + (npc.upkeepOwed or 0)
            if status == 'closed' then stats.vacant = stats.vacant + 1 else stats.owned = stats.owned + 1 end
            if status == 'overdue' then stats.overdue = stats.overdue + 1 end
            if status == 'packed' then stats.packed = stats.packed + 1 end
            rows[#rows + 1] = {
                id = npc.id, name = npc.name, label = npc.shop and npc.shop.label or npc.name, status = status, sign = npc.prop ~= nil,
                owner = npc.owner and { name = npc.owner.name, cid = npc.owner.citizenid, online = ownerOnline(npc) } or nil,
                salePrice = npc.salePrice, till = till, owed = A.round2(npc.upkeepOwed or 0), staff = staff, items = npc.shop and #npc.shop.items or 0,
            }
        end
    end
    local order = { overdue = 1, open = 2, closed = 3, packed = 4 }
    table.sort(rows, function(a, b)
        if a.status ~= b.status then return order[a.status] < order[b.status] end
        return (a.label or ''):lower() < (b.label or ''):lower()
    end)
    stats.tills, stats.owed = A.round2(stats.tills), A.round2(stats.owed)

    local t = os.date('*t')
    local midnight = os.time({ year = t.year, month = t.month, day = t.day, hour = 0 })
    local today = MySQL.single.await("SELECT COUNT(*) AS c, COALESCE(SUM(amount), 0) AS s FROM rsg_shops_ledger WHERE kind = 'sale' AND ts >= ?", { midnight }) or {}
    stats.salesToday, stats.salesCount = A.round2(tonumber(today.s) or 0), tonumber(today.c) or 0

    local activity = ledgerRows(MySQL.query.await('SELECT npc_id, ts, kind, item, qty, amount, who FROM rsg_shops_ledger ORDER BY id DESC LIMIT ?', { ACTIVITY }) or {})
    for _, r in ipairs(activity) do
        local npc = A.findNpc(r.npc_id)
        r.store = npc and (npc.shop and npc.shop.label or npc.name) or ('#' .. tostring(r.npc_id))
    end
    return { ok = true, stats = stats, stores = rows, activity = activity }
end)

registerCallback('rsg-stores:server:adminRunUpkeep', function(source)
    local g = gate(source, 'adminRunUpkeep'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local ok, e = pcall(A.runUpkeep)
    if not ok then print('[rsg-stores] upkeep error: ' .. tostring(e)); return fail('sv_update_fail') end
    Webhook.Send('admin', locale('wh_t_adm_upkeep'), locale('sv_adm_upkeep_ran'), source)
    return { ok = true, msg = locale('sv_adm_upkeep_ran') }
end)

-- ============================================
-- STORE DETAIL
-- ============================================
local function buildDetail(npc)
    local up = A.upkeep()
    local on = A.upkeepOn(npc)
    local stats = {}
    for _, r in ipairs(MySQL.query.await('SELECT kind, COUNT(*) AS c, COALESCE(SUM(amount), 0) AS s FROM rsg_shops_ledger WHERE npc_id = ? GROUP BY kind', { npc.id }) or {}) do
        stats[r.kind] = { count = tonumber(r.c) or 0, sum = A.round2(tonumber(r.s) or 0) }
    end
    local stock = 0
    for _, it in ipairs(npc.shop.items) do stock = stock + (tonumber(it.amount) or 0) end

    local staff = {}
    for _, s in ipairs(A.staffOn() and A.staffList(npc) or {}) do
        local entry = npc.staff[s.cid]
        s.withdrawn = entry.withdrawDay == A.today() and A.round2(entry.withdrawn or 0) or 0
        staff[#staff + 1] = s
    end
    local ranks = {}
    for _, r in ipairs(A.rankList()) do ranks[#ranks + 1] = r.name end

    local amount = tonumber(up.Amount) or 0
    local evictAfter = tonumber(up.EvictAfterMissed) or 3
    return {
        id = npc.id, name = npc.name, label = npc.shop.label, status = statusOf(npc), sign = npc.prop ~= nil,
        x = npc.x, y = npc.y, z = npc.z,
        owner = npc.owner and { name = npc.owner.name, cid = npc.owner.citizenid, online = ownerOnline(npc) } or nil,
        till = A.round2(A.getBalance(npc.id)), tillSource = A.societyAccount(npc.id) and 'society' or 'database',
        items = #npc.shop.items, stock = stock, stats = stats,
        upkeep = on and {
            amount = amount, owed = A.round2(npc.upkeepOwed or 0), hours = tonumber(up.IntervalHours) or 24,
            nextIn = npc.upkeepNext and math.max(0, npc.upkeepNext - os.time()) or nil,
            evictAfter = evictAfter, evictAt = A.round2(evictAfter * amount),
        } or nil,
        staffOn = A.staffOn(), staff = staff, ranks = ranks,
    }
end

registerCallback('rsg-stores:server:adminStoreDetail', function(source, npcId)
    local g = gate(source, 'adminStoreDetail'); if g then return g end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    return { ok = true, detail = buildDetail(npc) }
end)

registerCallback('rsg-stores:server:adminLedger', function(source, npcId, kind, offset)
    local g = gate(source, 'adminLedger'); if g then return g end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    offset = math.max(0, math.min(100000, math.floor(tonumber(offset) or 0)))
    local rows
    if LEDGER_KINDS[kind] then
        rows = MySQL.query.await('SELECT ts, kind, item, qty, amount, who FROM rsg_shops_ledger WHERE npc_id = ? AND kind = ? ORDER BY id DESC LIMIT ? OFFSET ?',
            { npc.id, kind, PAGE + 1, offset })
    else
        rows = MySQL.query.await('SELECT ts, kind, item, qty, amount, who FROM rsg_shops_ledger WHERE npc_id = ? ORDER BY id DESC LIMIT ? OFFSET ?',
            { npc.id, PAGE + 1, offset })
    end
    rows = ledgerRows(rows or {})
    local more = #rows > PAGE
    if more then rows[#rows] = nil end
    return { ok = true, rows = rows, more = more, offset = offset, page = PAGE }
end)

-- ============================================
-- AUDIT LOG
-- ============================================
registerCallback('rsg-stores:server:adminAudit', function(source, offset)
    local g = gate(source, 'adminAudit'); if g then return g end
    local page = tonumber(PANEL.AuditPage) or 40
    offset = math.max(0, math.min(100000, math.floor(tonumber(offset) or 0)))
    local rows = MySQL.query.await('SELECT ts, actor_name, action, npc_id, detail FROM rsg_shops_audit ORDER BY id DESC LIMIT ? OFFSET ?', { page + 1, offset }) or {}
    local more = #rows > page
    if more then rows[#rows] = nil end
    for _, r in ipairs(rows) do
        local npc = r.npc_id and A.findNpc(r.npc_id)
        r.store = npc and ((npc.shop and npc.shop.label) or npc.name) or nil
    end
    return { ok = true, rows = rows, more = more, offset = offset, page = page }
end)

-- ============================================
-- FINANCE: adjust the till
-- ============================================
registerCallback('rsg-stores:server:adminTill', function(source, npcId, action, amount, reason)
    local g = gate(source, 'adminTill'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount < 0.01 or amount > MAX_ADJUST then return fail('sv_adm_amount', { MAX_ADJUST }) end
    amount = A.round2(amount)
    reason = clean(reason, 100)
    if not reason then return fail('sv_adm_reason') end
    local who = adminName(source)
    local msg

    if action == 'add' then
        A.addBalance(npc.id, amount)
        A.ledger(npc, 'admin', reason, 0, amount, who)
        msg = locale('sv_adm_till_added'):format(amount)
    elseif action == 'remove' then
        if not A.takeBalance(npc.id, amount) then return fail('sv_adm_till_low') end
        A.ledger(npc, 'admin', reason, 0, -amount, who)
        msg = locale('sv_adm_till_removed'):format(amount)
    elseif action == 'payout' then
        local Owner = npc.owner and RSGCore.Functions.GetPlayerByCitizenId(npc.owner.citizenid)
        if not Owner then return fail('sv_adm_owner_offline') end
        if not A.takeBalance(npc.id, amount) then return fail('sv_adm_till_low') end
        if not Owner.Functions.AddMoney('cash', amount, 'rsg-stores-admin-payout') then
            A.addBalance(npc.id, amount)
            return fail('sv_update_fail')
        end
        A.ledger(npc, 'admin', reason, 0, -amount, who)
        A.notify(Owner.PlayerData.source, npc.shop.label, locale('sv_adm_owner_payout'):format(amount), 'inform')
        msg = locale('sv_adm_till_payout'):format(amount, npc.owner.name)
    else
        return fail('sv_adm_bad_action')
    end

    log(source, npc, locale('wh_t_adm_till'), {
        { name = locale('wh_f_action'), value = ('%s'):format(action) },
        { name = locale('wh_f_total'), value = Webhook.Money(amount) },
        { name = locale('wh_f_reason'), value = reason },
    })
    return { ok = true, msg = msg, detail = buildDetail(npc) }
end)

-- ============================================
-- UPKEEP
-- ============================================
registerCallback('rsg-stores:server:adminUpkeep', function(source, npcId, action, value)
    local g = gate(source, 'adminUpkeep'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    if not A.upkeepOn(npc) then return fail('sv_adm_no_upkeep') end
    local who = adminName(source)
    local up = A.upkeep()
    local wasOwing = (npc.upkeepOwed or 0) > 0
    local msg, ownerMsg

    local function saveOwed()
        MySQL.update.await('UPDATE rsg_shops_npcs SET upkeep_owed = ?, upkeep_next = ? WHERE id = ?', { npc.upkeepOwed or 0, npc.upkeepNext, npc.id })
        if wasOwing ~= ((npc.upkeepOwed or 0) > 0) then A.broadcastShop(npc) end -- opens / closes the store to customers
    end

    if action == 'waive' then
        npc.upkeepOwed = 0
        saveOwed()
        A.ledger(npc, 'admin', 'upkeep waived', 0, 0, who)
        msg, ownerMsg = locale('sv_adm_upkeep_waived'), locale('sv_adm_owner_waived')
    elseif action == 'collect' then
        local owed = A.round2(npc.upkeepOwed or 0)
        if owed <= 0 then return fail('sv_upkeep_none') end
        if not A.takeBalance(npc.id, owed) then return fail('sv_adm_till_low') end
        npc.upkeepOwed = 0
        saveOwed()
        A.ledger(npc, 'upkeep', nil, 0, owed, who)
        msg, ownerMsg = locale('sv_adm_upkeep_collected'):format(owed), locale('sv_adm_owner_waived')
    elseif action == 'setowed' then
        local v = tonumber(value)
        if not v or v ~= v or v < 0 or v > 1000000 then return fail('sv_adm_amount', { 1000000 }) end
        npc.upkeepOwed = A.round2(v)
        saveOwed()
        A.ledger(npc, 'admin', 'upkeep owed set', 0, 0, who)
        msg = locale('sv_adm_upkeep_set'):format(npc.upkeepOwed)
    elseif action == 'postpone' then
        local h = tonumber(value)
        if not h or h ~= h or h ~= math.floor(h) or h < 1 or h > 720 then return fail('sv_adm_hours') end
        npc.upkeepNext = math.max(os.time(), npc.upkeepNext or 0) + h * 3600
        saveOwed()
        msg = locale('sv_adm_upkeep_postponed'):format(h)
    elseif action == 'reset' then
        npc.upkeepNext = os.time() + math.floor((tonumber(up.IntervalHours) or 24) * 3600)
        saveOwed()
        msg = locale('sv_adm_upkeep_reset')
    else
        return fail('sv_adm_bad_action')
    end

    if ownerMsg then A.notifyOwner(npc, ownerMsg) end
    log(source, npc, locale('wh_t_adm_upkeep'), {
        { name = locale('wh_f_action'), value = ('%s'):format(action) },
        { name = locale('wh_f_total'), value = Webhook.Money(npc.upkeepOwed or 0) },
    })
    return { ok = true, msg = msg, detail = buildDetail(npc) }
end)

-- ============================================
-- STAFF
-- ============================================
registerCallback('rsg-stores:server:adminStaff', function(source, npcId, action, cid, rank)
    local g = gate(source, 'adminStaff'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    local s = type(cid) == 'string' and npc.staff and npc.staff[cid]
    if not s then return fail('sv_staff_not_found') end
    local msg

    if action == 'fire' then
        A.removeStaff(npc, cid)
        local T = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if T then A.notify(T.PlayerData.source, npc.shop.label, locale('sv_staff_you_fired'):format(npc.shop.label), 'inform') end
        msg = locale('sv_adm_staff_fired'):format(s.name)
    elseif action == 'rank' then
        local name, perms = A.resolveRank(rank)
        if name == 'custom' or next(perms) == nil then return fail('sv_staff_no_perms') end
        MySQL.update.await('UPDATE rsg_shops_staff SET staff_rank = ?, perms = ? WHERE npc_id = ? AND citizenid = ?', { name, A.encodePerms(perms), npc.id, cid })
        s.rank, s.perms = name, perms
        msg = locale('sv_adm_staff_rank'):format(s.name, A.rankLabel(name))
    else
        return fail('sv_adm_bad_action')
    end

    log(source, npc, locale('wh_t_adm_staff'), {
        { name = locale('wh_f_action'), value = ('%s'):format(action) },
        { name = locale('wh_f_staff'), value = ('%s (`%s`)'):format(s.name, cid) },
    })
    return { ok = true, msg = msg, detail = buildDetail(npc) }
end)

-- ============================================
-- OWNERSHIP
-- ============================================
-- target = { id = serverId } for an online player, or { citizenid = 'ABC12345' } (online or offline).
local function resolveOwner(target)
    if type(target) ~= 'table' then return nil end
    local P
    if tonumber(target.id) then
        P = RSGCore.Functions.GetPlayer(tonumber(target.id))
    elseif type(target.citizenid) == 'string' and #target.citizenid <= 50 and target.citizenid:match('^%w+$') then
        P = RSGCore.Functions.GetPlayerByCitizenId(target.citizenid)
        if not P then
            local ok, off = pcall(RSGCore.Functions.GetOfflinePlayerByCitizenId, target.citizenid)
            P = ok and off or nil
        end
    end
    if not P or not P.PlayerData or not P.PlayerData.citizenid then return nil end
    return { citizenid = P.PlayerData.citizenid, name = A.charName(P) }
end

registerCallback('rsg-stores:server:adminTransfer', function(source, npcId, target)
    local g = gate(source, 'adminTransfer'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    if npc.packed then return fail('sv_adm_packed') end
    local new = resolveOwner(target)
    if not new then return fail('sv_adm_target_unknown') end
    if npc.owner and npc.owner.citizenid == new.citizenid then return fail('sv_adm_same_owner') end

    local old = { id = npc.id, kind = npc.kind, owner = npc.owner, shop = npc.shop, name = npc.name }
    MySQL.update.await('UPDATE rsg_shops_npcs SET owner_citizenid = ?, owner_name = ?, resale_price = NULL WHERE id = ?', { new.citizenid, new.name, npc.id })
    npc.owner, npc.resalePrice = new, nil
    A.clearStaff(npc) -- staff belong to the owner who hired them
    StoreSociety.Update(old, npc)
    A.broadcastNPCs()

    local OldP = old.owner and RSGCore.Functions.GetPlayerByCitizenId(old.owner.citizenid)
    if OldP then A.notify(OldP.PlayerData.source, npc.shop.label, locale('sv_adm_owner_lost'):format(npc.shop.label), 'error') end
    local NewP = RSGCore.Functions.GetPlayerByCitizenId(new.citizenid)
    if NewP then A.notify(NewP.PlayerData.source, npc.shop.label, locale('sv_adm_owner_gained'):format(npc.shop.label), 'success') end

    log(source, npc, locale('wh_t_adm_transfer'), {
        { name = locale('wh_f_owner'), value = ('%s → %s (`%s`)'):format(old.owner and old.owner.name or locale('wh_no_owner'), new.name, new.citizenid) },
    })
    return { ok = true, msg = locale('sv_adm_transferred'):format(new.name), detail = buildDetail(npc) }
end)

-- mode 'evict' = give stock, till and sign back to the (online) owner; 'forfeit' = repossess, everything is lost.
registerCallback('rsg-stores:server:adminCloseStore', function(source, npcId, mode)
    local g = gate(source, 'adminCloseStore'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local npc = playerStore(npcId)
    if not npc then return fail('sv_shop_notfound') end
    if not npc.owner then return fail('sv_evict_no_owner') end
    if mode ~= 'evict' and mode ~= 'forfeit' then return fail('sv_adm_bad_action') end
    if mode == 'evict' and not ownerOnline(npc) then return fail('sv_evict_offline') end

    local owner, label = npc.owner, npc.shop.label
    local fields = A.shopFields(npc)
    local returned, till = A.closeOwnedStore(npc, mode == 'evict', mode == 'evict' and 'evicted' or 'repossessed')
    fields[#fields + 1] = { name = locale('wh_f_action'), value = mode }
    fields[#fields + 1] = { name = locale('wh_f_owner'), value = ('%s (`%s`)'):format(owner.name, owner.citizenid) }
    fields[#fields + 1] = { name = locale('wh_f_returned'), value = #returned > 0 and table.concat(returned, ', ') or '-' }
    fields[#fields + 1] = { name = locale('wh_f_payout'), value = Webhook.Money(till) }
    Webhook.Send('admin', locale('wh_t_adm_close'), nil, source, fields)
    return { ok = true, closed = true, msg = locale('sv_adm_closed'):format(label) }
end)

-- ============================================
-- LIVE SETTINGS
-- ============================================
registerCallback('rsg-stores:server:adminSettingsGet', function(source)
    local g = gate(source, 'adminSettingsGet'); if g then return g end
    return { ok = true, groups = Settings.Get() }
end)

local function settingsLog(src, applied)
    local lines = {}
    for _, a in ipairs(applied) do
        lines[#lines + 1] = ('**%s:** %s → %s'):format(a.path, Settings.Describe(a.old), Settings.Describe(a.new))
    end
    Webhook.Send('admin', locale('wh_t_adm_settings'), table.concat(lines, '\n'), src)
end

local function settingsChanged(src, applied)
    A.reloadConfig()
    TriggerClientEvent('rsg-stores:client:applySettings', -1, Settings.Effective())
    settingsLog(src, applied)
end

registerCallback('rsg-stores:server:adminSettingsSave', function(source, changes)
    local g = gate(source, 'adminSettingsSave'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    local res = Settings.Save(changes)
    if #res.applied > 0 then settingsChanged(source, res.applied) end
    local hasErrors = next(res.errors) ~= nil
    return {
        ok = not hasErrors, err = hasErrors and 'sv_set_some_failed' or nil, errors = res.errors,
        msg = #res.applied > 0 and locale('sv_set_saved'):format(#res.applied) or nil,
        groups = Settings.Get(),
    }
end)

registerCallback('rsg-stores:server:adminSettingsReset', function(source, path)
    local g = gate(source, 'adminSettingsReset'); if g then return g end
    if busy(source) then return fail('sv_slow_down') end
    if not Settings.Reset(path) then return fail('ui_set_err_unknown') end
    settingsChanged(source, { { path = path, old = '(override)', new = '(config.lua)' } })
    return { ok = true, msg = locale('sv_set_reset'), groups = Settings.Get() }
end)
