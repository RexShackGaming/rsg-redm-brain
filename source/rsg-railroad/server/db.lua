DB = {}

---------------------------------------------------------------
-- TRAINS
---------------------------------------------------------------
function DB.GetOwnedTrains(citizenid)
    return MySQL.query.await('SELECT * FROM railroad_trains WHERE citizenid = @cid', { ['@cid'] = citizenid })
end

function DB.GetTrainById(trainId)
    local result = MySQL.query.await('SELECT * FROM railroad_trains WHERE id = @id LIMIT 1', { ['@id'] = trainId })
    return result and result[1] or nil
end

function DB.InsertTrain(citizenid, companyId, model, label, fuel, water, condition)
    return MySQL.insert.await(
        'INSERT INTO railroad_trains (citizenid, company_id, train_model, label, fuel, water, `condition`) VALUES (@cid, @comp, @model, @label, @fuel, @water, @cond)',
        { ['@cid'] = citizenid, ['@comp'] = companyId, ['@model'] = model, ['@label'] = label, ['@fuel'] = fuel, ['@water'] = water, ['@cond'] = condition }
    )
end

-- Returns the number of rows deleted so callers can detect a double-sell race.
function DB.DeleteTrain(trainId, citizenid)
    return MySQL.update.await('DELETE FROM railroad_trains WHERE id = @id AND citizenid = @cid', { ['@id'] = trainId, ['@cid'] = citizenid })
end

function DB.UpdateTrainFuel(trainId, fuel)
    MySQL.query.await('UPDATE railroad_trains SET fuel = @fuel WHERE id = @id', { ['@id'] = trainId, ['@fuel'] = fuel })
end

function DB.UpdateTrainWater(trainId, water)
    MySQL.query.await('UPDATE railroad_trains SET water = @water WHERE id = @id', { ['@id'] = trainId, ['@water'] = water })
end

function DB.UpdateTrainCondition(trainId, condition)
    MySQL.query.await('UPDATE railroad_trains SET `condition` = @cond WHERE id = @id', { ['@id'] = trainId, ['@cond'] = condition })
end

function DB.UpdateTrainState(trainId, fuel, water, condition)
    MySQL.query.await('UPDATE railroad_trains SET fuel = @fuel, water = @water, `condition` = @cond WHERE id = @id',
        { ['@id'] = trainId, ['@fuel'] = fuel, ['@water'] = water, ['@cond'] = condition })
end

function DB.ParkTrain(trainId, stationId, fuel, water, condition)
    MySQL.query.await('UPDATE railroad_trains SET is_parked = 1, parked_station = @station, fuel = @fuel, water = @water, `condition` = @cond WHERE id = @id',
        { ['@id'] = trainId, ['@station'] = stationId, ['@fuel'] = fuel, ['@water'] = water, ['@cond'] = condition })
end

function DB.UnparkTrain(trainId)
    MySQL.query.await('UPDATE railroad_trains SET is_parked = 0, parked_station = NULL WHERE id = @id', { ['@id'] = trainId })
end

function DB.AddMiles(trainId, miles)
    MySQL.query.await('UPDATE railroad_trains SET total_miles = total_miles + @miles WHERE id = @id', { ['@id'] = trainId, ['@miles'] = miles })
end

function DB.CountTrains(citizenid)
    local result = MySQL.query.await('SELECT COUNT(*) as cnt FROM railroad_trains WHERE citizenid = @cid', { ['@cid'] = citizenid })
    return result and result[1] and result[1].cnt or 0
end

---------------------------------------------------------------
-- COMPANIES
---------------------------------------------------------------
function DB.GetCompanyMembership(citizenid, companyId)
    local result = MySQL.query.await('SELECT * FROM railroad_companies WHERE citizenid = @cid AND company_id = @comp LIMIT 1',
        { ['@cid'] = citizenid, ['@comp'] = companyId })
    return result and result[1] or nil
end

function DB.JoinCompany(citizenid, companyId)
    MySQL.insert.await('INSERT INTO railroad_companies (citizenid, company_id, `rank`) VALUES (@cid, @comp, 1)', { ['@cid'] = citizenid, ['@comp'] = companyId })
end

function DB.EnsureCompanyMembership(citizenid, companyId)
    local existing = DB.GetCompanyMembership(citizenid, companyId)
    if not existing then
        DB.JoinCompany(citizenid, companyId)
    end
end

function DB.AddCompanyXP(citizenid, companyId, xp)
    DB.EnsureCompanyMembership(citizenid, companyId)
    MySQL.query.await('UPDATE railroad_companies SET xp = xp + @xp WHERE citizenid = @cid AND company_id = @comp',
        { ['@cid'] = citizenid, ['@comp'] = companyId, ['@xp'] = xp })
