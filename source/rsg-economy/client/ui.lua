-- rsg-economy: NUI panel (/economy). The client only shows data and forwards requests; the server validates everything.
local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false

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
        if uiOpen and Config.AllowPushToTalkWhileOpen then
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
    'ui_permanent', 'ui_days', 'ui_cost', 'ui_remaining', 'ui_ledger', 'ui_ledger_empty', 'ui_market_empty', 'ui_hidden', 'ui_daily_limit',
    'ui_close', 'ui_loading', 'ui_taxes_hint', 'ui_market_hint', 'ui_donate_hint',
    'kind_tax', 'kind_deposit', 'kind_withdraw', 'kind_payout', 'kind_project', 'kind_admin', 'kind_tax_rate', 'kind_interest',
    'ui_tab_elections', 'ui_tab_admin', 'ui_mayor', 'ui_no_mayor', 'ui_term_ends', 'ui_election_idle', 'ui_candidacy_open',
    'ui_voting_open', 'ui_candidates', 'ui_no_candidates', 'ui_platform', 'ui_register', 'ui_register_fee', 'ui_withdraw_candidacy',
    'ui_vote', 'ui_your_vote', 'ui_votes', 'ui_elections_hint', 'ui_admin_hint', 'ui_admin_new', 'ui_admin_id', 'ui_admin_label',
    'ui_admin_order', 'ui_admin_law', 'ui_admin_officials', 'ui_admin_add', 'ui_admin_use_pos', 'ui_admin_save', 'ui_admin_delete',
    'ui_admin_position', 'ui_job', 'ui_grade',
}

local function strings()
    local out = {}
    for i = 1, #STRING_KEYS do out[STRING_KEYS[i]] = locale(STRING_KEYS[i]) end
    return out
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function openUi()
    if uiOpen or not LocalPlayer.state.isLoggedIn then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-economy:server:getPanel', 5000)
    if not data then
        RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('notify_panel_failed'), type = 'error' })
        return
    end
    uiOpen = true
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

RegisterNUICallback('election', function(data, cb)
    CreateThread(function()
        cb(RSGCore.Functions.AwaitCallback('rsg-economy:server:getElection', 5000, data and data.region) or false)
    end)
end)

RegisterNUICallback('admin', function(_, cb)
    CreateThread(function()
        cb(RSGCore.Functions.AwaitCallback('rsg-economy:server:getAdmin', 5000) or false)
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
forward('electionRegister', 'rsg-economy:server:electionRegister', function(d) return d.region, d.platform end)
forward('electionWithdraw', 'rsg-economy:server:electionWithdraw', function(d) return d.region end)
forward('electionVote', 'rsg-economy:server:electionVote', function(d) return d.region, d.candidate end)
forward('adminSave', 'rsg-economy:server:adminSaveRegion', function(d) return d.data end)
forward('adminDelete', 'rsg-economy:server:adminDeleteRegion', function(d) return d.id end)

if Config.Command and Config.Command ~= '' then
    RegisterCommand(Config.Command, function()
        if uiOpen then closeUi() else CreateThread(openUi) end
    end, false)
end

-- rebindable key (rsg-core RegisterKey); Config.UseKeyMapping = false keeps only the chat command
if Config.UseKeyMapping and RSGCore.Functions.RegisterKey then
    RSGCore.Functions.RegisterKey('rsgeconomy_open', locale('key_open'), Config.Key or '', function()
        if not uiOpen then CreateThread(openUi) end
    end, nil, { canTrigger = function() return not IsPauseMenuActive() end })
end

-- for other client scripts (for example a street lamp script): is this project active in that town?
exports('HasProject', function(region, id)
    local all = GlobalState['rsg-economy:projects']
    return type(all) == 'table' and type(all[region]) == 'table' and all[region][id] == true
end)

RegisterNetEvent('rsg-economy:client:open', function()
    CreateThread(openUi)
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function() closeUi() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then applyNuiFocus(false) end
end)
