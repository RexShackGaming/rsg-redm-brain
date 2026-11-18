RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

local MAX_JSON_SIZE = 32768
local MAX_OUTFITS = 30
local cooldowns = {}

local function Notify(src, title, description)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = description, type = 'error', duration = 5000 })
end

local function OnCooldown(src, ms)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < ms then return true end
    cooldowns[src] = now
    return false
end

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)

local function SafeDecode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return (ok and type(decoded) == 'table') and decoded or fallback
end

-- Wardrobe props (rsg-target) are map objects the server can't see, so when they are
-- enabled outfits can be worn anywhere. Saved outfits are already paid for, so this is safe.
local function CanUseWardrobe(src)
    if RSG.WardrobeTarget and RSG.WardrobeTarget.enabled then return true end
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, v in ipairs(RSG.Cloakroom) do
        if #(coords - v) <= 5.0 then return true end
    end
    return false
end

-- no markup or control characters: names are shown in the NUI wardrobe and webhook embeds
function RSG.SanitizeOutfitName(name)
    if type(name) ~= 'string' then return '' end
    return (name:gsub('[<>&"\'`%c]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 40))
end

local function IsMale(Player)
    return (tonumber(Player.PlayerData.charinfo and Player.PlayerData.charinfo.gender) or 0) == 0
end

RegisterNetEvent('rsg-character:server:saveOutfit', function(newClothes, _, outfitName)
    local src = source
    if OnCooldown(src, 2000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not RSG.IsNearClothingStore(src, 10.0) then return end

    local isMale = IsMale(Player)
    local valid, reason = ValidateClothesData(newClothes, isMale)
    if not valid then
        Notify(src, locale('clothing_validation.title'), reason)
        return
    end

    local encoded = json.encode(newClothes)
    if #encoded > MAX_JSON_SIZE then return end

    local citizenid = Player.PlayerData.citizenid
    local current = MySQL.scalar.await('SELECT clothes FROM playerskins WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { citizenid })
    local price = CalculatePrice(newClothes, SafeDecode(current, {}), isMale)

    if price > 0 and not Player.Functions.RemoveMoney('cash', price, 'rsg-character:buy-clothes') then
        Notify(src, locale('insufficient_funds.title'), locale('insufficient_funds.description'))
        return
    end

    MySQL.update('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', { encoded, citizenid })

    -- every purchase is saved to the wardrobe; a blank/cancelled name gets an automatic one
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM playeroutfit WHERE citizenid = ? AND is_default = 0', { citizenid }) or 0
    if type(outfitName) == 'string' then
        outfitName = RSG.SanitizeOutfitName(outfitName)
    else
        outfitName = ''
    end
    if outfitName == '' then
        outfitName = locale('auto_outfit_name', count + 1)
    end
    if count < MAX_OUTFITS then
        MySQL.insert('INSERT INTO playeroutfit (citizenid, name, clothes, is_default) VALUES (?, ?, ?, 0)', { citizenid, outfitName, encoded })
    else
        Notify(src, locale('clothing_validation.title'), locale('outfit_limit_reached', MAX_OUTFITS))
    end

    TriggerEvent('rsg-character:server:outfitPurchased', src, citizenid, price, outfitName)

    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('outfit_purchased', {
        title = locale('webhooks.outfit_purchased.title'),
        description = locale('webhooks.outfit_purchased.description', price),
        fields = {
            { name = locale('webhooks.outfit_purchased.field_citizenid'), value = citizenid, inline = true },
            { name = locale('webhooks.outfit_purchased.field_outfit_name'), value = outfitName, inline = true },
            identityFields[1],
            identityFields[2],
        },
    })
end)

-- Wear a saved outfit by id; returns the clothes to apply or nil.
RSGCore.Functions.CreateCallback('rsg-character:server:wearOutfit', function(src, cb, id)
    id = tonumber(id)
    if not id or OnCooldown(src, 1000) then return cb(nil) end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not CanUseWardrobe(src) then return cb(nil) end

    local citizenid = Player.PlayerData.citizenid
    local clothes = MySQL.scalar.await('SELECT clothes FROM playeroutfit WHERE id = ? AND citizenid = ?', { id, citizenid })
    local decoded = SafeDecode(clothes)
    -- re-validate: rows written by older versions or by hand must still be real clothing for this gender
    if not decoded or not ValidateClothesData(decoded, IsMale(Player)) then return cb(nil) end
    MySQL.update('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', { clothes, citizenid })
    cb(decoded)
end)

RegisterNetEvent('rsg-character:server:DeleteOutfit', function(id)
    local src = source
    id = tonumber(id)
    if not id or OnCooldown(src, 1000) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    -- the Default outfit from character creation can never be deleted
    MySQL.update('DELETE FROM playeroutfit WHERE id = ? AND citizenid = ? AND is_default = 0', { id, Player.PlayerData.citizenid })
end)

-- Share a saved outfit with a nearby player. The receiver must accept; the copy is re-validated for their body type.
local shareCooldown, sharePending = {}, {}

local function ShareNotify(src, key, ntype, ...)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('labels.share'), description = locale(key, ...), type = ntype or 'error', duration = 5000,
    })
end

AddEventHandler('playerDropped', function()
    shareCooldown[source] = nil
    sharePending[source] = nil
end)

RegisterNetEvent('rsg-character:server:ShareOutfit', function(outfitId, targetSrc)
    local src = source
    local cfg = RSG.OutfitSharing
    if not cfg or not cfg.Enabled then return end
    outfitId, targetSrc = tonumber(outfitId), tonumber(targetSrc)
    if not outfitId or not targetSrc or targetSrc == src then return end

    local now = os.time()
    if shareCooldown[src] and now - shareCooldown[src] < (cfg.Cooldown or 10) then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetSrc)
    if not Player or not Target then return ShareNotify(src, 'outfit_share.no_player') end
    if sharePending[targetSrc] then return ShareNotify(src, 'outfit_share.busy') end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc)))
    if dist > (cfg.MaxDistance or 4.0) then return ShareNotify(src, 'outfit_share.too_far') end

    local row = MySQL.single.await('SELECT name, clothes FROM playeroutfit WHERE id = ? AND citizenid = ?', { outfitId, Player.PlayerData.citizenid })
    local decoded = row and SafeDecode(row.clothes)
    if not decoded or IsMale(Player) ~= IsMale(Target) or not ValidateClothesData(decoded, IsMale(Target)) then
        return ShareNotify(src, 'outfit_share.failed')
    end

    shareCooldown[src] = now
    sharePending[targetSrc] = true
    ShareNotify(src, 'outfit_share.sent', 'inform')

    local senderName = ('%s %s'):format(Player.PlayerData.charinfo.firstname or '', Player.PlayerData.charinfo.lastname or '')
    local accepted = RSGCore.Functions.AwaitClientCallback('rsg-character:client:confirmShare', targetSrc, (cfg.AcceptTimeout or 15) * 1000, senderName, row.name)
    sharePending[targetSrc] = nil

    if not accepted then return ShareNotify(src, 'outfit_share.declined') end

    -- the world may have changed while the prompt was open: re-check everything
    Target = RSGCore.Functions.GetPlayer(targetSrc)
    if not Target or not GetPlayerName(src) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > (cfg.MaxDistance or 4.0) * 2 then
        return ShareNotify(src, 'outfit_share.too_far')
    end
    local targetCid = Target.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM playeroutfit WHERE citizenid = ? AND is_default = 0', { targetCid }) or 0
    if count >= MAX_OUTFITS then
        ShareNotify(src, 'outfit_share.failed')
        return ShareNotify(targetSrc, 'outfit_share.failed')
    end

    MySQL.insert.await('INSERT INTO playeroutfit (citizenid, name, clothes, is_default) VALUES (?, ?, ?, 0)', { targetCid, row.name, row.clothes })
    TriggerEvent('rsg-character:server:outfitShared', src, targetSrc, outfitId)
    ShareNotify(src, 'outfit_share.done_sender', 'success')
    ShareNotify(targetSrc, 'outfit_share.done_target', 'success')
