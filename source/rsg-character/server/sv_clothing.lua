RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

local MAX_JSON_SIZE = 32768
local MAX_OUTFITS = 30
local cooldowns = {}

local function Notify(src, title, description)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = description, type = 'error', duration = 5000 })
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

local function IsNearCloakroom(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, v in ipairs(RSG.Cloakroom) do
        if #(coords - v) <= 5.0 then return true end
    end
    return false
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
    local price = CalculatePrice(newClothes, current and json.decode(current) or {}, isMale)

    if price > 0 and not Player.Functions.RemoveMoney('cash', price, 'rsg-character:buy-clothes') then
        Notify(src, locale('insufficient_funds.title'), locale('insufficient_funds.description'))
        return
    end

    MySQL.update('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', { encoded, citizenid })

    -- every purchase is saved to the wardrobe; a blank/cancelled name gets an automatic one
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM playeroutfit WHERE citizenid = ? AND is_default = 0', { citizenid }) or 0
    if type(outfitName) == 'string' then
        outfitName = outfitName:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 40)
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
lib.callback.register('rsg-character:server:wearOutfit', function(src, id)
    id = tonumber(id)
    if not id or OnCooldown(src, 1000) then return nil end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not IsNearCloakroom(src) then return nil end

    local citizenid = Player.PlayerData.citizenid
    local clothes = MySQL.scalar.await('SELECT clothes FROM playeroutfit WHERE id = ? AND citizenid = ?', { id, citizenid })
    if not clothes then return nil end

    MySQL.update('UPDATE playerskins SET clothes = ? WHERE citizenid = ?', { clothes, citizenid })
    return json.decode(clothes)
end)

RegisterNetEvent('rsg-character:server:DeleteOutfit', function(id)
    local src = source
    id = tonumber(id)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not id then return end
    -- the Default outfit from character creation can never be deleted
    MySQL.update('DELETE FROM playeroutfit WHERE id = ? AND citizenid = ? AND is_default = 0', { id, Player.PlayerData.citizenid })
end)

lib.callback.register('rsg-character:server:LoadClothes', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {} end
    local clothes = MySQL.scalar.await('SELECT clothes FROM playerskins WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { Player.PlayerData.citizenid })
    return clothes and json.decode(clothes) or {}
end)

lib.callback.register('rsg-character:server:getOutfits', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {} end
    local rows = MySQL.query.await('SELECT id, name, clothes, is_default FROM playeroutfit WHERE citizenid = ? ORDER BY is_default DESC, id', { Player.PlayerData.citizenid }) or {}
    for i = 1, #rows do
        rows[i].clothes = json.decode(rows[i].clothes)
        rows[i].is_default = rows[i].is_default == 1 or rows[i].is_default == true
    end
    return rows
end)

-- Schema migration + backfill: adds is_default and gives existing characters a Default outfit
-- copied from what they are currently wearing. Safe to run on every start.
MySQL.ready(function()
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
