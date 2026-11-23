local RSGCore = exports['rsg-core']:GetCoreObject()

local ActiveDeliveries = {}
local ReturnOffers = {} -- src -> { netId, hubIndex, destination, baseCash, distance, fragile, region, society, expires }
local LastDelivery = {}

local START_RADIUS = 30.0       -- player must be this close to the hub's cart spawn to start
local COMPLETE_RADIUS = 20.0    -- server-side tolerance for player / wagon at the drop-off
local EXPIRY_GRACE = 15         -- seconds of slack: the client timer starts after the wagon spawns, the server's at the callback
local WAGON_REGISTER_TIMEOUT = 10000 -- ms the server waits for a freshly spawned wagon to sync before giving up
local FAIL_REASONS = { timeout = 'Timeout', damaged_wagon = 'Damaged Wagon', wagon_lost = 'Wagon Lost', player_died = 'Player Died' }

local function Notify(src, title, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = description, type = ntype, duration = 5000 })
end

local function Log(msg, ...)
    print(('^1[%s] ' .. msg .. '^7'):format(GetCurrentResourceName(), ...))
end

local function Started(resource)
    return GetResourceState(resource) == 'started'
end

---Calls an export of an optional resource without ever throwing. Returns ok, result.
local function CallExport(resource, fn, ...)
    if not Started(resource) then return false end
    local exp = exports[resource]
    return pcall(function(...) return exp[fn](exp, ...) end, ...)
end

