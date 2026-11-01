local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function serverNotify(src, key, nType, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = locale(key, ...), type = nType, duration = 5000,
    })
end

local function charName(src)
    local p = RSGCore.Functions.GetPlayer(src)
    local ci = p and p.PlayerData.charinfo
    if ci and ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    return GetPlayerName(src) or ('#' .. src)
end

local function getLicense(src)
    return GetPlayerIdentifierByType(src, 'license')
end

---------------------------------------------------------------------
-- Mute sources: a player is muted while ANY source (admin, rsg-prison, ...) holds a mute.
-- Enforced with MumbleSetPlayerMuted, so the client can't bypass it.
---------------------------------------------------------------------
local muteSources = {} -- [src] = { [reason] = true }

local function isPlayerMuted(src)
    return muteSources[src] ~= nil and next(muteSources[src]) ~= nil
end

local function setMuteSource(src, reason, state)
    if not GetPlayerName(src) then return false end
    local was = isPlayerMuted(src)
    muteSources[src] = muteSources[src] or {}
    muteSources[src][reason] = state and true or nil
    if next(muteSources[src]) == nil then muteSources[src] = nil end
    local now = isPlayerMuted(src)
    MumbleSetPlayerMuted(src, now)
    if now ~= was then TriggerClientEvent('rsg-voice:client:muteState', src, now) end
    return true
end

---------------------------------------------------------------------
-- Admin mutes (keyed by license, saved in rsg_voice_mutes)
---------------------------------------------------------------------
local adminMutes = {} -- [license] = { reason = str, expires = unix|nil }

local function activeMute(license)
    local m = license and adminMutes[license]
    if not m then return nil end
    if m.expires and m.expires <= os.time() then
        adminMutes[license] = nil
        MySQL.update('DELETE FROM rsg_voice_mutes WHERE license = ?', { license })
        return nil
    end
    return m
end

local function minutesLeft(m)
    return m.expires and math.max(1, math.ceil((m.expires - os.time()) / 60)) or 0
end

local function notifyMuted(src, m)
    if m.expires then
        serverNotify(src, 'cl_admin_muted_timed', 'error', minutesLeft(m), m.reason)
    else
        serverNotify(src, 'cl_admin_muted_reason', 'error', m.reason)
    end
end

local function applyAdminMute(src, silent)
    local m = activeMute(getLicense(src))
    setMuteSource(src, 'admin', m ~= nil)
    if m and not silent then notifyMuted(src, m) end
end

RSGCore.Commands.Add(Config.AdminMuteCommand, locale('sv_cmd_help'), {
    { name = 'id', help = locale('sv_cmd_id') },
    { name = 'minutes', help = locale('sv_cmd_minutes') },
    { name = 'reason', help = locale('sv_cmd_reason') },
}, false, function(source, args)
    local target = tonumber(args[1])
    local license = target and GetPlayerName(target) and getLicense(target)
    if not license then return serverNotify(source, 'sv_invalid_player', 'error') end

    local minutes, first = tonumber(args[2]), 3
    if not minutes then minutes, first = 0, 2 end
    minutes = math.max(0, math.min(math.floor(minutes), 525600)) -- cap at a year
    local reason = table.concat(args, ' ', first)
    if reason == '' then reason = locale('sv_no_reason') end
    reason = reason:sub(1, 255)

    local expires = minutes > 0 and (os.time() + minutes * 60) or nil
    local by = source > 0 and GetPlayerName(source) or 'console'
    adminMutes[license] = { reason = reason, expires = expires }
    MySQL.insert('INSERT INTO rsg_voice_mutes (license, reason, muted_by, expires_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE reason = VALUES(reason), muted_by = VALUES(muted_by), expires_at = VALUES(expires_at)',
        { license, reason, by, expires })

    applyAdminMute(target)
    if source > 0 then
        if expires then serverNotify(source, 'sv_muted_timed', 'inform', GetPlayerName(target), minutes)
        else serverNotify(source, 'sv_muted', 'inform', GetPlayerName(target)) end
    end
end, Config.AdminPermission)

