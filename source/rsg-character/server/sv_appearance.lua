RSGCore = exports['rsg-core']:GetCoreObject()

-- Server-side session state. The client can never open these on its own:
-- a creator session only exists after the server itself sent OpenCreator.
CreatorSessions = {}   -- [src] = { cid = number|nil, isNew = bool, created = bool }
local assignedBuckets = {} -- [src] = bucket this resource put the player in

local MAX_JSON_SIZE = 32768

---------------------------------------------------------------------------
-- Routing buckets
---------------------------------------------------------------------------
function RSG.SetPrivateBucket(src)
    local bucket = math.random(10000, 0xfffff)
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetPlayerRoutingBucket(src, bucket)
    assignedBuckets[src] = bucket
end

function RSG.ResetBucket(src)
    -- only ever undo a bucket this resource assigned, so players can't use
    -- this resource to escape instances created by other resources (jail etc.)
    if not assignedBuckets[src] then return end
    if GetPlayerRoutingBucket(src) == assignedBuckets[src] then
        SetPlayerRoutingBucket(src, 0)
    end
    assignedBuckets[src] = nil
end

local function IsNearClothingStore(src, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    for _, zone in ipairs(RSG.Zones1) do
        if #(coords - zone.fittingcoords.xyz) <= maxDist or #(coords - zone.promtcoords) <= maxDist then
            return true
        end
    end
    return false
end
RSG.IsNearClothingStore = IsNearClothingStore

-- Only used by the clothing store now: random = enter fitting room, otherwise leave it.
RegisterNetEvent('rsg-character:server:SetPlayerBucket', function(_, random)
    local src = source
    if random then
        if not RSGCore.Functions.GetPlayer(src) then return end
        if not IsNearClothingStore(src, 10.0) then return end
        RSG.SetPrivateBucket(src)
    elseif not CreatorSessions[src] then
        RSG.ResetBucket(src)
    end
end)

AddEventHandler('playerDropped', function()
    CreatorSessions[source] = nil
    assignedBuckets[source] = nil
end)

---------------------------------------------------------------------------
-- Creator sessions
---------------------------------------------------------------------------
function RSG.OpenCreatorFor(src, data)
    CreatorSessions[src] = { cid = data and data.cid, isNew = data ~= nil, created = false }
    RSG.SetPrivateBucket(src)
    TriggerClientEvent('rsg-character:client:OpenCreator', src, data, data == nil)
end

local function ValidateSkin(skin)
    if type(skin) ~= 'table' then return false end
    local count = 0
    for k, v in pairs(skin) do
        count = count + 1
        if count > 150 or type(k) ~= 'string' or #k > 32 then return false end
        local t = type(v)
        if t == 'table' then
            for k2, v2 in pairs(v) do
                if type(k2) ~= 'string' or type(v2) ~= 'number' then return false end
            end
        elseif t ~= 'number' then
            return false
        end
    end
    return true
end

RegisterNetEvent('rsg-character:server:SaveSkin', function(skin, clothes)
    local src = source
    local session = CreatorSessions[src]
    if not session then return end -- only valid at the end of a server-opened creator
    if session.isNew and not session.created then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not ValidateSkin(skin) or type(clothes) ~= 'table' then return end

    local gender = tonumber(Player.PlayerData.charinfo and Player.PlayerData.charinfo.gender) or 0
    skin.sex = gender == 1 and 2 or 1 -- trust the character record, not the client
    if not ValidateClothesData(clothes, gender == 0) then return end

    local encodedSkin, encodedClothes = json.encode(skin), json.encode(clothes)
    if #encodedSkin > MAX_JSON_SIZE or #encodedClothes > MAX_JSON_SIZE then return end

    local citizenid = Player.PlayerData.citizenid
    local affected = MySQL.update.await('UPDATE playerskins SET skin = ?, clothes = ? WHERE citizenid = ?', { encodedSkin, encodedClothes, citizenid })
    if not affected or affected == 0 then
        MySQL.insert.await('INSERT INTO playerskins (citizenid, skin, clothes) VALUES (?, ?, ?)', { citizenid, encodedSkin, encodedClothes })
    end

    -- first-time creation: store the chosen clothes as the protected "Default" wardrobe outfit
    if session.isNew then
        local hasDefault = MySQL.scalar.await('SELECT 1 FROM playeroutfit WHERE citizenid = ? AND is_default = 1 LIMIT 1', { citizenid })
        if not hasDefault then
            MySQL.insert.await('INSERT INTO playeroutfit (citizenid, name, clothes, is_default) VALUES (?, ?, ?, 1)', { citizenid, locale('default_outfit_name'), encodedClothes })
        end
    end

    local isNew = session.isNew
    CreatorSessions[src] = nil
    RSG.ResetBucket(src)
    TriggerClientEvent('rsg-character:client:OpenSpawnSelect', src, nil, isNew)

    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('appearance_saved', {
        title = locale('webhooks.appearance_saved.title_initial'),
        description = locale('webhooks.appearance_saved.description', citizenid),
        fields = {
            { name = locale('webhooks.appearance_saved.field_citizenid'), value = citizenid, inline = true },
            identityFields[1],
            identityFields[2],
        },
    })
end)

local function SafeDecode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
    return fallback
end

local function GetSkinRow(citizenid)
    return MySQL.single.await('SELECT skin, clothes FROM playerskins WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { citizenid })
end

-- Returns true when a skin was found and applied, false when the creator was opened instead.
function RSG.LoadSkinForSource(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local row = GetSkinRow(Player.PlayerData.citizenid)
    local skin = row and SafeDecode(row.skin)
    if skin then
        -- legacy rows (rsg-appearance) can have NULL/empty clothes: fall back to an empty table
        TriggerClientEvent('rsg-character:client:ApplySkin', src, skin, SafeDecode(row.clothes, {}))
        return true
    end
    RSG.OpenCreatorFor(src, nil)
    return false
end

RegisterNetEvent('rsg-character:server:LoadSkin', function()
    RSG.LoadSkinForSource(source)
end)

local function GetAppearance(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local row = GetSkinRow(Player.PlayerData.citizenid)
    local skin = row and SafeDecode(row.skin)
    if not skin then return nil end
    return { skin = skin, clothes = SafeDecode(row.clothes, {}) }
end

lib.callback.register('rsg-character:server:getAppearance', GetAppearance)

-- legacy name kept for external resources that still call it
RSGCore.Functions.CreateCallback('rsg-multicharacter:server:getAppearance', function(src, cb)
    cb(GetAppearance(src) or { skin = {}, clothes = {} })
end)

---------------------------------------------------------------------------
-- New character
---------------------------------------------------------------------------
local validNationality
local function IsValidNationality(value)
    if not validNationality then
        validNationality = {}
        -- The client builds the dropdown with the PLAYER's ox_lib language, which can
        -- differ from the server's language. Accept the translation from every locale
        -- file so players on any language can create a character.
        local resource = GetCurrentResourceName()
        local langs = { 'en', 'de', 'el', 'es', 'fr', 'ja', 'nl', 'pl', 'pt-br', 'ro' }
        for _, lang in ipairs(langs) do
            local raw = LoadResourceFile(resource, ('locales/%s.json'):format(lang))
            local ok, data = pcall(json.decode, raw or '')
            local list = ok and type(data) == 'table' and data.nationalities
            if type(list) == 'table' then
                for _, key in ipairs(RSG.Nationalities) do
                    if type(list[key]) == 'string' then
                        validNationality[list[key]] = true
                    end
                end
            end
        end
        -- Always include the server's own locale as a fallback
        for _, key in ipairs(RSG.Nationalities) do
            validNationality[locale('nationalities.' .. key)] = true
        end
    end
    return validNationality[value] == true
end

local function IsValidName(name)
    return type(name) == 'string' and #name >= 2 and #name <= 20
        and name:match('^%u%l+$') ~= nil and not RSG.ProfanityWords[name:lower()]
end

local function IsValidBirthdate(date)
    if type(date) ~= 'string' then return false end
    local y, m, d = date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    return y and y >= 1750 and y <= 1900 and m >= 1 and m <= 12 and d >= 1 and d <= 31
end

RegisterNetEvent('rsg-multicharacter:server:createCharacter', function(newData)
    local src = source
    local session = CreatorSessions[src]
    if not session or not session.isNew or session.created then return end
    if RSGCore.Functions.GetPlayer(src) then return end -- already logged in
    if type(newData) ~= 'table' then return end

    local cid = tonumber(newData.cid)
    if not cid or cid ~= session.cid then return end

    if not IsValidName(newData.firstname) or not IsValidName(newData.lastname)
        or not IsValidNationality(newData.nationality) or not IsValidBirthdate(newData.birthdate) then
        return
    end

    local license = RSGCore.Functions.GetIdentifier(src, 'license')
    if not license then return end

    if MySQL.scalar.await('SELECT citizenid FROM players WHERE license = ? AND cid = ?', { license, cid }) then
        CreatorSessions[src] = nil
        TriggerClientEvent('ox_lib:notify', src, { title = locale('charselect.slot_taken.title'), description = locale('charselect.slot_taken.desc'), type = 'error', duration = 5000 })
        TriggerClientEvent('rsg-character:client:OpenCharSelect', src)
        return
    end

    local gender = tonumber(newData.gender) == 1 and 1 or 0
    session.created = true

    RSGCore.Player.Login(src, nil, {
        cid = cid,
        charinfo = {
            firstname = newData.firstname,
            lastname = newData.lastname,
            nationality = newData.nationality,
            birthdate = newData.birthdate,
            gender = gender,
        }
    })

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        CreatorSessions[src] = nil
        return
    end

    for _, entry in ipairs(RSG.StarterItems or {}) do
        local itemName, amount = entry.item, tonumber(entry.amount) or 1
        if itemName and amount > 0 and RSGCore.Shared.Items[itemName] then
            exports['rsg-inventory']:AddItem(src, itemName, amount, nil, nil, 'rsg-character:starter-items')
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'add', amount)
        end
    end

    local identityFields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('character_created', {
        title = locale('webhooks.character_created.title'),
        description = locale('webhooks.character_created.description', newData.firstname, newData.lastname, cid),
        fields = {
            { name = locale('webhooks.character_created.field_citizenid'), value = Player.PlayerData.citizenid, inline = true },
            { name = locale('webhooks.character_created.field_gender'), value = gender == 0 and locale('webhooks.character_created.male') or locale('webhooks.character_created.female'), inline = true },
            { name = locale('webhooks.character_created.field_nationality'), value = newData.nationality, inline = true },
            { name = locale('webhooks.character_created.field_birthdate'), value = newData.birthdate, inline = true },
            identityFields[1],
            identityFields[2],
        },
    })
end)