local function SendWebhook(eventType, player, details)
    if not SvConfig.Webhook.url or SvConfig.Webhook.url == '' then return end

    local charinfo = player.PlayerData.charinfo
    local fields = {
        { name = 'Event', value = eventType, inline = true },
        { name = 'Player', value = charinfo.firstname .. ' ' .. charinfo.lastname, inline = true },
        { name = 'Identifier', value = player.PlayerData.citizenid, inline = false },
    }
    for _, field in ipairs(details or {}) do fields[#fields + 1] = field end

    PerformHttpRequest(SvConfig.Webhook.url, function() end, 'POST', json.encode({
        embeds = {{
            title = SvConfig.Webhook.title,
            color = SvConfig.Webhook.color,
            fields = fields,
            footer = { text = SvConfig.Webhook.footer },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }}
    }), { ['Content-Type'] = 'application/json' })
end

---------------------------------
-- rsg-skills: register the teamster skill, read its perks
---------------------------------
local function RegisterSkill()
    if not Config.Skills.Enabled then return end
    CallExport('rsg-skills', 'RegisterSkill', Config.Skills.Skill, Config.Skills.Definition)
end

RegisterSkill()
AddEventHandler('rsg-skills:server:ready', RegisterSkill) -- again if rsg-skills restarts

local function GetPerk(src, perk)
    if not Config.Skills.Enabled then return 0 end
    local ok, value = CallExport('rsg-skills', 'GetPerk', src, Config.Skills.Skill, perk)
    return ok and tonumber(value) or 0
end

---------------------------------
-- wagons
---------------------------------
local function DeleteDeliveryWagon(delivery)
    if not delivery or not delivery.netId then return end
    local wagon = NetworkGetEntityFromNetworkId(delivery.netId)
    if wagon ~= 0 and DoesEntityExist(wagon) then DeleteEntity(wagon) end
end

---Resolves a net id to the contract's wagon. Returns the entity, or nil plus the reason it was rejected.
---The wagon must exist on the server and match the contract's model; with checkCreator it must also
---have been created by this player (used when the net id was not registered at the start).
local function GetContractWagon(src, delivery, netId, checkCreator)
    if type(netId) ~= 'number' then return nil, 'no net id' end
    local wagon = NetworkGetEntityFromNetworkId(netId)
    if not wagon or wagon == 0 or not DoesEntityExist(wagon) then return nil, 'not synced to the server' end
    if (GetEntityModel(wagon) & 0xFFFFFFFF) ~= (joaat(delivery.destination.wagonModel) & 0xFFFFFFFF) then
        return nil, 'wrong model'
    end
    if checkCreator and NetworkGetFirstEntityOwner and NetworkGetFirstEntityOwner(wagon) ~= src then
        return nil, 'not spawned by this player'
    end
    return wagon
end

---------------------------------
-- return trips: the wagon is kept for a short time after a delivery so it can carry a load back
---------------------------------
local function ExpireOffer(src, silent)
    local offer = ReturnOffers[src]
    if not offer then return end
    ReturnOffers[src] = nil
    DeleteDeliveryWagon(offer)
    if not silent then
        Notify(src, locale('delivery_title'), locale('delivery_return_expired'), 'inform')
    end
end

---------------------------------
-- start: client only sends indexes, server resolves everything from Config
---------------------------------
local function CanUseHub(Player, location)
    local required = location.job
    if not required then return true end
    local job = Player.PlayerData.job
    if not job then return false end
    local grade = job.grade and job.grade.level or 0
    for _, name in ipairs(type(required) == 'table' and required or { required }) do
        if job.name == name and grade >= (location.minGrade or 0) then return true end
    end
    return false
end

local function StartDelivery(src, hubIndex, destIndex)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    hubIndex, destIndex = tonumber(hubIndex), tonumber(destIndex)
    local location = hubIndex and Config.DeliveryLocations[hubIndex]
    local destination = location and destIndex and location.deliveries[destIndex]
    if not destination then
        Log('Player %s sent an invalid delivery index', src)
        Notify(src, locale('delivery_title'), locale('delivery_rejected'), 'error')
        return false
    end

    if ActiveDeliveries[src] then
        Notify(src, locale('delivery_title'), locale('delivery_already_active'), 'error')
        return false
    end

    if not CanUseHub(Player, location) then
        Notify(src, locale('delivery_title'), locale('delivery_job_locked'), 'error')
        return false
    end

    local last = LastDelivery[src]
    if Config.DeliveryCooldown > 0 and last and os.time() - last < Config.DeliveryCooldown then
        Notify(src, locale('delivery_title'), locale('delivery_cooldown', Config.DeliveryCooldown - (os.time() - last)), 'error')
        return false
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - location.cartSpawn.xyz) > START_RADIUS then
        Log('Player %s tried to start a delivery away from the hub', src)
        Notify(src, locale('delivery_title'), locale('delivery_too_far_hub'), 'error')
        return false
    end

    ExpireOffer(src, true) -- taking a new contract forfeits an open return load

    local distance = GetRouteDistance(location, destination)
    local baseCash = CalculateCashReward(location, destination)
    local seconds = math.floor(Config.DefaultDeliveryTime * 60 * (1 + GetPerk(src, 'time_bonus') / 100))
    local hot = Config.HotRoute.Enabled and GetHotRouteIndex(hubIndex, #location.deliveries) == destIndex
    local fragile = Config.Fragile.Enabled and destination.fragile == true
    local now = os.time()

    ActiveDeliveries[src] = {
        hubIndex = hubIndex,
        hubLabel = location.label,
        region = Config.Reputation and Config.Reputation.Regions[location.label],
        econRegion = Config.Economy.Regions[location.label],
        society = location.society,
        noReturn = location.noReturn,
        cartSpawn = location.cartSpawn.xyz,
        destination = destination,
        baseCash = baseCash,
        distance = distance,
        fragile = fragile,
        hot = hot,
        startedAt = now,
        expiry = now + seconds + EXPIRY_GRACE,
    }

    SendWebhook('Delivery Started', Player, {
        { name = 'Route', value = location.label .. ' → ' .. destination.label, inline = false },
        { name = 'Distance', value = ('%.2f km'):format(distance / 1000), inline = true },
        { name = 'Base Reward', value = '$' .. baseCash, inline = true },
    })
    return { seconds = seconds, fragile = fragile }
end

RSGCore.Functions.CreateCallback('rsg-deliveries:server:startdelivery', function(src, cb, hubIndex, destIndex)
    cb(StartDelivery(src, hubIndex, destIndex))
end)

RegisterNetEvent('rsg-deliveries:server:setwagon', function(netId)
    local src = source
    local delivery = ActiveDeliveries[src]
    if not delivery or delivery.netId or delivery.registering or type(netId) ~= 'number' then return end
    delivery.registering = true

    -- the client sends this right after CreateVehicle, usually before the entity has
    -- reached the server, so keep trying for a few seconds instead of giving up
    local wagon, reason
    local deadline = GetGameTimer() + WAGON_REGISTER_TIMEOUT
    repeat
        wagon, reason = GetContractWagon(src, delivery, netId, true)
        if wagon or reason ~= 'not synced to the server' then break end
        Wait(250)
    until GetGameTimer() > deadline or ActiveDeliveries[src] ~= delivery

    delivery.registering = nil
    if ActiveDeliveries[src] ~= delivery then return end -- cancelled / failed while waiting

    if not wagon then
        Log('Player %s: delivery wagon (net id %s) was not registered: %s', src, netId, reason)
        return
    end
    if #(GetEntityCoords(wagon) - GetEntityCoords(GetPlayerPed(src))) > START_RADIUS then
        Log('Player %s: delivery wagon was not registered: too far from the player', src)
        return
    end
    for otherSrc, other in pairs(ActiveDeliveries) do
        if other ~= delivery and other.netId == netId then
            Log('Player %s: delivery wagon was not registered: already used by player %s', src, otherSrc)
            return
        end
    end
    delivery.netId = netId
end)

---------------------------------
-- complete
---------------------------------
local function RollItemReward(itemreward)
    if not itemreward or not itemreward.activation then return nil end
    if not RSGCore.Shared.Items[itemreward.itemname] then
        Log('Item reward "%s" does not exist in shared items', tostring(itemreward.itemname))
        return nil
    end
    if itemreward.chance and math.random() > itemreward.chance then return nil end

    local amount = itemreward.itemamount
    if type(amount) == 'table' then amount = math.random(amount[1], amount[2]) end
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return nil end
    return { name = itemreward.itemname, amount = amount }
end

---Ends a completion the server refused: logs it, removes the wagon, starts the cooldown and tells the player.
local function RejectCompletion(src, delivery, localeKey, logMsg, ...)
    Log(logMsg, src, ...)
    DeleteDeliveryWagon(delivery)
    LastDelivery[src] = os.time()
    Notify(src, locale('delivery_failed_title'), locale(localeKey), 'error')
    TriggerClientEvent('rsg-deliveries:client:finished', src, false)
end

---Works out the final cash for a delivery. Everything here is server side: the client only
---ever reports "I arrived", never an amount, a health value or a streak.
---@return integer cash, table info
local function ComputePayout(src, Player, delivery, wagon, now)
    local cash = delivery.baseCash
    local info = { streak = 0, streakPct = 0 }

    if delivery.fragile then
        local pct = 0.0
        if wagon then
            local maxHealth = GetEntityMaxHealth(wagon)
            if maxHealth > 0 then pct = math.max(0.0, math.min(1.0, GetEntityHealth(wagon) / maxHealth)) end
        end
        local minPay = Config.Fragile.MinPayPct / 100
        cash = cash * (minPay + (1.0 - minPay) * pct)
        info.health = math.floor(pct * 100)
    end

    local bonusPct = GetPerk(src, 'pay_bonus')
    if not delivery.isReturn then
        if delivery.hot then
            bonusPct = bonusPct + Config.HotRoute.BonusPct
            info.hot = true
        end
        local streak, streakPct = Stats.NextStreak(Player.PlayerData.citizenid, now)
        info.streak, info.streakPct = streak, streakPct
        bonusPct = bonusPct + streakPct
    end
    if delivery.ambushWon and Config.Ambush.Enabled then
        bonusPct = bonusPct + Config.Ambush.BonusPct
        info.ambushPct = Config.Ambush.BonusPct
    end
    cash = cash * (1 + bonusPct / 100)

    cash = math.min(math.floor(cash + 0.5), Config.MaxPayoutAmount)

    -- rsg-economy: pay what a 'sell' quote for the hub's town says (tax goes to the treasury)
    if Config.Economy.Enabled and delivery.econRegion and cash > 0 then
        local ok, quote = CallExport('rsg-economy', 'Quote', src, { region = delivery.econRegion, mode = 'sell', base = cash, qty = 1 })
        if ok and type(quote) == 'table' and tonumber(quote.total) then
            info.quote = quote
            cash = math.min(math.floor(quote.total), Config.MaxPayoutAmount)
        end
    end
    return math.max(0, cash), info
end

---rsg-society: the company account either earns a cut or pays the driver. Returns the cash the server must pay.
local function SettleSociety(src, delivery, cash)
    if not (delivery.society and Config.Society.Enabled and Started('rsg-society')) or cash <= 0 then return cash end
    CallExport('rsg-society', 'EnsureJobSociety', delivery.society)

    if Config.Society.PayFromSociety then
        local ok, paid = CallExport('rsg-society', 'RemoveMoney', delivery.society, cash, 'rsg-deliveries payout')
        if ok and paid then return cash end
        Notify(src, locale('delivery_title'), locale('delivery_society_broke'), 'error')
        return Config.Society.FallbackToServer and cash or 0
    end

    local cut = math.floor(cash * Config.Society.Cut / 100)
    if cut > 0 then CallExport('rsg-society', 'AddMoney', delivery.society, cut, 'rsg-deliveries company cut') end
    return cash
end

RegisterNetEvent('rsg-deliveries:server:completedelivery', function(clientNetId)
    local src = source
    local delivery = ActiveDeliveries[src]
    if not delivery then return end
    ActiveDeliveries[src] = nil -- consume immediately so the event can't be replayed

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    if now > delivery.expiry then
        return RejectCompletion(src, delivery, 'delivery_failed_timeout', 'Player %s tried to complete an expired delivery')
    end

    local endCoord = delivery.destination.deliveryLoc
    if #(GetEntityCoords(GetPlayerPed(src)) - endCoord) > COMPLETE_RADIUS then
        return RejectCompletion(src, delivery, 'delivery_rejected', 'Player %s tried to complete a delivery away from the drop-off')
    end

    if now - delivery.startedAt < delivery.distance / Config.MaxAverageSpeed then
        return RejectCompletion(src, delivery, 'delivery_rejected', 'Player %s completed a %.0fm delivery in %ds (possible teleport)', delivery.distance, now - delivery.startedAt)
    end

    local wagon
    if Config.RequireWagonAtDestination then
        -- normally the wagon registered at the start; if that never landed, fall back to the
        -- net id sent with the completion (still validated: model, creator and position)
        local netId = delivery.netId or clientNetId
        local reason
        wagon, reason = GetContractWagon(src, delivery, netId, not delivery.netId)
        if wagon and #(GetEntityCoords(wagon) - endCoord) > COMPLETE_RADIUS then
            wagon, reason = nil, ('%.0fm from the drop-off'):format(#(GetEntityCoords(wagon) - endCoord))
        end
        if not wagon then
            return RejectCompletion(src, delivery, 'delivery_failed_no_wagon', 'Player %s: delivery rejected, wagon check failed (%s)', reason)
        end
        delivery.netId = netId
    elseif delivery.netId then
        wagon = GetContractWagon(src, delivery, delivery.netId, false) -- best effort, for fragile health and return trips
    end

    LastDelivery[src] = now

    local cash, info = ComputePayout(src, Player, delivery, wagon, now)
    local payout = SettleSociety(src, delivery, cash)
    if payout > 0 then
        Player.Functions.AddMoney('cash', payout, 'rsg-deliveries-complete')
        if info.quote then CallExport('rsg-economy', 'Record', src, info.quote) end
    end

    -- teamster skill XP
    if Config.Skills.Enabled and not delivery.isReturn then
        local xp = math.floor(Config.Skills.XPBase + Config.Skills.XPPerKm * delivery.distance / 1000)
        if xp > 0 then CallExport('rsg-skills', 'AddXP', src, Config.Skills.Skill, xp, 'delivery') end
    end

    -- statistics, streak and leaderboard
    local charinfo = Player.PlayerData.charinfo
    Stats.Record(Player.PlayerData.citizenid, charinfo.firstname .. ' ' .. charinfo.lastname, delivery.distance, payout, info.streak > 0 and info.streak or Stats.Get(Player.PlayerData.citizenid).streak, now)

    -- rsg-reputation (optional): standing in the town the delivery started from
    if not delivery.isReturn and Config.Reputation and Config.Reputation.Enabled and Started('rsg-reputation') then
        CallExport('rsg-reputation', 'ApplyAction', src, Config.Reputation.Action, delivery.region)
    end

    local item
    if not delivery.isReturn then
        item = RollItemReward(delivery.destination.reward and delivery.destination.reward.itemreward)
        if item then
            if exports['rsg-inventory']:CanAddItem(src, item.name, item.amount) then
                exports['rsg-inventory']:AddItem(src, item.name, item.amount, nil, nil, 'rsg-deliveries-complete')
            else
                Notify(src, locale('delivery_title'), locale('inventory_full'), 'error')
                item = nil
            end
        end
    end

    Notify(src, locale('delivery_success_title'), locale('delivery_success_desc', payout), 'success')
    if info.streakPct > 0 then
        Notify(src, locale('delivery_title'), locale('delivery_streak', info.streak, info.streakPct), 'inform')
    end
    if info.ambushPct then
        Notify(src, locale('delivery_title'), locale('delivery_ambush_bonus', info.ambushPct), 'inform')
    end

    -- return trip: keep the wagon for a short while instead of deleting it
    local offered = false
    if Config.ReturnTrips.Enabled and not delivery.isReturn and not delivery.noReturn and wagon then
        offered = true
        local offer = {
            netId = delivery.netId, hubIndex = delivery.hubIndex, hubLabel = delivery.hubLabel,
            destination = delivery.destination, cartSpawn = delivery.cartSpawn, baseCash = delivery.baseCash,
            distance = delivery.distance, fragile = delivery.fragile, econRegion = delivery.econRegion,
            society = delivery.society, expires = now + Config.ReturnTrips.OfferTime,
        }
        ReturnOffers[src] = offer
        SetTimeout((Config.ReturnTrips.OfferTime + 2) * 1000, function()
            if ReturnOffers[src] == offer then ExpireOffer(src) end
        end)
        Notify(src, locale('delivery_title'), locale('delivery_return_offer', Config.ReturnTrips.OfferTime, math.floor(delivery.baseCash * Config.ReturnTrips.PayPct / 100 + 0.5)), 'inform')
    else
        DeleteDeliveryWagon(delivery)
    end
    TriggerClientEvent('rsg-deliveries:client:finished', src, offered, Config.ReturnTrips.OfferTime)

    local details = {
        { name = 'Cash Earned', value = '$' .. payout .. (delivery.isReturn and ' (return trip)' or ''), inline = true },
        { name = 'Streak', value = tostring(info.streak), inline = true },
    }
    if item then details[#details + 1] = { name = 'Item Earned', value = item.name .. ' x' .. item.amount, inline = true } end
    if info.health then details[#details + 1] = { name = 'Wagon Health', value = info.health .. '%', inline = true } end
    if info.hot then details[#details + 1] = { name = 'Hot Route', value = 'yes', inline = true } end
    if info.ambushPct then details[#details + 1] = { name = 'Ambush Survived', value = 'yes', inline = true } end
    SendWebhook('Delivery Completed', Player, details)
end)

---------------------------------
-- return trip: accept / decline
---------------------------------
RSGCore.Functions.CreateCallback('rsg-deliveries:server:acceptreturn', function(src, cb)
    local Player = RSGCore.Functions.GetPlayer(src)
    local offer = ReturnOffers[src]
    if not Player or not offer or os.time() > offer.expires then
        if offer then ExpireOffer(src) else Notify(src, locale('delivery_title'), locale('delivery_return_none'), 'error') end
        return cb(false)
    end
    if ActiveDeliveries[src] then return cb(false) end

    local origin = offer.destination.deliveryLoc
    local wagon, reason = GetContractWagon(src, offer, offer.netId, false)
    if not wagon or #(GetEntityCoords(wagon) - origin) > COMPLETE_RADIUS or #(GetEntityCoords(GetPlayerPed(src)) - origin) > COMPLETE_RADIUS * 2 then
        Log('Player %s: return trip refused (%s)', src, reason or 'wagon or player not at the drop-off')
        ExpireOffer(src, true)
        Notify(src, locale('delivery_title'), locale('delivery_rejected'), 'error')
        return cb(false)
    end

    ReturnOffers[src] = nil
    local seconds = math.floor(Config.DefaultDeliveryTime * 60 * (1 + GetPerk(src, 'time_bonus') / 100))
    local now = os.time()
    ActiveDeliveries[src] = {
        isReturn = true,
        hubIndex = offer.hubIndex,
        hubLabel = offer.hubLabel,
        econRegion = offer.econRegion,
        society = offer.society,
        destination = { label = offer.hubLabel, deliveryLoc = offer.cartSpawn, wagonModel = offer.destination.wagonModel },
        baseCash = math.floor(offer.baseCash * Config.ReturnTrips.PayPct / 100 + 0.5),
        distance = offer.distance,
        fragile = offer.fragile,
        netId = offer.netId,
        startedAt = now,
        expiry = now + seconds + EXPIRY_GRACE,
    }
    cb({ seconds = seconds, fragile = offer.fragile, endCoords = offer.cartSpawn, label = offer.hubLabel })
end)

RegisterNetEvent('rsg-deliveries:server:declinereturn', function()
    ExpireOffer(source, true)
end)

---------------------------------
-- rsg-ambush hooks (local server events, not reachable from clients)
---------------------------------
AddEventHandler('rsg-ambush:server:ambushStarted', function(src)
    local delivery = ActiveDeliveries[src]
    if delivery and Config.Ambush.Enabled then delivery.ambushed = true end
end)

AddEventHandler('rsg-ambush:server:ambushWon', function(src)
    local delivery = ActiveDeliveries[src]
    if delivery and delivery.ambushed then delivery.ambushWon = true end
end)

---Used by rsg-ambush: multiplies its trigger chance while the player carries a contract.
exports('GetAmbushMultiplier', function(src)
    if Config.Ambush.Enabled and ActiveDeliveries[src] then return Config.Ambush.ChanceMultiplier end
    return 1.0
end)

---------------------------------
-- cancel / fail
---------------------------------
local function EndDelivery(src, label)
    local delivery = ActiveDeliveries[src]
    if not delivery then return end
    ActiveDeliveries[src] = nil
    LastDelivery[src] = os.time() -- cooldown also applies to cancel/fail (stops wagon spawn spam)
    DeleteDeliveryWagon(delivery)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then SendWebhook(label, Player) end
end

RegisterNetEvent('rsg-deliveries:server:canceldelivery', function()
    EndDelivery(source, 'Delivery Cancelled')
end)

RegisterNetEvent('rsg-deliveries:server:faildelivery', function(reason)
    EndDelivery(source, ('Delivery Failed (%s)'):format(FAIL_REASONS[reason] or 'Unknown'))
end)

AddEventHandler('playerDropped', function()
    local src = source
    DeleteDeliveryWagon(ActiveDeliveries[src])
    ExpireOffer(src, true)
    ActiveDeliveries[src] = nil
    LastDelivery[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, delivery in pairs(ActiveDeliveries) do DeleteDeliveryWagon(delivery) end
    for _, offer in pairs(ReturnOffers) do DeleteDeliveryWagon(offer) end
end)
