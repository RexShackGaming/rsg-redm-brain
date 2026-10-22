-- rsg-huntingpets: Bird Server (rewritten - unified schema)
local RSGCore = exports['rsg-core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════
-- HUNT REWARD WHITELIST
-- Loot/XP awarded after a hunt is reported by the client, so build the set
-- of legitimate values from the config once at startup and check every
-- report against it instead of trusting whatever the client sends.
-- ═══════════════════════════════════════════════════════════
local ScavengerItemsByName = {}
for _, item in pairs(Config.ScavengerItems) do
    ScavengerItemsByName[item.name] = item
end

local ValidHuntXp = {}
local function RegisterHuntXp(xp)
    if xp and xp > 0 then ValidHuntXp[xp] = true end
end
for _, item in pairs(Config.ScavengerItems) do RegisterHuntXp(item.xp) end
for _, item in pairs(Config.FishItems) do RegisterHuntXp(item.xp) end
local function RegisterAreaPreyXp(areas)
    for _, area in pairs(areas) do
        local preyList = area[5]
        if type(preyList) == 'table' then
            for _, prey in pairs(preyList) do
                RegisterHuntXp(prey.xp)
            end
        end
    end
end
RegisterAreaPreyXp(Config.Areas)
RegisterAreaPreyXp(Config.Districts)
RegisterAreaPreyXp(Config.Districts2)

-- A hunt report (addxp / addscavengeditem) is only accepted for a short
-- window after the player actually started a hunt via checkhunt, so the
-- events can't be fired cold without ever going through the hunt flow.
local ActiveHunts = {}
local HuntWindowSeconds = (Config.BirdGoForHuntTimer or 0) + (Config.HuntingTimer or 0) + 15

local function HasActiveHuntWindow(src)
    local startedAt = ActiveHunts[src]
    return startedAt ~= nil and (os.time() - startedAt) <= HuntWindowSeconds
end

-- ═══════════════════════════════════════════════════════════
-- BUY BIRD (from NUI shop)
-- ═══════════════════════════════════════════════════════════
-- Look up a bird's authoritative price/model from the config so the client
-- can never dictate what it pays (was previously fully client-controlled).
local function GetBirdShopEntry(model, preset)
    local modelNum = tonumber(model)
    local presetNum = tonumber(preset) or 0
    for _, category in ipairs(Config.Birds) do
        for _, variant in ipairs(category.variants) do
            if tonumber(variant.model) == modelNum and variant.preset == presetNum then
                return variant
            end
        end
    end
    return nil
end

RegisterServerEvent('rsg-huntingpets:server:buyBird')
AddEventHandler('rsg-huntingpets:server:buyBird', function(model, preset)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local entry = GetBirdShopEntry(model, preset)
    if not entry then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_not_for_sale_bird'), duration = 5000, type = 'error'})
        return
    end
    local price = entry.price

    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_not_enough_money'), duration = 5000, type = 'error'})
        return
    end

    Player.Functions.RemoveMoney('cash', price)
    MySQL.insert('INSERT INTO player_birds (identifier, charid, model, preset, xp, price) VALUES (?, ?, ?, ?, 0, ?)', {cid, charid, tostring(entry.model), entry.preset, price})
    TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_bird_purchased'), duration = 5000, type = 'success'})
end)

-- ═══════════════════════════════════════════════════════════
-- SELL BIRD (by row id)
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:sellBird')
AddEventHandler('rsg-huntingpets:server:sellBird', function(birdId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local result = MySQL.query.await('SELECT * FROM player_birds WHERE id = ? AND identifier = ? AND charid = ?', {birdId, cid, charid})
    if result and result[1] then
        local sellPrice = math.floor(result[1].price * 0.5)
        MySQL.execute('DELETE FROM player_birds WHERE id = ?', {birdId})
        Player.Functions.AddMoney('cash', sellPrice)
        TriggerClientEvent('rsg-huntingpets:client:birdSold', src)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_bird_sold', sellPrice), duration = 5000, type = 'success'})
    end
end)

-- ═══════════════════════════════════════════════════════════
-- CALL BIRD (by row id - sends data to client to spawn)
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:callBird')
AddEventHandler('rsg-huntingpets:server:callBird', function(birdId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local result = MySQL.query.await('SELECT * FROM player_birds WHERE id = ? AND identifier = ? AND charid = ?', {birdId, cid, charid})
    if result and result[1] then
        local modelNum = tonumber(result[1].model)
        TriggerClientEvent('rsg-huntingpets:client:spawnBird', src, result[1].id, modelNum, result[1].preset, result[1].xp)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_no_bird_found'), duration = 5000, type = 'error'})
    end
end)

-- ═══════════════════════════════════════════════════════════
-- LOAD BIRD (callbird command - spawns selected bird)
-- ═══════════════════════════════════════════════════════════
RegisterServerEvent('rsg-huntingpets:server:loadBird')
AddEventHandler('rsg-huntingpets:server:loadBird', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local sel = MySQL.query.await('SELECT selected_bird FROM player_selected_pets WHERE identifier = ? AND charid = ?', {cid, charid})
    if not sel or not sel[1] or not sel[1].selected_bird then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_no_bird_selected'), duration = 5000, type = 'error'})
        return
    end

    local birdId = sel[1].selected_bird
    local result = MySQL.query.await('SELECT * FROM player_birds WHERE id = ? AND identifier = ? AND charid = ?', {birdId, cid, charid})
    if result and result[1] then
        local modelNum = tonumber(result[1].model)
        TriggerClientEvent('rsg-huntingpets:client:spawnBird', src, result[1].id, modelNum, result[1].preset, result[1].xp)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_pets'), description = locale('notif_bird_no_longer_exists'), duration = 5000, type = 'error'})
        MySQL.execute('UPDATE player_selected_pets SET selected_bird = NULL WHERE identifier = ? AND charid = ?', {cid, charid})
    end
end)

-- ═══════════════════════════════════════════════════════════
-- BIRD GAMEPLAY EVENTS (hunting, XP, scavenging)
-- ═══════════════════════════════════════════════════════════

-- Check if player job allows hunting
RegisterServerEvent("rsg-huntingpets:checkhunt")
AddEventHandler("rsg-huntingpets:checkhunt", function()
    local src = source
    if Config.Hunting.jobrequired then
        local User = RSGCore.Functions.GetPlayer(src)
        if not User then return end
        local u_job = User.PlayerData.job.name
        for _, v in pairs(Config.Hunting.jobs) do
            if u_job == v then
                ActiveHunts[src] = os.time()
                TriggerClientEvent("rsg-huntingpets:starthunt", src)
                return
            end
        end
        TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_hunting_birds'), description = Config.Texts.NoJob, duration = 5000, type = 'error'})
    else
        ActiveHunts[src] = os.time()
        TriggerClientEvent("rsg-huntingpets:starthunt", src)
    end
end)

-- Add XP to a bird
RegisterServerEvent('rsg-huntingpets:addxp')
AddEventHandler('rsg-huntingpets:addxp', function(xp, id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id
    local _xp = tonumber(xp)
    local _id = tonumber(id)
    if not _xp or not _id then return end

    -- Only accept an XP report that matches a real hunt reward and that
    -- follows an actual checkhunt call, instead of trusting the client's
    -- number outright (was previously unbounded).
    if not HasActiveHuntWindow(src) or not ValidHuntXp[_xp] then return end

    if Config.Hunting.extra_XP and Config.Hunting.jobs then
        for _, v in pairs(Config.Hunting.jobs) do
            if Player.PlayerData.job.name == v then
                _xp = _xp + Config.Hunting.extra_XP
                break
            end
        end
    end

    local result = MySQL.query.await('SELECT xp FROM player_birds WHERE id = ? AND identifier = ? AND charid = ?', {_id, cid, charid})
    if result and result[1] then
        local newxp = math.min(result[1].xp + _xp, Config.MaxBirdXP)
        MySQL.execute('UPDATE player_birds SET xp = ? WHERE id = ?', {newxp, _id})
    end
end)

-- Add scavenged item to player inventory
RegisterServerEvent('rsg-huntingpets:addscavengeditem')
AddEventHandler('rsg-huntingpets:addscavengeditem', function(name, am)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- The item name/amount must match a configured scavenger reward and can
    -- only be claimed after an actual checkhunt call. The client-supplied
    -- amount is ignored entirely - the configured amount is always used, so
    -- the client can no longer pick an arbitrary item or quantity.
    if not HasActiveHuntWindow(src) then return end
    local item = ScavengerItemsByName[tostring(name)]
    if not item then return end

    Player.Functions.AddItem(item.name, item.amount)
    TriggerClientEvent('ox_lib:notify', src, {title = locale('notif_title_hunting_birds'), description = Config.Texts.FoundScavItem, duration = 5000, type = 'success'})
end)

-- Check job for selling birds
RegisterServerEvent("rsg-huntingpets:check_sell")
AddEventHandler("rsg-huntingpets:check_sell", function()
    local src = source
    local User = RSGCore.Functions.GetPlayer(src)
    if User then
        local go = true
        if Config.SellingBirdJob then
            go = false
            for _, v in pairs(Config.SellingBirdJob) do
                if User.PlayerData.job.name == v then go = true break end
            end
        end
        if go then
            TriggerClientEvent("rsg-huntingpets:start_sell", src)
        else
        TriggerClientEvent('ox_lib:notify', src, {title = Config.Texts.Bird, description = Config.Texts.NoJob, duration = 5000, type = 'error'})
        end
    end
end)

-- Player-to-player bird selling (keep existing system)
local SellPoints = {}

AddEventHandler('playerDropped', function()
    local _source = source
    for i, v in pairs(SellPoints) do
        if v.owner == _source then
            TriggerClientEvent("rsg-huntingpets:sell:updatepoints", -1, nil, i, tonumber(v.pedid))
            SellPoints[i] = nil
        end
    end
end)

RegisterServerEvent("rsg-huntingpets:sell:create")
AddEventHandler("rsg-huntingpets:sell:create", function(id, price, coords, pid, pedid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id
    local _id = tonumber(id)
    local result = MySQL.query.await('SELECT * FROM player_birds WHERE id = ? AND identifier = ? AND charid = ?', {_id, cid, charid})
    if result and result[1] then
        SellPoints[_id] = result[1]
        SellPoints[_id].identifier = nil
        SellPoints[_id].charid = nil
        SellPoints[_id].sellprice = tonumber(price)
        SellPoints[_id].owner = src
        SellPoints[_id].sellcoords = coords
        SellPoints[_id].pedid = tonumber(pedid)
        TriggerClientEvent("rsg-huntingpets:sell:updatepoints", -1, SellPoints[_id], _id, nil)
    end
end)

RegisterServerEvent("rsg-huntingpets:sell:stop")
AddEventHandler("rsg-huntingpets:sell:stop", function(id)
    SellPoints[tonumber(id)] = nil
    TriggerClientEvent("rsg-huntingpets:sell:updatepoints1", -1, tonumber(id))
end)

RegisterServerEvent("rsg-huntingpets:sell:getpoints")
AddEventHandler("rsg-huntingpets:sell:getpoints", function()
    TriggerClientEvent("rsg-huntingpets:sell:gotpoints_c", source, SellPoints)
end)

RegisterServerEvent("rsg-huntingpets:sell:buyoffer")
AddEventHandler("rsg-huntingpets:sell:buyoffer", function(_owner, _price, _id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local charid = Player.PlayerData.id

    local sellData = SellPoints[tonumber(_id)]
    if not sellData then return end

    -- The price and the seller are read from the listing the server itself
    -- stored at `sell:create`, never from the buyer's own event parameters
    -- (which previously let a buyer name their own price and recipient).
    local owner = sellData.owner
    local price = tonumber(sellData.sellprice) or 0
    if owner == src then return end

    local OwnerPlayer = RSGCore.Functions.GetPlayer(owner)
    if not OwnerPlayer then
        TriggerClientEvent('ox_lib:notify', src, {title = Config.Texts.PlayerBuyBird, description = locale('notif_no_bird_found'), duration = 5000, type = 'error'})
        SellPoints[tonumber(_id)] = nil
        TriggerClientEvent("rsg-huntingpets:sell:updatepoints", -1, nil, tonumber(_id), tonumber(sellData.pedid))
        return
    end

    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('ox_lib:notify', src, {title = Config.Texts.PlayerBuyBird, description = Config.Texts.PlayerBuyNoMoney, duration = 5000, type = 'error'})
        TriggerClientEvent('ox_lib:notify', owner, {title = Config.Texts.PlayerBuyBird, description = Config.Texts.PlayerBuyNoMoneyAtBuyer, duration = 5000, type = 'error'})
        return
    end

    Player.Functions.RemoveMoney('cash', price)
    OwnerPlayer.Functions.AddMoney('cash', price)

    -- Transfer bird: delete from old owner, insert for new owner
    MySQL.execute('DELETE FROM player_birds WHERE id = ?', {tonumber(_id)})
    MySQL.insert('INSERT INTO player_birds (identifier, charid, model, preset, xp, price) VALUES (?, ?, ?, ?, ?, ?)', {
        cid, charid, tostring(sellData.model), sellData.preset, sellData.xp, sellData.price or 0
    })

    SellPoints[tonumber(_id)] = nil
    TriggerClientEvent("rsg-huntingpets:sell:finishsell", owner)
    TriggerClientEvent("rsg-huntingpets:sell:updatepoints", -1, nil, tonumber(_id), tonumber(sellData.pedid))
    TriggerClientEvent('ox_lib:notify', src, {title = Config.Texts.PlayerBuyBird, description = Config.Texts.PlayerBoughtBird, duration = 5000, type = 'success'})
    TriggerClientEvent('ox_lib:notify', owner, {title = Config.Texts.PlayerBuyBird, description = Config.Texts.PlayerSoldBird, duration = 5000, type = 'success'})
end)
