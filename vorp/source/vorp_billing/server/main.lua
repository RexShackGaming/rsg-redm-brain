local Lib <const> = Import({ "/config", "/languages/translations", "/languages/Logs" })
local Billing <const> = Lib.Billing --[[@as vorp_billing]]
local Translation <const> = Lib.Translation --[[@as vorp_billing_translation]]
local Logs <const> = Lib.Logs
local Core <const> = exports.vorp_core:GetCore()

local T <const> = Translation.Langs[Billing.Lang] -- Load the active language for the server

local function checkJob(source, job, grade)
    if not Billing.Jobs[job] then
        return Core.NotifyObjective(source, T.Notifications.not_allowed_command, 5000)
    end

    if grade < Billing.Jobs[job] then
        return Core.NotifyObjective(source, T.Notifications.not_allowed_command, 5000)
    end

    return true
end

RegisterCommand(Billing.Command, function(source)
    local user <const> = Core.getUser(source)
    if not user then return end

    local character <const> = user.getUsedCharacter

    if not checkJob(source, character.job, character.jobGrade) then
        return
    end

    if not Billing.GetIsOnduty(source) then
        return Core.NotifyObjective(source, T.Notifications.not_on_duty, 5000)
    end

    TriggerClientEvent("vorp_billing:client:openMenu", source)
end, false)


AddEventHandler("vorp:SelectedCharacter", function(source, char)
    local job <const> = char.job
    local grade <const> = char.jobGrade

    if Billing.Jobs[job] and Billing.Jobs[job] >= grade then
        TriggerClientEvent("chat:addSuggestion", source, Billing.Command, T.MenuLabels.confirm_desc, {})
    end
end)

-- we need an event to register the bill
RegisterNetEvent("vorp_billing:server:SendBill", function(data)
    local _source <const> = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    local sourceCharacter <const>  = user.getUsedCharacter
    local charname <const>         = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
    local sourceIdentifier <const> = sourceCharacter.identifier
    local steamname <const>        = GetPlayerName(_source)


    if not checkJob(source, sourceCharacter.job, sourceCharacter.jobGrade) then
        return
    end

    if data.playerId == _source then
        return Core.NotifyObjective(_source, T.Notifications.self_billing_error, 5000)
    end

    local target <const> = Core.getUser(data.playerId)
    if not target then
        return Core.NotifyObjective(_source, T.Notifications.target_not_found, 5000)
    end

    local distance = #(GetEntityCoords(GetPlayerPed(_source)) - GetEntityCoords(GetPlayerPed(data.playerId)))
    if distance > 5.0 then
        return Core.NotifyObjective(_source, T.Notifications.target_too_far, 5000)
    end

    if data.amount > Billing.MaxBillAmount then
        return Core.NotifyObjective(_source, T.Notifications.max_bill_exceeded .. Billing.MaxBillAmount, 5000)
    end

    if Billing.AllowBillingNegative then
        target.getUsedCharacter.addCurrency(0, -data.amount)
        Core.NotifyObjective(_source, T.Notifications.bill_successful .. " " .. target.getUsedCharacter.firstname .. " " .. target.getUsedCharacter.lastname .. " " .. T.Notifications.For .. " " .. data.amount, 5000)
        Core.NotifyObjective(data.playerId, T.Notifications.bill_received .. data.amount .. " " .. T.ReceiptInfo.billed_by .. " " .. charname .. " " .. T.Notifications.For .. " " .. data.reason, 5000)
    else
        if target.getUsedCharacter.money < data.amount then
            return Core.NotifyObjective(_source, T.Notifications.insufficient_funds, 5000)
        end
        target.getUsedCharacter.addCurrency(0, -data.amount)
    end

    if Billing.GiveMoneyToJob then
        sourceCharacter.addCurrency(0, data.amount)
    end

    if Billing.GiveReceipt then
        local day <const> = os.date("%d")
        local month <const> = os.date("%m")
        local year <const> = Billing.ServerYear
        local metadata <const> = {
            description = T.ReceiptInfo.receipt_description ..
                "<br> " .. T.ReceiptInfo.Ammount .. ": " .. data.amount ..
                "<br>" .. T.ReceiptInfo.billed_by .. ": " .. charname ..
                "<br>" .. T.ReceiptInfo.date .. ": " .. day .. "/" .. month .. "/" .. year ..
                "<br>" .. T.ReceiptInfo.reason .. ": " .. data.reason
        }
        exports.vorp_inventory:addItem(data.playerId, Billing.ReceiptItem, 1, metadata)
    end

    -- Webhook for bill sent
    local targetCharacter <const> = target.getUsedCharacter
    local targetname <const> = targetCharacter.firstname .. ' ' .. targetCharacter.lastname
    local targetIdentifier <const> = targetCharacter.identifier
    local targetSteamname <const> = GetPlayerName(data.playerId)

    local description = "**" .. Logs.Lang.BillSent .. "**" .. "\n" ..
        "**" .. Logs.Lang.BilledBy .. "** " .. charname .. "\n" ..
        "**" .. Logs.Lang.BilledPlayer .. "** " .. targetname .. "\n" ..
        "**" .. Logs.Lang.BillAmount .. "** " .. data.amount .. "\n" ..
        "**" .. Logs.Lang.BillReason .. "** " .. data.reason .. "\n" ..
        "**" .. Logs.Lang.OfficerSteam .. "** " .. steamname .. "\n" ..
        "**" .. Logs.Lang.OfficerID .. "** " .. sourceIdentifier .. "\n" ..
        "**" .. Logs.Lang.TargetSteam .. "** " .. targetSteamname .. "\n" ..
        "**" .. Logs.Lang.TargetID .. "** " .. targetIdentifier

    Core.AddWebhook(Logs.Lang.BillSent, Logs.Webhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)
end)
