local RSGCore = exports['rsg-core']:GetCoreObject()

-- rsg-core callback wrapper: handler returns its answer, we pass it to cb.
local function registerCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...) cb(fn(source, ...)) end)
end

local SELL_PCT       = Config.SellPricePercentage or 0.80
local MAX_QTY        = 1000   -- max units per line
local MAX_CART_LINES = 100    -- max distinct lines per cart
local MAX_DIST       = (Config.TargetDistance or 2.5) + 5.0 -- server-side proximity tolerance
local TX_COOLDOWN    = 750    -- ms between transactions per player

local CachedNPCs, CachedBlips = {}, {}
local CachedPresets = { model = {}, blip = {} } -- admin-managed dropdown options
local DbReady = false
local lastTx = {}

local getBalance, addBalance, takeBalance, broadcastShop, notifyOwner -- defined in OWNED STORE HELPERS
local ownerUpkeepInfo, wholesaleList, ownerLedger                      -- defined in OWNER MANAGEMENT
local OS = Config.OwnedStores or {}
local OWNED_ENABLED = OS.Enabled ~= false
local OWNED_PCT     = tonumber(OS.BuyBackPercentage) or SELL_PCT
local BLACKLIST = {}
for _, n in ipairs(OS.BlacklistItems or {}) do BLACKLIST[n] = true end

-- ============================================
-- HELPERS
-- ============================================
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

local function notify(src, title, desc, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = desc, type = nType or 'error', duration = 5000 })
end

local function isAdmin(src)
    return RSGCore.Functions.GetPlayer(src) ~= nil and RSGCore.Functions.HasPermission(src, Config.AdminPermission or 'admin') == true
end

local function denyIfNotAdmin(src, action)
    if isAdmin(src) then return false end
    notify(src, locale('t_access_denied'), locale('sv_admin_only'))
    Webhook.Security(src, locale('wh_sec_admin_event'), {
        { name = locale('wh_f_event'), value = action or locale('wh_unknown') },
    })
    return true
end

local function shopFields(npc)
    return {
        { name = locale('wh_f_shop'), value = ('%s (`%s`)'):format(npc.shop and npc.shop.label or npc.name, npc.shop and npc.shop.name or '-') },
        { name = locale('wh_f_npc_id'), value = tostring(npc.id) },
    }
end

local function coordStr(t) return ('%.2f, %.2f, %.2f'):format(t.x or 0, t.y or 0, t.z or 0) end

local function charName(P)
    local ci = P and P.PlayerData.charinfo or {}
    local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or (P and P.PlayerData.citizenid or '?')
end

-- Owner-facing ledger (player-owned stores only). Best effort: never blocks a trade.
local LEDGER = Config.Ledger or {}
local function ledger(npc, kind, item, qty, amount, who)
    if LEDGER.Enabled == false or not npc or npc.kind ~= 'player' then return end
    MySQL.insert('INSERT INTO rsg_shops_ledger (npc_id, ts, kind, item, qty, amount, who) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { npc.id, os.time(), kind, item, qty or 0, amount or 0, who })
end

-- Best job/gang discount (0..MaxDiscount) for NPC shop purchases.
local DISC = Config.Discounts or {}
local function discountFor(Player)
    if not DISC.Enabled or not Player then return 0 end
    local job, gang = Player.PlayerData.job, Player.PlayerData.gang
    local d = math.max(tonumber(job and DISC.Jobs and DISC.Jobs[job.name]) or 0, tonumber(gang and DISC.Gangs and DISC.Gangs[gang.name]) or 0)
    return math.min(math.max(d, 0), tonumber(DISC.MaxDiscount) or 0.5)
end

-- Positive whole number within [1, MAX_QTY], else nil (blocks 1.5 / -1 / NaN / huge).
local function toQty(v)
    v = tonumber(v)
    if not v or v ~= v or v < 1 or v > MAX_QTY or math.floor(v) ~= v then return nil end
    return v
end

local function onCooldown(src)
    local now = GetGameTimer()
    if lastTx[src] and now - lastTx[src] < TX_COOLDOWN then return true end
    lastTx[src] = now
    return false
end

local function getCash(src)
    local P = RSGCore.Functions.GetPlayer(src)
    return P and P.PlayerData.money.cash or 0
end

local function findNpc(id)
    id = tonumber(id)
    if not id then return nil end
    for i, npc in ipairs(CachedNPCs) do
        if npc.id == id then return npc, i end
    end
end

local function findShopItem(npc, itemName)
    for _, item in ipairs(npc.shop.items) do
        if item.name == itemName then return item end
    end
end

local function findBlip(id)
    id = tonumber(id)
    for i, b in ipairs(CachedBlips) do
        if b.id == id then return b, i end
    end
end

-- Player must be standing at the NPC (stops remote buy/sell via injected events).
local function isNearNpc(src, npc)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(npc.x, npc.y, npc.z)) <= MAX_DIST
end

-- Resolve + validate an open shop for a transaction. Returns npc or nil (and notifies).
local function resolveShop(src, npcId, wantType, failEvent)
    local npc = findNpc(npcId)
    if not npc or not npc.shop then
        TriggerClientEvent(failEvent, src, false, locale('sv_shop_notfound'), getCash(src))
        return nil
    end
    if npc.kind == 'player' and (not npc.owner or (npc.upkeepOwed or 0) > 0) then
        TriggerClientEvent(failEvent, src, false, locale(npc.owner and 'sv_store_upkeep' or 'sv_store_closed'), getCash(src))
        return nil
    end
    local t = npc.shop.type
    if t ~= 'both' and t ~= wantType then
        TriggerClientEvent(failEvent, src, false, locale(wantType == 'buy' and 'sv_shop_not_sell' or 'sv_shop_not_buy'), getCash(src))
        return nil
    end
    if not isNearNpc(src, npc) then
        Webhook.Security(src, locale('wh_sec_too_far_trade'), {
            { name = locale('wh_f_action'), value = locale(wantType == 'buy' and 'wh_act_buy' or 'wh_act_sell') }, table.unpack(shopFields(npc)),
        })
        TriggerClientEvent(failEvent, src, false, locale('sv_too_far'), getCash(src))
        return nil
    end
    return npc
end

local function shopItemsForClient(npc)
    local out = {}
    for _, item in ipairs(npc.shop.items) do
        out[#out + 1] = { name = item.name, label = item.label, price = item.price, amount = item.amount }
    end
    return out
end

local function restoreStock(npcId, name, qty)
    MySQL.update.await('UPDATE rsg_shops_items SET stock = stock + ? WHERE npc_id = ? AND item_name = ?', { qty, npcId, name })
end

local function takeStock(npcId, name, qty)
    local affected = MySQL.update.await(
        'UPDATE rsg_shops_items SET stock = stock - ? WHERE npc_id = ? AND item_name = ? AND stock >= ?',
        { qty, npcId, name, qty })
    return affected and affected > 0
end

local function resyncStock(npc)
    local rows = MySQL.query.await('SELECT item_name, stock FROM rsg_shops_items WHERE npc_id = ?', { npc.id }) or {}
    for _, row in ipairs(rows) do
        local si = findShopItem(npc, row.item_name)
        if si and row.stock ~= nil then si.amount = tonumber(row.stock) end
    end
end

-- ============================================
-- PLAYER-OWNED STORE HELPERS
-- ============================================
getBalance = function(npcId)
    return round2(tonumber(MySQL.scalar.await('SELECT balance FROM rsg_shops_npcs WHERE id = ?', { npcId })) or 0)
end

addBalance = function(npcId, amount)
    MySQL.update.await('UPDATE rsg_shops_npcs SET balance = balance + ? WHERE id = ?', { amount, npcId })
end

-- Atomic: only succeeds when the till holds enough.
takeBalance = function(npcId, amount)
    local affected = MySQL.update.await('UPDATE rsg_shops_npcs SET balance = balance - ? WHERE id = ? AND balance >= ?', { amount, npcId, amount })
    return affected and affected > 0
end

-- Light per-store sync (no NPC respawn); balance is never broadcast.
broadcastShop = function(npc)
    TriggerClientEvent('rsg-stores:client:updateShop', -1, npc.id, npc.shop, npc.owner, npc.upkeepOwed)
end

notifyOwner = function(npc, msg)
    if OS.NotifyOwner == false or not npc.owner then return end
    local Owner = RSGCore.Functions.GetPlayerByCitizenId(npc.owner.citizenid)
    if Owner then notify(Owner.PlayerData.source, npc.shop and npc.shop.label or npc.name, msg, 'inform') end
end

-- Online player (server id) -> { citizenid, name } or nil.
local function ownerFromServerId(id)
    local P = RSGCore.Functions.GetPlayer(tonumber(id) or -1)
    if not P then return nil end
    local ci = P.PlayerData.charinfo or {}
    local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return { citizenid = P.PlayerData.citizenid, name = name ~= '' and name or P.PlayerData.citizenid }
end

-- ============================================
-- SANITISERS (admin payloads -> clean server tables)
-- ============================================
local VALID_TYPES = { both = true, buy = true, sell = true }
local VALID_COLORS = {}
for _, c in ipairs(Config.BlipColors) do VALID_COLORS[c.value] = true end

local function str(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return nil end
    return v:sub(1, max or 100)
end

local function sanitizeItems(items)
    local out, seen = {}, {}
    if type(items) ~= 'table' then return out end
    for _, it in ipairs(items) do
        local name = type(it) == 'table' and str(it.name)
        local shared = name and RSGCore.Shared.Items[name]
        if shared and not seen[name] then
            seen[name] = true
            local stock = tonumber(it.amount)
            out[#out + 1] = {
                name   = name,
                label  = str(it.label) or shared.label or name,
                price  = round2(math.max(0, tonumber(it.price) or 0)),
                amount = stock and math.max(0, math.floor(stock)) or nil,
            }
        end
    end
    return out
end

local function sanitizeNpc(data)
    if type(data) ~= 'table' then return nil end
    local npc = {
        name  = str(data.name) or locale('sv_default_npc'),
        kind  = (OWNED_ENABLED and data.kind == 'player') and 'player' or 'npc',
        model = str(data.model),
        x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z), h = tonumber(data.h) or 0.0,
    }
    if npc.kind == 'player' then npc.model = npc.model or '' end -- no ped is spawned for owned stores
    if not npc.model or not npc.x or not npc.y or not npc.z then return nil end
    if type(data.shop) == 'table' then
        local sName = str(data.shop.name)
        if sName then
            npc.shop = {
                name  = sName,
                label = str(data.shop.label) or sName,
                type  = VALID_TYPES[data.shop.type] and data.shop.type or 'both',
                items = npc.kind == 'player' and {} or sanitizeItems(data.shop.items), -- owners stock their own store
            }
        end
    end
    -- an owned store is always a shop
    if npc.kind == 'player' and not npc.shop then return nil end
    return npc
end

local function sanitizeBlip(data)
    if type(data) ~= 'table' then return nil end
    local b = {
        name   = str(data.name) or locale('sv_default_blip'),
        sprite = math.floor(tonumber(data.sprite) or 0),
        color  = VALID_COLORS[data.color] and data.color or nil,
        x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z),
        associatedNpcId = tonumber(data.associatedNpcId),
    }
    if not b.x or not b.y or not b.z then return nil end
    return b
