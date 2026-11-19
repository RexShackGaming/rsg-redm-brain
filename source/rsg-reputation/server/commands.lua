-- rsg-reputation: admin commands (work from the server console too)
local RSGCore = exports['rsg-core']:GetCoreObject()

local function reply(src, text, ntype)
    if src == 0 then
        print(('[rsg-reputation] %s'):format(text))
        return
    end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = text, type = ntype or 'inform', duration = 5000,
    })
end

local function target(src, idArg)
    local id = tonumber(idArg)
    if not id or not RSGCore.Functions.GetPlayer(id) then
        reply(src, locale('cmd_player_not_found'), 'error')
        return nil
    end
    return id
end

local function amountOf(src, arg)
    local n = tonumber(arg)
    if not n or n ~= n then
        reply(src, locale('cmd_invalid_amount'), 'error')
        return nil
    end
    return n
end

local function regionOf(src, arg)
    local id = type(arg) == 'string' and arg:lower() or ''
    if not Config.Regions[id] then
        reply(src, locale('cmd_unknown_region', id), 'error')
        return nil
    end
    return id
end

local function add(name, help, params, cb)
    RSGCore.Commands.Add(name, help, params, true, function(source, args)
        CreateThread(function() cb(source, args) end)
    end, Config.AdminPermission)
end

add('addhonor', locale('cmd_addhonor_help'), {
    { name = 'id', help = locale('cmd_arg_id') }, { name = 'amount', help = locale('cmd_arg_amount') },
}, function(source, args)
    local id, n = target(source, args[1]), amountOf(source, args[2])
    if not id or not n then return end
    local v = RSGRep.AddHonor(id, n, 'admin')
    reply(source, locale('cmd_honor_now', id, v or 0), 'success')
end)

add('sethonor', locale('cmd_sethonor_help'), {
    { name = 'id', help = locale('cmd_arg_id') }, { name = 'value', help = locale('cmd_arg_value') },
}, function(source, args)
    local id, n = target(source, args[1]), amountOf(source, args[2])
    if not id or not n then return end
    local v = RSGRep.SetHonor(id, n, 'admin')
    reply(source, locale('cmd_honor_now', id, v or 0), 'success')
end)

add('addstanding', locale('cmd_addstanding_help'), {
    { name = 'id', help = locale('cmd_arg_id') }, { name = 'region', help = locale('cmd_arg_region') }, { name = 'amount', help = locale('cmd_arg_amount') },
}, function(source, args)
    local id, region, n = target(source, args[1]), regionOf(source, args[2]), amountOf(source, args[3])
    if not id or not region or not n then return end
    local v = RSGRep.AddStanding(id, region, n, 'admin')
    reply(source, locale('cmd_standing_now', id, region, v or 0), 'success')
end)

add('setstanding', locale('cmd_setstanding_help'), {
    { name = 'id', help = locale('cmd_arg_id') }, { name = 'region', help = locale('cmd_arg_region') }, { name = 'value', help = locale('cmd_arg_value') },
}, function(source, args)
    local id, region, n = target(source, args[1]), regionOf(source, args[2]), amountOf(source, args[3])
    if not id or not region or not n then return end
    local v = RSGRep.SetStanding(id, region, n, 'admin')
    reply(source, locale('cmd_standing_now', id, region, v or 0), 'success')
end)

add('resetreputation', locale('cmd_reset_help'), {
    { name = 'id', help = locale('cmd_arg_id') },
}, function(source, args)
    local id = target(source, args[1])
    if not id then return end
    RSGRep.Reset(id)
    reply(source, locale('cmd_reset_done', id), 'success')
end)

add('reputationinfo', locale('cmd_info_help'), {
    { name = 'id', help = locale('cmd_arg_id') },
}, function(source, args)
    local id = target(source, args[1])
    if not id then return end
    local c = RSGRep.Load(id)
    if not c then return reply(source, locale('cmd_player_not_found'), 'error') end
    local parts = {}
    for region, value in pairs(c.standing) do
        if value ~= 0 then parts[#parts + 1] = ('%s %d'):format(region, value) end
    end
    table.sort(parts)
    reply(source, locale('cmd_info_line', id, c.honor, #parts > 0 and table.concat(parts, ', ') or '-'))
end)
