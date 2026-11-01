local RSGCore = exports['rsg-core']:GetCoreObject()

local ActiveDeliveries = {}
local LastDelivery = {}

local START_RADIUS = 30.0       -- player must be this close to the hub's cart spawn to start
local COMPLETE_RADIUS = 20.0    -- server-side tolerance for player / wagon at the drop-off
local FAIL_REASONS = { timeout = 'Timeout', damaged_wagon = 'Damaged Wagon', wagon_lost = 'Wagon Lost', player_died = 'Player Died' }

local function Notify(src, title, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = title, description = description, type = ntype, duration = 5000 })
end

local function Log(msg, ...)
    print(('^1[%s] ' .. msg .. '^7'):format(GetCurrentResourceName(), ...))
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
-- start: client only sends indexes, server resolves everything from Config
---------------------------------
local StartDelivery

RSGCore.Functions.CreateCallback('rsg-deliveries:server:startdelivery', function(src, cb, hubIndex, destIndex)
    cb(StartDelivery(src, hubIndex, destIndex))
end)

function StartDelivery(src, hubIndex, destIndex)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local location = Config.DeliveryLocations[tonumber(hubIndex)]
    local destination = location and location.deliveries[tonumber(destIndex)]
    if not destination then
        Log('Player %s sent an invalid delivery index', src)
        return false
    end

    if ActiveDeliveries[src] then
        Notify(src, locale('delivery_title'), locale('delivery_already_active'), 'error')
        return false
    end

    local last = LastDelivery[src]
    if Config.DeliveryCooldown > 0 and last and os.time() - last < Config.DeliveryCooldown then
        Notify(src, locale('delivery_title'), locale('delivery_cooldown', Config.DeliveryCooldown - (os.time() - last)), 'error')
        return false
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - location.cartSpawn.xyz) > START_RADIUS then
        Log('Player %s tried to start a delivery away from the hub', src)
        return false
    end

    local distance = GetRouteDistance(location, destination)
    local cash = CalculateCashReward(location, destination)

    ActiveDeliveries[src] = {
        destination = destination,
        cash = cash,
        distance = distance,
        startedAt = os.time(),
        expiry = os.time() + (Config.DefaultDeliveryTime * 60),
    }

    SendWebhook('Delivery Started', Player, {
        { name = 'Route', value = location.label .. ' → ' .. destination.label, inline = false },
        { name = 'Distance', value = ('%.2f km'):format(distance / 1000), inline = true },
        { name = 'Est. Reward', value = '$' .. cash, inline = true },
    })
    return true
end

local function DeleteDeliveryWagon(delivery)
    if not delivery or not delivery.netId then return end
    local wagon = NetworkGetEntityFromNetworkId(delivery.netId)
    if wagon ~= 0 and DoesEntityExist(wagon) then DeleteEntity(wagon) end
end

RegisterNetEvent('rsg-deliveries:server:setwagon', function(netId)
    local src = source
    local delivery = ActiveDeliveries[src]
    if not delivery or delivery.netId or type(netId) ~= 'number' then return end
    -- only accept the wagon model this contract spawned, near the player
    local wagon = NetworkGetEntityFromNetworkId(netId)
    if wagon == 0 or not DoesEntityExist(wagon) then return end
    if (GetEntityModel(wagon) & 0xFFFFFFFF) ~= (joaat(delivery.destination.wagonModel) & 0xFFFFFFFF) then
        Log('Player %s registered a wagon with the wrong model', src)
        return
    end
    if #(GetEntityCoords(wagon) - GetEntityCoords(GetPlayerPed(src))) > START_RADIUS then return end
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

RegisterNetEvent('rsg-deliveries:server:completedelivery', function()
    local src = source
    local delivery = ActiveDeliveries[src]
    if not delivery then return end
    ActiveDeliveries[src] = nil -- consume immediately so the event can't be replayed

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    if now > delivery.expiry then
        Log('Player %s tried to complete an expired delivery', src)
        DeleteDeliveryWagon(delivery)
        return
    end

    local endCoord = delivery.destination.deliveryLoc
    if #(GetEntityCoords(GetPlayerPed(src)) - endCoord) > COMPLETE_RADIUS then
        Log('Player %s tried to complete a delivery away from the drop-off', src)
        return
    end

    local minTime = delivery.distance / Config.MaxAverageSpeed
    if now - delivery.startedAt < minTime then
        Log('Player %s completed a %.0fm delivery in %ds (possible teleport)', src, delivery.distance, now - delivery.startedAt)
        return
    end

    if Config.RequireWagonAtDestination then
        local wagon = delivery.netId and NetworkGetEntityFromNetworkId(delivery.netId) or 0
        if wagon == 0 or not DoesEntityExist(wagon) or #(GetEntityCoords(wagon) - endCoord) > COMPLETE_RADIUS then
            Notify(src, locale('delivery_failed_title'), locale('delivery_failed_no_wagon'), 'error')
            LastDelivery[src] = now
            return
        end
    end

    LastDelivery[src] = now
    DeleteDeliveryWagon(delivery)

    if delivery.cash > 0 then
        Player.Functions.AddMoney('cash', delivery.cash, 'rsg-deliveries-complete')
    end

    local item = RollItemReward(delivery.destination.reward and delivery.destination.reward.itemreward)
    if item then
        if exports['rsg-inventory']:CanAddItem(src, item.name, item.amount) then
            exports['rsg-inventory']:AddItem(src, item.name, item.amount, nil, nil, 'rsg-deliveries-complete')
        else
            Notify(src, locale('delivery_title'), locale('inventory_full'), 'error')
            item = nil
        end
    end

    Notify(src, locale('delivery_success_title'), locale('delivery_success_desc', delivery.cash), 'success')

    local details = { { name = 'Cash Earned', value = '$' .. delivery.cash, inline = true } }
    if item then details[2] = { name = 'Item Earned', value = item.name .. ' x' .. item.amount, inline = true } end
    SendWebhook('Delivery Completed', Player, details)
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
    ActiveDeliveries[src] = nil
    LastDelivery[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, delivery in pairs(ActiveDeliveries) do DeleteDeliveryWagon(delivery) end
end)
