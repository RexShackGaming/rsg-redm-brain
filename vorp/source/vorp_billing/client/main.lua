local Lib <const> = Import({ "/config", "/languages/translations" })
local Billing <const> = Lib.Billing --[[@as vorp_billing]]
local Translation <const> = Lib.Translation --[[@as vorp_billing_translation]]

local Core <const> = exports.vorp_core:GetCore()
local MenuData <const> = exports.vorp_menu:GetMenuData()
local T <const> = Translation.Langs[Billing.Lang]

RegisterNetEvent("vorp_billing:client:openMenu", function()
    OpenBillingMenu()
end)

local function myInput(header, placeholder, type, pattern, title)
    local input <const> = {
        type = "enableinput",
        inputType = "input",
        button = T.MenuLabels.confirm,
        placeholder = placeholder,
        style = "block",
        attributes = {
            inputHeader = header,
            type = type,
            pattern = pattern,
            title = title,
            style = "border-radius: 10px; background-color: ; border:none;",
        }
    }
    return input
end

function OpenBillingMenu()
    MenuData.CloseAll()
    local playerId = 0
    local reason = ""
    local amount = 0

    local elements <const> = {
        { label = T.MenuLabels.player_id,   value = "playerId", desc = T.MenuLabels.player_id_desc },
        { label = T.MenuLabels.bill_reason, value = "reason",   desc = T.MenuLabels.reason_desc },
        { label = T.MenuLabels.bill_amount, value = "amount",   desc = T.MenuLabels.amount_desc },
        { label = T.MenuLabels.confirm,     value = "confirm",  desc = T.MenuLabels.confirm_desc },
    }

    MenuData.Open("default", GetCurrentResourceName(), "OpenBillingMenu", {
        title = T.MenuLabels.menu_title,
        subtext = T.MenuLabels.submenu_text,
        align = "top-left",
        itemHeight = "4vh",
        elements = elements
    }, function(data, menu)
        if data.current.value == "confirm" then
            if playerId <= 0 or reason == "" or amount <= 0 then
                return Core.NotifyObjective(T.Notifications.fill_all_fields, 5000)
            end

            menu.close()

            local info = {
                playerId = playerId,
                reason = reason,
                amount = amount,
            }
            return TriggerServerEvent("vorp_billing:server:SendBill", info)
        end

        local type <const> = (data.current.value == "playerId" or data.current.value == "amount") and "number" or "text"
        local pattern <const> = (data.current.value == "playerId" or data.current.value == "amount") and "[0-9]" or "[a-zA-Z ]+"
        local title <const> = (data.current.value == "playerId" or data.current.value == "amount") and T.InputInfo.only_numbers_allowed or T.InputInfo.only_letters_allowed
        local input <const> = myInput(T.MenuLabels.menu_title, T.MenuLabels.menu_input, type, pattern, title)

        local result <const> = exports.vorp_inputs:advancedInput(input)
        if not result then return end

        if data.current.value == "playerId" and tonumber(result) > 0 then
            menu.setElement(1, "label", T.MenuLabels.player_id .. "<br><b> " .. T.InputInfo.Added .. result)
            menu.setElement(1, "desc", T.MenuLabels.player_id_desc)
            menu.refresh()
            playerId = tonumber(result)
        end

        if data.current.value == "reason" then
            menu.setElement(2, "label", T.MenuLabels.bill_reason .. "<br> " .. T.Notifications.bill_successful)
            menu.setElement(2, "desc", T.MenuLabels.reason_desc .. ": " .. result)
            menu.refresh()
            reason = result
        end

        if data.current.value == "amount" and tonumber(result) > 0 then
            if tonumber(result) > Billing.MaxBillAmount then
                return Core.NotifyObjective(T.Notifications.max_bill_exceeded .. Billing.MaxBillAmount, 5000)
            end
            menu.setElement(3, "label", T.MenuLabels.bill_amount .. "<br> " .. T.Notifications.bill_received .. "$" .. result)
            menu.setElement(3, "desc", T.MenuLabels.amount_desc)
            menu.refresh()
            amount = tonumber(result)
        end
    end, function(_, menu)
        menu.close()
    end)
end
