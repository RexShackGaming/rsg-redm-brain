-- ============================================
-- LIVE SETTINGS (admin panel > Settings tab)
-- Admins edit a curated list of Config values in-game. Changes are saved to `rsg_shops_settings`
-- and applied to Config straight away (server and every client), and re-applied on each start.
-- Only the fields listed in GROUPS can be changed, each with its own type and range, and every
-- value is validated here again no matter what the NUI sent.
-- Loaded BEFORE server.lua. server.lua calls Settings.Load() once the database is ready.
-- ============================================
local RSGCore = exports['rsg-core']:GetCoreObject()

Settings = {}

local function F(path, typ, label, o)
    o = o or {}
    o.path, o.type, o.label = path, typ, 'ui_set_' .. label
    return o
end

-- type: bool | int | num | pct (0-1, shown as %) | choice | map_cost | map_pct | map_hours
local GROUPS = {
    { id = 'general', label = 'ui_set_g_general', fields = {
        F('SellPricePercentage', 'pct', 'sell_pct'),
        F('SellAddsStock', 'bool', 'sell_adds_stock'),
        F('MaxShopStock', 'int', 'max_shop_stock', { min = 0, max = 100000 }),
    } },
    { id = 'owned', label = 'ui_set_g_owned', fields = {
        F('OwnedStores.BuyBackPercentage', 'pct', 'buyback_pct'),
        F('OwnedStores.MaxListings', 'int', 'max_listings', { min = 1, max = 500 }),
        F('OwnedStores.MaxStock', 'int', 'owned_max_stock', { min = 0, max = 100000 }),
        F('OwnedStores.MaxPrice', 'num', 'max_price', { min = 1, max = 1000000 }),
        F('OwnedStores.MinQuality', 'int', 'min_quality', { min = 0, max = 100 }),
        F('OwnedStores.NotifyOwner', 'bool', 'notify_owner'),
        F('OwnedStores.BankPayment', 'bool', 'bank_payment'),
        F('OwnedStores.AllowResale', 'bool', 'allow_resale'),
    } },
    { id = 'staff', label = 'ui_set_g_staff', fields = {
        F('Staff.MaxStaff', 'int', 'max_staff', { min = 1, max = 50 }),
        F('Staff.MaxJobsPerPlayer', 'int', 'max_jobs', { min = 0, max = 50 }),
        F('Staff.HireDistance', 'num', 'hire_distance', { min = 1, max = 30 }),
        F('Staff.DailyWithdrawLimit', 'num', 'daily_limit', { min = 0, max = 1000000 }),
    } },
    { id = 'sign', label = 'ui_set_g_sign', fields = {
        F('ShopSign.MaxPerPlayer', 'int', 'sign_max', { min = 0, max = 20 }),
        F('ShopSign.MinSpacing', 'num', 'sign_spacing', { min = 0, max = 500 }),
        F('ShopSign.AllowMove', 'bool', 'sign_move'),
        F('ShopSign.ReturnOnPackUp', 'bool', 'sign_return'),
        F('ShopSign.Upkeep.Enabled', 'bool', 'upkeep_enabled'),
        F('ShopSign.Upkeep.Amount', 'num', 'upkeep_amount', { min = 0, max = 100000 }),
        F('ShopSign.Upkeep.IntervalHours', 'num', 'upkeep_hours', { min = 1, max = 720 }),
        F('ShopSign.Upkeep.EvictAfterMissed', 'int', 'upkeep_evict', { min = 1, max = 100 }),
    } },
    { id = 'hours', label = 'ui_set_g_hours', fields = {
        F('OpeningHours.Enabled', 'bool', 'hours_enabled'),
        F('OpeningHours.Open', 'int', 'hours_open', { min = 0, max = 23 }),
        F('OpeningHours.Close', 'int', 'hours_close', { min = 0, max = 23 }),
        F('OpeningHours.OwnedStores', 'bool', 'hours_owned'),
        F('OpeningHours.Shops', 'map_hours', 'hours_shops', { max = 200 }),
    } },
    { id = 'discounts', label = 'ui_set_g_discounts', fields = {
        F('Discounts.Enabled', 'bool', 'disc_enabled'),
        F('Discounts.MaxDiscount', 'pct', 'disc_max'),
        F('Discounts.Jobs', 'map_pct', 'disc_jobs', { max = 100 }),
        F('Discounts.Gangs', 'map_pct', 'disc_gangs', { max = 100 }),
    } },
    { id = 'wholesale', label = 'ui_set_g_wholesale', fields = {
        F('Wholesale.Enabled', 'bool', 'whs_enabled'),
        F('Wholesale.PayFrom', 'choice', 'whs_payfrom', { options = { 'till', 'cash', 'either' } }),
        F('Wholesale.Markup', 'num', 'whs_markup', { min = 1, max = 100 }),
        F('Wholesale.Items', 'map_cost', 'whs_items', { max = 200 }),
    } },
    { id = 'ledger', label = 'ui_set_g_ledger', fields = {
        F('Ledger.Keep', 'int', 'ledger_keep', { min = 10, max = 1000 }),
        F('Ledger.Show', 'int', 'ledger_show', { min = 10, max = 200 }),
    } },
}

