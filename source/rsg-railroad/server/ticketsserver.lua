local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- TRAIN TICKETS
-- Called once when a player boards a train they are not driving.
-- The ticket is consumed on boarding (or bought at the markup price if
-- the player has none), so one ticket = one journey and the company
-- register can't be farmed by re-triggering the check.
---------------------------------------------------------------
local TICKET_CHECK_COOLDOWN = 10 -- seconds
local lastCheck = {}             -- [source] = { time = os.time(), result = string }

local function CheckTicket(src, Player, companyId)
    local ownership = companyId and Config.Companies[companyId] and DB.GetCompanyOwnership(companyId) or nil

    -- Company owners ride for free
    if ownership and ownership.owner_citizenid == Player.PlayerData.citizenid then
        return 'has_ticket'
    end

    if exports['rsg-inventory']:RemoveItem(src, Config.TicketItem, 1, nil, 'railroad-ticket-used') then
        if ownership then DB.AddToCashRegister(companyId, Config.TicketPrice) end
        return 'has_ticket'
    end

    if Player.Functions.RemoveMoney('cash', Config.MarkupPrice, 'railroad-ticket-onboard') then
        if ownership then DB.AddToCashRegister(companyId, Config.MarkupPrice) end
        return 'bought_ticket'
    end

    return 'no_ticket'
end

lib.callback.register('rsg-railroad:server:useTicket', function(source, companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return 'no_ticket' end

    -- Repeat calls inside the cooldown get the previous answer instead of
    -- charging again (or riding free).
    local now = os.time()
    local last = lastCheck[src]
    if last and (now - last.time) < TICKET_CHECK_COOLDOWN then
        return last.result == 'no_ticket' and 'no_ticket' or 'has_ticket'
    end

    local result = CheckTicket(src, Player, companyId)
    lastCheck[src] = { time = now, result = result }
    return result
end)

AddEventHandler('playerDropped', function()
    lastCheck[source] = nil
end)
