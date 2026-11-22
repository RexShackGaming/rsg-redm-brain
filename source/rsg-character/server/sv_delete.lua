RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

-- Character deletion with a grace period.
--   RSG.Delete.SoftDelete = true : the character is hidden from character select for RSG.Delete.GraceDays,
--     staff can bring it back with /restorechar, and it is removed for good afterwards.
--   RSG.Delete.SoftDelete = false: the character is removed at once (the old behaviour).
-- A hidden character keeps its row in `players` but its `cid` is moved out of the slot range, so the slot is free
-- for a new character. The original slot is stored in rsg_character_deleted.

local CID_OFFSET = 1000
local DAY = 86400

function RSG.IsPendingDeletion(citizenid)
    if type(citizenid) ~= 'string' then return false end
    local ok, found = pcall(MySQL.scalar.await, 'SELECT 1 FROM rsg_character_deleted WHERE citizenid = ?', { citizenid })
    return ok and found ~= nil
end

-- removes everything this resource and rsg-core store for a character, for good
function RSG.HardDeleteCharacter(citizenid)
    if type(citizenid) ~= 'string' then return false end
    RSGCore.Player.ForceDeleteCharacter(citizenid)
    MySQL.update.await('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
    MySQL.update.await('DELETE FROM playeroutfit WHERE citizenid = ?', { citizenid })
    MySQL.update.await('DELETE FROM rsg_character_deleted WHERE citizenid = ?', { citizenid })
    RSG.RemoveCharacterName(citizenid)
    return true
end

-- hide a character for the grace period. Returns true, purgeAt
function RSG.SoftDeleteCharacter(citizenid, license)
    local cid = tonumber(MySQL.scalar.await('SELECT cid FROM players WHERE citizenid = ? AND license = ?', { citizenid, license }))
    if not cid then return false end
    local now = os.time()
    local purgeAt = now + math.max(1, (RSG.Delete.GraceDays or 7)) * DAY
    MySQL.insert.await(
        'INSERT INTO rsg_character_deleted (citizenid, license, original_cid, deleted_at, purge_at) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE purge_at = VALUES(purge_at)',
        { citizenid, license, cid, now, purgeAt })
    local moved = MySQL.update.await('UPDATE players SET cid = ? WHERE citizenid = ?', { cid + CID_OFFSET, citizenid })
    if not moved or moved == 0 then
        MySQL.update.await('DELETE FROM rsg_character_deleted WHERE citizenid = ?', { citizenid })
        return false
    end
    return true, purgeAt
end

-- bring a hidden character back into a free slot. Returns true, cid | false, reason ('not_found' | 'no_slot')
function RSG.RestoreCharacter(citizenid)
    local row = type(citizenid) == 'string'
        and MySQL.single.await('SELECT license, original_cid FROM rsg_character_deleted WHERE citizenid = ?', { citizenid })
    if not row then return false, 'not_found' end

    local maxSlots = RSG.GetMaxSlotsForLicense(row.license)
    local used = {}
    for _, r in ipairs(MySQL.query.await('SELECT cid FROM players WHERE license = ? AND citizenid <> ?', { row.license, citizenid }) or {}) do
        used[tonumber(r.cid) or 0] = true
    end
    local cid = tonumber(row.original_cid)
    if not cid or cid < 1 or cid > maxSlots or used[cid] then
        cid = nil
        for i = 1, maxSlots do
            if not used[i] then cid = i break end
        end
    end
    if not cid then return false, 'no_slot' end

    MySQL.update.await('UPDATE players SET cid = ? WHERE citizenid = ?', { cid, citizenid })
    MySQL.update.await('DELETE FROM rsg_character_deleted WHERE citizenid = ?', { citizenid })
    TriggerEvent('rsg-character:server:characterRestored', citizenid, row.license, cid)
    return true, cid
end

-- characters waiting for deletion: { citizenid, license, firstname, lastname, deleted_at, purge_at }[]
function RSG.GetDeletedCharacters(license)
    local rows
    if license then
        rows = MySQL.query.await('SELECT citizenid, license, deleted_at, purge_at FROM rsg_character_deleted WHERE license = ? ORDER BY purge_at', { license })
    else
        rows = MySQL.query.await('SELECT citizenid, license, deleted_at, purge_at FROM rsg_character_deleted ORDER BY purge_at')
    end
    rows = rows or {}
    for i = 1, #rows do
        local info = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { rows[i].citizenid })
        local ok, decoded = pcall(json.decode, info or '')
        decoded = ok and type(decoded) == 'table' and decoded or {}
        rows[i].firstname, rows[i].lastname = decoded.firstname or '?', decoded.lastname or ''
    end
    return rows