end

function DB.SetCompanyRank(citizenid, companyId, rank)
    DB.EnsureCompanyMembership(citizenid, companyId)
    MySQL.query.await('UPDATE railroad_companies SET `rank` = @rank WHERE citizenid = @cid AND company_id = @comp',
        { ['@cid'] = citizenid, ['@comp'] = companyId, ['@rank'] = rank })
end

function DB.IncrementMissions(citizenid, companyId)
    DB.EnsureCompanyMembership(citizenid, companyId)
    MySQL.query.await('UPDATE railroad_companies SET missions_completed = missions_completed + 1 WHERE citizenid = @cid AND company_id = @comp',
        { ['@cid'] = citizenid, ['@comp'] = companyId })
end

function DB.AddEarnings(citizenid, companyId, amount)
    DB.EnsureCompanyMembership(citizenid, companyId)
    MySQL.query.await('UPDATE railroad_companies SET total_earnings = total_earnings + @amt WHERE citizenid = @cid AND company_id = @comp',
        { ['@cid'] = citizenid, ['@comp'] = companyId, ['@amt'] = amount })
end

---------------------------------------------------------------
-- REWARDS
---------------------------------------------------------------
function DB.HasClaimedReward(citizenid, rewardId)
    local result = MySQL.query.await('SELECT id FROM railroad_rewards WHERE citizenid = @cid AND reward_id = @rid LIMIT 1',
        { ['@cid'] = citizenid, ['@rid'] = rewardId })
    return result and #result > 0
end

function DB.ClaimReward(citizenid, rewardId)
    MySQL.insert.await('INSERT INTO railroad_rewards (citizenid, reward_id) VALUES (@cid, @rid)', { ['@cid'] = citizenid, ['@rid'] = rewardId })
end

---------------------------------------------------------------
-- V2: COMPANY OWNERSHIP
---------------------------------------------------------------
function DB.GetCompanyOwnership(companyId)
    local result = MySQL.query.await('SELECT * FROM railroad_companies_owned WHERE company_id = @comp LIMIT 1', { ['@comp'] = companyId })
    return result and result[1] or nil
end

function DB.GetAllOwnedCompanies()
    return MySQL.query.await('SELECT * FROM railroad_companies_owned') or {}
end

function DB.GetOwnedCompaniesByCitizen(citizenid)
    return MySQL.query.await('SELECT * FROM railroad_companies_owned WHERE owner_citizenid = @cid', { ['@cid'] = citizenid }) or {}
end

function DB.PurchaseCompany(companyId, citizenid, ownerName)
    return MySQL.insert.await('INSERT INTO railroad_companies_owned (company_id, owner_citizenid, owner_name) VALUES (@comp, @cid, @name)',
        { ['@comp'] = companyId, ['@cid'] = citizenid, ['@name'] = ownerName })
end

function DB.SellCompany(companyId, citizenid)
    return MySQL.update.await('DELETE FROM railroad_companies_owned WHERE company_id = @comp AND owner_citizenid = @cid',
        { ['@comp'] = companyId, ['@cid'] = citizenid })
end

function DB.SetCompanyName(companyId, name)
    MySQL.query.await('UPDATE railroad_companies_owned SET company_name = @name WHERE company_id = @comp',
        { ['@comp'] = companyId, ['@name'] = name })
end

function DB.GetOwnedCompanyCount()
    local result = MySQL.query.await('SELECT COUNT(*) as cnt FROM railroad_companies_owned')
    return result and result[1] and result[1].cnt or 0
end

function DB.GetCashRegister(companyId)
    local result = MySQL.query.await('SELECT cash_register FROM railroad_companies_owned WHERE company_id = @comp LIMIT 1', { ['@comp'] = companyId })
    return result and result[1] and result[1].cash_register or 0
end

function DB.AddToCashRegister(companyId, amount)
    MySQL.query.await('UPDATE railroad_companies_owned SET cash_register = cash_register + @amt WHERE company_id = @comp',
        { ['@comp'] = companyId, ['@amt'] = amount })
end

-- Atomic: only succeeds when the register holds enough. Returns affected rows (0 or 1).
function DB.WithdrawFromCashRegister(companyId, amount)
    return MySQL.update.await('UPDATE railroad_companies_owned SET cash_register = cash_register - @amt WHERE company_id = @comp AND cash_register >= @amt',
        { ['@comp'] = companyId, ['@amt'] = amount })
end

-- Get company trains (owned by company, not individual)
function DB.GetCompanyTrains(companyId)
    return MySQL.query.await('SELECT * FROM railroad_trains WHERE company_id = @comp', { ['@comp'] = companyId }) or {}
