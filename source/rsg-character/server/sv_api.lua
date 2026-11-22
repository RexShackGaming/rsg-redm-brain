RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

-- Public server API for other resources (documented in DOCS.md, "Developer API").
-- Clothing exports (SetClothes, AddOutfit, GetOutfits) live in sv_clothing.lua.

local function Decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return (ok and type(decoded) == 'table') and decoded or fallback
end

-- gender of a character, online or offline: 0 = male, 1 = female, nil = unknown citizenid
function RSG.GetGender(citizenid)
    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    local info = Player and Player.PlayerData.charinfo
    if not info then
        info = Decode(MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid }))
    end
    if not info or info.gender == nil then return nil end
    return tonumber(info.gender) == 1 and 1 or 0
end

-- delete a character's saved appearance and Default outfit: the creator opens on their next login
function RSG.ResetAppearance(citizenid)
    if type(citizenid) ~= 'string' then return false end
    MySQL.update.await('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
    MySQL.update.await('DELETE FROM playeroutfit WHERE citizenid = ? AND is_default = 1', { citizenid })
    TriggerEvent('rsg-character:server:appearanceReset', citizenid)
    return true
end

-- rename a character (online or offline). Returns ok, reason ('invalid_name' | 'name_taken' | 'not_found')
function RSG.ChangeName(citizenid, firstname, lastname)
    if type(citizenid) ~= 'string' then return false, 'not_found' end
    if not RSG.IsValidName(firstname) or not RSG.IsValidName(lastname) or RSG.IsReservedName(firstname, lastname) then return false, 'invalid_name' end
    if RSG.NameExists(firstname, lastname, citizenid) then return false, 'name_taken' end

    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        local charinfo = Player.PlayerData.charinfo
        charinfo.firstname, charinfo.lastname = firstname, lastname
        Player.Functions.SetPlayerData('charinfo', charinfo)
        Player.Functions.Save()
    else
        local info = Decode(MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid }))
        if not info then return false, 'not_found' end
        info.firstname, info.lastname = firstname, lastname
        MySQL.update.await('UPDATE players SET charinfo = ? WHERE citizenid = ?', { json.encode(info), citizenid })
    end
    RSG.SetCharacterName(citizenid, firstname, lastname)
    TriggerEvent('rsg-character:server:nameChanged', citizenid, firstname, lastname)
    return true
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

-- Character slots this player may use (RSG.MaxCharacterSlots + best RSG.SlotRules match)
exports('GetMaxSlots', function(src) return RSG.GetMaxSlots(src) end)

-- true while the player is inside a server-opened creator session
exports('IsInCreator', function(src) return CreatorSessions[src] ~= nil end)

-- true when no character uses this first + last name (always true if RSG.UniqueNames = false)
exports('IsNameAvailable', function(firstname, lastname)
    if type(firstname) ~= 'string' or type(lastname) ~= 'string' then return false end
    return not RSG.NameExists(firstname, lastname)
end)

-- { skin = {...}, clothes = {...} } for a citizenid (online or offline), or nil when none is saved
exports('GetAppearance', function(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    local row = MySQL.single.await('SELECT skin, clothes FROM playerskins WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { citizenid })
    local skin = row and Decode(row.skin)
    if not skin then return nil end
    return { skin = skin, clothes = Decode(row.clothes, {}) }
end)

exports('ResetAppearance', function(citizenid) return RSG.ResetAppearance(citizenid) end)
exports('ChangeCharacterName', function(citizenid, firstname, lastname) return RSG.ChangeName(citizenid, firstname, lastname) end)

-- Save + log out a logged-in player and send them to character select (ignores the /logout cooldown)
exports('LogoutToCharacterSelect', function(src)
    if not RSGCore.Functions.GetPlayer(src) then return false end
    CreateThread(function() RSG.DoLogout(src, true) end)
    return true
end)
