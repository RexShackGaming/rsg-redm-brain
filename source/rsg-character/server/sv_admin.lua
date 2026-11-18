RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

-- Admin tools: /charinfo, /resetskin, /changename (names and permission in RSG.AdminCommands)
local cfg = RSG.AdminCommands
if not cfg or not cfg.Enabled then return end

local function Notify(src, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('admin.title'), description = description, type = ntype or 'inform', duration = 7000,
    })
end

local function FindTarget(src, id)
    local target = tonumber(id)
    local Player = target and RSGCore.Functions.GetPlayer(target)
    if not Player then Notify(src, locale('admin.player_not_found'), 'error') end
    return Player, target
end

local function Log(src, targetPlayer, action)
    local fields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('admin_action', {
        title = locale('webhooks.admin_action.title'),
        description = locale('webhooks.admin_action.description', action, targetPlayer.PlayerData.citizenid),
        fields = { fields[1], fields[2] },
    })
end

RSGCore.Commands.Add(cfg.CharInfo or 'charinfo', locale('admin.charinfo_help'), { { name = 'id', help = locale('admin.arg_id') } }, true, function(src, args)
    local Player = FindTarget(src, args[1])
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local hasSkin = (MySQL.scalar.await('SELECT COUNT(*) FROM playerskins WHERE citizenid = ?', { cid }) or 0) > 0
    local outfits = MySQL.scalar.await('SELECT COUNT(*) FROM playeroutfit WHERE citizenid = ?', { cid }) or 0
    local info = Player.PlayerData.charinfo or {}
    Notify(src, locale('admin.charinfo', info.firstname or '', info.lastname or '', cid, Player.PlayerData.cid or '?',
        hasSkin and locale('admin.yes') or locale('admin.no'), outfits))
end, cfg.Permission or 'admin')

RSGCore.Commands.Add(cfg.ResetSkin or 'resetskin', locale('admin.resetskin_help'), { { name = 'id', help = locale('admin.arg_id') } }, true, function(src, args)
    local Player, target = FindTarget(src, args[1])
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    RSG.ResetAppearance(cid)
    local info = Player.PlayerData.charinfo or {}
    Notify(src, locale('admin.skin_reset_done', info.firstname or '', info.lastname or ''), 'success')
    Notify(target, locale('admin.skin_reset_target'), 'warning')
    Log(src, Player, 'resetskin')
end, cfg.Permission or 'admin')

RSGCore.Commands.Add(cfg.ChangeName or 'changename', locale('admin.changename_help'), {
    { name = 'id', help = locale('admin.arg_id') },
    { name = 'firstname', help = locale('admin.arg_first') },
    { name = 'lastname', help = locale('admin.arg_last') },
}, true, function(src, args)
    local Player, target = FindTarget(src, args[1])
    if not Player then return end
    local first, last = args[2], args[3]
    local ok, reason = RSG.ChangeName(Player.PlayerData.citizenid, first, last)
    if not ok then
        return Notify(src, reason == 'name_taken' and locale('admin.name_taken') or locale('admin.name_invalid'), 'error')
    end
    Notify(src, locale('admin.name_changed', first, last), 'success')
    Notify(target, locale('admin.name_changed_target', first, last), 'inform')
    Log(src, Player, 'changename')
end, cfg.Permission or 'admin')
