local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- CALLBACKS: Company ownership + role detection
---------------------------------------------------------------

-- Get ownership data for a specific company
lib.callback.register('rsg-railroad:getCompanyOwnership', function(source, companyId)
    return DB.GetCompanyOwnership(companyId)
end)

-- Get ALL owned companies
lib.callback.register('rsg-railroad:getAllOwnedCompanies', function(source)
    return DB.GetAllOwnedCompanies()
end)

-- Determine player's role at a station's company
-- Returns: 'owner', 'driver', 'pending', 'visitor', 'unowned'
lib.callback.register('rsg-railroad:getPlayerRole', function(source, companyId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return 'visitor' end
    local citizenid = Player.PlayerData.citizenid

    -- Check if company is owned at all
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership then return 'unowned' end

    -- Check if this player is the owner
    if ownership.owner_citizenid == citizenid then return 'owner' end

    -- Check if this player is an employee
    local employee = DB.GetEmployeeByIds(companyId, citizenid)
    if employee then
        if employee.status == 'approved' then return 'driver' end
        if employee.status == 'pending' then return 'pending' end
    end

    return 'visitor'
end)

-- Get player's employee record for a company
lib.callback.register('rsg-railroad:getMyEmployeeData', function(source, companyId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    return DB.GetEmployeeByIds(companyId, Player.PlayerData.citizenid)
end)

---------------------------------------------------------------
-- BUY COMPANY
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:buyCompany', function(companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    if not Config.Companies[companyId] then return end

    -- Check if already owned
    local existing = DB.GetCompanyOwnership(companyId)
    if existing then
        NotifyPlayer(src, locale('company_already_owned'), 'error')
        return
    end

    -- Check if player already owns a company
    local ownedByPlayer = DB.GetOwnedCompaniesByCitizen(citizenid)
    if #ownedByPlayer > 0 then
        NotifyPlayer(src, locale('already_own_company'), 'error')
        return
    end

    local price = Config.CompanyPurchasePrice
    if not Player.Functions.RemoveMoney('cash', price, 'railroad-buy-company') then
        NotifyPlayer(src, locale('not_enough_money'), 'error')
        return
    end

    local ownerName = GetPlayerFullName(Player)

    -- company_id is the primary key, so a simultaneous purchase by two
    -- players fails the insert for one of them -> refund that player.
    local ok, inserted = pcall(DB.PurchaseCompany, companyId, citizenid, ownerName)
    if not ok or not inserted then
        Player.Functions.AddMoney('cash', price, 'railroad-buy-company-refund')
        NotifyPlayer(src, locale('company_already_owned'), 'error')
        return
    end

    local companyLabel = CompanyLabel(companyId)
    NotifyPlayer(src, locale('company_purchased', companyLabel), 'success', 7000)

    Webhook.SendFields('economy', 'Company Purchased', {
        { 'Player', ownerName .. ' (' .. citizenid .. ')' },
        { 'Company', companyLabel },
        { 'Price', '$' .. price },
    }, 'success')

    local ownedCount = DB.GetOwnedCompanyCount()
    TriggerClientEvent('rsg-railroad:setAmbientState', -1, ownedCount == 0)
end)

---------------------------------------------------------------
-- SELL COMPANY
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:sellCompany', function(companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership or ownership.owner_citizenid ~= citizenid then
        NotifyPlayer(src, locale('not_owner_of_company'), 'error')
        return
    end

    -- Refund
    local refund = math.floor(Config.CompanyPurchasePrice * Config.CompanySellPercent)
    -- Add cash register balance to refund
    refund = refund + math.floor(ownership.cash_register or 0)

    -- Delete the ownership row first; only the call that actually removed
    -- it gets paid (blocks double-sell spam).
    if (DB.SellCompany(companyId, citizenid) or 0) < 1 then return end
    DB.DeleteEmployeesByCompany(companyId)
    DB.DeleteSuppliesByCompany(companyId)

    Player.Functions.AddMoney('cash', refund, 'railroad-sell-company')
    NotifyPlayer(src, locale('company_sold', refund), 'success', 7000)

    Webhook.SendFields('economy', 'Company Sold', {
        { 'Player', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
        { 'Company', CompanyLabel(companyId) },
        { 'Refund', '$' .. refund },
    }, 'info')

    local ownedCount = DB.GetOwnedCompanyCount()
    TriggerClientEvent('rsg-railroad:setAmbientState', -1, ownedCount == 0)
end)

---------------------------------------------------------------
-- RENAME COMPANY
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:renameCompany', function(companyId, newName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership or ownership.owner_citizenid ~= citizenid then return end

    if type(newName) == 'string' then
        newName = newName:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    end
    if type(newName) ~= 'string' or #newName < 3 or #newName > 50 then
        NotifyPlayer(src, locale('company_name_length'), 'error')
        return
    end

    DB.SetCompanyName(companyId, newName)
    NotifyPlayer(src, locale('company_renamed', newName), 'success')

    Webhook.SendFields('economy', 'Company Renamed', {
        { 'Player', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
        { 'Company ID', companyId },
        { 'New Name', newName },
    }, 'info')
end)

---------------------------------------------------------------
-- WITHDRAW FROM CASH REGISTER
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:withdrawFunds', function(companyId, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership or ownership.owner_citizenid ~= citizenid then
        NotifyPlayer(src, locale('not_owner_of_company'), 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    -- Atomic: the UPDATE only applies when the register still holds enough.
    if (DB.WithdrawFromCashRegister(companyId, amount) or 0) < 1 then
        NotifyPlayer(src, locale('insufficient_register_funds', math.floor(DB.GetCashRegister(companyId))), 'error')
        return
    end

    Player.Functions.AddMoney('cash', amount, 'railroad-register-withdraw')
    NotifyPlayer(src, locale('funds_withdrawn', amount), 'success')

    Webhook.SendFields('economy', 'Funds Withdrawn', {
        { 'Player', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
        { 'Company', CompanyLabel(companyId) },
        { 'Amount', '$' .. amount },
    }, 'warn')
end)

---------------------------------------------------------------
-- COMPANY STATS (for Records tab)
---------------------------------------------------------------
lib.callback.register('rsg-railroad:getCompanyStats', function(source, companyId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or GetCompanyRole(companyId, Player.PlayerData.citizenid) ~= 'owner' then return {} end
    local employees = DB.GetEmployeesByCompany(companyId) or {}
    local ownership = DB.GetCompanyOwnership(companyId)

    local totalDrivers = 0
    local totalMissions = 0
    local totalEarnings = 0
    local topEarner = nil
    local topEarnings = 0
    local mostMissionsName = nil
    local mostMissionsCount = 0
    local highestRank = 0
    local highestRankName = nil

    for _, emp in ipairs(employees) do
        if emp.status == 'approved' then
            totalDrivers = totalDrivers + 1
            totalMissions = totalMissions + (emp.missions_completed or 0)
            totalEarnings = totalEarnings + (emp.total_earnings or 0)
            if (emp.total_earnings or 0) > topEarnings then
                topEarnings = emp.total_earnings or 0
                topEarner = (emp.firstname or '') .. ' ' .. (emp.lastname or '')
            end
            if (emp.missions_completed or 0) > mostMissionsCount then
                mostMissionsCount = emp.missions_completed or 0
                mostMissionsName = (emp.firstname or '') .. ' ' .. (emp.lastname or '')
            end
            if (emp.rank or 1) > highestRank then
                highestRank = emp.rank or 1
                highestRankName = (emp.firstname or '') .. ' ' .. (emp.lastname or '')
            end
        end
    end

    local highestRankLabel = Config.Ranks[highestRank] and Config.Ranks[highestRank].label or nil

    return {
        total_drivers = totalDrivers,
        total_missions = totalMissions,
        total_earnings = totalEarnings,
        cash_register = ownership and ownership.cash_register or 0,
        top_earner = topEarner,
        top_earnings = topEarnings,
        most_missions_name = mostMissionsName,
        most_missions_count = mostMissionsCount,
        highest_rank_name = highestRankName,
        highest_rank_label = highestRankLabel,
    }
end)

---------------------------------------------------------------
-- ALL COMPANY STATS (for leaderboard comparison)
---------------------------------------------------------------
lib.callback.register('rsg-railroad:getAllCompanyStats', function(source)
    local allOwned = DB.GetAllOwnedCompanies() or {}
    local results = {}

    for _, owned in ipairs(allOwned) do
        local compId = owned.company_id
        local employees = DB.GetEmployeesByCompany(compId) or {}
        local compConf = Config.Companies[compId]

        local totalDrivers = 0
        local totalMissions = 0
        local totalEarnings = 0

        for _, emp in ipairs(employees) do
            if emp.status == 'approved' then
                totalDrivers = totalDrivers + 1
                totalMissions = totalMissions + (emp.missions_completed or 0)
                totalEarnings = totalEarnings + (emp.total_earnings or 0)
            end
        end

        table.insert(results, {
            company_id = compId,
            company_label = compConf and compConf.label or compId,
            company_name = owned.company_name,
            owner_name = owned.owner_name,
            total_drivers = totalDrivers,
            total_missions = totalMissions,
            total_earnings = totalEarnings,
            cash_register = owned.cash_register or 0,
        })
    end

    return results
end)

---------------------------------------------------------------
-- GET COMPANY TRAINS (for station UI)
---------------------------------------------------------------
lib.callback.register('rsg-railroad:getCompanyTrains', function(source, companyId)
    return DB.GetCompanyTrains(companyId)
end)
