local RSGCore = exports['rsg-core']:GetCoreObject()
local robCooldowns = {}
local activeRobberies = {}

local function cleanupCooldowns()
    local now = GetGameTimer()
    for src, expiry in pairs(robCooldowns) do
        if expiry <= now then
            robCooldowns[src] = nil
        end
    end
end

RegisterNetEvent('rsg-robbery:server:robplayer', function(targetId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(tonumber(targetId))
    if not Player or not Target then return end

    if Player.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.not_cuffed'), type = 'error', duration = 5000 })
        return
    end

    if robCooldowns[src] and robCooldowns[src] > GetGameTimer() then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.cooldown'), type = 'error', duration = 5000 })
        return
    end

    local hasCuffs = Player.Functions.GetItemByName(Config.HandcuffItem)
    if not hasCuffs then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.need_cuffs'), type = 'error', duration = 5000 })
        return
    end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > Config.RobDistance then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.too_far'), type = 'error', duration = 5000 })
        return
    end

    if Target.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.already_cuffed'), type = 'error', duration = 5000 })
        return
    end

    if IsPedInAnyVehicle(targetPed) or IsPedInAnyVehicle(srcPed) then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.in_vehicle'), type = 'error', duration = 5000 })
        return
    end

    TriggerClientEvent('rsg-robbery:client:verifyhandsup', targetId, src)
end)

RegisterNetEvent('rsg-robbery:server:confirmrobbery', function(robberId)
    local targetSrc = source
    local Target = RSGCore.Functions.GetPlayer(targetSrc)
    local Player = RSGCore.Functions.GetPlayer(robberId)
    if not Player or not Target then return end

    if not Target.PlayerData.metadata.ishandcuffed then
        local srcPed = GetPlayerPed(robberId)
        local targetPed = GetPlayerPed(targetSrc)
        if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > Config.RobDistance then return end

        if Config.ConsumeHandcuffs then
            Player.Functions.RemoveItem(Config.HandcuffItem, 1)
        end

        robCooldowns[robberId] = GetGameTimer() + Config.RobCooldown
        cleanupCooldowns()

        Target.Functions.SetMetaData('ishandcuffed', true)
        TriggerClientEvent('rsg-robbery:client:getcuffed', targetSrc)

        TriggerClientEvent('RSGCore:Client:Notify', targetSrc, { title = locale('robbery.title'), description = locale('robbery.being_robbed'), type = 'error', duration = 7000 })
        TriggerClientEvent('RSGCore:Client:Notify', robberId, { title = locale('robbery.title'), description = locale('robbery.cuffing'), type = 'success', duration = 3000 })

        SetTimeout(1500, function()
            activeRobberies[robberId] = targetSrc
            exports['rsg-inventory']:OpenInventoryById(robberId, targetSrc)
        end)

        if Config.AutoUncuffTime > 0 then
            SetTimeout(Config.AutoUncuffTime, function()
                if not activeRobberies[robberId] then return end
                local TargetStill = RSGCore.Functions.GetPlayer(targetSrc)
                if TargetStill and TargetStill.PlayerData.metadata.ishandcuffed then
                    TargetStill.Functions.SetMetaData('ishandcuffed', false)
                    TriggerClientEvent('rsg-robbery:client:uncuffed', targetSrc)
                    TriggerClientEvent('RSGCore:Client:Notify', targetSrc, { title = locale('robbery.title'), description = locale('robbery.broke_free'), type = 'success', duration = 5000 })
                end
                activeRobberies[robberId] = nil
            end)
        end
    end
end)

RegisterNetEvent('rsg-inventory:server:closeInventory', function(inventory)
    local src = source
    local targetSrc = activeRobberies[src]
    if targetSrc then
        local Target = RSGCore.Functions.GetPlayer(targetSrc)
        if Target and Target.PlayerData.metadata.ishandcuffed then
            Target.Functions.SetMetaData('ishandcuffed', false)
            TriggerClientEvent('rsg-robbery:client:uncuffed', targetSrc)
            TriggerClientEvent('RSGCore:Client:Notify', targetSrc, { title = locale('robbery.title'), description = locale('robbery.uncuffed_you'), type = 'success', duration = 5000 })
            TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.uncuffed_other'), type = 'success', duration = 5000 })
        end
        activeRobberies[src] = nil
    end
end)

RegisterNetEvent('rsg-robbery:server:uncuffplayer', function(targetId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(tonumber(targetId))
    if not Player or not Target then return end

    if not Target.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.target_not_cuffed'), type = 'error', duration = 5000 })
        return
    end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > Config.CuffDistance then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.too_far'), type = 'error', duration = 5000 })
        return
    end

    Target.Functions.SetMetaData('ishandcuffed', false)
    TriggerClientEvent('rsg-robbery:client:uncuffed', targetId)
    TriggerClientEvent('RSGCore:Client:Notify', targetId, { title = locale('robbery.title'), description = locale('robbery.uncuffed_you'), type = 'success', duration = 5000 })
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.uncuffed_other'), type = 'success', duration = 5000 })
end)

RSGCore.Commands.Add('uncuff', locale('robbery.uncuff_self_help'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData.metadata.ishandcuffed then
        Player.Functions.SetMetaData('ishandcuffed', false)
        TriggerClientEvent('rsg-robbery:client:uncuffed', src)
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.broke_free'), type = 'success', duration = 5000 })
    else
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('robbery.title'), description = locale('robbery.not_cuffed'), type = 'error', duration = 5000 })
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for robberId, targetSrc in pairs(activeRobberies) do
        if robberId == src then
            local Target = RSGCore.Functions.GetPlayer(targetSrc)
            if Target and Target.PlayerData.metadata.ishandcuffed then
                Target.Functions.SetMetaData('ishandcuffed', false)
                TriggerClientEvent('rsg-robbery:client:uncuffed', targetSrc)
                TriggerClientEvent('RSGCore:Client:Notify', targetSrc, { title = locale('robbery.title'), description = locale('robbery.broke_free'), type = 'success', duration = 5000 })
            end
            activeRobberies[robberId] = nil
        elseif targetSrc == src then
            activeRobberies[robberId] = nil
        end
    end
end)
