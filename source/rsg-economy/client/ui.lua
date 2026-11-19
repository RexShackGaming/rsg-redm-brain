-- rsg-economy: NUI panel (/economy). The client only shows data and forwards requests; the server validates everything.
local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false
local uiFocus = false

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

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

local STRING_KEYS = {
    'ui_title', 'ui_subtitle', 'ui_tab_taxes', 'ui_tab_treasury', 'ui_tab_market', 'ui_region', 'ui_official', 'ui_citizen',
    'ui_rate', 'ui_apply', 'ui_balance', 'ui_amount', 'ui_withdraw', 'ui_deposit', 'ui_projects', 'ui_fund', 'ui_active_until',
    'ui_permanent', 'ui_days', 'ui_cost', 'ui_ledger', 'ui_ledger_empty', 'ui_market_empty', 'ui_hidden', 'ui_daily_limit',
    'ui_close', 'ui_loading', 'ui_taxes_hint', 'ui_market_hint', 'ui_donate_hint',
    'kind_tax', 'kind_deposit', 'kind_withdraw', 'kind_payout', 'kind_project', 'kind_admin', 'kind_tax_rate',
}

local function strings()
    local out = {}
    for i = 1, #STRING_KEYS do out[STRING_KEYS[i]] = locale(STRING_KEYS[i]) end
    return out
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    uiFocus = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function openUi()
    if uiOpen then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-economy:server:getPanel', 5000)
    if not data then
        RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('notify_panel_failed'), type = 'error' })
        return
    end
    uiOpen = true
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', data = data, strings = strings() })
end

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('panel', function(_, cb)
    CreateThread(function()
        cb(RSGCore.Functions.AwaitCallback('rsg-economy:server:getPanel', 5000) or false)
    end)
end)

RegisterNUICallback('ledger', function(data, cb)
    CreateThread(function()
        cb(RSGCore.Functions.AwaitCallback('rsg-economy:server:getLedger', 5000, data and data.region) or false)
    end)
end)

local function forward(endpoint, callbackName, build)
    RegisterNUICallback(endpoint, function(data, cb)
        CreateThread(function()
            data = type(data) == 'table' and data or {}
            local result = RSGCore.Functions.AwaitCallback(callbackName, 8000, build(data)) or { ok = false, msg = locale('msg_failed') }
            if result.msg then
                RSGCore.Functions.Notify({
                    title = locale('notify_title'), description = result.msg, type = result.ok and 'success' or 'error', id = 'rsg-economy',
                })
            end
            cb(result)
        end)
    end)
end

forward('setTax', 'rsg-economy:server:setTax', function(d) return d.region, d.category, d.rate end)
forward('withdraw', 'rsg-economy:server:withdraw', function(d) return d.region, d.amount end)
forward('deposit', 'rsg-economy:server:deposit', function(d) return d.region, d.amount end)
forward('fundProject', 'rsg-economy:server:fundProject', function(d) return d.region, d.project end)

if Config.Command and Config.Command ~= '' then
    RegisterCommand(Config.Command, function()
        if uiOpen then closeUi() else CreateThread(openUi) end
    end, false)
end

RegisterNetEvent('rsg-economy:client:open', function()
    CreateThread(openUi)
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function() closeUi() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiFocus then applyNuiFocus(false) end
end)