end

-- ============================================
-- PRESETS (admin-managed NPC model / blip type dropdown options)
-- ============================================
local PRESET_KINDS = { model = true, blip = true }

-- Signed 32-bit int (blip hashes are stored/used signed, like Config.BlipTypes)
local function toSigned(n)
    n = math.floor(n) % 4294967296
    return n >= 2147483648 and n - 4294967296 or n
end

-- Validates + normalises a preset. Returns preset or nil, errorLocaleKey.
local function sanitizePreset(data)
    if type(data) ~= 'table' or not PRESET_KINDS[data.kind] then return nil, 'sv_preset_invalid' end
    local label = type(data.label) == 'string' and data.label:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 100) or ''
    local value = type(data.value) == 'string' and data.value:gsub('%s', '') or tostring(data.value or '')
    if value == '' or #value > 100 then return nil, 'sv_preset_invalid' end
    if data.kind == 'model' then
        if not value:match('^[%w_]+$') then return nil, 'sv_preset_invalid' end
        value = value:lower()
    else
        local n = tonumber(value)
        if n then
            if n ~= n or math.floor(n) ~= n then return nil, 'sv_preset_invalid' end
            value = tostring(toSigned(n))
        elseif value:match('^[%w_]+$') then
            value = tostring(toSigned(joaat(value)))  -- accept sprite names, e.g. blip_shop_store
        else
            return nil, 'sv_preset_invalid'
        end
    end
    if label == '' then label = value end
    return { kind = data.kind, label = label, value = value }
end

local function presetOut(row)
    return { id = tonumber(row.id), label = row.label, value = row.kind == 'blip' and tonumber(row.value) or row.value }
end

local function seedPresets()
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rsg_shops_presets') or 0
    if count > 0 then return end
    local function seed(kind, list)
        for _, o in ipairs(list or {}) do
            MySQL.insert.await('INSERT IGNORE INTO rsg_shops_presets (kind, label, value) VALUES (?, ?, ?)',
                { kind, o.label, tostring(o.value) })
        end
    end
    seed('model', Config.NpcModels)
    seed('blip', Config.BlipTypes)
    print('[rsg-stores] ' .. locale('sv_presets_seeded'))
end

