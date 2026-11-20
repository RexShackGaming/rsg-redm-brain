local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------------
-- Player commands
---------------------------------------------------------------------
RSGCore.Commands.Add(Config.Command, locale('cmd_open_help'), {}, false, function(source)
    -- With the wagon target menu on, gang members manage their gang at the wagon instead.
    if Config.GangVehicle.enabled and Config.GangVehicle.useTargetMenu then
        local citizenid = RSGGangs.GetPlayerCitizenId(source)
        if citizenid and RSGGangs.FindGangByMember(citizenid) then
            RSGGangs.Notify(source, locale('notify_admin_head_to_wagon'), 'inform')
            return
        end
    end
    TriggerClientEvent('rsg-gangs:client:openMenu', source)
end)

RSGCore.Commands.Add('gangaccept', locale('cmd_accept_help'), {}, false, function(source)
    TriggerClientEvent('rsg-gangs:client:requestAccept', source)
end)

RSGCore.Commands.Add('gangdecline', locale('cmd_decline_help'), {}, false, function(source)
    TriggerClientEvent('rsg-gangs:client:requestDecline', source)
end)

---------------------------------------------------------------------
-- Admin commands
---------------------------------------------------------------------
RSGCore.Commands.Add('creategangadmin', locale('cmd_create_help'), {
    { name = 'name', help = locale('cmd_arg_name') },
    { name = 'label', help = locale('cmd_arg_label') },
}, false, function(source, args)
    local rawName = args[1]
    local label = RSGGangs.CleanLabel(table.concat(args, ' ', 2))
    local gangName = rawName and RSGGangs.SanitizeGangName(rawName)

    if not gangName or gangName == '' or not label then
        RSGGangs.Notify(source, locale('notify_admin_usage'), 'error')
        return
    end
    if RSGGangs.Gangs[gangName] then
        RSGGangs.Notify(source, locale('error_gang_exists'), 'error')
        return
    end

    local gang = RSGGangs.CreateGangRecord(gangName, label, Config.GangColors[1], 'SYSTEM', nil)
    if not gang then
        RSGGangs.Notify(source, locale('error_generic'), 'error')
        return
    end

    RSGGangs.Log('Gang created (admin)', ('%s (%s) by source %s'):format(label, gangName, source))
    RSGGangs.Notify(source, locale('notify_admin_gang_created', label), 'success')
end, 'admin')

RSGCore.Commands.Add('disbandgangadmin', locale('cmd_disband_help'), {
    { name = 'name', help = locale('cmd_arg_name') },
}, true, function(source, args)
    local gang = RSGGangs.Gangs[args[1] or '']
    if not gang then
        RSGGangs.Notify(source, locale('error_gang_not_found'), 'error')
        return
    end

    local name = gang.name
    if not RSGGangs.DestroyGang(gang, 'notify_admin_outfit_disbanded', 'inform') then
        RSGGangs.Notify(source, locale('error_generic'), 'error')
        return
    end

    RSGGangs.Log('Gang disbanded (admin)', ('%s by source %s'):format(name, source))
    RSGGangs.Notify(source, locale('notify_admin_gang_disbanded'), 'success')
end, 'admin')

RSGCore.Commands.Add('addgangmember', locale('cmd_addmember_help'), {
    { name = 'id', help = locale('cmd_arg_id') },
    { name = 'gang', help = locale('cmd_arg_name') },
    { name = 'rank', help = locale('cmd_arg_rank') },
}, false, function(source, args)
    local target = tonumber(args[1])
    local gang = RSGGangs.Gangs[args[2] or '']
    local Player = target and RSGCore.Functions.GetPlayer(target)

    if not Player then RSGGangs.Notify(source, locale('error_player_not_found'), 'error') return end
    if not gang then RSGGangs.Notify(source, locale('error_gang_not_found'), 'error') return end

    local rank = args[3] or Config.DefaultJoinRank
    if not RSGGangs.GetRankData(rank) then
        RSGGangs.Notify(source, locale('error_invalid_rank'), 'error')
        return
    end

    if RSGGangs.FindGangByMember(Player.PlayerData.citizenid) then
        RSGGangs.Notify(source, locale('error_player_already_gang'), 'error')
        return
    end

    if not RSGGangs.InsertMember(gang, Player, rank) then
        RSGGangs.Notify(source, locale('error_generic'), 'error')
        return
    end

    RSGGangs.Notify(target, locale('success_joined_gang', gang.label), 'success')
    RSGGangs.Notify(source, locale('notify_admin_member_added', RSGGangs.CharName(Player), gang.label), 'success')
    RSGGangs.BroadcastGangUpdate(gang)
end, 'admin')

-- Moves a gang's wagon to where the admin is standing (fixes a gang whose wagon spot is bad).
RSGCore.Commands.Add('setgangwagon', locale('cmd_setwagon_help'), {
    { name = 'gang', help = locale('cmd_arg_name') },
}, true, function(source, args)
    local gang = RSGGangs.Gangs[args[1] or '']
    if not gang then RSGGangs.Notify(source, locale('error_gang_not_found'), 'error') return end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    if not RSGGangs.SetWagonLocation(gang, GetEntityCoords(ped), GetEntityHeading(ped)) then
        RSGGangs.Notify(source, locale('error_generic'), 'error')
        return
    end

    -- Respawn the wagon at its new spot (the streaming loop recreates it when someone is near).
    RSGGangs.DeleteGangWagon(gang.name)
    RSGGangs.BroadcastGangUpdate(gang)
    RSGGangs.Notify(source, locale('notify_admin_wagon_set', gang.label), 'success')
end, 'admin')
