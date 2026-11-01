local RSGCore = exports['rsg-core']:GetCoreObject()

local playerFines = {}
local finesTargetCreated = false

local function hasUnpaidFines()
    return #playerFines > 0
end

local function getTotalFinesAmount()
    local total = 0
    for _, fine in ipairs(playerFines) do
        total = total + (fine.total_amount or 0)
    end
    return total
end

local function formatTimeRemaining(dueTimestamp)
    if not dueTimestamp or type(dueTimestamp) ~= 'number' or dueTimestamp <= 0 then
        return locale('fines_unknown'), 0
    end
    
    local now = GetCloudTimeAsInt()
    local remaining = dueTimestamp - now
    
    if remaining <= 0 then
        return locale('fines_overdue'), 0
    end
    
    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local seconds = remaining % 60
    
    if days > 0 then
        return locale('fines_amount_left', days, days == 1 and '' or 's', hours, hours == 1 and '' or 's'), remaining
    elseif hours > 0 then
        return locale('fines_hours_left', hours, hours == 1 and '' or 's', minutes), remaining
    elseif minutes > 0 then
        return locale('fines_minutes_left', minutes, seconds), remaining
    else
        return locale('fines_seconds_left', seconds, seconds == 1 and '' or 's'), remaining
    end
end

exports('hasUnpaidFines', hasUnpaidFines)
exports('getTotalFinesAmount', getTotalFinesAmount)
exports('getPlayerFines', function() return playerFines end)

RegisterNetEvent('rsg-mdt:client:updatePlayerFines', function(fines)
    playerFines = fines or {}
    
    SendNUIMessage(json.encode({
        action = 'playerFinesUpdated',
        data = { fines = playerFines, total = getTotalFinesAmount() }
    }))
end)

RegisterNetEvent('rsg-mdt:client:finePaid', function(data)
    for i, fine in ipairs(playerFines) do
        if fine.id == data.fineId then
            table.remove(playerFines, i)
            break
        end
    end
    
    SendNUIMessage(json.encode({
        action = 'playerFinesUpdated',
        data = { fines = playerFines, total = getTotalFinesAmount() }
    }))
end)

RegisterNetEvent('rsg-mdt:client:finePaymentResult', function(data)
    if data.success then
        lib.notify({
            title = locale('fines_title'),
            description = data.message,
            type = 'success'
        })
    else
        lib.notify({
            title = locale('fines_title'),
            description = data.message,
            type = 'error'
        })
    end
end)

