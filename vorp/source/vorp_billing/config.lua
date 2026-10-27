---@class vorp_billing
local Billing = {}

Billing.Lang = "English"            -- Language you want to use please make sure its in the translation.lua

Billing.GiveMoneyToJob = true       -- If false the money wont be given to anyone if true the money will be given to the person who is billing

Billing.AllowBillingNegative = true -- If true it will alow to bill player to negative money, if true you cant bill players that dont have money

Billing.GiveReceipt = true          -- If true the player who got billed will receive a receipt as item

Billing.ReceiptItem = "receipt"     -- The item that will be given to the player who paid the bill, add this item to the database

Billing.ServerYear = 1899           -- The year that will be used in the receipt description

-- jobs allowed to use billing and ranks
Billing.Jobs = {
    ValSheriff = 0, -- job and grade allowed anything above the grade you add will have permission if grade is 1 then grade 0 will not have permission but grade 1 and above will
    BwPolice = 0,
    SdPolice = 0,
    RhoSheriff = 0,
    ArmSheriff = 0,
    Doctor = 0,
    Shaman = 0,
}

-- The command that will be used to bill players
Billing.Command = "bill"

Billing.MaxBillAmount = 1000 -- Players can not be billed more than this amount

Billing.GetIsOnduty = function(source)
    -- add here your own logic for other jobs
    -- by default these will work for vorp_medic and vorp_police
    local isDuty = (Player(source).state.isMedicDuty or Player(source).state.isPoliceDuty) and true or false
    return isDuty     -- do return true to remove the onduty check
end

return {
    Billing = Billing
}
