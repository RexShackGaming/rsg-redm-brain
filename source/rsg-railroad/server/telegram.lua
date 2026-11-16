-- Owner telegram notices via rsg-telegram (optional; silently skipped if the resource isn't running).
local lastLowStock = {} -- [companyId..':'..item] = os.time()

function SendOwnerTelegram(companyId, subject, message)
    if not (Config.Telegram and Config.Telegram.Enabled) then return end
    if GetResourceState('rsg-telegram') ~= 'started' then return end
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership or not ownership.owner_citizenid then return end
    local ok, err = pcall(function()
        return exports['rsg-telegram']:SendTelegram(ownership.owner_citizenid, subject, message, {
            senderName = CompanyLabel(companyId),
        })
    end)
    if not ok then print(('^3[rsg-railroad]^7 Telegram notice failed: %s'):format(tostring(err))) end
end

-- Called after stock is taken; telegrams the owner when an item runs low (rate limited per item).
function CheckLowSupply(companyId, itemName, itemLabel)
    local cfg = Config.Telegram
    if not (cfg and cfg.Enabled and cfg.LowSupplyThreshold and cfg.LowSupplyThreshold > 0) then return end
    local row = DB.GetSupplyItem(companyId, itemName)
    local qty = row and tonumber(row.quantity) or 0
    if qty > cfg.LowSupplyThreshold then return end
    local key = companyId .. ':' .. itemName
    if lastLowStock[key] and os.time() - lastLowStock[key] < (cfg.LowSupplyCooldown or 3600) then return end
    lastLowStock[key] = os.time()
    SendOwnerTelegram(companyId, locale('tg_subject_lowstock'), locale('tg_body_lowstock', itemLabel, qty))
end
