local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Commands.Add(Config.Command, locale('cmd_help'), {}, false, function(source)
    TriggerClientEvent('rsg-bandana:client:toggle', source)
end)

if Config.UseItem then
    if RSGCore.Shared.Items[Config.ItemName] then
        RSGCore.Functions.CreateUseableItem(Config.ItemName, function(source)
            TriggerClientEvent('rsg-bandana:client:toggle', source)
        end)
    else
        print('^3[rsg-bandana]^7 ' .. locale('item_missing', Config.ItemName))
    end
end