end

---------------------------------------------------------------
-- COMPANY UPGRADES
---------------------------------------------------------------
function DB.GetCompanyUpgrades(companyId)
    return MySQL.query.await('SELECT * FROM railroad_company_upgrades WHERE company_id = @comp', { ['@comp'] = companyId }) or {}
end

function DB.GetCompanyTrainUpgrade(companyId, trainModel)
    local result = MySQL.query.await('SELECT * FROM railroad_company_upgrades WHERE company_id = @comp AND train_model = @model LIMIT 1',
        { ['@comp'] = companyId, ['@model'] = trainModel })
    return result and result[1] or nil
end

function DB.UpsertCompanyUpgrade(companyId, trainModel, column, level)
    MySQL.query.await(
        'INSERT INTO railroad_company_upgrades (company_id, train_model, `' .. column .. '`) VALUES (@comp, @model, @lvl) ' ..
        'ON DUPLICATE KEY UPDATE `' .. column .. '` = @lvl',
        { ['@comp'] = companyId, ['@model'] = trainModel, ['@lvl'] = level }
    )
end

---------------------------------------------------------------
-- V2: EMPLOYEES
---------------------------------------------------------------
function DB.ApplyAsDriver(companyId, citizenid, firstname, lastname)
    MySQL.insert.await(
        'INSERT INTO railroad_employees (company_id, citizenid, firstname, lastname, status) VALUES (@comp, @cid, @fn, @ln, @status)',
        { ['@comp'] = companyId, ['@cid'] = citizenid, ['@fn'] = firstname, ['@ln'] = lastname, ['@status'] = 'pending' }
    )
end

function DB.GetEmployeesByCompany(companyId)
    return MySQL.query.await([[
        SELECT e.*, COALESCE(m.xp, 0) as company_xp, COALESCE(m.`rank`, 1) as company_rank, COALESCE(m.missions_completed, 0) as company_missions
        FROM railroad_employees e
        LEFT JOIN railroad_companies m ON e.citizenid = m.citizenid AND e.company_id = m.company_id
        WHERE e.company_id = @comp ORDER BY e.status, e.applied_at DESC
    ]], { ['@comp'] = companyId }) or {}
end

function DB.GetEmployeeByIds(companyId, citizenid)
    local result = MySQL.query.await('SELECT * FROM railroad_employees WHERE company_id = @comp AND citizenid = @cid LIMIT 1',
        { ['@comp'] = companyId, ['@cid'] = citizenid })
    return result and result[1] or nil
end

function DB.GetPlayerEmployment(citizenid)
    return MySQL.query.await('SELECT * FROM railroad_employees WHERE citizenid = @cid AND status = @status',
        { ['@cid'] = citizenid, ['@status'] = 'approved' }) or {}
end

function DB.GetPendingApplications(companyId)
    return MySQL.query.await('SELECT * FROM railroad_employees WHERE company_id = @comp AND status = @status ORDER BY applied_at ASC',
        { ['@comp'] = companyId, ['@status'] = 'pending' }) or {}
end

-- All employee mutations are scoped to company_id so an owner can only
-- act on employees of their own company.
function DB.GetEmployeeById(companyId, employeeId)
    local result = MySQL.query.await('SELECT * FROM railroad_employees WHERE id = @id AND company_id = @comp LIMIT 1',
        { ['@id'] = employeeId, ['@comp'] = companyId })
    return result and result[1] or nil
end

function DB.ApproveEmployee(companyId, employeeId)
    return MySQL.update.await('UPDATE railroad_employees SET status = @status, approved_at = NOW() WHERE id = @id AND company_id = @comp AND status = @pending',
        { ['@id'] = employeeId, ['@comp'] = companyId, ['@status'] = 'approved', ['@pending'] = 'pending' })
end

function DB.RejectEmployee(companyId, employeeId)
    return MySQL.update.await('UPDATE railroad_employees SET status = @status WHERE id = @id AND company_id = @comp AND status = @pending',
        { ['@id'] = employeeId, ['@comp'] = companyId, ['@status'] = 'rejected', ['@pending'] = 'pending' })
end

function DB.FireEmployee(companyId, employeeId)
    return MySQL.update.await('DELETE FROM railroad_employees WHERE id = @id AND company_id = @comp', { ['@id'] = employeeId, ['@comp'] = companyId })
end

function DB.IncrementEmployeeMissions(employeeId)
    MySQL.query.await('UPDATE railroad_employees SET missions_completed = missions_completed + 1 WHERE id = @id', { ['@id'] = employeeId })
end

