-- Reference: secure server-side purchase/reward event (RSG + ox_lib + locales)
local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local cooldowns = {}
local COOLDOWN = 2 -- seconds

RegisterNetEvent('rsg-example:server:buyItem', function(itemName, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- rate limit
    local now = os.time()
    if cooldowns[src] and now - cooldowns[src] < COOLDOWN then return end
    cooldowns[src] = now

    -- validate input
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > 50 then return end
    local cfg = Config.Items[itemName]
    local shared = RSGCore.Shared.Items[itemName]
    if not cfg or not shared then return end

    -- server-side distance check
    local pcoords = GetEntityCoords(GetPlayerPed(src))
    if #(pcoords - Config.ShopCoords) > Config.InteractDistance then return end

    local total = cfg.price * amount
    if not exports['rsg-inventory']:CanAddItem(src, itemName, amount) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('shop_title'), description = locale('inventory_full'), type = 'error' })
        return
    end
    if not Player.Functions.RemoveMoney('cash', total, 'rsg-example-purchase') then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('shop_title'), description = locale('not_enough_money'), type = 'error' })
        return
    end

    exports['rsg-inventory']:AddItem(src, itemName, amount, nil, nil, 'rsg-example-purchase')
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('shop_title'),
        description = locale('bought_success', amount, shared.label, total),
        type = 'success',
    })
end)

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)
