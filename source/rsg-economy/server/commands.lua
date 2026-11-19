-- rsg-economy: admin commands (work from the server console too)
local RSGCore = exports['rsg-core']:GetCoreObject()

local function reply(src, text, ntype)
    if src == 0 then
        print(('[rsg-economy] %s'):format(text))
        return
    end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = text, type = ntype or 'inform', duration = 5000,
    })
end

local function regionOf(src, arg)
    local id = type(arg) == 'string' and arg:lower() or ''
    if not Config.Regions[id] then
        reply(src, locale('cmd_unknown_region', id), 'error')
        return nil
    end
    return id
end

local function numberOf(src, arg)
    local n = tonumber(arg)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        reply(src, locale('cmd_invalid_amount'), 'error')
        return nil
    end
    return n
end

local function add(name, help, params, required, cb)
    RSGCore.Commands.Add(name, help, params, required, function(source, args)
        CreateThread(function()
            if not RSGEcon.Ready then return reply(source, locale('cmd_not_ready'), 'error') end
            cb(source, args)
        end)
    end, Config.AdminPermission)
end

add('settax', locale('cmd_settax_help'), {
    { name = 'region', help = locale('cmd_arg_region') }, { name = 'category', help = locale('cmd_arg_category') }, { name = 'percent', help = locale('cmd_arg_percent') },
}, true, function(source, args)
    local region, pct = regionOf(source, args[1]), numberOf(source, args[3])
    local cat = tostring(args[2] or ''):lower()
    if not region or not pct then return end
    if not Config.Tax.Categories[cat] then return reply(source, locale('cmd_unknown_category', cat), 'error') end
    local ok, rate = RSGEcon.SetTaxRate(region, cat, pct / 100, 'admin')
    if not ok then return reply(source, locale('cmd_invalid_amount'), 'error') end
    reply(source, locale('cmd_tax_now', region, cat, ('%.1f%%'):format(rate * 100)), 'success')
end)

add('addtreasury', locale('cmd_addtreasury_help'), {
    { name = 'region', help = locale('cmd_arg_region') }, { name = 'amount', help = locale('cmd_arg_amount') },
}, true, function(source, args)
    local region, n = regionOf(source, args[1]), numberOf(source, args[2])
    if not region or not n then return end
    local bal
    if n >= 0 then bal = RSGEcon.DepositTreasury(region, n, 'admin', 'admin', 'admin')
    else bal = RSGEcon.WithdrawTreasury(region, -n, 'admin', 'admin', 'admin') end
    if not bal then return reply(source, locale('msg_insufficient_treasury'), 'error') end
    reply(source, locale('cmd_treasury_now', region, ('%.2f'):format(bal)), 'success')
end)

add('settreasury', locale('cmd_settreasury_help'), {
    { name = 'region', help = locale('cmd_arg_region') }, { name = 'amount', help = locale('cmd_arg_value') },
}, true, function(source, args)
    local region, n = regionOf(source, args[1]), numberOf(source, args[2])
    if not region or not n then return end
    local bal = RSGEcon.SetTreasury(region, n, 'admin')
    reply(source, locale('cmd_treasury_now', region, ('%.2f'):format(bal or 0)), 'success')
end)

add('resetmarket', locale('cmd_resetmarket_help'), {
    { name = 'region', help = locale('cmd_arg_region_or_all') },
}, true, function(source, args)
    local arg = tostring(args[1] or ''):lower()
    local region
    if arg ~= 'all' then region = regionOf(source, arg) if not region then return end end
    local n = RSGEcon.ResetMarket(region)
    reply(source, locale('cmd_market_reset', n), 'success')
end)

add('economyinfo', locale('cmd_info_help'), {
    { name = 'region', help = locale('cmd_arg_region') },
}, true, function(source, args)
    local region = regionOf(source, args[1])
    if not region then return end
    local parts = {}
    for key in pairs(Config.Tax.Categories) do
        parts[#parts + 1] = ('%s %.1f%%'):format(key, RSGEcon.GetTaxRate(region, key) * 100)
    end
    table.sort(parts)
    local items = 0
    for _ in pairs(RSGEcon.Market[region] or {}) do items = items + 1 end
    reply(source, locale('cmd_info_line', region, ('%.2f'):format(RSGEcon.GetTreasury(region)), table.concat(parts, ', '), items))
end)
