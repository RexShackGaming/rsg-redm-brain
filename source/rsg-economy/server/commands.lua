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
    if not n or not RSGEcon.finite(n) or math.abs(n) > RSGEcon.MaxBalance then
        reply(src, locale('cmd_invalid_amount'), 'error')
        return nil
    end
    return n
end

-- who ran the command, for the ledger
local function who(src)
    return src == 0 and 'console' or RSGEcon.ActorName(src)
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
    local ok, rate = RSGEcon.SetTaxRate(region, cat, pct / 100, who(source))
    if not ok then return reply(source, locale('cmd_invalid_amount'), 'error') end
    reply(source, locale('cmd_tax_now', region, cat, ('%.1f%%'):format(rate * 100)), 'success')
end)

add('addtreasury', locale('cmd_addtreasury_help'), {
    { name = 'region', help = locale('cmd_arg_region') }, { name = 'amount', help = locale('cmd_arg_amount') },
}, true, function(source, args)
    local region, n = regionOf(source, args[1]), numberOf(source, args[2])
    if not region or not n then return end
    local bal
    if n >= 0 then bal = RSGEcon.DepositTreasury(region, n, 'admin', who(source), 'admin')
    else bal = RSGEcon.WithdrawTreasury(region, -n, 'admin', who(source), 'admin') end
    if not bal then return reply(source, locale('msg_insufficient_treasury'), 'error') end
    reply(source, locale('cmd_treasury_now', region, ('%.2f'):format(bal)), 'success')
end)

add('settreasury', locale('cmd_settreasury_help'), {
    { name = 'region', help = locale('cmd_arg_region') }, { name = 'amount', help = locale('cmd_arg_value') },
}, true, function(source, args)
    local region, n = regionOf(source, args[1]), numberOf(source, args[2])
    if not region or not n then return end
    local bal = RSGEcon.SetTreasury(region, n, who(source))
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

------------------------------------------
-- elections and mayors
------------------------------------------
local ELECTION_REASONS = {
    unknown = 'cmd_unknown_region', disabled = 'cmd_election_disabled', running = 'cmd_election_running',
    none = 'cmd_election_none', busy = 'msg_busy', notready = 'cmd_not_ready', citizen = 'cmd_unknown_citizen',
}

local function fail(src, reason)
    reply(src, locale(ELECTION_REASONS[reason] or 'msg_failed', ''), 'error')
end

add('startelection', locale('cmd_startelection_help'), {
    { name = 'region', help = locale('cmd_arg_region') },
}, true, function(source, args)
    local region = regionOf(source, args[1])
    if not region then return end
    local ok, reason = RSGEcon.StartElection(region)
    if not ok then return fail(source, reason) end
    reply(source, locale('cmd_election_done', region), 'success')
end)

add('endelection', locale('cmd_endelection_help'), {
    { name = 'region', help = locale('cmd_arg_region') },
}, true, function(source, args)
    local region = regionOf(source, args[1])
    if not region then return end
    local ok, reason = RSGEcon.AdvanceElection(region)
    if not ok then return fail(source, reason) end
    reply(source, locale('cmd_election_done', region), 'success')
end)

add('cancelelection', locale('cmd_cancelelection_help'), {
    { name = 'region', help = locale('cmd_arg_region') },
}, true, function(source, args)
    local region = regionOf(source, args[1])
    if not region then return end
    local ok, reason = RSGEcon.CancelElection(region)
    if not ok then return fail(source, reason) end
    reply(source, locale('cmd_election_done', region), 'success')
end)

add('setmayor', locale('cmd_setmayor_help'), {
    { name = 'region', help = locale('cmd_arg_region') }, { name = 'citizenid', help = locale('cmd_arg_citizenid') },
}, true, function(source, args)
    local region = regionOf(source, args[1])
    if not region then return end
    local ok, result = RSGEcon.SetMayor(region, tostring(args[2] or ''))
    if not ok then return fail(source, result) end
    reply(source, locale('cmd_mayor_set', result, region), 'success')
end)

add('clearmayor', locale('cmd_clearmayor_help'), {
    { name = 'region', help = locale('cmd_arg_region') },
}, true, function(source, args)
    local region = regionOf(source, args[1])
    if not region then return end
    local ok, reason = RSGEcon.ClearMayor(region)
    if not ok then return fail(source, reason) end
    reply(source, locale('cmd_election_done', region), 'success')
end)