RSGCore.Commands.Add(Config.AdminUnmuteCommand, locale('sv_unmute_help'), {
    { name = 'id', help = locale('sv_cmd_id') },
}, false, function(source, args)
    local target = tonumber(args[1])
    local license = target and GetPlayerName(target) and getLicense(target)
    if not license then return serverNotify(source, 'sv_invalid_player', 'error') end
    if not adminMutes[license] then
        return source > 0 and serverNotify(source, 'sv_not_muted', 'error', GetPlayerName(target)) or nil
    end
    adminMutes[license] = nil
    MySQL.update('DELETE FROM rsg_voice_mutes WHERE license = ?', { license })
    setMuteSource(target, 'admin', false)
    serverNotify(target, 'cl_admin_unmuted', 'success')
    if source > 0 then serverNotify(source, 'sv_unmuted', 'inform', GetPlayerName(target)) end
end, Config.AdminPermission)

RSGCore.Functions.CreateCallback('rsg-voice:server:isMuted', function(src, cb)
    applyAdminMute(src, true)
    cb(isPlayerMuted(src))
end)

-- Re-apply a stored mute on load, so a modified client that skips the callback still can't talk
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then applyAdminMute(src) end
end)

CreateThread(function()
    -- Create the table on first start (same as install.sql)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_voice_mutes` (
            `license`    VARCHAR(64)  NOT NULL,
            `reason`     VARCHAR(255) DEFAULT NULL,
            `muted_by`   VARCHAR(100) DEFAULT NULL,
            `expires_at` INT UNSIGNED DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`license`)
        )
    ]])
    local rows = MySQL.query.await('SELECT license, reason, expires_at FROM rsg_voice_mutes') or {}
    local now = os.time()
    for _, r in ipairs(rows) do
        if not r.expires_at or r.expires_at > now then
            adminMutes[r.license] = { reason = r.reason or locale('sv_no_reason'), expires = r.expires_at }
        end
    end
    MySQL.update('DELETE FROM rsg_voice_mutes WHERE expires_at IS NOT NULL AND expires_at <= ?', { now })
    for _, id in ipairs(GetPlayers()) do applyAdminMute(tonumber(id), true) end

    -- Lift expired mutes for online players
    while true do
        Wait(Config.MuteExpiryCheck * 1000)
        for _, id in ipairs(GetPlayers()) do
            id = tonumber(id)
            if muteSources[id] and muteSources[id].admin and not activeMute(getLicense(id)) then
                setMuteSource(id, 'admin', false)
                serverNotify(id, 'cl_mute_expired', 'success')
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(muteSources) do MumbleSetPlayerMuted(src, false) end
end)

---------------------------------------------------------------------
-- Server exports
---------------------------------------------------------------------
-- exports['rsg-voice']:SetPlayerMuted(src, true, 'prison')   (reason defaults to the calling resource)
exports('SetPlayerMuted', function(src, state, reason)
    src = tonumber(src)
    if not src then return false end
    reason = tostring(reason or GetInvokingResource() or 'script')
    if reason == 'admin' then return false end -- admin mutes only via the commands
    return setMuteSource(src, reason, state == true)
end)
exports('IsPlayerMuted', function(src) return isPlayerMuted(tonumber(src)) end)

---------------------------------------------------------------------
-- Riding party
---------------------------------------------------------------------
local P               = Config.Party
local parties         = {} -- [partyId] = { leader = src, members = { src, ... } }
local playerParty     = {} -- [src] = partyId

local function partyMembers(src)
    local id = playerParty[tonumber(src)]
    local party = id and parties[id]
    if not party then return nil end
    local list = {}
    for i, m in ipairs(party.members) do list[i] = m end
    return list, party.leader
end
exports('GetPartyMembers', partyMembers) -- returns { src, ... }, leaderSrc  (nil if not in a party)
exports('IsInParty', function(src) return playerParty[tonumber(src)] ~= nil end)

local function cleanupMute(src) muteSources[src] = nil end

if not P.Enabled then
    AddEventHandler('playerDropped', function() cleanupMute(source) end)
    return
end

local invites         = {} -- [targetSrc] = { party = partyId, from = src, expires = os.time() }
local nextId          = 0
local inviteCooldown  = {} -- [src] = GetGameTimer() when the next invite is allowed
local refreshCooldown = {} -- [src] = GetGameTimer() when getParty may run again
local waypointCooldown = {}
local INVITE_COOLDOWN  = 3000
local REFRESH_COOLDOWN = 750

local function memberIndex(party, src)
    for i, m in ipairs(party.members) do if m == src then return i end end
end

local function partyPayload(id)
    local party = parties[id]
    if not party then return nil end
    local list = {}
    for _, m in ipairs(party.members) do
        list[#list + 1] = { id = m, name = charName(m), leader = m == party.leader }
    end
    return { id = id, leader = party.leader, members = list, max = P.MaxMembers }
end

local function syncParty(id)
    local party = parties[id]
    if not party then return end
    local data = partyPayload(id)
    for _, m in ipairs(party.members) do
        TriggerClientEvent('rsg-voice:client:partyUpdate', m, data)
    end
end

local function dissolve(id, notifyKey)
    local party = parties[id]
    if not party then return end
    for _, m in ipairs(party.members) do
        playerParty[m] = nil
        TriggerClientEvent('rsg-voice:client:partyUpdate', m, nil)
        if notifyKey then serverNotify(m, notifyKey, 'inform') end
    end
    parties[id] = nil
end

local function removeFromParty(src, kicked)
    local id = playerParty[src]
    local party = id and parties[id]
    if not party then return end
    local idx = memberIndex(party, src)
    if idx then table.remove(party.members, idx) end
    playerParty[src] = nil
    TriggerClientEvent('rsg-voice:client:partyUpdate', src, nil)
    if GetPlayerName(src) then
        serverNotify(src, kicked and 'sv_party_kicked' or 'sv_party_left', kicked and 'error' or 'inform')
    end

    if #party.members <= 1 then return dissolve(id, 'sv_party_disbanded') end
    if party.leader == src then party.leader = party.members[1] end
    syncParty(id)
end

-- An invite creates a party of just the leader; drop it if nobody joined
local function disbandIfSolo(id)
    local party = parties[id]
    if not party or #party.members > 1 then return end
    local now = os.time()
    for _, inv in pairs(invites) do
        if inv.party == id and now <= inv.expires then return end -- still waiting on someone
    end
    dissolve(id)
end

local function isNear(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= P.InviteRange
end

RSGCore.Functions.CreateCallback('rsg-voice:server:getParty', function(src, cb)
    local now = GetGameTimer()
    if (refreshCooldown[src] or 0) > now then return cb(nil) end
    refreshCooldown[src] = now + REFRESH_COOLDOWN

    local list = {}
    local myParty = playerParty[src]
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src and (not myParty or playerParty[id] ~= myParty) and isNear(src, id) then
            list[#list + 1] = { id = id, name = charName(id), busy = playerParty[id] ~= nil }
        end
    end
    cb({ party = myParty and partyPayload(myParty) or nil, nearby = list, me = src })
end)

RegisterNetEvent('rsg-voice:server:partyInvite', function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return end
    local now = GetGameTimer()
    if (inviteCooldown[src] or 0) > now then return end
    inviteCooldown[src] = now + INVITE_COOLDOWN
    local pending = invites[target]
    if pending and os.time() <= pending.expires then
        if pending.from ~= src then serverNotify(src, 'sv_party_pending', 'error') end
        return -- no dialog spam / don't overwrite someone else's invite
    end
    if not isNear(src, target) then return serverNotify(src, 'sv_party_too_far', 'error') end
    if playerParty[target] then return serverNotify(src, 'sv_party_busy', 'error') end

    local id = playerParty[src]
    if id and parties[id].leader ~= src then return serverNotify(src, 'sv_party_not_leader', 'error') end
    if id and #parties[id].members >= P.MaxMembers then return serverNotify(src, 'sv_party_full', 'error') end
    if not id then
        nextId = nextId + 1
        id = nextId
        parties[id] = { leader = src, members = { src } }
        playerParty[src] = id
        syncParty(id)
    end

    invites[target] = { party = id, from = src, expires = os.time() + P.InviteTimeout }
    TriggerClientEvent('rsg-voice:client:partyInvite', target, charName(src), P.InviteTimeout)
    serverNotify(src, 'sv_party_invited', 'inform', charName(target))

    -- Ignored invites: clear them and drop the leader's empty party
    SetTimeout((P.InviteTimeout + 1) * 1000, function()
        local inv = invites[target]
        if inv and inv.party == id and os.time() > inv.expires then invites[target] = nil end
        disbandIfSolo(id)
    end)
end)

RegisterNetEvent('rsg-voice:server:partyRespond', function(accept)
    local src = source
    local inv = invites[src]
    invites[src] = nil
    if not inv then return end
    local party = parties[inv.party]
    if not party then return serverNotify(src, 'sv_party_expired', 'error') end
    if os.time() > inv.expires then
        serverNotify(src, 'sv_party_expired', 'error')
        return disbandIfSolo(inv.party)
    end
    if accept ~= true then
        if GetPlayerName(inv.from) then serverNotify(inv.from, 'sv_party_declined', 'inform', charName(src)) end
        return disbandIfSolo(inv.party)
    end
    if playerParty[src] then return disbandIfSolo(inv.party) end
    if #party.members >= P.MaxMembers then return serverNotify(src, 'sv_party_full', 'error') end

    party.members[#party.members + 1] = src
    playerParty[src] = inv.party
    for _, m in ipairs(party.members) do
        if m ~= src then serverNotify(m, 'sv_party_joined', 'success', charName(src)) end
    end
    syncParty(inv.party)
end)

RegisterNetEvent('rsg-voice:server:partyKick', function(target)
    local src = source
    target = tonumber(target)
    local id = playerParty[src]
    if not target or not id or parties[id].leader ~= src or target == src or playerParty[target] ~= id then return end
    removeFromParty(target, true)
end)

RegisterNetEvent('rsg-voice:server:partyLeave', function()
    removeFromParty(source, false)
end)

-- Waypoint sharing
RegisterNetEvent('rsg-voice:server:partyWaypoint', function(coords)
    local src = source
    if not P.Waypoint.Enabled then return end
    local id = playerParty[src]
    local party = id and parties[id]
    if not party or #party.members < 2 then return serverNotify(src, 'cl_not_in_party', 'error') end
    local now = GetGameTimer()
    if (waypointCooldown[src] or 0) > now then return serverNotify(src, 'cl_waypoint_cooldown', 'error') end
    waypointCooldown[src] = now + P.Waypoint.Cooldown * 1000

    local wp
    if type(coords) == 'table' or type(coords) == 'vector3' then
        local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z) or 0.0
        if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return end
        wp = { x = x, y = y, z = z }
    end
    local name = charName(src)
    for _, m in ipairs(party.members) do
        if m ~= src then TriggerClientEvent('rsg-voice:client:partyWaypoint', m, wp, name) end
    end
    serverNotify(src, wp and 'cl_waypoint_sent' or 'cl_waypoint_cleared', 'success')
end)

-- Member positions for map blips
if P.Blips.Enabled then
    CreateThread(function()
        while true do
            Wait(P.Blips.Interval)
            for _, party in pairs(parties) do
                if #party.members > 1 then
                    local list = {}
                    for _, m in ipairs(party.members) do
                        local ped = GetPlayerPed(m)
                        if ped ~= 0 then
                            local c = GetEntityCoords(ped)
                            list[#list + 1] = { id = m, x = c.x, y = c.y, z = c.z }
                        end
                    end
                    for _, m in ipairs(party.members) do
                        TriggerClientEvent('rsg-voice:client:partyPositions', m, list)
                    end
                end
            end
        end
    end)
end

local function cleanupPlayer(src)
    local inv = invites[src]
    invites[src] = nil
    inviteCooldown[src] = nil
    refreshCooldown[src] = nil
    waypointCooldown[src] = nil
    removeFromParty(src, false)
    if inv then disbandIfSolo(inv.party) end
end

AddEventHandler('playerDropped', function()
    local src = source
    cleanupPlayer(src)
    cleanupMute(src)
end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', cleanupPlayer)
