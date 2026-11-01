local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local SELL_PCT       = Config.SellPricePercentage or 0.80
local FEE_PCT        = math.floor((1 - SELL_PCT) * 100 + 0.5)
local MAX_QTY        = 1000   -- max units per line
local MAX_CART_LINES = 100    -- max distinct lines per cart
local MAX_DIST       = (Config.TargetDistance or 2.5) + 5.0 -- server-side proximity tolerance
local TX_COOLDOWN    = 750    -- ms between transactions per player

local CachedNPCs, CachedBlips = {}, {}
local CachedPresets = { model = {}, blip = {} } -- admin-managed dropdown options
local DbReady = false
local lastTx = {}

-- ============================================
-- HELPERS
-- ============================================
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

local function notify(src, title, desc, nType)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = desc, type = nType or 'error', duration = 5000 })
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
        model = str(data.model),
        x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z), h = tonumber(data.h) or 0.0,
    }
    if not npc.model or not npc.x or not npc.y or not npc.z then return nil end
    if type(data.shop) == 'table' then
        local sName = str(data.shop.name)
        if sName then
            npc.shop = {
                name  = sName,
                label = str(data.shop.label) or sName,
                type  = VALID_TYPES[data.shop.type] and data.shop.type or 'both',
                items = sanitizeItems(data.shop.items),
            }
        end
    end
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

lib.callback.register('rsg-stores:server:getPresets', function(source)
    if not isAdmin(source) then return nil end
    return CachedPresets
end)