end

local function PurgeExpired()
    local rows = MySQL.query.await('SELECT citizenid, license FROM rsg_character_deleted WHERE purge_at <= ?', { os.time() }) or {}
    for _, row in ipairs(rows) do
        local info = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { row.citizenid })
        local ok, decoded = pcall(json.decode, info or '')
        decoded = ok and type(decoded) == 'table' and decoded or {}
        RSG.HardDeleteCharacter(row.citizenid)
        TriggerEvent('rsg-character:server:characterPurged', row.citizenid, row.license)
        RSG.SendWebhook('character_deleted', {
            title = locale('webhooks.character_purged.title'),
            description = locale('webhooks.character_purged.description',
                decoded.firstname or locale('webhooks.common.unknown'), decoded.lastname or '', row.citizenid),
        })
    end
    return #rows
end
RSG.PurgeDeletedCharacters = PurgeExpired

MySQL.ready(function()
    if not RSG.Delete or not RSG.Delete.SoftDelete then return end
    CreateThread(function()
        Wait(5000)
        while true do
            local ok, err = pcall(PurgeExpired)
            if not ok then print(('^1[rsg-character] purge of deleted characters failed: %s^7'):format(tostring(err))) end
            Wait(math.max(1, (RSG.Delete.PurgeInterval or 60)) * 60000)
        end
    end)
end)

exports('GetDeletedCharacters', function(license) return RSG.GetDeletedCharacters(license) end)
exports('RestoreCharacter', function(citizenid) return RSG.RestoreCharacter(citizenid) end)
exports('PurgeDeletedCharacters', function() return RSG.PurgeDeletedCharacters() end)

---------------------------------------------------------------------------
-- Admin commands: /restorechar [citizenid], /deletedchars [id]
---------------------------------------------------------------------------
local cfg = RSG.Delete
if not cfg or not cfg.SoftDelete then return end

local function Reply(src, description, ntype)
    if src == 0 then print(('[rsg-character] %s'):format(description)) return end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('admin.title'), description = description, type = ntype or 'inform', duration = 8000,
    })
end

RSGCore.Commands.Add(cfg.Restore or 'restorechar', locale('admin.restorechar_help'), {
    { name = 'citizenid', help = locale('admin.arg_citizenid') },
}, true, function(src, args)
    local citizenid = tostring(args[1] or '')
    local ok, result = RSG.RestoreCharacter(citizenid)
    if not ok then
        return Reply(src, result == 'no_slot' and locale('admin.restore_no_slot') or locale('admin.restore_not_found'), 'error')
    end
    Reply(src, locale('admin.restored', citizenid, result), 'success')
    if src ~= 0 then
        local fields = RSG.WebhookIdentityFields(src)
        RSG.SendWebhook('character_restored', {
            title = locale('webhooks.character_restored.title'),
            description = locale('webhooks.character_restored.description', citizenid, result),
            fields = { fields[1], fields[2] },
        })
    end
end, cfg.Permission or 'admin')

RSGCore.Commands.Add(cfg.List or 'deletedchars', locale('admin.deletedchars_help'), {
    { name = 'id', help = locale('admin.arg_id') },
}, false, function(src, args)
    local license
    if args[1] then
        local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]) or -1)
        if not Player then return Reply(src, locale('admin.player_not_found'), 'error') end
        license = Player.PlayerData.license or RSGCore.Functions.GetIdentifier(Player.PlayerData.source, 'license')
    end
    local rows = RSG.GetDeletedCharacters(license)
    if #rows == 0 then return Reply(src, locale('admin.deleted_none')) end
    local lines, now = {}, os.time()
    for i = 1, math.min(#rows, 8) do
        local r = rows[i]
        lines[#lines + 1] = locale('admin.deleted_line', r.citizenid, r.firstname, r.lastname,
            math.max(0, math.ceil((r.purge_at - now) / DAY)))
    end
    Reply(src, table.concat(lines, ' | '))
end, cfg.Permission or 'admin')
