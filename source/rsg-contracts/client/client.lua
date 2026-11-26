local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false
local zones, labels = {}, nil

local labelKeys = {
    'ui_title', 'ui_tab_mine', 'ui_tab_new', 'ui_tab_collect', 'ui_tab_disputes', 'ui_empty', 'ui_empty_collect',
    'ui_empty_disputes', 'ui_buyer', 'ui_worker', 'ui_pay', 'ui_deposit', 'ui_time_left', 'ui_deadline', 'ui_goods',
    'ui_type', 'ui_supply', 'ui_job', 'ui_player', 'ui_no_nearby', 'ui_subject', 'ui_details', 'ui_item', 'ui_quantity',
    'ui_hours', 'ui_send', 'ui_send_hint', 'ui_sign', 'ui_decline', 'ui_withdraw', 'ui_deliver', 'ui_finish',
    'ui_approve', 'ui_dispute', 'ui_giveup', 'ui_cancel', 'ui_agree_cancel', 'ui_cancel_waiting', 'ui_rule_worker',
    'ui_rule_buyer', 'ui_collect', 'ui_office_only', 'ui_confirm_title', 'ui_confirm', 'ui_back', 'ui_search',
    'ui_status_offered', 'ui_status_active', 'ui_status_review', 'ui_status_disputed', 'ui_status_closed', 'ui_paper',
}

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function Close()
    if not uiOpen then return end
    uiOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function Show(payload)
    if not labels then
        labels = {}
        for _, k in ipairs(labelKeys) do labels[k] = locale(k) end
    end
    payload.action, payload.labels = 'open', labels
    payload.limits = {
        minPay = Config.MinPay, maxPay = Config.MaxPay, maxDeposit = Config.MaxDeposit, minHours = Config.MinHours,
        maxHours = Config.MaxHours, maxQuantity = Config.MaxQuantity, maxTitle = Config.MaxTitle, maxDetails = Config.MaxDetails,
    }
    uiOpen = true
    applyNuiFocus(true)
    SendNUIMessage(payload)
end

local function Open(tab)
    if uiOpen or IsEntityDead(PlayerPedId()) then return end
    RSGCore.Functions.TriggerCallback('rsg-contracts:server:getState', function(state)
        if state and not uiOpen then Show({ state = state, tab = tab }) end
    end)
end

if Config.Command then
    RegisterCommand(Config.Command, function() Open('mine') end, false)
end

RegisterNetEvent('rsg-contracts:client:paper', function(id)
    if uiOpen then return end
    exports['rsg-inventory']:CloseInventory()
    RSGCore.Functions.TriggerCallback('rsg-contracts:server:getPaper', function(contract)
        if contract and not uiOpen then Show({ paper = contract }) end
    end, id)
end)

RegisterNUICallback('close', function(_, cb) cb('ok') Close() end)

RegisterNUICallback('refresh', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-contracts:server:getState', function(state) cb({ state = state }) end)
end)

RegisterNUICallback('items', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-contracts:server:getItems', function(items) cb({ items = items }) end)
end)

-- the server checks everything again
RegisterNUICallback('action', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-contracts:server:action', function(result) cb(result or { ok = false }) end,
        data.name, data.data)
end)

CreateThread(function()
    while true do
        if uiOpen then
            if IsEntityDead(PlayerPedId()) or IsPauseMenuActive() then
                Close()
                Wait(250)
            elseif Config.AllowPushToTalkWhileOpen then
                Wait(0)
                DisableAllControlActions(0)
                DisableAllControlActions(1)
                DisableAllControlActions(2)
                for _, control in ipairs(Config.PushToTalkControls or {}) do
                    EnableControlAction(0, control, true)
                    EnableControlAction(1, control, true)
                    EnableControlAction(2, control, true)
                end
            else
                Wait(250)
            end
        else
            Wait(250)
        end
    end
end)

for _, office in ipairs(Config.Offices) do
    zones[#zones + 1] = exports['rsg-target']:addSphereZone({
        coords = office.coords, radius = Config.TargetRadius,
        options = {
            {
                name = 'rsg_contracts_' .. office.id, icon = 'fa-solid fa-file-signature', label = locale('target_office'),
                distance = 2.5, onSelect = function() Open('collect') end,
            },
        },
    })
end

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', Close)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then applyNuiFocus(false) end
    for _, zone in ipairs(zones) do exports['rsg-target']:removeZone(zone) end
end)
