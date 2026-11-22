RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

local lastLogout = {}
local loggingOut = {} -- [src] = true while a logout is running
local lastCombat = {} -- [src] = os.time() of the last combat report from the client

AddEventHandler('playerDropped', function()
    lastLogout[source] = nil
    loggingOut[source] = nil
    lastCombat[source] = nil
end)

-- The client reports damage taken / weapon fire (at most every few seconds). A modified client can skip
-- reporting, so this only stops honest players from using /logout to leave a fight.
RegisterNetEvent('rsg-character:server:combatActivity', function()
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    lastCombat[src] = os.time()
end)

local function Notify(src, key, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('logout.title'),
        description = locale(key),
        type = ntype or 'error',
        duration = 5000,
    })
end

-- force = true skips the cooldown / dead checks (used by the LogoutToCharacterSelect export)
local function DoLogout(src, force)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if CreatorSessions[src] or loggingOut[src] then return end

    local now = os.time()
    local cooldown = RSG.Logout.Cooldown or 0
    if not force and lastLogout[src] and now - lastLogout[src] < cooldown then
        Notify(src, 'logout.cooldown')
        return
    end

    local meta = Player.PlayerData.metadata or {}
    if not force then
        if RSG.Logout.BlockWhenDead and (meta.isdead or meta.inlaststand) then
            Notify(src, 'logout.dead')
            return
        end
        if RSG.Logout.BlockWhenCuffed and meta.ishandcuffed then
            Notify(src, 'logout.cuffed')
            return
        end
        if RSG.Logout.BlockWhenJailed and (tonumber(meta.injail) or 0) > 0 then
            Notify(src, 'logout.jailed')
            return
        end
        local combatWindow = tonumber(RSG.Logout.CombatCooldown) or 0
        if combatWindow > 0 and lastCombat[src] and now - lastCombat[src] < combatWindow then
            Notify(src, 'logout.combat')
            return
        end
    end

    lastLogout[src] = now
    loggingOut[src] = true

    local charinfo = Player.PlayerData.charinfo or {}
    local citizenid = Player.PlayerData.citizenid

    -- fade the client out before anything is unloaded
    TriggerClientEvent('rsg-character:client:BeginLogout', src)
    Wait(1000)
    if not GetPlayerName(src) then loggingOut[src] = nil return end

    Player.Functions.Save()
    RSGCore.Player.Logout(src)
    Wait(500)
    loggingOut[src] = nil
    if not GetPlayerName(src) then return end

    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('character_logout', {
        title = locale('webhooks.character_logout.title'),
        description = locale('webhooks.character_logout.description',
            charinfo.firstname or locale('webhooks.common.unknown'), charinfo.lastname or '', citizenid or ''),
        fields = { identityFields[1], identityFields[2] },
    })

    TriggerEvent('rsg-character:server:characterLoggedOut', src, citizenid)
    TriggerClientEvent('rsg-character:client:OpenCharSelect', src)
end

RSG.DoLogout = DoLogout

if RSG.Logout and RSG.Logout.Enabled then
    RSGCore.Commands.Add(RSG.Logout.Command or 'logout', locale('logout.help'), {}, false, function(source)
        DoLogout(source)
    end)
end
