RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

local function SafeDecode(value)
    if not value then return nil end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or nil
end

local function GetCharacterSlots(license)
    local maxSlots = RSG.MaxCharacterSlots or 4
    local slots = {}
    for i = 1, maxSlots do
        slots[i] = { cid = i, exists = false }
    end

    local rows = MySQL.query.await([[
        SELECT p.citizenid, p.cid, p.charinfo, p.job, p.money, s.skin, s.clothes
        FROM players p
        LEFT JOIN playerskins s ON s.citizenid = p.citizenid
        WHERE p.license = ?
    ]], { license }) or {}

    for _, row in ipairs(rows) do
        local cid = tonumber(row.cid)
        if cid and cid >= 1 and cid <= maxSlots then
            local info = SafeDecode(row.charinfo) or {}
            local money = SafeDecode(row.money)
            slots[cid] = {
                cid = cid,
                exists = true,
                citizenid = row.citizenid,
                firstname = info.firstname,
                lastname = info.lastname,
                gender = info.gender,
                nationality = info.nationality,
                birthdate = info.birthdate,
                job = SafeDecode(row.job),
                cash = money and tonumber(money.cash) or 0,
                skin = SafeDecode(row.skin),
                clothes = SafeDecode(row.clothes),
            }
        end
    end

    return slots
end

local function OwnsCharacter(license, citizenid)
    if type(citizenid) ~= 'string' then return false end
    local owner = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { citizenid })
    return owner ~= nil and owner == license
end

local function SendSlots(src)
    local license = RSGCore.Functions.GetIdentifier(src, 'license')
    if not license then
        TriggerClientEvent('rsg-character:client:CharSelectFailed', src)
        return
    end
    TriggerClientEvent('rsg-character:client:ReceiveCharacterSlots', src, GetCharacterSlots(license))
end

RegisterNetEvent('rsg-character:server:RequestCharacterSlots', function()
    local src = source
    if RSGCore.Functions.GetPlayer(src) then return end -- character select is only for logged-out players
    CreatorSessions[src] = nil
    RSG.SetPrivateBucket(src)

    if RSGCore.Functions.GetIdentifier(src, 'license') then
        SendSlots(src)
    else
        -- identifiers can lag a moment behind the first request on connect
        SetTimeout(1500, function()
            if GetPlayerName(src) then SendSlots(src) end
        end)
    end
end)

RegisterNetEvent('rsg-character:server:SelectCharacterSlot', function(citizenid)
    local src = source
    if RSGCore.Functions.GetPlayer(src) then return end

    local license = RSGCore.Functions.GetIdentifier(src, 'license')
    if not license or type(citizenid) ~= 'string' then
        TriggerClientEvent('rsg-character:client:CharSelectFailed', src)
        return
    end

    if not OwnsCharacter(license, citizenid) then
        DropPlayer(src, locale('charselect.exploit_dropped'))
        return
    end

    if not RSGCore.Player.Login(src, citizenid) then
        TriggerClientEvent('rsg-character:client:CharSelectFailed', src)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        TriggerClientEvent('rsg-character:client:CharSelectFailed', src)
        return
    end

    local charinfo = Player.PlayerData.charinfo or {}
    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('character_selected', {
        title = locale('webhooks.character_selected.title'),
        description = locale('webhooks.character_selected.description',
            charinfo.firstname or locale('webhooks.common.unknown'), charinfo.lastname or '', citizenid
        ),
        fields = { identityFields[1], identityFields[2] },
    })

    -- no saved skin -> the creator opens instead and SaveSkin sends the spawn select afterwards
    if not RSG.LoadSkinForSource(src) then return end

    RSG.ResetBucket(src)

    local pos = Player.PlayerData.position
    local isValidPos = type(pos) == 'table'
        and tonumber(pos.x) and tonumber(pos.y) and tonumber(pos.z)
        and (math.abs(pos.x) > 1.0 or math.abs(pos.y) > 1.0 or math.abs(pos.z) > 1.0)

    TriggerClientEvent('rsg-character:client:OpenSpawnSelect', src, isValidPos and pos or nil)
end)

RegisterNetEvent('rsg-character:server:DeleteCharacterSlot', function(citizenid)
    local src = source
    if RSGCore.Functions.GetPlayer(src) then return end

    local license = RSGCore.Functions.GetIdentifier(src, 'license')
    if not license or not OwnsCharacter(license, citizenid) then return end

    local charRow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    local info = charRow and SafeDecode(charRow.charinfo) or {}

    RSGCore.Player.DeleteCharacter(src, citizenid)
    MySQL.update('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
    MySQL.update('DELETE FROM playeroutfit WHERE citizenid = ?', { citizenid })

    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('character_deleted', {
        title = locale('webhooks.character_deleted.title'),
        description = locale('webhooks.character_deleted.description',
            info.firstname or locale('webhooks.common.unknown'), info.lastname or '', citizenid),
        fields = { identityFields[1], identityFields[2] },
    })

    Wait(300)
    SendSlots(src)
end)

RegisterNetEvent('rsg-character:server:RequestCreateCharacterSlot', function(cid, selectedSex)
    local src = source
    if RSGCore.Functions.GetPlayer(src) then return end

    local license = RSGCore.Functions.GetIdentifier(src, 'license')
    cid = tonumber(cid)
    if not license or not cid or cid < 1 or cid > (RSG.MaxCharacterSlots or 4) or cid % 1 ~= 0 then
        TriggerClientEvent('rsg-character:client:CharSelectFailed', src)
        return
    end

    selectedSex = tonumber(selectedSex) == 2 and 2 or 1

    if MySQL.scalar.await('SELECT citizenid FROM players WHERE license = ? AND cid = ?', { license, cid }) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('charselect.slot_taken.title'), description = locale('charselect.slot_taken.desc'), type = 'error', duration = 5000 })
        SendSlots(src)
        return
    end

    RSG.OpenCreatorFor(src, { cid = cid, selectedSex = selectedSex })
end)
