-- rsg-huntingpets: Dog Server (rewritten - unified schema)
local RSGCore = exports['rsg-core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════
-- SHOP DATA CALLBACK (returns owned dogs + birds for NUI)
-- ═══════════════════════════════════════════════════════════
RSGCore.Functions.CreateCallback('rsg-huntingpets:server:getShopData', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local dogs = MySQL.query.await('SELECT * FROM player_dogs WHERE identifier = ? AND charid = ?', {cid, charid}) or {}
    local birds = MySQL.query.await('SELECT * FROM player_birds WHERE identifier = ? AND charid = ?', {cid, charid}) or {}
    local sel = MySQL.query.await('SELECT selected_dog, selected_bird FROM player_selected_pets WHERE identifier = ? AND charid = ?', {cid, charid})
    local selectedDog = (sel and sel[1]) and sel[1].selected_dog or nil
    local selectedBird = (sel and sel[1]) and sel[1].selected_bird or nil

    cb({ ownedDogs = dogs, ownedBirds = birds, selectedDog = selectedDog, selectedBird = selectedBird })
end)

-- ═══════════════════════════════════════════════════════════
-- BUY DOG
-- ═══════════════════════════════════════════════════════════
-- Look up a dog breed's authoritative price from the config so the client
-- can never dictate what it pays (was previously fully client-controlled).
local function GetDogShopEntry(model)
    for _, dog in ipairs(Config.Dogs) do
        if dog.Param.Model == model then
            return dog
        end
    end
    return nil
end

RegisterServerEvent('rsg-huntingpets:server:buyDog')
AddEventHandler('rsg-huntingpets:server:buyDog', function(model)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local entry = GetDogShopEntry(model)
    if not entry then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_not_for_sale_dog'), duration = 5000, type = 'error'})
        return
    end
    local price = entry.Param.Price

    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_not_enough_money'), duration = 5000, type = 'error'})
        return
    end

    local skin = math.random(0, 2)
    Player.Functions.RemoveMoney('cash', price)
    MySQL.insert('INSERT INTO player_dogs (identifier, charid, model, preset, xp, price) VALUES (?, ?, ?, ?, 0, ?)', {cid, charid, entry.Param.Model, skin, price})
    TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_dog_purchased'), duration = 5000, type = 'success'})
end)

-- ═══════════════════════════════════════════════════════════
-- SELL DOG (by row id)
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:sellDog')
AddEventHandler('rsg-huntingpets:server:sellDog', function(dogId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local result = MySQL.query.await('SELECT * FROM player_dogs WHERE id = ? AND identifier = ? AND charid = ?', {dogId, cid, charid})
    if result and result[1] then
        local sellPrice = math.floor(result[1].price * 0.5)
        MySQL.execute('DELETE FROM player_dogs WHERE id = ?', {dogId})
        Player.Functions.AddMoney('cash', sellPrice)
        TriggerClientEvent('rsg-huntingpets:client:putawayDog', src)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_dog_sold', sellPrice), duration = 5000, type = 'success'})
    end
end)

-- ═══════════════════════════════════════════════════════════
-- CALL DOG (by row id - spawn on client)
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:callDog')
AddEventHandler('rsg-huntingpets:server:callDog', function(dogId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local result = MySQL.query.await('SELECT * FROM player_dogs WHERE id = ? AND identifier = ? AND charid = ?', {dogId, cid, charid})
    if result and result[1] then
        TriggerClientEvent('rsg-huntingpets:client:spawnDog', src, result[1].id, result[1].model, result[1].preset, false, result[1].xp)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_no_dog_found'), duration = 5000, type = 'error'})
    end
end)

-- ═══════════════════════════════════════════════════════════
-- FEED DOG
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:feedDog')
AddEventHandler('rsg-huntingpets:server:feedDog', function(dogId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local food = Player.Functions.GetItemByName(Config.AnimalFood)
    if not food then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_no_food'), duration = 5000, type = 'error'})
        return
    end

    -- Ownership + current XP are read from the DB, never trusted from the client
    local result = MySQL.query.await('SELECT xp FROM player_dogs WHERE id = ? AND identifier = ? AND charid = ?', {dogId, cid, charid})
    if not result or not result[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_dog_not_yours'), duration = 5000, type = 'error'})
        return
    end

    Player.Functions.RemoveItem(Config.AnimalFood, 1)
    local newXp = math.min(result[1].xp + Config.DogXpPerFeed, Config.DogFullGrownXp)
    MySQL.execute('UPDATE player_dogs SET xp = ? WHERE id = ?', {newXp, dogId})
    TriggerClientEvent('rsg-huntingpets:client:dogFed', src, newXp)
    TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_pet_fed', newXp, Config.DogFullGrownXp), duration = 5000, type = 'inform'})
end)

-- ═══════════════════════════════════════════════════════════
-- LOAD DOG (calldog command - spawns selected dog)
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:loadDog')
AddEventHandler('rsg-huntingpets:server:loadDog', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local sel = MySQL.query.await('SELECT selected_dog FROM player_selected_pets WHERE identifier = ? AND charid = ?', {cid, charid})
    if not sel or not sel[1] or not sel[1].selected_dog then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_no_dog_selected'), duration = 5000, type = 'error'})
        return
    end

    local dogId = sel[1].selected_dog
    local result = MySQL.query.await('SELECT * FROM player_dogs WHERE id = ? AND identifier = ? AND charid = ?', {dogId, cid, charid})
    if result and result[1] then
        TriggerClientEvent('rsg-huntingpets:client:spawnDog', src, result[1].id, result[1].model, result[1].preset, false, result[1].xp)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_dog_no_longer_exists'), duration = 5000, type = 'error'})
        MySQL.execute('UPDATE player_selected_pets SET selected_dog = NULL WHERE identifier = ? AND charid = ?', {cid, charid})
    end
end)

-- ═══════════════════════════════════════════════════════════
-- SELECT DOG (save selection to DB)
-- A callback (not a fire-and-forget event) so the NUI only updates its
-- "Selected" state once the server has actually confirmed and saved it.
-- ═══════════════════════════════════════════════════════════
RSGCore.Functions.CreateCallback('rsg-huntingpets:server:selectDog', function(source, cb, dogId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local owned = MySQL.query.await('SELECT id FROM player_dogs WHERE id = ? AND identifier = ? AND charid = ?', {dogId, cid, charid})
    if not owned or not owned[1] then cb(false) return end

    MySQL.execute('INSERT INTO player_selected_pets (identifier, charid, selected_dog) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE selected_dog = ?', {cid, charid, dogId, dogId})
    TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_dog_selected'), duration = 5000, type = 'success'})
    cb(true)
end)

-- ═══════════════════════════════════════════════════════════
-- SELECT BIRD (save selection to DB)
-- ═══════════════════════════════════════════════════════════
RSGCore.Functions.CreateCallback('rsg-huntingpets:server:selectBird', function(source, cb, birdId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local owned = MySQL.query.await('SELECT id FROM player_birds WHERE id = ? AND identifier = ? AND charid = ?', {birdId, cid, charid})
    if not owned or not owned[1] then cb(false) return end

    MySQL.execute('INSERT INTO player_selected_pets (identifier, charid, selected_bird) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE selected_bird = ?', {cid, charid, birdId, birdId})
    TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_bird_selected'), duration = 5000, type = 'success'})
    cb(true)
end)

-- ═══════════════════════════════════════════════════════════
-- GET PET DATA (for NUI My Pets detail panel)
-- ═══════════════════════════════════════════════════════════
RSGCore.Functions.CreateCallback('rsg-huntingpets:server:getPetData', function(source, cb, petName)
    cb({ health = 100, hungry = 100, thirst = 100, followDistance = 5, leftRightDistance = 0 })
end)