local function createFinesPaymentTargets()
    if finesTargetCreated then return end
    if not Config.Fines or not Config.Fines.enabled then return end
    
    local locations = Config.Fines.paymentLocations or {}
    
    for i, location in ipairs(locations) do
        local coords = location.coords
        local name = location.name or locale('system_court_clerk')
        
        local pedModel = GetHashKey('u_m_m_valsheriff_01')
        
        RequestModel(pedModel)
        local timeout = 0
        while not HasModelLoaded(pedModel) and timeout < 5000 do
            Wait(100)
            timeout = timeout + 100
        end
        
        if not HasModelLoaded(pedModel) then
            print('[rsg-mdt] Warning: Failed to load ped model for fines payment NPC at ' .. name)
            goto continue
        end
        
        local ped = CreatePed(pedModel, coords.x, coords.y, coords.z - 1.0, location.heading or 0.0, false, true, true, true)
        SetModelAsNoLongerNeeded(pedModel)
        SetRandomOutfitVariation(ped, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedCanPlayAmbientAnims(ped, true)
        SetPedCanRagdoll(ped, false)
        
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'pay_fines_' .. i,
                icon = 'fa-solid fa-money-bill',
                label = locale('fines_pay_label'),
                distance = 2.5,
                canInteract = function()
                    return hasUnpaidFines()
                end,
                onSelect = function()
                    lib.callback('rsg-mdt:server:getPlayerFines', false, function(fines)
                        playerFines = fines or {}
                        
                        if #playerFines == 0 then
                            lib.notify({
                                title = locale('fines_title'),
                                description = locale('notification_no_unpaid_fines'),
                                type = 'inform'
                            })
                            return
                        end
                        
                        local total = getTotalFinesAmount()
                        local options = {}
                        
                        for _, fine in ipairs(playerFines) do
                            local timeRemaining, _ = formatTimeRemaining(fine.due_timestamp)
                            local statusLabel = fine.status == 'overdue' and locale('fines_fine_overdue') or ''
                            
                            table.insert(options, {
                                title = locale('fines_fine_label'):format(fine.id) .. statusLabel,
                                description = locale('fines_fine_detail', fine.total_amount, timeRemaining),
                                icon = fine.status == 'overdue' and 'exclamation-triangle' or 'money-bill',
                                onSelect = function()
                                    local alert = lib.alertDialog({
                                        header = locale('fines_pay_header'),
                                        content = locale('fines_pay_content', fine.id, fine.total_amount),
                                        centered = true,
                                        cancel = true,
                                        labels = {
                                            confirm = locale('fines_pay_confirm'),
                                            cancel = locale('fines_cancel')
                                        }
                                    })
                                    
                                    if alert == 'confirm' then
                                        local result = lib.callback.await('rsg-mdt:server:payFine', false, fine.id)
                                        if result and result.success then
                                            lib.callback('rsg-mdt:server:getPlayerFines', false, function(newFines)
                                                playerFines = newFines or {}
                                            end)
                                        end
                                    end
                                end
                            })
                        end
                        
                        table.insert(options, {
                            title = locale('fines_pay_all_title'),
                            description = locale('fines_pay_all_total', total),
                            icon = 'money-check-dollar',
                            onSelect = function()
                                local alert = lib.alertDialog({
                                    header = locale('fines_pay_all_title'),
                                    content = locale('fines_pay_all_content', #playerFines, total),
                                    centered = true,
                                    cancel = true,
                                    labels = {
                                        confirm = locale('fines_pay_all_confirm'),
                                        cancel = locale('fines_cancel')
                                    }
                                })
                                
                                if alert == 'confirm' then
                                    for _, fine in ipairs(playerFines) do
                                        lib.callback.await('rsg-mdt:server:payFine', false, fine.id)
                                    end
                                    
                                    lib.callback('rsg-mdt:server:getPlayerFines', false, function(newFines)
                                        playerFines = newFines or {}
                                    end)
                                end
                            end
                        })
                        
                        lib.registerContext({
                            id = 'fines_payment_menu',
                            title = locale('fines_unpaid_title', name),
                            options = options
                        })
                        
                        lib.showContext('fines_payment_menu')
                    end)
                end
            },
            {
                name = 'check_fines_' .. i,
                icon = 'fa-solid fa-file-invoice-dollar',
                label = locale('fines_check_label'),
                distance = 2.5,
                onSelect = function()
                    lib.callback('rsg-mdt:server:getPlayerFines', false, function(fines)
                        playerFines = fines or {}
                        
                        if #playerFines == 0 then
                            lib.notify({
                                title = locale('fines_title'),
                                description = locale('notification_no_unpaid_fines_clear'),
                                type = 'success'
                            })
                        else
                            local total = getTotalFinesAmount()
                            lib.notify({
                                title = locale('fines_title'),
                                description = locale('notification_unpaid_fines_count', #playerFines, total),
                                type = 'warning'
                            })
                        end
                    end)
                end
            }
        })
        
        ::continue::
    end
    
    finesTargetCreated = true
end

CreateThread(function()
    Wait(3000)
    
    lib.callback('rsg-mdt:server:getPlayerFines', false, function(fines)
        playerFines = fines or {}
    end)
    
    if Config.Fines and Config.Fines.enabled then
        createFinesPaymentTargets()
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    
    lib.callback('rsg-mdt:server:getPlayerFines', false, function(fines)
        playerFines = fines or {}
    end)
end)

RegisterNuiCallback('getPlayerFines', function(_, cb)
    local fines = lib.callback.await('rsg-mdt:server:getPlayerFines')
    cb(fines or {})
end)

RegisterNuiCallback('payFine', function(data, cb)
    local result = lib.callback.await('rsg-mdt:server:payFine', false, data.fineId)
    cb(result or { success = false, message = locale('notification_unknown_error') })
end)

RegisterNuiCallback('getUnpaidFinesCount', function(data, cb)
    local count = lib.callback.await('rsg-mdt:server:getUnpaidFinesCount', false, data.citizenid)
    cb(count or 0)
end)

RegisterNuiCallback('getCitizenFines', function(data, cb)
    local fines = lib.callback.await('rsg-mdt:server:getCitizenFines', false, data.citizenid)
    cb(fines or {})
end)

RegisterNuiCallback('getAllUnpaidFines', function(_, cb)
    local fines = lib.callback.await('rsg-mdt:server:getAllUnpaidFines')
    cb(fines or {})
end)

RegisterNuiCallback('markFinePaid', function(data, cb)
    local result = lib.callback.await('rsg-mdt:server:markFinePaid', false, data.fineId)
    cb(result or { success = false, message = locale('notification_unknown_error') })
end)

RegisterNetEvent('rsg-mdt:client:finePaid', function(data)
    SendNUIMessage(json.encode({ action = 'finePaid', data = data }))
end)

RegisterNetEvent('rsg-mdt:client:fineStatusUpdated', function(data)
    SendNUIMessage(json.encode({ action = 'fineStatusUpdated', data = data }))
end)

RegisterNetEvent('rsg-mdt:client:playerFinePaid', function(data)
    for i, fine in ipairs(playerFines) do
        if fine.id == data.fineId then
            table.remove(playerFines, i)
            break
        end
    end
    
    SendNUIMessage(json.encode({
        action = 'playerFinesUpdated',
        data = { fines = playerFines, total = getTotalFinesAmount() }
    }))
end)