-- Create (no id) or update (id) a preset. Returns { ok, presets, err }.
lib.callback.register('rsg-stores:server:savePreset', function(source, id, data)
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

lib.callback.register('rsg-stores:server:deletePreset', function(source, id)
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
            x = tonumber(row.x) or 0, y = tonumber(row.y) or 0, z = tonumber(row.z) or 0, h = tonumber(row.h) or 0,
        }
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
lib.callback.register('rsg-blipmenu:server:hasAdminPerm', function(source)
    return isAdmin(source)
end)

-- ============================================
-- SELL (player -> shop)
-- ============================================
RegisterNetEvent('rsg-stores:server:sellItem', function(npcId, itemName, quantity)
    local src = source
    local FAIL = 'rsg-stores:client:transactionResult'
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(itemName) ~= 'string' then return end
    if onCooldown(src) then return end

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

    local payout = round2(shopItem.price * qty * SELL_PCT)
    if payout < 0.01 then return TriggerClientEvent(FAIL, src, false, locale('sv_bad_price'), getCash(src)) end

    -- Sold items go back on the shelf (limited-stock items only), up to Config.MaxShopStock.
    -- Reserved atomically in SQL first so two sellers can't push past the cap.
    local restock = Config.SellAddsStock ~= false and shopItem.amount ~= nil
    if restock then
        local cap = tonumber(Config.MaxShopStock) or 0
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
            resyncStock(npc)
            local room = math.max(0, cap - (shopItem.amount or 0))
            local msg = room > 0 and locale('sv_stock_full'):format(room, shopItem.label) or locale('sv_stock_full_none'):format(shopItem.label)
            return TriggerClientEvent(FAIL, src, false, msg, getCash(src), shopItemsForClient(npc))
        end
    end

    if not exports['rsg-inventory']:RemoveItem(src, itemName, qty, nil, 'rsg-stores-sell') then
        if restock then restoreStock(npc.id, itemName, -qty) end -- undo the reservation
        return TriggerClientEvent(FAIL, src, false, locale('sv_remove_failed'), getCash(src))
    end
    Player.Functions.AddMoney('cash', payout, 'rsg-stores-sell')
    if restock then shopItem.amount = shopItem.amount + qty end

    local info = RSGCore.Shared.Items[itemName]
    if info then TriggerClientEvent('rsg-inventory:client:ItemBox', src, info, 'remove', qty) end

    TriggerClientEvent(FAIL, src, true, locale('sv_sold'):format(qty, shopItem.label, payout, FEE_PCT), getCash(src), shopItemsForClient(npc))

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
    if onCooldown(src) then return end

    if type(cartItems) ~= 'table' or #cartItems == 0 then return fail(locale('sv_cart_empty')) end
    if #cartItems > MAX_CART_LINES then return fail(locale('sv_invalid_qty')) end

    local npc = findNpc(npcId)
    if not npc or not npc.shop then return fail(locale('sv_shop_notfound')) end
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

    local lines, total = {}, 0
    for _, name in ipairs(order) do
        local qty = merged[name]
        local shopItem = findShopItem(npc, name)
        if not shopItem or not RSGCore.Shared.Items[name] then return fail(locale('sv_no_longer_sold')) end
        if shopItem.amount ~= nil and shopItem.amount < qty then
            return fail(locale('sv_no_stock_item'):format(shopItem.label))
        end
        if not exports['rsg-inventory']:CanAddItem(src, name, qty) then return fail(locale('sv_inv_full')) end
        total = total + shopItem.price * qty
        lines[#lines + 1] = { item = shopItem, name = name, qty = qty }
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
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[l.name], 'add', l.qty)
    end

    TriggerClientEvent('rsg-stores:client:purchaseSuccess', src,
        locale('sv_cart_done'):format(#lines, total), getCash(src), shopItemsForClient(npc))

    local list = {}
    for _, l in ipairs(lines) do
        local stockLeft = l.item.amount and locale('wh_stock_left'):format(l.item.amount) or ''
        list[#list + 1] = ('• %dx %s @ %s%s'):format(l.qty, l.item.label, Webhook.Money(l.item.price), stockLeft)
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

lib.callback.register('rsg-blipmenu:server:saveNPC', function(source, data)
    if denyIfNotAdmin(source, 'saveNPC') then return nil end
    local npc = sanitizeNpc(data)
    if not npc then return nil end
    local s = npc.shop
    npc.id = tonumber(MySQL.insert.await(
        'INSERT INTO rsg_shops_npcs (name, model, x, y, z, h, shop_name, shop_label, shop_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { npc.name, npc.model, npc.x, npc.y, npc.z, npc.h, s and s.name, s and s.label, s and s.type or 'both' }))
    if not npc.id then return nil end
    if s then insertShopItems(npc.id, s.items) end
    CachedNPCs[#CachedNPCs + 1] = npc
    broadcastNPCs()
    local fields = shopFields(npc)
    fields[#fields + 1] = { name = locale('wh_f_name_model'), value = ('%s / `%s`'):format(npc.name, npc.model) }
    fields[#fields + 1] = { name = locale('wh_f_type'), value = s and locale('cl_shop_' .. s.type) or locale('wh_no_shop') }
    fields[#fields + 1] = { name = locale('wh_f_items'), value = tostring(s and #s.items or 0) }
    fields[#fields + 1] = { name = locale('wh_f_coords'), value = coordStr(npc) }
    Webhook.Send('admin', locale('wh_t_npc_created'), nil, source, fields)
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

    MySQL.update.await(
        'UPDATE rsg_shops_npcs SET name = ?, model = ?, x = ?, y = ?, z = ?, h = ?, shop_name = ?, shop_label = ?, shop_type = ? WHERE id = ?',
        { npc.name, npc.model, npc.x, npc.y, npc.z, npc.h, s and s.name, s and s.label, s and s.type or 'both', npc.id })
    MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { npc.id })
    if s then insertShopItems(npc.id, s.items) end

    -- keep linked blips on the NPC
    MySQL.update.await('UPDATE rsg_shops_blips SET x = ?, y = ?, z = ? WHERE associated_npc_id = ?', { npc.x, npc.y, npc.z, npc.id })
    for _, b in ipairs(CachedBlips) do
        if b.associatedNpcId == npc.id then b.x, b.y, b.z = npc.x, npc.y, npc.z end
    end

    CachedNPCs[idx] = npc
    broadcastNPCs()
    broadcastBlips()
    Webhook.Send('admin', locale('wh_t_npc_updated'), diffNpc(existing, npc), src, shopFields(npc))
end)

RegisterNetEvent('rsg-blipmenu:server:deleteNPC', function(npcId)
    local src = source
    if denyIfNotAdmin(src, 'deleteNPC') then return end
    local existing, idx = findNpc(npcId)
    if not existing then return end
    MySQL.query.await('DELETE FROM rsg_shops_items WHERE npc_id = ?', { existing.id })
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
    Webhook.Send('admin', locale('wh_t_npc_deleted'), nil, src, fields)
end)

RegisterNetEvent('rsg-blipmenu:server:requestNPCs', function()
    TriggerClientEvent('rsg-blipmenu:client:refreshNPCs', source, CachedNPCs)
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
