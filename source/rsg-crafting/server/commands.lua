---------------------------------------------
-- admin commands (all need the 'admin' permission)
---------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
CraftingServer = CraftingServer or {}

local function notify(src, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = description, type = ntype or 'inform', duration = 5000,
    })
end

-- /craftingxp [id] [amount]  (a negative amount takes XP away)
RSGCore.Commands.Add('craftingxp', locale('cmd_xp_help'), {
    { name = 'id', help = locale('cmd_arg_id') },
    { name = 'amount', help = locale('cmd_arg_amount') },
}, true, function(src, args)
    local target = math.tointeger(tonumber(args[1]))
    local amount = math.tointeger(math.floor(tonumber(args[2]) or 0))
    local Player = target and RSGCore.Functions.GetPlayer(target)
    if not Player or not amount or amount == 0 or math.abs(amount) > 100000 then
        return notify(src, locale('cmd_invalid'), 'error')
    end
    if amount > 0 then
        Player.Functions.AddRep(Config.XPType, amount)
    else
        Player.Functions.RemoveRep(Config.XPType, -amount)
    end
    notify(src, locale('xp_given_admin', amount, target), 'success')
end, 'admin')

-- /craftingrecipe [id] [blueprint item] [remove]
RSGCore.Commands.Add('craftingrecipe', locale('cmd_recipe_help'), {
    { name = 'id', help = locale('cmd_arg_id') },
    { name = 'blueprint', help = locale('cmd_arg_blueprint') },
}, true, function(src, args)
    local target = math.tointeger(tonumber(args[1]))
    local key = tostring(args[2] or '')
    local Player = target and RSGCore.Functions.GetPlayer(target)
    if not Player then return notify(src, locale('cmd_invalid'), 'error') end
    if not CraftingServer.IsBlueprint(key) then return notify(src, locale('recipe_unknown_admin', key), 'error') end

    if args[3] == 'remove' then
        CraftingServer.ForgetRecipe(Player, key)
        notify(src, locale('recipe_removed_admin', key, target), 'success')
    else
        CraftingServer.LearnRecipe(Player, key)
        notify(src, locale('recipe_granted_admin', key, target), 'success')
    end
end, 'admin')

-- /craftstation [type]: place a station (with the gizmo when the type has a prop, otherwise where you stand)
RSGCore.Commands.Add('craftstation', locale('cmd_station_help'), {
    { name = 'type', help = locale('cmd_arg_station') },
}, true, function(src, args)
    local stationType = tostring(args[1] or '')
    if not Config.Stations.Enabled or not Config.Stations.Types[stationType] then
        return notify(src, locale('station_invalid_type'), 'error')
    end
    TriggerClientEvent('rsg-crafting:client:placeStation', src, stationType)
end, 'admin')

-- /removecraftstation: remove the closest placed station within 3 metres
RSGCore.Commands.Add('removecraftstation', locale('cmd_remove_station_help'), {}, false, function(src)
    if CraftingServer.RemoveNearestStation(src) then
        notify(src, locale('station_removed'), 'success')
    else
        notify(src, locale('station_none_near'), 'error')
    end
end, 'admin')
