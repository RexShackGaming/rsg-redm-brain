local RSGCore = exports['rsg-core']:GetCoreObject()
local isOpen = false

local LABEL_KEYS = {
    'ui_title', 'ui_subtitle', 'ui_tab_queue', 'ui_tab_vips', 'ui_online', 'ui_waiting', 'ui_reserved',
    'ui_empty_queue', 'ui_empty_vips', 'ui_front', 'ui_remove', 'ui_identifier', 'ui_name', 'ui_days',
    'ui_add', 'ui_permanent', 'ui_expires', 'ui_expired', 'ui_refresh', 'card_grace',
    'ui_vip', 'ui_maint_on', 'ui_maint_off',
}

local function labels()
    local t = {}
    for _, k in ipairs(LABEL_KEYS) do t[k] = locale(k) end
    return t
end

local function close()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('rsg-queue:client:openAdmin', function(data)
    if not data then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', labels = labels(), data = data })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-queue:server:getAdminData', 5000) or false)
end)

RegisterNUICallback('action', function(d, cb)
    local res = RSGCore.Functions.AwaitCallback('rsg-queue:server:adminAction', 5000, d.action, d.data)
    if res and res.msg then
        RSGCore.Functions.Notify({ title = locale('ui_title'), description = res.msg, type = res.ok and 'success' or 'error' })
    end
    cb(res or { ok = false })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then close() end
end)
