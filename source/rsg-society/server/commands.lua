local RSGCore = Soc.Core
local ADMIN = Config.AdminPermission

local function say(src, desc, nType)
    Soc.Notify(src, locale('sv_admin_title'), desc, nType or 'inform')
end

-- The client asks for the desk list when it loads and whenever it restarts
RegisterNetEvent('rsg-society:server:requestLocations', function()
    if not Soc.Ready then return end
    Soc.BroadcastLocations(source)
end)

-- /addsociety <job>: give a rsg-core job a society
RSGCore.Commands.Add('addsociety', locale('cmd_addsociety_desc'), { { name = 'job', help = locale('cmd_arg_job') } }, true, function(source, args)
    local name = args[1] and args[1]:lower()
    if not name or not Soc.JobExists(name) then return say(source, locale('sv_admin_no_job'), 'error') end
    if Soc.S[name] then return say(source, locale('sv_admin_exists', name), 'error') end
    Soc.EnsureJob(name)
    Soc.Audit(name, nil, GetPlayerName(source), 'admin_create')
    say(source, locale('sv_admin_added', name), 'success')
end, ADMIN)

-- /societydesk <society>: a desk where you are standing
RSGCore.Commands.Add('societydesk', locale('cmd_societydesk_desc'), { { name = 'society', help = locale('cmd_arg_society') } }, true, function(source, args)
    local name = args[1] and args[1]:lower()
    local s = name and Soc.S[name]
    if not s then return say(source, locale('sv_err_unknown'), 'error') end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local id = MySQL.insert.await('INSERT INTO rsg_society_locations (society, label, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, Soc.Trunc(Soc.Label(name), 80), pos.x, pos.y, pos.z, heading, GetPlayerName(source),
    })
    if not id then return say(source, locale('sv_err_unknown'), 'error') end
    Soc.Locations['db_' .. id] = { id = 'db_' .. id, name = Soc.Label(name), society = name, coords = vector3(pos.x, pos.y, pos.z), showblip = false, db = id }
    Soc.BroadcastLocations()
    Soc.Audit(name, nil, GetPlayerName(source), 'admin_desk', ('%.1f %.1f %.1f'):format(pos.x, pos.y, pos.z))
    say(source, locale('sv_admin_desk_added', name), 'success')
end, ADMIN)

-- /removesocietydesk: the nearest desk that was added in game (config desks are removed in shared/config.lua)
RSGCore.Commands.Add('removesocietydesk', locale('cmd_removesocietydesk_desc'), {}, false, function(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local pos = GetEntityCoords(ped)
    local bestId, best = nil, 3.0
    for id, loc in pairs(Soc.Locations) do
        local d = loc.db and #(pos - loc.coords) or 9999.0
        if d <= best then bestId, best = id, d end
    end
    if not bestId then return say(source, locale('sv_admin_no_desk'), 'error') end
    local loc = Soc.Locations[bestId]
    MySQL.update.await('DELETE FROM rsg_society_locations WHERE id = ?', { loc.db })
    Soc.Locations[bestId] = nil
    Soc.BroadcastLocations()
    Soc.Audit(loc.society, nil, GetPlayerName(source), 'admin_desk_removed')
    say(source, locale('sv_admin_desk_removed'), 'success')
end, ADMIN)

-- /societyfunds <society> <add|remove> <amount>
RSGCore.Commands.Add('societyfunds', locale('cmd_societyfunds_desc'), {
    { name = 'society', help = locale('cmd_arg_society') },
    { name = 'add|remove', help = locale('cmd_arg_mode') },
    { name = 'amount', help = locale('cmd_arg_amount') },
}, true, function(source, args)
    local name, mode = args[1] and args[1]:lower(), args[2] and args[2]:lower()
    local cents = Soc.ToCents(args[3])
    if not name or not Soc.S[name] or not cents or (mode ~= 'add' and mode ~= 'remove') then
        return say(source, locale('sv_err_unknown'), 'error')
    end
    local who = GetPlayerName(source)
    if mode == 'add' then
        Soc.Credit(name, cents, 'admin', who, nil, who)
    elseif not Soc.Debit(name, cents, 'admin', who, nil, who) then
        return say(source, locale('sv_err_funds'), 'error')
    end
    Soc.Audit(name, nil, who, 'admin_funds', ('%s $%.2f'):format(mode, cents / 100))
    say(source, locale('sv_admin_funds', name, Soc.S[name].balance / 100), 'success')
end, ADMIN)

-- /societymigrate: run the import of the old resources again (only adds what is missing)
RSGCore.Commands.Add('societymigrate', locale('cmd_societymigrate_desc'), {}, false, function(source)
    Soc.Migrate(true)
    say(source, locale('sv_admin_migrated'), 'success')
end, ADMIN)

-- /removegang <id>: takes a player out of their gang (same name rsg-gangmenu used)
RSGCore.Commands.Add('removegang', locale('cmd_removegang_desc'), { { name = 'id', help = locale('cmd_arg_id') } }, true, function(source, args)
    local Target = RSGCore.Functions.GetPlayer(tonumber(args[1]) or -1)
    if not Target then return say(source, locale('sv_err_player'), 'error') end
    local cid = Target.PlayerData.citizenid
    local gang = Soc.GangOf[cid]
    if not gang then return say(source, locale('sv_err_no_gang'), 'error') end
    Soc.RemoveGangMember(gang, cid)
    Soc.Audit(gang, nil, GetPlayerName(source), 'admin_remove', nil, cid, Soc.PlayerName(Target))
    Soc.Notify(Target.PlayerData.source, Soc.Label(gang), locale('sv_you_fired', Soc.Label(gang)), 'error')
    say(source, locale('sv_fired', Soc.PlayerName(Target)), 'success')
end, ADMIN)
