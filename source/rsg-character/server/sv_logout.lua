RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

local lastLogout = {}

AddEventHandler('playerDropped', function()
    lastLogout[source] = nil
end)

local function Notify(src, key, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('logout.title'),
        description = locale(key),
        type = ntype or 'error',
        duration = 5000,
    })
end

local function DoLogout(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if CreatorSessions[src] then return end

    local now = os.time()
    local cooldown = RSG.Logout.Cooldown or 0
    if lastLogout[src] and now - lastLogout[src] < cooldown then
        Notify(src, 'logout.cooldown')
        return
    end

    local meta = Player.PlayerData.metadata or {}
    if RSG.Logout.BlockWhenDead and (meta.isdead or meta.inlaststand) then
        Notify(src, 'logout.dead')
        return
    end

    lastLogout[src] = now

    local charinfo = Player.PlayerData.charinfo or {}
    local citizenid = Player.PlayerData.citizenid

    -- fade the client out before anything is unloaded
    TriggerClientEvent('rsg-character:client:BeginLogout', src)
    Wait(1000)
    if not GetPlayerName(src) then return end

    Player.Functions.Save()
    RSGCore.Player.Logout(src)
    Wait(500)
    if not GetPlayerName(src) then return end

    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('character_logout', {
        title = locale('webhooks.character_logout.title'),
        description = locale('webhooks.character_logout.description',
            charinfo.firstname or locale('webhooks.common.unknown'), charinfo.lastname or '', citizenid or ''),
        fields = { identityFields[1], identityFields[2] },
    })

    TriggerClientEvent('rsg-character:client:OpenCharSelect', src)
end

if RSG.Logout and RSG.Logout.Enabled then
    RSGCore.Commands.Add(RSG.Logout.Command or 'logout', locale('logout.help'), {}, false, function(source)
        DoLogout(source)
    end)
end