end)

RSGCore.Functions.CreateCallback('rsg-character:server:LoadClothes', function(src, cb)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb({}) end
    local clothes = MySQL.scalar.await('SELECT clothes FROM playerskins WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { Player.PlayerData.citizenid })
    cb(SafeDecode(clothes, {}))
end)

RSGCore.Functions.CreateCallback('rsg-character:server:getOutfits', function(src, cb)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb({}) end
    local rows = MySQL.query.await('SELECT id, name, clothes, is_default FROM playeroutfit WHERE citizenid = ? ORDER BY is_default DESC, id', { Player.PlayerData.citizenid }) or {}
    for i = 1, #rows do
        rows[i].clothes = SafeDecode(rows[i].clothes, {})
        rows[i].is_default = rows[i].is_default == 1 or rows[i].is_default == true
    end
    cb(rows)
end)

-- Schema migration + backfill: adds is_default and gives existing characters a Default outfit
-- copied from what they are currently wearing. Safe to run on every start.
MySQL.ready(function()
    if RSG.AutoDatabase and not RSG.EnsureDatabase() then return end
    MySQL.query.await('ALTER TABLE playeroutfit ADD COLUMN IF NOT EXISTS is_default TINYINT(1) NOT NULL DEFAULT 0')
    local added = MySQL.update.await([[
        INSERT INTO playeroutfit (citizenid, name, clothes, is_default)
        SELECT s.citizenid, ?, s.clothes, 1 FROM playerskins s
        WHERE s.clothes IS NOT NULL AND s.clothes <> '' AND s.clothes <> '[]' AND s.clothes <> '{}'
          AND NOT EXISTS (SELECT 1 FROM playeroutfit o WHERE o.citizenid = s.citizenid AND o.is_default = 1)
    ]], { locale('default_outfit_name') })
    if added and added > 0 then
        print(('[rsg-character] created Default outfits for %s existing characters'):format(added))
    end
end)

---------------------------------------------------------------------------
-- Public server API (see DOCS.md, "Developer API")
---------------------------------------------------------------------------

-- Wear clothes on an online player. clothes = { [category] = { hash = n }, ... }.
-- save = true also stores them as the character's current clothes (free, no outfit row).
-- Returns ok, reason ('no_player' | 'invalid_clothes' | 'too_large')
exports('SetClothes', function(src, clothes, save)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false, 'no_player' end
    if not ValidateClothesData(clothes, IsMale(Player)) then return false, 'invalid_clothes' end
    local encoded = json.encode(clothes)
    if #encoded > MAX_JSON_SIZE then return false, 'too_large' end
    if save then
        MySQL.update.await('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', { encoded, Player.PlayerData.citizenid })
    end
    TriggerClientEvent('rsg-character:client:ApplyClothes', src, clothes)
    return true
end)

-- Add a saved outfit to a character's wardrobe (online or offline).
-- Returns the new outfit id, or nil + reason ('no_character' | 'invalid_clothes' | 'limit_reached')
exports('AddOutfit', function(citizenid, name, clothes)
    if type(citizenid) ~= 'string' then return nil, 'no_character' end
    local gender = RSG.GetGender(citizenid)
    if gender == nil then return nil, 'no_character' end
    if not ValidateClothesData(clothes, gender == 0) then return nil, 'invalid_clothes' end
    local encoded = json.encode(clothes)
    if #encoded > MAX_JSON_SIZE then return nil, 'invalid_clothes' end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM playeroutfit WHERE citizenid = ? AND is_default = 0', { citizenid }) or 0
    if count >= MAX_OUTFITS then return nil, 'limit_reached' end
    name = RSG.SanitizeOutfitName(name)
    if name == '' then name = locale('auto_outfit_name', count + 1) end
    return MySQL.insert.await('INSERT INTO playeroutfit (citizenid, name, clothes, is_default) VALUES (?, ?, ?, 0)', { citizenid, name, encoded })
end)

-- Saved outfits of a character: { id, name, clothes, is_default }[] (Default first)
exports('GetOutfits', function(citizenid)
    if type(citizenid) ~= 'string' then return {} end
    local rows = MySQL.query.await('SELECT id, name, clothes, is_default FROM playeroutfit WHERE citizenid = ? ORDER BY is_default DESC, id', { citizenid }) or {}
    for i = 1, #rows do
        rows[i].clothes = SafeDecode(rows[i].clothes, {})
        rows[i].is_default = rows[i].is_default == 1 or rows[i].is_default == true
    end
    return rows
end)