local function LoadPresets()
    seedPresets()
    CachedPresets = { model = {}, blip = {} }
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rsg_shops_presets ORDER BY id ASC') or {}) do
        if PRESET_KINDS[row.kind] then
            local list = CachedPresets[row.kind]
            list[#list + 1] = presetOut(row)
        end
    end
end

local function findPreset(id)
    id = tonumber(id)
    for kind, list in pairs(CachedPresets) do
        for i, p in ipairs(list) do
            if p.id == id then return p, kind, i end
        end
    end
end

registerCallback('rsg-stores:server:getPresets', function(source)
    if not isAdmin(source) then return nil end
    return CachedPresets
end)

-- Create (no id) or update (id) a preset. Returns { ok, presets, err }.
registerCallback('rsg-stores:server:savePreset', function(source, id, data)
    if denyIfNotAdmin(source, 'savePreset') then return { ok = false } end
    local p, err = sanitizePreset(data)
    if not p then return { ok = false, err = err } end
    local existing, oldKind = nil, nil
    if id then
        existing, oldKind = findPreset(id)
        if not existing then return { ok = false, err = 'sv_preset_invalid' } end
    end
    local dupe = MySQL.scalar.await('SELECT id FROM rsg_shops_presets WHERE kind = ? AND value = ?', { p.kind, p.value })
    if dupe and tonumber(dupe) ~= (existing and existing.id) then return { ok = false, err = 'sv_preset_exists' } end

    if existing then
        MySQL.update.await('UPDATE rsg_shops_presets SET kind = ?, label = ?, value = ? WHERE id = ?', { p.kind, p.label, p.value, existing.id })
    else
        MySQL.insert.await('INSERT INTO rsg_shops_presets (kind, label, value) VALUES (?, ?, ?)', { p.kind, p.label, p.value })
    end
    LoadPresets()
    Webhook.Send('admin', locale(existing and 'wh_t_preset_updated' or 'wh_t_preset_created'), nil, source, {
        { name = locale('wh_f_type'), value = p.kind }, { name = locale('wh_f_name'), value = p.label },
        { name = locale('wh_f_value'), value = ('`%s`'):format(p.value) },
    })
    return { ok = true, presets = CachedPresets }
end)

registerCallback('rsg-stores:server:deletePreset', function(source, id)
    if denyIfNotAdmin(source, 'deletePreset') then return { ok = false } end
    local existing, kind = findPreset(id)
    if not existing then return { ok = false, err = 'sv_preset_invalid' } end
    MySQL.query.await('DELETE FROM rsg_shops_presets WHERE id = ?', { existing.id })
    LoadPresets()
    Webhook.Send('admin', locale('wh_t_preset_deleted'), nil, source, {
        { name = locale('wh_f_type'), value = kind }, { name = locale('wh_f_name'), value = existing.label },
        { name = locale('wh_f_value'), value = ('`%s`'):format(tostring(existing.value)) },
    })
    return { ok = true, presets = CachedPresets }
end)

-- ============================================
-- DATABASE / CACHE
-- ============================================
local function LoadCacheFromDB()
    local npcs  = MySQL.query.await('SELECT * FROM rsg_shops_npcs ORDER BY id ASC') or {}
    local items = MySQL.query.await('SELECT * FROM rsg_shops_items ORDER BY id ASC') or {}
    local blips = MySQL.query.await('SELECT * FROM rsg_shops_blips ORDER BY id ASC') or {}

    local itemsByNpc = {}
    for _, row in ipairs(items) do
        local nid = tonumber(row.npc_id)
        itemsByNpc[nid] = itemsByNpc[nid] or {}
        table.insert(itemsByNpc[nid], {
            name   = row.item_name,
            label  = row.label or row.item_name,
            price  = tonumber(row.price) or 0,
            amount = row.stock ~= nil and tonumber(row.stock) or nil,
        })
    end

    CachedNPCs = {}
    for _, row in ipairs(npcs) do
        local nid = tonumber(row.id)
        local entry = {
            id = nid, name = row.name, model = row.model,
            kind = row.store_kind == 'player' and 'player' or 'npc',
            x = tonumber(row.x) or 0, y = tonumber(row.y) or 0, z = tonumber(row.z) or 0, h = tonumber(row.h) or 0,
        }
        if entry.kind == 'player' and row.owner_citizenid and row.owner_citizenid ~= '' then
            entry.owner = { citizenid = row.owner_citizenid, name = row.owner_name or row.owner_citizenid }
        end
        if entry.kind == 'player' and row.prop_model and row.prop_model ~= '' then entry.prop = row.prop_model end
        if entry.kind == 'player' then
            entry.upkeepOwed = tonumber(row.upkeep_owed) or 0
            entry.upkeepNext = tonumber(row.upkeep_next)
        end
        if entry.kind == 'player' then -- owned stock is always limited
            for _, it in ipairs(itemsByNpc[nid] or {}) do it.amount = it.amount or 0 end
        end
        if row.shop_name and row.shop_name ~= '' then
            entry.shop = {
                name  = row.shop_name,
                label = row.shop_label or row.shop_name,
                type  = VALID_TYPES[row.shop_type] and row.shop_type or 'both',
                items = itemsByNpc[nid] or {},
            }
        end
        CachedNPCs[#CachedNPCs + 1] = entry
    end

    CachedBlips = {}
    for _, row in ipairs(blips) do
        CachedBlips[#CachedBlips + 1] = {
            id = tonumber(row.id), name = row.name, sprite = tonumber(row.sprite) or 0, color = row.color,
            x = tonumber(row.x) or 0, y = tonumber(row.y) or 0, z = tonumber(row.z) or 0,
            associatedNpcId = tonumber(row.associated_npc_id),
        }
    end

    LoadPresets()
    print(('[rsg-stores] ' .. locale('sv_loaded')):format(#CachedNPCs, #CachedBlips))
end

local dbInstalled = false
local function BootDatabase()
    for tries = 1, 10 do
        local ok, err = pcall(function()
            if Config.AutoInstallDatabase ~= false and not dbInstalled then
                local changes = Database.Install()
                dbInstalled = true
                if changes > 0 then
                    Webhook.Send('system', locale('wh_t_db_installed'), locale('sv_db_installed'):format(changes))
                end
            end
            LoadCacheFromDB()
        end)
        if ok then
            DbReady = true
            Webhook.Send('system', locale('wh_t_started'), locale('wh_d_started'):format(#CachedNPCs, #CachedBlips))
            TriggerClientEvent('rsg-blipmenu:client:refreshNPCs', -1, CachedNPCs)
            TriggerClientEvent('rsg-blipmenu:client:refreshBlips', -1, CachedBlips)
            return
        end
        print(('[rsg-stores] ' .. locale('sv_db_retry')):format(tries, tostring(err)))
        Wait(2000)
    end
    print('[rsg-stores] ' .. locale('sv_db_fail'))
    Webhook.Send('system', locale('wh_t_db_fail'), locale('wh_d_db_fail'), nil, nil, { ping = true })
end

local function broadcastNPCs() TriggerClientEvent('rsg-blipmenu:client:refreshNPCs', -1, CachedNPCs) end
local function broadcastBlips() TriggerClientEvent('rsg-blipmenu:client:refreshBlips', -1, CachedBlips) end

-- ============================================
-- CALLBACKS
-- ============================================
-- Online characters for the owner dropdown (admins only).
registerCallback('rsg-stores:server:getOnlinePlayers', function(source)
    if not isAdmin(source) then return {} end
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(tonumber(id))
        if P then
            local ci = P.PlayerData.charinfo or {}
            local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            out[#out + 1] = { id = P.PlayerData.source, name = name ~= '' and name or GetPlayerName(id) or '?', citizenid = P.PlayerData.citizenid }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end)

registerCallback('rsg-blipmenu:server:hasAdminPerm', function(source)
    return isAdmin(source)
end)

-- ============================================
-- SELL (player -> shop)
-- ============================================
RegisterNetEvent('rsg-stores:server:sellItem', function(npcId, itemName, quantity)
    local src = source
    local FAIL = 'rsg-stores:client:transactionResult'
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(itemName) ~= 'string' then return TriggerClientEvent(FAIL, src, false, locale('sv_invalid_qty'), getCash(src)) end
    if not DbReady then return TriggerClientEvent(FAIL, src, false, locale('sv_try_again'), getCash(src)) end
    if onCooldown(src) then return TriggerClientEvent(FAIL, src, false, locale('sv_slow_down'), getCash(src)) end

    local qty = toQty(quantity)
    if not qty then
        Webhook.Security(src, locale('wh_sec_bad_qty'), {
            { name = locale('wh_f_item'), value = itemName }, { name = locale('wh_f_qty'), value = tostring(quantity) },
        })
        return TriggerClientEvent(FAIL, src, false, locale('sv_invalid_qty'), getCash(src))
    end

    local npc = resolveShop(src, npcId, 'sell', FAIL)
    if not npc then return end

    local shopItem = findShopItem(npc, itemName)
    if not shopItem then return TriggerClientEvent(FAIL, src, false, locale('sv_shop_not_accept'), getCash(src)) end

    -- Counts across all stacks, not just the first slot.
    local owned = exports['rsg-inventory']:GetItemCount(src, itemName) or 0
    if owned < qty then return TriggerClientEvent(FAIL, src, false, locale('sv_no_items_held'), getCash(src)) end

    local isOwned = npc.kind == 'player'
    local pct = isOwned and OWNED_PCT or SELL_PCT
    local feePct = math.floor((1 - pct) * 100 + 0.5)
    local payout = round2(shopItem.price * qty * pct)
    if payout < 0.01 then return TriggerClientEvent(FAIL, src, false, locale('sv_bad_price'), getCash(src)) end

    -- Owned stores pay sellers out of their till (reserved atomically).
    local tillTaken = false
    if isOwned then
        if not takeBalance(npc.id, payout) then
            return TriggerClientEvent(FAIL, src, false, locale('sv_till_empty'), getCash(src))
        end
        tillTaken = true
    end

    -- Sold items go back on the shelf (limited-stock items only), up to Config.MaxShopStock.
    -- Reserved atomically in SQL first so two sellers can't push past the cap.
    local restock = (isOwned or Config.SellAddsStock ~= false) and shopItem.amount ~= nil
    if restock then
        local cap = tonumber(isOwned and OS.MaxStock or Config.MaxShopStock) or 0
        local affected
        if cap > 0 then
            affected = MySQL.update.await(
                'UPDATE rsg_shops_items SET stock = stock + ? WHERE npc_id = ? AND item_name = ? AND stock + ? <= ?',
                { qty, npc.id, itemName, qty, cap })
        else
            affected = MySQL.update.await(
                'UPDATE rsg_shops_items SET stock = stock + ? WHERE npc_id = ? AND item_name = ?',
                { qty, npc.id, itemName })
        end
        if not affected or affected == 0 then
            if tillTaken then addBalance(npc.id, payout) end
            resyncStock(npc)
            local room = math.max(0, cap - (shopItem.amount or 0))
            local msg = room > 0 and locale('sv_stock_full'):format(room, shopItem.label) or locale('sv_stock_full_none'):format(shopItem.label)
            return TriggerClientEvent(FAIL, src, false, msg, getCash(src), shopItemsForClient(npc))
        end
    end

    if not exports['rsg-inventory']:RemoveItem(src, itemName, qty, nil, 'rsg-stores-sell') then
        if restock then restoreStock(npc.id, itemName, -qty) end -- undo the reservation
        if tillTaken then addBalance(npc.id, payout) end
        return TriggerClientEvent(FAIL, src, false, locale('sv_remove_failed'), getCash(src))
    end
    Player.Functions.AddMoney('cash', payout, 'rsg-stores-sell')
    if restock then shopItem.amount = shopItem.amount + qty end

    TriggerClientEvent(FAIL, src, true, locale('sv_sold'):format(qty, shopItem.label, payout, feePct), getCash(src), shopItemsForClient(npc))
    if isOwned then
        ledger(npc, 'buyback', shopItem.label, qty, payout, charName(Player))
        broadcastShop(npc)
        notifyOwner(npc, locale('sv_owner_bought'):format(qty, shopItem.label, payout))
    end

    local large = Webhook.IsLarge(payout)
    local fields = shopFields(npc)
    fields[#fields + 1] = { name = locale('wh_f_item'), value = ('%dx %s (`%s`)'):format(qty, shopItem.label, itemName) }
    fields[#fields + 1] = { name = locale('wh_f_payout'), value = Webhook.Money(payout) }
    fields[#fields + 1] = { name = locale('wh_f_cash_after'), value = Webhook.Money(getCash(src)) }
    Webhook.Send('sales', locale(large and 'wh_t_large_sale' or 'wh_t_sale'), nil, src, fields)
    if large then Webhook.Send('security', locale('wh_t_large_sale'), locale('wh_d_payout'):format(Webhook.Money(payout)), src, fields) end
end)

-- ============================================
-- CART PURCHASE (shop -> player)
-- ============================================
RegisterNetEvent('rsg-stores:server:purchaseCart', function(npcId, cartItems)
    local src = source
    local FAIL_EVT = 'rsg-stores:client:purchaseFailed'
    local function fail(msg) TriggerClientEvent(FAIL_EVT, src, msg, getCash(src)) end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not DbReady then return fail(locale('sv_try_again')) end
    if onCooldown(src) then return fail(locale('sv_slow_down')) end

    if type(cartItems) ~= 'table' or #cartItems == 0 then return fail(locale('sv_cart_empty')) end
    if #cartItems > MAX_CART_LINES then return fail(locale('sv_invalid_qty')) end

    local npc = findNpc(npcId)
    if not npc or not npc.shop then return fail(locale('sv_shop_notfound')) end
    if npc.kind == 'player' and not npc.owner then return fail(locale('sv_store_closed')) end
    if npc.kind == 'player' and (npc.upkeepOwed or 0) > 0 then return fail(locale('sv_store_upkeep')) end
    if npc.shop.type ~= 'both' and npc.shop.type ~= 'buy' then return fail(locale('sv_shop_not_sell')) end
    if not isNearNpc(src, npc) then
        Webhook.Security(src, locale('wh_sec_too_far_purchase'), shopFields(npc))
        return fail(locale('sv_too_far'))
    end

    -- Merge duplicate lines, validate everything, compute server-side total.
    local merged, order = {}, {}
    for _, line in ipairs(cartItems) do
        local name = type(line) == 'table' and line.name
        local qty  = type(line) == 'table' and toQty(line.quantity)
        if type(name) ~= 'string' or not qty then
            Webhook.Security(src, locale('wh_sec_bad_cart'), {
                { name = locale('wh_f_item'), value = tostring(name) }, { name = locale('wh_f_qty'), value = tostring(type(line) == 'table' and line.quantity) },
            })
            return fail(locale('sv_cart_bad_qty'))
        end
        if not merged[name] then merged[name] = 0; order[#order + 1] = name end
        merged[name] = merged[name] + qty
        if merged[name] > MAX_QTY then return fail(locale('sv_cart_bad_qty')) end
    end

    local disc = npc.kind == 'npc' and discountFor(Player) or 0
    local lines, total = {}, 0
    for _, name in ipairs(order) do
        local qty = merged[name]
        local shopItem = findShopItem(npc, name)
        if not shopItem or not RSGCore.Shared.Items[name] then return fail(locale('sv_no_longer_sold')) end
        if shopItem.amount ~= nil and shopItem.amount < qty then
            return fail(locale('sv_no_stock_item'):format(shopItem.label))
        end
        if not exports['rsg-inventory']:CanAddItem(src, name, qty) then return fail(locale('sv_inv_full')) end
        local unit = round2(shopItem.price * (1 - disc))
        total = total + unit * qty
        lines[#lines + 1] = { item = shopItem, name = name, qty = qty, unit = unit }
    end
    total = round2(total)

    if Player.Functions.GetMoney('cash') < total then return fail(locale('sv_cant_afford')) end

    -- Atomic per-line stock decrement; roll back on any miss.
    local taken = {}
    local function rollbackStock()
        for _, l in ipairs(taken) do
            restoreStock(npc.id, l.name, l.qty)
            l.item.amount = l.item.amount + l.qty
        end
    end

    for _, l in ipairs(lines) do
        if l.item.amount ~= nil then
            if not takeStock(npc.id, l.name, l.qty) then
                rollbackStock()
                resyncStock(npc)
                return fail(locale('sv_no_stock_item'):format(l.item.label))
            end
            l.item.amount = l.item.amount - l.qty
            taken[#taken + 1] = l
        end
    end

    if total > 0 and not Player.Functions.RemoveMoney('cash', total, 'rsg-stores-purchase') then
        rollbackStock()
        return fail(locale('sv_pay_failed'))
    end

    local granted = {}
    for _, l in ipairs(lines) do
        if not exports['rsg-inventory']:AddItem(src, l.name, l.qty, nil, nil, 'rsg-stores-purchase') then
            for _, g in ipairs(granted) do
                exports['rsg-inventory']:RemoveItem(src, g.name, g.qty, nil, 'rsg-stores-refund')
            end
            if total > 0 then Player.Functions.AddMoney('cash', total, 'rsg-stores-refund') end
            rollbackStock()
            Webhook.Send('purchases', locale('wh_t_refund'), locale('wh_d_refund'):format(l.name, Webhook.Money(total)), src, shopFields(npc))
            return fail(locale('sv_inv_full_refund'))
        end
        granted[#granted + 1] = l
    end

    -- Owned stores: takings go into the store till for the owner to collect.
    if npc.kind == 'player' then
        if total > 0 then addBalance(npc.id, total) end
        local who = charName(Player)
        for _, l in ipairs(lines) do ledger(npc, 'sale', l.item.label, l.qty, round2(l.unit * l.qty), who) end
        broadcastShop(npc)
        notifyOwner(npc, locale('sv_owner_sold'):format(#lines, total))
    end

    TriggerClientEvent('rsg-stores:client:purchaseSuccess', src,
        locale('sv_cart_done'):format(#lines, total), getCash(src), shopItemsForClient(npc))

    local list = {}
    for _, l in ipairs(lines) do
        local stockLeft = l.item.amount and locale('wh_stock_left'):format(l.item.amount) or ''
        list[#list + 1] = ('• %dx %s @ %s%s'):format(l.qty, l.item.label, Webhook.Money(l.unit), stockLeft)
    end
    local large = Webhook.IsLarge(total)
    local fields = shopFields(npc)
    fields[#fields + 1] = { name = locale('wh_f_total'), value = Webhook.Money(total) }
    fields[#fields + 1] = { name = locale('wh_f_cash_after'), value = Webhook.Money(getCash(src)) }
    Webhook.Send('purchases', locale(large and 'wh_t_large_purchase' or 'wh_t_purchase'), table.concat(list, '\n'), src, fields)
    if large then Webhook.Send('security', locale('wh_t_large_purchase'), table.concat(list, '\n'), src, fields) end
end)

RegisterNetEvent('rsg-stores:server:requestShopStock', function(npcId)
    local npc = findNpc(npcId)
    if not npc or not npc.shop then return end
    TriggerClientEvent('rsg-stores:client:shopStock', source, shopItemsForClient(npc))
end)

-- ============================================
-- BLIP ADMIN (keyed by DB id, not list index)
-- ============================================
RegisterNetEvent('rsg-blipmenu:server:saveBlip', function(data)
    local src = source
    if denyIfNotAdmin(src, 'saveBlip') then return end
    local b = sanitizeBlip(data)
    if not b then return end
    b.id = tonumber(MySQL.insert.await(
        'INSERT INTO rsg_shops_blips (name, sprite, color, x, y, z, associated_npc_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { b.name, b.sprite, b.color, b.x, b.y, b.z, b.associatedNpcId }))
    if not b.id then return end
    CachedBlips[#CachedBlips + 1] = b
    broadcastBlips()
    Webhook.Send('admin', locale('wh_t_blip_created'), nil, src, {
        { name = locale('wh_f_name'), value = b.name }, { name = locale('wh_f_blip_id'), value = tostring(b.id) },
        { name = locale('wh_f_linked_npc'), value = tostring(b.associatedNpcId or '-') }, { name = locale('wh_f_coords'), value = coordStr(b) },
    })
end)

RegisterNetEvent('rsg-blipmenu:server:updateBlip', function(blipId, data)
    local src = source
    if denyIfNotAdmin(src, 'updateBlip') then return end
    local existing, idx = findBlip(blipId)
    local b = sanitizeBlip(data)
    if not existing or not b then return end
    b.id = existing.id
    MySQL.update.await(
        'UPDATE rsg_shops_blips SET name = ?, sprite = ?, color = ?, x = ?, y = ?, z = ?, associated_npc_id = ? WHERE id = ?',
        { b.name, b.sprite, b.color, b.x, b.y, b.z, b.associatedNpcId, b.id })
    CachedBlips[idx] = b
    broadcastBlips()
    Webhook.Send('admin', locale('wh_t_blip_updated'), nil, src, {
        { name = locale('wh_f_name'), value = ('%s → %s'):format(existing.name, b.name) }, { name = locale('wh_f_blip_id'), value = tostring(b.id) },
        { name = locale('wh_f_colour'), value = ('%s → %s'):format(tostring(existing.color), tostring(b.color)) }, { name = locale('wh_f_coords'), value = coordStr(b) },
    })
end)

RegisterNetEvent('rsg-blipmenu:server:deleteBlip', function(blipId)
    local src = source
    if denyIfNotAdmin(src, 'deleteBlip') then return end
    local existing, idx = findBlip(blipId)
    if not existing then return end
    MySQL.query.await('DELETE FROM rsg_shops_blips WHERE id = ?', { existing.id })
    table.remove(CachedBlips, idx)
    broadcastBlips()
    Webhook.Send('admin', locale('wh_t_blip_deleted'), nil, src, {
        { name = locale('wh_f_name'), value = existing.name }, { name = locale('wh_f_blip_id'), value = tostring(existing.id) }, { name = locale('wh_f_coords'), value = coordStr(existing) },
    })
end)

RegisterNetEvent('rsg-blipmenu:server:requestBlips', function()
    TriggerClientEvent('rsg-blipmenu:client:refreshBlips', source, CachedBlips)
end)

-- ============================================
-- NPC ADMIN
-- ============================================
-- Human-readable change list for admin logs (fields + per-item price/stock changes).
local function diffNpc(old, new)
    local out = {}
    local function cmp(label, a, b)
        if tostring(a) ~= tostring(b) then out[#out + 1] = ('**%s:** %s → %s'):format(label, tostring(a), tostring(b)) end
    end
    cmp(locale('wh_f_name'), old.name, new.name)
    cmp(locale('wh_f_model'), old.model, new.model)
    if old.x ~= new.x or old.y ~= new.y or old.z ~= new.z then cmp(locale('wh_f_coords'), coordStr(old), coordStr(new)) end
    local os_, ns = old.shop or {}, new.shop or {}
    cmp(locale('wh_f_shop_id'), os_.name, ns.name)
    cmp(locale('wh_f_shop_label'), os_.label, ns.label)
    cmp(locale('wh_f_shop_type'), os_.type, ns.type)

    local oldItems, newItems = {}, {}
    for _, i in ipairs(os_.items or {}) do oldItems[i.name] = i end
    for _, i in ipairs(ns.items or {}) do newItems[i.name] = i end
    local function fmt(i) return ('%s, stock %s'):format(Webhook.Money(i.price), i.amount or '∞') end
    for name, n in pairs(newItems) do
        local o = oldItems[name]
        if not o then
            out[#out + 1] = ('➕ %s (%s)'):format(n.label, fmt(n))
        elseif o.price ~= n.price or o.amount ~= n.amount then
            out[#out + 1] = ('✏️ %s: %s → %s'):format(n.label, fmt(o), fmt(n))
        end
    end
    for name, o in pairs(oldItems) do
        if not newItems[name] then out[#out + 1] = ('➖ %s'):format(o.label) end
    end
    return #out > 0 and table.concat(out, '\n') or locale('wh_no_changes')
end

local function insertShopItems(npcId, items)
    for _, item in ipairs(items) do
        MySQL.insert.await(
            'INSERT INTO rsg_shops_items (npc_id, item_name, label, price, stock) VALUES (?, ?, ?, ?, ?)',
            { npcId, item.name, item.label, item.price, item.amount })
    end
end

registerCallback('rsg-blipmenu:server:saveNPC', function(source, data)
    if denyIfNotAdmin(source, 'saveNPC') then return nil end
    local npc = sanitizeNpc(data)
    if not npc then return nil end
    if npc.kind == 'player' then
        local assign = type(data.owner) == 'table' and data.owner.assign
        if assign and tostring(assign) ~= '' then
            npc.owner = ownerFromServerId(assign)
            if not npc.owner then notify(source, locale('t_error'), locale('sv_owner_not_found')) return nil end
        end
    end
    local s, o = npc.shop, npc.owner
    npc.id = tonumber(MySQL.insert.await(
        'INSERT INTO rsg_shops_npcs (name, model, x, y, z, h, shop_name, shop_label, shop_type, store_kind, owner_citizenid, owner_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { npc.name, npc.model, npc.x, npc.y, npc.z, npc.h, s and s.name, s and s.label, s and s.type or 'both', npc.kind, o and o.citizenid, o and o.name }))
    if not npc.id then return nil end
    if s then insertShopItems(npc.id, s.items) end
    CachedNPCs[#CachedNPCs + 1] = npc
    broadcastNPCs()
    local fields = shopFields(npc)
    fields[#fields + 1] = { name = locale('wh_f_name_model'), value = ('%s / `%s`'):format(npc.name, npc.model) }
    fields[#fields + 1] = { name = locale('wh_f_type'), value = s and locale('cl_shop_' .. s.type) or locale('wh_no_shop') }
    fields[#fields + 1] = { name = locale('wh_f_items'), value = tostring(s and #s.items or 0) }
    fields[#fields + 1] = { name = locale('wh_f_coords'), value = coordStr(npc) }
    if npc.kind == 'player' then
        fields[#fields + 1] = { name = locale('wh_f_owner'), value = o and ('%s (`%s`)'):format(o.name, o.citizenid) or locale('wh_no_owner') }
    end
    Webhook.Send('admin', locale(npc.kind == 'player' and 'wh_t_store_created' or 'wh_t_npc_created'), nil, source, fields)
    return npc.id
end)

RegisterNetEvent('rsg-blipmenu:server:updateNPC', function(npcId, data)
    local src = source
    if denyIfNotAdmin(src, 'updateNPC') then return end
    local existing, idx = findNpc(npcId)
    local npc = sanitizeNpc(data)
    if not existing or not npc then
        return notify(src, locale('t_error'), locale('sv_update_fail'))
    end
    npc.id = existing.id
    local s = npc.shop
    local kindChanged = existing.kind ~= npc.kind

    -- Owner: keep, assign (online server id) or clear. Only owned stores have one.
    local owner = existing.owner
    if npc.kind == 'player' and type(data.owner) == 'table' then
        if data.owner.clear then
            owner = nil
        elseif data.owner.assign and tostring(data.owner.assign) ~= '' then
            owner = ownerFromServerId(data.owner.assign)
            if not owner then return notify(src, locale('t_error'), locale('sv_owner_not_found')) end
        end
    end
    if npc.kind ~= 'player' then owner = nil end
    npc.owner = owner
    npc.prop = npc.kind == 'player' and existing.prop or nil -- sign stores keep their sign
    npc.upkeepOwed, npc.upkeepNext = existing.upkeepOwed, existing.upkeepNext

    -- Owned stock belongs to the owner: admins can't edit it, so keep it as it is.
    local keepItems = npc.kind == 'player' and not kindChanged
    if keepItems then s.items = existing.shop and existing.shop.items or {} end
    local lostBalance = kindChanged and existing.kind == 'player' and getBalance(npc.id) or 0

    MySQL.update.await(
        'UPDATE rsg_shops_npcs SET name = ?, model = ?, x = ?, y = ?, z = ?, h = ?, shop_name = ?, shop_label = ?, shop_type = ?, store_kind = ?, owner_citizenid = ?, owner_name = ?, prop_model = ?, balance = IF(?, 0, balance) WHERE id = ?',
        { npc.name, npc.model, npc.x, npc.y, npc.z, npc.h, s and s.name, s and s.label, s and s.type or 'both',
          npc.kind, owner and owner.citizenid, owner and owner.name, npc.prop, kindChanged, npc.id })
    if not keepItems then
        MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { npc.id })
        if s then insertShopItems(npc.id, s.items) end
    end

    -- keep linked blips on the NPC
    MySQL.update.await('UPDATE rsg_shops_blips SET x = ?, y = ?, z = ? WHERE associated_npc_id = ?', { npc.x, npc.y, npc.z, npc.id })
    for _, b in ipairs(CachedBlips) do
        if b.associatedNpcId == npc.id then b.x, b.y, b.z = npc.x, npc.y, npc.z end
    end

    CachedNPCs[idx] = npc
    broadcastNPCs()
    broadcastBlips()
    local fields = shopFields(npc)
    if npc.kind == 'player' or existing.kind == 'player' then
        local function who(o) return o and ('%s (`%s`)'):format(o.name, o.citizenid) or locale('wh_no_owner') end
        fields[#fields + 1] = { name = locale('wh_f_owner'), value = ('%s → %s'):format(who(existing.owner), who(owner)) }
        if lostBalance > 0 then fields[#fields + 1] = { name = locale('wh_f_till_lost'), value = Webhook.Money(lostBalance) } end
    end
    Webhook.Send('admin', locale('wh_t_npc_updated'), diffNpc(existing, npc), src, fields)
end)

RegisterNetEvent('rsg-blipmenu:server:deleteNPC', function(npcId)
    local src = source
    if denyIfNotAdmin(src, 'deleteNPC') then return end
    local existing, idx = findNpc(npcId)
    if not existing then return end
    local lostBalance = existing.kind == 'player' and getBalance(existing.id) or 0
    MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { existing.id })
    MySQL.query.await('DELETE FROM rsg_shops_ledger WHERE npc_id = ?', { existing.id })
    MySQL.query.await('DELETE FROM rsg_shops_blips WHERE associated_npc_id = ?', { existing.id })
    MySQL.query.await('DELETE FROM rsg_shops_npcs WHERE id = ?', { existing.id })
    table.remove(CachedNPCs, idx)
    for i = #CachedBlips, 1, -1 do
        if CachedBlips[i].associatedNpcId == existing.id then table.remove(CachedBlips, i) end
    end
    broadcastNPCs()
    broadcastBlips()
    local fields = shopFields(existing)
    fields[#fields + 1] = { name = locale('wh_f_name_model'), value = ('%s / `%s`'):format(existing.name, existing.model) }
    fields[#fields + 1] = { name = locale('wh_f_coords'), value = coordStr(existing) }
    if existing.kind == 'player' then
        fields[#fields + 1] = { name = locale('wh_f_owner'), value = existing.owner and ('%s (`%s`)'):format(existing.owner.name, existing.owner.citizenid) or locale('wh_no_owner') }
        if lostBalance > 0 then fields[#fields + 1] = { name = locale('wh_f_till_lost'), value = Webhook.Money(lostBalance) } end
    end
    Webhook.Send('admin', locale('wh_t_npc_deleted'), nil, src, fields)
end)

RegisterNetEvent('rsg-blipmenu:server:requestNPCs', function()
    TriggerClientEvent('rsg-blipmenu:client:refreshNPCs', source, CachedNPCs)
end)

-- ============================================
-- OWNER MANAGEMENT (player-owned stores)
-- Every call: owner citizenid must match, owner must stand at the store,
-- all amounts/prices validated here, inventory/money moved server-side only.
-- ============================================
local function ownerFail(err) return { ok = false, err = err } end

local function requireOwner(src, npcId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not OWNED_ENABLED then return nil, nil, 'sv_shop_notfound' end
    local npc = findNpc(npcId)
    if not npc or npc.kind ~= 'player' or not npc.shop then return nil, nil, 'sv_shop_notfound' end
    if not npc.owner or npc.owner.citizenid ~= Player.PlayerData.citizenid then
        Webhook.Security(src, locale('wh_sec_not_owner'), shopFields(npc))
        return nil, nil, 'sv_not_owner'
    end
    if not isNearNpc(src, npc) then return nil, nil, 'sv_too_far' end
    return npc, Player
end

local function toPrice(v)
    v = tonumber(v)
    local max = tonumber(OS.MaxPrice) or 10000
    if not v or v ~= v or v < 0 or v > max then return nil end
    return round2(v)
end

local UPKEEP = (Config.ShopSign or {}).Upkeep or {}
local function upkeepOn(npc) return UPKEEP.Enabled ~= false and (Config.ShopSign or {}).Upkeep ~= nil and npc.prop ~= nil end

ownerUpkeepInfo = function(npc)
    if not upkeepOn(npc) then return nil end
    return { amount = tonumber(UPKEEP.Amount) or 0, owed = npc.upkeepOwed or 0,
        dueIn = npc.upkeepNext and math.max(0, npc.upkeepNext - os.time()) or nil,
        evictAfter = tonumber(UPKEEP.EvictAfterMissed) or 3 }
end

local WHOLESALE = Config.Wholesale or {}
local wholesaleCache
wholesaleList = function()
    if WHOLESALE.Enabled == false then return {} end
    if wholesaleCache then return wholesaleCache end
    wholesaleCache = {}
    for name, cost in pairs(WHOLESALE.Items or {}) do
        local shared = RSGCore.Shared.Items[name]
        if shared and tonumber(cost) then
            wholesaleCache[#wholesaleCache + 1] = { name = name, label = shared.label or name, cost = round2(tonumber(cost)) }
        end
    end
    table.sort(wholesaleCache, function(a, b) return a.label < b.label end)
    return wholesaleCache
end

ownerLedger = function(npc)
    if LEDGER.Enabled == false then return {} end
    local rows = MySQL.query.await('SELECT ts, kind, item, qty, amount, who FROM rsg_shops_ledger WHERE npc_id = ? ORDER BY id DESC LIMIT ?',
        { npc.id, tonumber(LEDGER.Show) or 50 }) or {}
    for _, r in ipairs(rows) do r.amount = tonumber(r.amount) or 0 end
    return rows
end

local function ownerState(npc, msg)
    return {
        ok = true, msg = msg,
        label = npc.shop.label, type = npc.shop.type,
        balance = getBalance(npc.id),
        items = shopItemsForClient(npc),
        maxListings = tonumber(OS.MaxListings) or 50,
        maxStock = tonumber(OS.MaxStock) or 0,
        maxPrice = tonumber(OS.MaxPrice) or 10000,
        markup = tonumber(WHOLESALE.Markup) or 1.5,
        buyBackPct = OWNED_PCT,
        canPackUp = npc.prop ~= nil,
        upkeep = ownerUpkeepInfo(npc),
        wholesale = wholesaleList(),
        ledger = ownerLedger(npc),
    }
end

local function ownerLog(src, npc, title, extra)
    local fields = shopFields(npc)
    for _, f in ipairs(extra or {}) do fields[#fields + 1] = f end
    Webhook.Send('owners', title, nil, src, fields)
end

local function stockable(name)
    local shared = type(name) == 'string' and RSGCore.Shared.Items[name]
    if not shared or BLACKLIST[name] or shared.unique or shared.type == 'weapon' then return nil end
    return shared
end

RSGCore.Functions.CreateCallback('rsg-stores:server:ownerGetState', function(source, cb, npcId)
    local npc, _, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    cb(ownerState(npc))
end)

-- Move items from the owner's inventory onto the shelf (creates the listing if new).
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerAddStock', function(source, cb, npcId, itemName, qty, price)
    local npc, _, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local shared = stockable(itemName)
    if not shared then return cb(ownerFail('sv_cant_stock')) end
    qty = toQty(qty)
    if not qty then return cb(ownerFail('sv_invalid_qty')) end

    local listing = findShopItem(npc, itemName)
    local newPrice = price ~= nil and toPrice(price) or nil
    if price ~= nil and not newPrice then return cb(ownerFail('sv_bad_price')) end
    if not listing then
        if not newPrice then return cb(ownerFail('sv_bad_price')) end
        if #npc.shop.items >= (tonumber(OS.MaxListings) or 50) then return cb(ownerFail('sv_max_listings')) end
    end
    local cap = tonumber(OS.MaxStock) or 0
    if cap > 0 and ((listing and listing.amount or 0) + qty) > cap then return cb(ownerFail('sv_stock_cap')) end
    if (exports['rsg-inventory']:GetItemCount(source, itemName) or 0) < qty then return cb(ownerFail('sv_no_items_held')) end
    if not exports['rsg-inventory']:RemoveItem(source, itemName, qty, nil, 'rsg-stores-owner-stock') then
        return cb(ownerFail('sv_remove_failed'))
    end

    if listing then
        MySQL.update.await('UPDATE rsg_shops_items SET stock = stock + ?, price = ? WHERE npc_id = ? AND item_name = ?',
            { qty, newPrice or listing.price, npc.id, itemName })
        listing.price = newPrice or listing.price
        resyncStock(npc)
    else
        listing = { name = itemName, label = shared.label or itemName, price = newPrice, amount = qty }
        insertShopItems(npc.id, { listing })
        npc.shop.items[#npc.shop.items + 1] = listing
    end
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_owner_stock'), {
        { name = locale('wh_f_item'), value = ('%dx %s (`%s`)'):format(qty, listing.label, itemName) },
        { name = locale('wh_f_price'), value = Webhook.Money(listing.price) },
    })
    cb(ownerState(npc, locale('sv_owner_stocked'):format(qty, listing.label)))
end)

-- Take items off the shelf back into the owner's inventory.
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerTakeStock', function(source, cb, npcId, itemName, qty)
    local npc, _, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local listing = findShopItem(npc, itemName)
    qty = toQty(qty)
    if not listing or not qty then return cb(ownerFail('sv_invalid_qty')) end
    if not exports['rsg-inventory']:CanAddItem(source, itemName, qty) then return cb(ownerFail('sv_inv_full')) end
    if not takeStock(npc.id, itemName, qty) then
        resyncStock(npc)
        return cb(ownerFail('sv_no_stock'))
    end
    if not exports['rsg-inventory']:AddItem(source, itemName, qty, nil, nil, 'rsg-stores-owner-take') then
        restoreStock(npc.id, itemName, qty)
        return cb(ownerFail('sv_inv_full'))
    end
    resyncStock(npc)
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_owner_take'), {
        { name = locale('wh_f_item'), value = ('%dx %s (`%s`)'):format(qty, listing.label, itemName) },
    })
    cb(ownerState(npc, locale('sv_owner_taken'):format(qty, listing.label)))
end)

RSGCore.Functions.CreateCallback('rsg-stores:server:ownerSetPrice', function(source, cb, npcId, itemName, price)
    local npc, _, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local listing = findShopItem(npc, itemName)
    price = toPrice(price)
    if not listing or not price then return cb(ownerFail('sv_bad_price')) end
    MySQL.update.await('UPDATE rsg_shops_items SET price = ? WHERE npc_id = ? AND item_name = ?', { price, npc.id, itemName })
    local old = listing.price
    listing.price = price
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_owner_price'), {
        { name = locale('wh_f_item'), value = listing.label },
        { name = locale('wh_f_price'), value = ('%s → %s'):format(Webhook.Money(old), Webhook.Money(price)) },
    })
    cb(ownerState(npc, locale('sv_owner_priced'):format(listing.label, price)))
end)

-- Remove a listing; any stock left goes back to the owner.
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerRemoveListing', function(source, cb, npcId, itemName)
    local npc, _, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local listing = findShopItem(npc, itemName)
    if not listing then return cb(ownerFail('sv_invalid_qty')) end
    local stock = tonumber(MySQL.scalar.await('SELECT stock FROM rsg_shops_items WHERE npc_id = ? AND item_name = ?', { npc.id, itemName })) or 0
    if stock > 0 and not exports['rsg-inventory']:CanAddItem(source, itemName, stock) then return cb(ownerFail('sv_inv_full')) end
    -- delete only if stock is unchanged (a customer may have just bought some)
    local affected = MySQL.update.await('DELETE FROM rsg_shops_items WHERE npc_id = ? AND item_name = ? AND stock = ?', { npc.id, itemName, stock })
    if not affected or affected == 0 then resyncStock(npc) return cb(ownerFail('sv_try_again')) end
    if stock > 0 and not exports['rsg-inventory']:AddItem(source, itemName, stock, nil, nil, 'rsg-stores-owner-remove') then
        insertShopItems(npc.id, { { name = itemName, label = listing.label, price = listing.price, amount = stock } })
        return cb(ownerFail('sv_inv_full'))
    end
    for i, it in ipairs(npc.shop.items) do
        if it.name == itemName then table.remove(npc.shop.items, i) break end
    end
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_owner_remove'), {
        { name = locale('wh_f_item'), value = ('%s (`%s`)'):format(listing.label, itemName) },
        { name = locale('wh_f_qty'), value = tostring(stock) },
    })
    cb(ownerState(npc, locale('sv_owner_removed'):format(listing.label)))
end)

-- Collect money from the till as cash. amount nil/0 = everything.
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerWithdraw', function(source, cb, npcId, amount)
    local npc, Player, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local amt = tonumber(amount)
    if amt == nil or amt == 0 then amt = getBalance(npc.id) end
    if not amt or amt ~= amt or amt < 0.01 then return cb(ownerFail('sv_till_empty')) end
    amt = round2(amt)
    if not takeBalance(npc.id, amt) then return cb(ownerFail('sv_till_empty')) end
    Player.Functions.AddMoney('cash', amt, 'rsg-stores-till-withdraw')
    ledger(npc, 'withdraw', nil, 0, amt, charName(Player))
    ownerLog(source, npc, locale('wh_t_owner_withdraw'), {
        { name = locale('wh_f_payout'), value = Webhook.Money(amt) },
    })
    cb(ownerState(npc, locale('sv_owner_withdrew'):format(amt)))
end)

-- Owner settings: shop sign (label) and what the counter does (buy/sell/both).
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerSetSettings', function(source, cb, npcId, label, sType)
    local npc, _, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    label = str(label, 60)
    if not label or not VALID_TYPES[sType] then return cb(ownerFail('sv_bad_settings')) end
    MySQL.update.await('UPDATE rsg_shops_npcs SET shop_label = ?, shop_type = ? WHERE id = ?', { label, sType, npc.id })
    local old = npc.shop.label
    npc.shop.label, npc.shop.type = label, sType
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_owner_settings'), {
        { name = locale('wh_f_shop_label'), value = ('%s → %s'):format(old, label) },
        { name = locale('wh_f_shop_type'), value = sType },
    })
    cb(ownerState(npc, locale('sv_owner_saved')))
end)

-- ============================================
-- SHOP SIGN ITEM (player opens their own store)
-- ============================================
local SIGN = Config.ShopSign or {}
local SIGN_ITEM = SIGN.Item or 'shopsign'

local function signStoresOwned(citizenid)
    local n = 0
    for _, npc in ipairs(CachedNPCs) do
        if npc.prop and npc.owner and npc.owner.citizenid == citizenid then n = n + 1 end
    end
    return n
end

local function signCheck(src, Player)
    if SIGN.Enabled == false or not OWNED_ENABLED then return 'sv_sign_disabled' end
    if (exports['rsg-inventory']:GetItemCount(src, SIGN_ITEM) or 0) < 1 then return 'sv_sign_no_item' end
    local max = tonumber(SIGN.MaxPerPlayer) or 1
    if max > 0 and signStoresOwned(Player.PlayerData.citizenid) >= max then return 'sv_sign_limit' end
    return nil
end

CreateThread(function()
    if SIGN.Enabled == false then return end
    if not RSGCore.Shared.Items[SIGN_ITEM] and type(SIGN.ItemDefinition) == 'table' then
        pcall(function() exports['rsg-core']:AddItem(SIGN_ITEM, SIGN.ItemDefinition) end)
    end
    RSGCore.Functions.CreateUseableItem(SIGN_ITEM, function(source)
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player or not DbReady then return end
        local err = signCheck(source, Player)
        if err then return notify(source, locale('t_error'), locale(err):format(tonumber(SIGN.MaxPerPlayer) or 1)) end
        TriggerClientEvent('rsg-stores:client:startSignPlacement', source)
    end)
end)

-- Place the sign and open the store. Everything re-checked here.
registerCallback('rsg-stores:server:placeSign', function(source, data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not DbReady or type(data) ~= 'table' then return { ok = false, err = 'sv_try_again' } end
    if onCooldown(src) then return { ok = false, err = 'sv_slow_down' } end
    local err = signCheck(src, Player)
    if err then return { ok = false, err = err } end

    local x, y, z, h = tonumber(data.x), tonumber(data.y), tonumber(data.z), tonumber(data.h) or 0.0
    local label = str(data.label, 60)
    local sType = VALID_TYPES[data.type] and data.type or 'buy'
    if not x or not y or not z or x ~= x or y ~= y or z ~= z or h ~= h or not label then return { ok = false, err = 'sv_bad_settings' } end
    local pos = vector3(x, y, z)
    if #(GetEntityCoords(GetPlayerPed(src)) - pos) > 5.0 then
        Webhook.Security(src, locale('wh_sec_too_far_trade'), { { name = locale('wh_f_coords'), value = coordStr({ x = x, y = y, z = z }) } })
        return { ok = false, err = 'sv_sign_too_far' }
    end
    local spacing = tonumber(SIGN.MinSpacing) or 8.0
    for _, other in ipairs(CachedNPCs) do
        if #(pos - vector3(other.x, other.y, other.z)) < spacing then return { ok = false, err = 'sv_sign_too_close' } end
    end
    if not exports['rsg-inventory']:RemoveItem(src, SIGN_ITEM, 1, nil, 'rsg-stores-sign-placed') then
        return { ok = false, err = 'sv_sign_no_item' }
    end

    local ci = Player.PlayerData.charinfo or {}
    local cid = Player.PlayerData.citizenid
    local owner = { citizenid = cid, name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '') }
    if owner.name == '' then owner.name = cid end
    local npc = {
        name = label, model = '', kind = 'player', prop = SIGN.Model or 'p_chalksign_buysell01x', owner = owner,
        x = x, y = y, z = z, h = h % 360.0,
        shop = { name = ('sign_%s_%d'):format(cid, os.time()), label = label, type = sType, items = {} },
        upkeepOwed = 0,
    }
    if upkeepOn(npc) then npc.upkeepNext = os.time() + math.floor((tonumber(UPKEEP.IntervalHours) or 24) * 3600) end
    npc.id = tonumber(MySQL.insert.await(
        'INSERT INTO rsg_shops_npcs (name, model, x, y, z, h, shop_name, shop_label, shop_type, store_kind, owner_citizenid, owner_name, prop_model, upkeep_next) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { npc.name, '', x, y, z, npc.h, npc.shop.name, label, sType, 'player', cid, owner.name, npc.prop, npc.upkeepNext }))
    if not npc.id then
        exports['rsg-inventory']:AddItem(src, SIGN_ITEM, 1, nil, nil, 'rsg-stores-sign-refund')
        return { ok = false, err = 'sv_try_again' }
    end
    CachedNPCs[#CachedNPCs + 1] = npc

    local bl = SIGN.Blip or {}
    if bl.Enabled ~= false then
        local b = { name = label, sprite = math.floor(tonumber(bl.Sprite) or 1475879922), color = VALID_COLORS[bl.Color] and bl.Color or nil,
            x = x, y = y, z = z, associatedNpcId = npc.id }
        b.id = tonumber(MySQL.insert.await(
            'INSERT INTO rsg_shops_blips (name, sprite, color, x, y, z, associated_npc_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { b.name, b.sprite, b.color, x, y, z, npc.id }))
        if b.id then CachedBlips[#CachedBlips + 1] = b end
    end
    broadcastNPCs()
    broadcastBlips()
    ownerLog(src, npc, locale('wh_t_sign_placed'), { { name = locale('wh_f_coords'), value = coordStr(npc) } })
    return { ok = true, msg = locale('sv_sign_placed'):format(label) }
end)

-- Owner closes a sign store: shelves must be empty; till is paid out; sign returned.
registerCallback('rsg-stores:server:ownerPackUp', function(source, npcId)
    local npc, Player, err = requireOwner(source, npcId)
    if not npc then return ownerFail(err) end
    if not npc.prop then return ownerFail('sv_packup_not_sign') end
    if onCooldown(source) then return ownerFail('sv_slow_down') end
    local stocked = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(stock), 0) FROM rsg_shops_items WHERE npc_id = ?', { npc.id })) or 0
    if stocked > 0 then return ownerFail('sv_packup_not_empty') end
    local giveBack = SIGN.ReturnOnPackUp ~= false
    if giveBack and not exports['rsg-inventory']:CanAddItem(source, SIGN_ITEM, 1) then return ownerFail('sv_packup_inv_full') end

    local till = getBalance(npc.id)
    if till > 0 then
        if not takeBalance(npc.id, till) then return ownerFail('sv_try_again') end
        Player.Functions.AddMoney('cash', till, 'rsg-stores-packup-till')
    end
    MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { npc.id })
    MySQL.query.await('DELETE FROM rsg_shops_ledger WHERE npc_id = ?', { npc.id })
    MySQL.query.await('DELETE FROM rsg_shops_blips WHERE associated_npc_id = ?', { npc.id })
    MySQL.query.await('DELETE FROM rsg_shops_npcs WHERE id = ?', { npc.id })
    local _, idx = findNpc(npc.id)
    if idx then table.remove(CachedNPCs, idx) end
    for i = #CachedBlips, 1, -1 do
        if CachedBlips[i].associatedNpcId == npc.id then table.remove(CachedBlips, i) end
    end
    if giveBack then exports['rsg-inventory']:AddItem(source, SIGN_ITEM, 1, nil, nil, 'rsg-stores-packup') end
    ownerLog(source, npc, locale('wh_t_packup'), { { name = locale('wh_f_payout'), value = Webhook.Money(till) } })
    SetTimeout(250, function() broadcastNPCs() broadcastBlips() end) -- after the reply reaches the owner
    return { ok = true, closed = true, label = npc.shop.label, msg = locale('sv_packup_done') }
end)


-- ============================================
-- WHOLESALE / UPKEEP / EVICTION (player-owned stores)
-- ============================================
local function payFromTillOrCash(npc, Player, cost, mode, reason)
    if cost <= 0 then return true end
    if (mode == 'till' or mode == 'either') and takeBalance(npc.id, cost) then return true, 'till' end
    if (mode == 'cash' or mode == 'either') and Player.Functions.RemoveMoney('cash', cost, reason) then return true, 'cash' end
    return false
end

-- Buy stock from the supplier straight onto the shelf.
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerWholesale', function(source, cb, npcId, itemName, qty, price)
    local npc, Player, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if WHOLESALE.Enabled == false then return cb(ownerFail('sv_wholesale_off')) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local cost = type(itemName) == 'string' and tonumber((WHOLESALE.Items or {})[itemName])
    local shared = cost and stockable(itemName)
    if not shared then return cb(ownerFail('sv_cant_stock')) end
    qty = toQty(qty)
    if not qty then return cb(ownerFail('sv_invalid_qty')) end

    local listing = findShopItem(npc, itemName)
    local newPrice = price ~= nil and toPrice(price) or nil
    if price ~= nil and not newPrice then return cb(ownerFail('sv_bad_price')) end
    if not listing then
        if #npc.shop.items >= (tonumber(OS.MaxListings) or 50) then return cb(ownerFail('sv_max_listings')) end
        newPrice = newPrice or math.min(round2(cost * (tonumber(WHOLESALE.Markup) or 1.5)), tonumber(OS.MaxPrice) or 10000)
    end
    local cap = tonumber(OS.MaxStock) or 0
    if cap > 0 and ((listing and listing.amount or 0) + qty) > cap then return cb(ownerFail('sv_stock_cap')) end

    local total = round2(cost * qty)
    local paid, from = payFromTillOrCash(npc, Player, total, WHOLESALE.PayFrom or 'either', 'rsg-stores-wholesale')
    if not paid then return cb(ownerFail('sv_wholesale_funds')) end

    if listing then
        MySQL.update.await('UPDATE rsg_shops_items SET stock = stock + ?, price = ? WHERE npc_id = ? AND item_name = ?',
            { qty, newPrice or listing.price, npc.id, itemName })
        listing.price = newPrice or listing.price
        resyncStock(npc)
    else
        listing = { name = itemName, label = shared.label or itemName, price = newPrice, amount = qty }
        insertShopItems(npc.id, { listing })
        npc.shop.items[#npc.shop.items + 1] = listing
    end
    ledger(npc, 'wholesale', listing.label, qty, total, charName(Player))
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_owner_wholesale'), {
        { name = locale('wh_f_item'), value = ('%dx %s (`%s`)'):format(qty, listing.label, itemName) },
        { name = locale('wh_f_total'), value = ('%s (%s)'):format(Webhook.Money(total), from or '-') },
    })
    cb(ownerState(npc, locale('sv_owner_wholesale'):format(qty, listing.label, total)))
end)

-- Pay off owed upkeep: till first, then cash.
RSGCore.Functions.CreateCallback('rsg-stores:server:ownerPayUpkeep', function(source, cb, npcId)
    local npc, Player, err = requireOwner(source, npcId)
    if not npc then return cb(ownerFail(err)) end
    if onCooldown(source) then return cb(ownerFail('sv_slow_down')) end
    local owed = round2(npc.upkeepOwed or 0)
    if owed <= 0 then return cb(ownerFail('sv_upkeep_none')) end
    if not payFromTillOrCash(npc, Player, owed, 'either', 'rsg-stores-upkeep') then return cb(ownerFail('sv_upkeep_funds')) end
    npc.upkeepOwed = 0
    MySQL.update.await('UPDATE rsg_shops_npcs SET upkeep_owed = 0 WHERE id = ?', { npc.id })
    ledger(npc, 'upkeep', nil, 0, owed, charName(Player))
    broadcastShop(npc)
    ownerLog(source, npc, locale('wh_t_upkeep_paid'), { { name = locale('wh_f_total'), value = Webhook.Money(owed) } })
    cb(ownerState(npc, locale('sv_upkeep_paid'):format(owed)))
end)

-- Close an owned store. giveBack = return stock, till and sign to the (online) owner.
-- Sign stores are deleted; admin-placed owned stores are emptied and left unowned.
local function closeOwnedStore(npc, giveBack, reason)
    local Owner = giveBack and npc.owner and RSGCore.Functions.GetPlayerByCitizenId(npc.owner.citizenid)
    local src = Owner and Owner.PlayerData.source
    local returned, till = {}, getBalance(npc.id)
    if src then
        for _, row in ipairs(MySQL.query.await('SELECT item_name, stock FROM rsg_shops_items WHERE npc_id = ? AND stock > 0', { npc.id }) or {}) do
            local q = tonumber(row.stock) or 0
            if q > 0 and exports['rsg-inventory']:AddItem(src, row.item_name, q, nil, nil, 'rsg-stores-evict') then
                returned[#returned + 1] = ('%dx %s'):format(q, row.item_name)
            end
        end
        if till > 0 and takeBalance(npc.id, till) then Owner.Functions.AddMoney('cash', till, 'rsg-stores-evict-till') else till = 0 end
        if npc.prop then exports['rsg-inventory']:AddItem(src, SIGN_ITEM, 1, nil, nil, 'rsg-stores-evict-sign') end
    end
    MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { npc.id })
    if npc.prop then
        MySQL.query.await('DELETE FROM rsg_shops_ledger WHERE npc_id = ?', { npc.id })
        MySQL.query.await('DELETE FROM rsg_shops_blips WHERE associated_npc_id = ?', { npc.id })
        MySQL.query.await('DELETE FROM rsg_shops_npcs WHERE id = ?', { npc.id })
        local _, idx = findNpc(npc.id)
        if idx then table.remove(CachedNPCs, idx) end
        for i = #CachedBlips, 1, -1 do
            if CachedBlips[i].associatedNpcId == npc.id then table.remove(CachedBlips, i) end
        end
    else
        MySQL.update.await('UPDATE rsg_shops_npcs SET owner_citizenid = NULL, owner_name = NULL, balance = 0, upkeep_owed = 0 WHERE id = ?', { npc.id })
        npc.owner, npc.shop.items, npc.upkeepOwed = nil, {}, 0
    end
    if src then notify(src, npc.shop.label, locale(reason == 'repossessed' and 'sv_repossessed' or 'sv_evicted'), 'error') end
    broadcastNPCs()
    broadcastBlips()
    return returned, till, src ~= nil
end

-- Admin: evict the owner. Owner must be online to get things back unless force (forfeit).
RegisterNetEvent('rsg-blipmenu:server:evictOwner', function(npcId, force)
    local src = source
    if denyIfNotAdmin(src, 'evictOwner') then return end
    local npc = findNpc(npcId)
    if not npc or npc.kind ~= 'player' or not npc.owner then return notify(src, locale('t_error'), locale('sv_evict_no_owner')) end
    local online = RSGCore.Functions.GetPlayerByCitizenId(npc.owner.citizenid) ~= nil
    if not online and force ~= true then return notify(src, locale('t_error'), locale('sv_evict_offline')) end
    local owner = npc.owner
    local returned, till = closeOwnedStore(npc, true, 'evicted')
    notify(src, locale('t_updated'), locale('sv_evict_done'):format(owner.name), 'success')
    local fields = shopFields(npc)
    fields[#fields + 1] = { name = locale('wh_f_owner'), value = ('%s (`%s`)'):format(owner.name, owner.citizenid) }
    fields[#fields + 1] = { name = locale('wh_f_returned'), value = #returned > 0 and table.concat(returned, ', ') or '-' }
    fields[#fields + 1] = { name = locale('wh_f_payout'), value = Webhook.Money(till) }
    Webhook.Send('admin', locale('wh_t_evicted'), nil, src, fields)
end)

-- Upkeep: every few minutes charge due periods from the till; unpaid adds to owed.
local function runUpkeep()
    if not DbReady or UPKEEP.Enabled == false then return end
    local amount = tonumber(UPKEEP.Amount) or 0
    local interval = math.floor((tonumber(UPKEEP.IntervalHours) or 24) * 3600)
    local evictAt = (tonumber(UPKEEP.EvictAfterMissed) or 3) * amount
    if amount <= 0 or interval < 60 then return end
    local now = os.time()
    for i = #CachedNPCs, 1, -1 do
        local npc = CachedNPCs[i]
        if npc and upkeepOn(npc) and npc.owner then
            if not npc.upkeepNext then npc.upkeepNext = now + interval
                MySQL.update.await('UPDATE rsg_shops_npcs SET upkeep_next = ? WHERE id = ?', { npc.upkeepNext, npc.id })
            elseif now >= npc.upkeepNext then
                local periods = math.floor((now - npc.upkeepNext) / interval) + 1
                local wasOpen = (npc.upkeepOwed or 0) <= 0
                for _ = 1, periods do
                    if takeBalance(npc.id, amount) then ledger(npc, 'upkeep', nil, 0, amount, 'auto')
                    else npc.upkeepOwed = round2((npc.upkeepOwed or 0) + amount) end
                end
                npc.upkeepNext = npc.upkeepNext + periods * interval
                MySQL.update.await('UPDATE rsg_shops_npcs SET upkeep_owed = ?, upkeep_next = ? WHERE id = ?', { npc.upkeepOwed, npc.upkeepNext, npc.id })
                if evictAt > 0 and npc.upkeepOwed >= evictAt then
                    local fields = shopFields(npc)
                    fields[#fields + 1] = { name = locale('wh_f_owner'), value = ('%s (`%s`)'):format(npc.owner.name, npc.owner.citizenid) }
                    fields[#fields + 1] = { name = locale('wh_f_total'), value = Webhook.Money(npc.upkeepOwed) }
                    closeOwnedStore(npc, false, 'repossessed')
                    Webhook.Send('owners', locale('wh_t_repossessed'), nil, nil, fields)
                elseif npc.upkeepOwed > 0 then
                    if wasOpen then broadcastShop(npc) end
                    notifyOwner(npc, locale('sv_upkeep_due'):format(npc.upkeepOwed))
                end
            end
        end
    end
    -- trim ledgers
    local keep = tonumber(LEDGER.Keep) or 100
    for _, npc in ipairs(CachedNPCs) do
        if npc.kind == 'player' then
            local cut = MySQL.scalar.await('SELECT id FROM rsg_shops_ledger WHERE npc_id = ? ORDER BY id DESC LIMIT 1 OFFSET ?', { npc.id, keep })
            if cut then MySQL.query.await('DELETE FROM rsg_shops_ledger WHERE npc_id = ? AND id <= ?', { npc.id, cut }) end
        end
    end
end

CreateThread(function()
    while true do
        Wait(5 * 60 * 1000)
        local ok, e = pcall(runUpkeep)
        if not ok then print('[rsg-stores] upkeep error: ' .. tostring(e)) end
    end
end)

-- ============================================
-- LIFECYCLE
-- ============================================
AddEventHandler('playerDropped', function()
    lastTx[source] = nil
end)

CreateThread(function()
    if not DbReady then BootDatabase() end
end)
