local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- CALLBACKS
---------------------------------------------------------------
-- Employee lists are owner-only.
local function IsOwner(source, companyId)
    local Player = RSGCore.Functions.GetPlayer(source)
    return Player and GetCompanyRole(companyId, Player.PlayerData.citizenid) == 'owner', Player
end

lib.callback.register('rsg-railroad:getEmployees', function(source, companyId)
    if not IsOwner(source, companyId) then return {} end
    return DB.GetEmployeesByCompany(companyId)
end)

lib.callback.register('rsg-railroad:getPendingApplications', function(source, companyId)
    if not IsOwner(source, companyId) then return {} end
    return DB.GetPendingApplications(companyId)
end)

lib.callback.register('rsg-railroad:getMyEmployment', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    return DB.GetPlayerEmployment(Player.PlayerData.citizenid)
end)

---------------------------------------------------------------
-- APPLY AS DRIVER
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:applyAsDriver', function(companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo

    -- Check company is owned
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership then
        NotifyPlayer(src, locale('company_no_owner'), 'error')
        return
    end

    -- Check not already applied/employed
    local existing = DB.GetEmployeeByIds(companyId, citizenid)
    -- A previously rejected applicant may apply again.
    if existing and existing.status == 'rejected' then
        DB.FireEmployee(companyId, existing.id)
        existing = nil
    end
    if existing then
        local msg = existing.status == 'pending' and locale('application_pending') or locale('already_employed')
        NotifyPlayer(src, msg, 'error')
        return
    end

    -- Check player doesn't own this company
    if ownership.owner_citizenid == citizenid then
        NotifyPlayer(src, locale('own_this_company'), 'error')
        return
    end

    DB.ApplyAsDriver(companyId, citizenid, charinfo.firstname or '', charinfo.lastname or '')
    NotifyPlayer(src, locale('application_submitted'), 'success', 7000)

    Webhook.SendFields('employees', 'Driver Application', {
        { 'Applicant', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
        { 'Company', CompanyLabel(companyId) },
    }, 'info')

    -- Notify owner if online
    local ownerPlayer = RSGCore.Functions.GetPlayerByCitizenId(ownership.owner_citizenid)
    if ownerPlayer then
        local applicantName = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        local companyLabel = CompanyLabel(companyId)
        TriggerClientEvent('ox_lib:notify', ownerPlayer.PlayerData.source, {
            title = companyLabel,
            description = locale('driver_applied_notify', applicantName),
            type = 'inform',
            duration = 10000,
        })
    end
end)

---------------------------------------------------------------
-- APPROVE / REJECT / FIRE (owner only, scoped to their company)
---------------------------------------------------------------
local function NotifyCitizen(citizenid, companyId, description, nType)
    local target = citizenid and RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if not target then return end
    TriggerClientEvent('ox_lib:notify', target.PlayerData.source, {
        title = CompanyLabel(companyId),
        description = description,
        type = nType,
        duration = 10000,
    })
end

RegisterNetEvent('rsg-railroad:approveDriver', function(companyId, employeeId)
    local src = source
    local ok, Player = IsOwner(src, companyId)
    if not ok then return end

    local emp = DB.GetEmployeeById(companyId, tonumber(employeeId))
    if not emp or (DB.ApproveEmployee(companyId, emp.id) or 0) < 1 then return end
    DB.EnsureCompanyMembership(emp.citizenid, companyId) -- XP/rank tracking row

    NotifyPlayer(src, locale('driver_approved'), 'success')
    NotifyCitizen(emp.citizenid, companyId, locale('application_approved_notify'), 'success')

    Webhook.SendFields('employees', 'Driver Approved', {
        { 'Approved By', GetPlayerFullName(Player) },
        { 'Company', CompanyLabel(companyId) },
        { 'Driver', (emp.firstname or '') .. ' ' .. (emp.lastname or '') },
    }, 'success')
end)

RegisterNetEvent('rsg-railroad:rejectDriver', function(companyId, employeeId)
    local src = source
    local ok, Player = IsOwner(src, companyId)
    if not ok then return end

    local emp = DB.GetEmployeeById(companyId, tonumber(employeeId))
    if not emp or (DB.RejectEmployee(companyId, emp.id) or 0) < 1 then return end

    NotifyPlayer(src, locale('application_rejected'), 'inform')

    Webhook.SendFields('employees', 'Driver Application Rejected', {
        { 'Rejected By', GetPlayerFullName(Player) },
        { 'Company', CompanyLabel(companyId) },
        { 'Applicant', (emp.firstname or '') .. ' ' .. (emp.lastname or '') },
    }, 'warn')
end)

RegisterNetEvent('rsg-railroad:fireDriver', function(companyId, employeeId)
    local src = source
    local ok, Player = IsOwner(src, companyId)
    if not ok then return end

    local emp = DB.GetEmployeeById(companyId, tonumber(employeeId))
    if not emp or (DB.FireEmployee(companyId, emp.id) or 0) < 1 then return end

    local firedName = (emp.firstname or '') .. ' ' .. (emp.lastname or '')
    NotifyPlayer(src, locale('driver_fired', firedName), 'success')
    NotifyCitizen(emp.citizenid, companyId, locale('fired_notify'), 'error')

    Webhook.SendFields('employees', 'Driver Fired', {
        { 'Fired By', GetPlayerFullName(Player) },
        { 'Company', CompanyLabel(companyId) },
        { 'Driver', firedName },
    }, 'error')
end)
