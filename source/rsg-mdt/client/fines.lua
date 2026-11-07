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
        RSGCore.Functions.Notify({
            title = locale('fines_title'),
            description = data.message,
            type = 'success'
        })
    else
        RSGCore.Functions.Notify({
            title = locale('fines_title'),
            description = data.message,
            type = 'error'
        })
    end
end)

-- ============================================
-- Fines Clerk NUI (replaces ox_lib context menu / alert dialogs)
-- ============================================
local clerkOpen = false
local clerkName = nil

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local clerkLabelKeys = {
    'fines_title', 'fines_fine_label', 'fines_fine_detail', 'fines_overdue', 'fines_pay_all_total',
    'fines_pay_all_title', 'fines_pay_header', 'fines_pay_content', 'fines_pay_all_content',
    'fines_pay_confirm', 'fines_pay_all_confirm', 'fines_cancel', 'notification_no_unpaid_fines_clear',
}

local function buildClerkPayload()
    local list = {}
    for _, fine in ipairs(playerFines) do
        local timeLeft = formatTimeRemaining(fine.due_timestamp)
        list[#list + 1] = {
            id = fine.id,
            amount = fine.total_amount or 0,
            timeLeft = timeLeft,
            overdue = fine.status == 'overdue',
        }
    end
    local labels = {}
    for _, k in ipairs(clerkLabelKeys) do labels[k] = locale(k) end
    return {
        title = locale('fines_unpaid_title', clerkName or locale('system_court_clerk')),
        fines = list,
        total = getTotalFinesAmount(),
        labels = labels,
    }
end

local function refreshClerk()
    local fines = RSGCore.Functions.AwaitCallback('rsg-mdt:server:getPlayerFines')
    playerFines = fines or {}
    if clerkOpen then
        SendNUIMessage({ action = 'updateFinesClerk', data = buildClerkPayload() })
    end
end

local function closeFinesClerk()
    if not clerkOpen then return end
    clerkOpen = false
    SendNUIMessage({ action = 'closeFinesClerk' })
    applyNuiFocus(false)
end

local function openFinesClerk(name)
    local fines = RSGCore.Functions.AwaitCallback('rsg-mdt:server:getPlayerFines')
    playerFines = fines or {}
    if #playerFines == 0 then
        RSGCore.Functions.Notify({ title = locale('fines_title'), description = locale('notification_no_unpaid_fines'), type = 'inform' })
        return
    end
    clerkName = name
    clerkOpen = true
    SendNUIMessage({ action = 'openFinesClerk', data = buildClerkPayload() })
    applyNuiFocus(true)
end

RegisterNuiCallback('finesClerkClose', function(_, cb)
    closeFinesClerk()
    cb({ success = true })
end)

RegisterNuiCallback('finesClerkPay', function(data, cb)
    local result = RSGCore.Functions.AwaitCallback('rsg-mdt:server:payFine', nil, tonumber(data and data.fineId))
    refreshClerk()
    if #playerFines == 0 then closeFinesClerk() end
    cb(result or { success = false })
end)

RegisterNuiCallback('finesClerkPayAll', function(_, cb)
    local ids = {}
    for _, fine in ipairs(playerFines) do ids[#ids + 1] = fine.id end
    for _, id in ipairs(ids) do
        RSGCore.Functions.AwaitCallback('rsg-mdt:server:payFine', nil, id)
    end
    refreshClerk()
    if #playerFines == 0 then closeFinesClerk() end
    cb({ success = true })
end)

-- Push-to-talk whitelist while the clerk UI has focus
CreateThread(function()
    while true do
        if clerkOpen and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and clerkOpen then
        applyNuiFocus(false)
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
        
        exports['rsg-target']:addLocalEntity(ped, {
            {
                name = 'pay_fines_' .. i,
                icon = 'fa-solid fa-money-bill',
                label = locale('fines_pay_label'),
                distance = 2.5,
                canInteract = function()
                    return hasUnpaidFines()
                end,
                onSelect = function()
                    openFinesClerk(name)
                end
            },
            {
                name = 'check_fines_' .. i,
                icon = 'fa-solid fa-file-invoice-dollar',
                label = locale('fines_check_label'),
                distance = 2.5,
                onSelect = function()
                    RSGCore.Functions.TriggerCallback('rsg-mdt:server:getPlayerFines', function(fines)
                        playerFines = fines or {}
                        
                        if #playerFines == 0 then
                            RSGCore.Functions.Notify({
                                title = locale('fines_title'),
                                description = locale('notification_no_unpaid_fines_clear'),
                                type = 'success'
                            })
                        else
                            local total = getTotalFinesAmount()
                            RSGCore.Functions.Notify({
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
    
    RSGCore.Functions.TriggerCallback('rsg-mdt:server:getPlayerFines', function(fines)
        playerFines = fines or {}
    end)
    
    if Config.Fines and Config.Fines.enabled then
        createFinesPaymentTargets()
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    
    RSGCore.Functions.TriggerCallback('rsg-mdt:server:getPlayerFines', function(fines)
        playerFines = fines or {}
    end)
end)

RegisterNuiCallback('getPlayerFines', function(_, cb)
    local fines = RSGCore.Functions.AwaitCallback('rsg-mdt:server:getPlayerFines')
    cb(fines or {})
end)

RegisterNuiCallback('payFine', function(data, cb)
    local result = RSGCore.Functions.AwaitCallback('rsg-mdt:server:payFine', nil, data.fineId)
    cb(result or { success = false, message = locale('notification_unknown_error') })
end)

RegisterNuiCallback('getUnpaidFinesCount', function(data, cb)
    local count = RSGCore.Functions.AwaitCallback('rsg-mdt:server:getUnpaidFinesCount', nil, data.citizenid)
    cb(count or 0)
end)

RegisterNuiCallback('getCitizenFines', function(data, cb)
    local fines = RSGCore.Functions.AwaitCallback('rsg-mdt:server:getCitizenFines', nil, data.citizenid)
    cb(fines or {})
end)

RegisterNuiCallback('getAllUnpaidFines', function(_, cb)
    local fines = RSGCore.Functions.AwaitCallback('rsg-mdt:server:getAllUnpaidFines')
    cb(fines or {})
end)

RegisterNuiCallback('markFinePaid', function(data, cb)
    local result = RSGCore.Functions.AwaitCallback('rsg-mdt:server:markFinePaid', nil, data.fineId)
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
