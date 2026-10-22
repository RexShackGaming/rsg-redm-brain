local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local cooldowns = {}

local function near(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - Config.ShopCoords) <= Config.InteractDistance
end

lib.callback.register('rsg-template:server:getData', function(source)
    local list = {}
    for name, cfg in pairs(Config.Items) do
        local item = RSGCore.Shared.Items[name]
        if item then list[#list + 1] = { id = name, label = item.label, price = cfg.price } end
    end
    return list
end)

RegisterNetEvent('rsg-template:server:select', function(itemName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    if cooldowns[src] and now - cooldowns[src] < 2 then return end
    cooldowns[src] = now

    local cfg, shared = Config.Items[itemName], RSGCore.Shared.Items[itemName]
    if type(itemName) ~= 'string' or not cfg or not shared or not near(src) then return end

    if not exports['rsg-inventory']:CanAddItem(src, itemName, 1) then
        return TriggerClientEvent('ox_lib:notify', src, { title = locale('ui_title'), description = locale('inventory_full'), type = 'error' })
    end
    if not Player.Functions.RemoveMoney('cash', cfg.price, 'rsg-template') then
        return TriggerClientEvent('ox_lib:notify', src, { title = locale('ui_title'), description = locale('not_enough_money'), type = 'error' })
    end
    exports['rsg-inventory']:AddItem(src, itemName, 1, nil, nil, 'rsg-template')
    TriggerClientEvent('ox_lib:notify', src, { title = locale('ui_title'), description = locale('bought_success', shared.label, cfg.price), type = 'success' })
end)

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)