function DB.AddEmployeeEarnings(employeeId, amount)
    MySQL.query.await('UPDATE railroad_employees SET total_earnings = total_earnings + @amt WHERE id = @id', { ['@id'] = employeeId, ['@amt'] = amount })
end

function DB.DeleteEmployeesByCompany(companyId)
    MySQL.query.await('DELETE FROM railroad_employees WHERE company_id = @comp', { ['@comp'] = companyId })
end

---------------------------------------------------------------
-- V2: COMPANY SUPPLIES
---------------------------------------------------------------
function DB.GetCompanySupplies(companyId)
    return MySQL.query.await('SELECT * FROM railroad_company_supplies WHERE company_id = @comp', { ['@comp'] = companyId }) or {}
end

function DB.GetSupplyItem(companyId, itemName)
    local result = MySQL.query.await('SELECT * FROM railroad_company_supplies WHERE company_id = @comp AND item_name = @item LIMIT 1',
        { ['@comp'] = companyId, ['@item'] = itemName })
    return result and result[1] or nil
end

function DB.AddSupplyItem(companyId, itemName, quantity)
    local existing = DB.GetSupplyItem(companyId, itemName)
    if existing then
        MySQL.query.await('UPDATE railroad_company_supplies SET quantity = quantity + @qty WHERE company_id = @comp AND item_name = @item',
            { ['@comp'] = companyId, ['@item'] = itemName, ['@qty'] = quantity })
    else
        MySQL.insert.await('INSERT INTO railroad_company_supplies (company_id, item_name, quantity) VALUES (@comp, @item, @qty)',
            { ['@comp'] = companyId, ['@item'] = itemName, ['@qty'] = quantity })
    end
end

-- Atomic: returns affected rows (0 when stock was insufficient).
function DB.TakeSupplyItem(companyId, itemName, quantity)
    return MySQL.update.await('UPDATE railroad_company_supplies SET quantity = quantity - @qty WHERE company_id = @comp AND item_name = @item AND quantity >= @qty',
        { ['@comp'] = companyId, ['@item'] = itemName, ['@qty'] = quantity })
end

function DB.DeleteSuppliesByCompany(companyId)
    MySQL.query.await('DELETE FROM railroad_company_supplies WHERE company_id = @comp', { ['@comp'] = companyId })
end

---------------------------------------------------------------
-- AUTOMATIC DATABASE INSTALL / MIGRATION
---------------------------------------------------------------
-- Parses install/rsg_railroad_full.sql into individual statements and
-- runs each one (all are CREATE TABLE IF NOT EXISTS, so this is safe to
-- run every time the resource starts) instead of requiring the server
-- owner to import the .sql file by hand.

local function stripSqlComments(sql)
    local lines = {}
    for line in (sql .. '\n'):gmatch('([^\r\n]*)\r?\n') do
        if not line:match('^%s*%-%-') then
            lines[#lines + 1] = line
        end
    end
    return table.concat(lines, '\n')
end

local function splitSqlStatements(sql)
    local statements = {}
    local cleaned = stripSqlComments(sql)
    for statement in (cleaned .. ';'):gmatch('([^;]*);') do
        local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if #trimmed > 0 then
            statements[#statements + 1] = trimmed
        end
    end
    return statements
end

function DB.EnsureTables()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'install/rsg_railroad_full.sql')
    if not sql then
        print(('^1[rsg-railroad]^7 Could not read install/rsg_railroad_full.sql - automatic database setup skipped. Import it manually.'))
        return
    end

    local statements = splitSqlStatements(sql)
    if #statements == 0 then
        print('^1[rsg-railroad]^7 install/rsg_railroad_full.sql contained no runnable statements.')
        return
    end

    local failed = 0
    for _, statement in ipairs(statements) do
        local ok, err = pcall(function()
            MySQL.query.await(statement)
        end)
        if not ok then
            failed = failed + 1
            print(('^1[rsg-railroad]^7 Database setup statement failed: %s'):format(tostring(err)))
        end
    end

    if failed == 0 then
        print('^2[rsg-railroad]^7 Database tables verified/created successfully (' .. #statements .. ' statements).')
    else
        print(('^1[rsg-railroad]^7 Database setup finished with %s failed statement(s). Check your MySQL user permissions (CREATE TABLE) and the log above.'):format(failed))
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Config.AutoInstallDatabase == false then
        print('^3[rsg-railroad]^7 Config.AutoInstallDatabase is false - skipping automatic database setup.')
        return
    end

    CreateThread(function()
        -- oxmysql queues queries until the pool is connected, but give it a
        -- brief moment on a fresh server boot before we hit it with the
        -- whole schema.
        Wait(500)
        DB.EnsureTables()
    end)
end)