local Defaults, Overrides, byPath = {}, {}, {}

local function copy(v)
    if type(v) ~= 'table' then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = copy(x) end
    return o
end

local function getPath(root, path)
    local n = root
    for part in path:gmatch('[^.]+') do
        if type(n) ~= 'table' then return nil end
        n = n[part]
    end
    return n
end

local function setPath(root, path, value)
    local parts = {}
    for part in path:gmatch('[^.]+') do parts[#parts + 1] = part end
    local n = root
    for i = 1, #parts - 1 do
        if type(n[parts[i]]) ~= 'table' then n[parts[i]] = {} end
        n = n[parts[i]]
    end
    n[parts[#parts]] = value
end

for _, g in ipairs(GROUPS) do
    for _, f in ipairs(g.fields) do
        byPath[f.path] = f
        Defaults[f.path] = copy(getPath(Config, f.path))
    end
end

-- ============================================
-- VALIDATION
-- ============================================
local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
local function round(n, d) local m = 10 ^ d; return math.floor(n * m + 0.5) / m end
local NAME = '^[%w_%-%.]+$'

local function mapCount(v)
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    return n
end

-- Returns the clean value, or nil + a locale key.
local function validate(f, v)
    local t = f.type
    if t == 'bool' then
        if type(v) ~= 'boolean' then return nil, 'ui_set_err_bad' end
        return v
    elseif t == 'int' then
        v = tonumber(v)
        if not finite(v) or v ~= math.floor(v) or v < f.min or v > f.max then return nil, 'ui_set_err_range' end
        return v
    elseif t == 'num' then
        v = tonumber(v)
        if not finite(v) or v < f.min or v > f.max then return nil, 'ui_set_err_range' end
        return round(v, 2)
    elseif t == 'pct' then
        v = tonumber(v)
        if not finite(v) or v < 0 or v > 1 then return nil, 'ui_set_err_range' end
        return round(v, 4)
    elseif t == 'choice' then
        for _, o in ipairs(f.options) do if o == v then return v end end
        return nil, 'ui_set_err_bad'
    end

    -- maps
    if type(v) ~= 'table' or mapCount(v) > (f.max or 100) then return nil, 'ui_set_err_bad' end
    local out = {}
    for k, x in pairs(v) do
        if type(k) ~= 'string' or #k < 1 or #k > 100 then return nil, 'ui_set_err_bad' end
        if t == 'map_cost' then
            local cost = tonumber(x)
            if not k:match(NAME) or not RSGCore.Shared.Items[k] or not finite(cost) or cost < 0 or cost > 100000 then
                return nil, 'ui_set_err_bad'
            end
            out[k] = round(cost, 2)
        elseif t == 'map_pct' then
            local p = tonumber(x)
            if not k:match(NAME) or not finite(p) or p < 0 or p > 1 then return nil, 'ui_set_err_bad' end
            out[k] = round(p, 4)
        elseif t == 'map_hours' then
            local o, c = type(x) == 'table' and tonumber(x.Open), type(x) == 'table' and tonumber(x.Close)
            if k:find('%c') or not finite(o) or not finite(c) or o ~= math.floor(o) or c ~= math.floor(c)
                or o < 0 or o > 23 or c < 0 or c > 23 then
                return nil, 'ui_set_err_bad'
            end
            out[k] = { Open = o, Close = c }
        end
    end
    return out
end

-- ============================================
-- PERSISTENCE
-- ============================================
--- Reads every saved override from the database and applies it to Config. Returns how many were applied.
function Settings.Load()
    local ok, rows = pcall(function() return MySQL.query.await('SELECT setting_key, setting_value FROM rsg_shops_settings') end)
    if not ok then return 0 end
    local n = 0
    Overrides = {}
    for _, row in ipairs(rows or {}) do
        local f = byPath[row.setting_key]
        local okJ, raw = pcall(json.decode, row.setting_value or '')
        if f and okJ and raw ~= nil then
            local v = validate(f, raw)
            if v ~= nil then
                Overrides[f.path] = v
                setPath(Config, f.path, copy(v))
                n = n + 1
            else
                print(('^3[rsg-stores] ignored invalid saved setting %s^7'):format(f.path))
            end
        end
    end
    return n
end

--- Settings in the shape the admin NUI needs: groups, fields, current value, default and whether it is overridden.
function Settings.Get()
    local out = {}
    for _, g in ipairs(GROUPS) do
        local fields = {}
        for _, f in ipairs(g.fields) do
            fields[#fields + 1] = {
                path = f.path, type = f.type, label = f.label, min = f.min, max = f.max, options = f.options,
                value = copy(getPath(Config, f.path)), default = copy(Defaults[f.path]), overridden = Overrides[f.path] ~= nil,
            }
        end
        out[#out + 1] = { id = g.id, label = g.label, fields = fields }
    end
    return out
end

--- Saves a { [path] = value } table. Returns { applied = { { path, old, new } }, errors = { [path] = localeKey } }.
function Settings.Save(changes)
    local applied, errors = {}, {}
    if type(changes) ~= 'table' then return { applied = applied, errors = errors } end
    for path, raw in pairs(changes) do
        local f = type(path) == 'string' and byPath[path]
        if not f then
            errors[tostring(path)] = 'ui_set_err_unknown'
        else
            local v, err = validate(f, raw)
            if v == nil then
                errors[path] = err
            else
                local okDb = pcall(function()
                    MySQL.query.await('REPLACE INTO rsg_shops_settings (setting_key, setting_value, updated_at) VALUES (?, ?, ?)',
                        { path, json.encode(v), os.time() })
                end)
                if not okDb then
                    errors[path] = 'sv_update_fail'
                else
                    local old = copy(getPath(Config, path))
                    Overrides[path] = v
                    setPath(Config, path, copy(v))
                    applied[#applied + 1] = { path = path, old = old, new = copy(v) }
                end
            end
        end
    end
    return { applied = applied, errors = errors }
end

--- Removes a saved override and puts the config.lua value back. Returns true when something changed.
function Settings.Reset(path)
    if type(path) ~= 'string' or not byPath[path] then return false end
    local ok = pcall(function() MySQL.query.await('DELETE FROM rsg_shops_settings WHERE setting_key = ?', { path }) end)
    if not ok then return false end
    Overrides[path] = nil
    setPath(Config, path, copy(Defaults[path]))
    return true
end

--- Current value of every editable setting ({ [path] = value }), sent to clients so their Config matches the server.
function Settings.Effective()
    local out = {}
    for path in pairs(byPath) do
        local v = getPath(Config, path)
        if v ~= nil then out[path] = copy(v) end
    end
    return out
end

--- Short one-line text of a value for webhook diffs.
function Settings.Describe(v)
    if type(v) == 'table' then return json.encode(v):sub(1, 200) end
    return tostring(v)
end
