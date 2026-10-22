local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- TRAIN ROBBERY CONSEQUENCES
-- robberyOccurred: outlaws took a cut of the company cash register.
-- robberyDefeated: the driver fought them off and earns company XP.
---------------------------------------------------------------

-- Basic anti-spam: a client could otherwise fire robberyOccurred
-- repeatedly by hand to keep draining a company's register.
local ROBBERY_COOLDOWN_MS = 20000
local lastRobberyAt = {} -- [source] = GetGameTimer()
local lastDefeatAt  = {} -- [source] = GetGameTimer()

RegisterNetEvent('rsg-railroad:robberyOccurred', function(companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastRobberyAt[src] and (now - lastRobberyAt[src]) < ROBBERY_COOLDOWN_MS then return end
    lastRobberyAt[src] = now

    -- Only the owner or an approved driver who actually has a train out can
    -- report a robbery against this company.
    local role, ownership = GetCompanyRole(companyId, Player.PlayerData.citizenid)
    if not role or not HasActiveTrain(src) then return end

    local cfg = Config.TrainRobbery or {}
    local balance = tonumber(ownership.cash_register) or 0
    if balance <= 0 then return end

    local percent = cfg.RobberyTakePercent or 0.20
    local take = math.floor(balance * percent)
    take = math.max(cfg.RobberyTakeMin or 0, take)
    take = math.min(take, balance, cfg.RobberyTakeMax or take)

    if take <= 0 then return end
    if (DB.WithdrawFromCashRegister(companyId, take) or 0) < 1 then return end
    print('[rsg-railroad] Train robbery: ' .. companyId .. ' lost $' .. take .. ' from cash register')

    Webhook.SendFields('robbery', 'Train Robbed', {
        { 'Company', CompanyLabel(companyId) },
        { 'Amount Taken', '$' .. take },
        { 'Register Balance After', '$' .. (balance - take) },
    }, 'error')

    -- Let the owner know if they're online
    local ownerPlayer = RSGCore.Functions.GetPlayerByCitizenId(ownership.owner_citizenid)
    if ownerPlayer then
        local companyLabel = CompanyLabel(companyId)
        TriggerClientEvent('ox_lib:notify', ownerPlayer.PlayerData.source, {
            title       = companyLabel,
            description = locale('robbery_taken_notify', take),
            type        = 'error',
            duration    = 9000,
        })
    end
end)

RegisterNetEvent('rsg-railroad:robberyDefeated', function(companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Rate-limit + require a real tie to the company and a train out, so the
    -- event can't be spammed for free XP.
    local now = GetGameTimer()
    local cooldown = math.max(ROBBERY_COOLDOWN_MS, (Config.TrainRobbery and Config.TrainRobbery.Cooldown or 0) * 1000)
    if lastDefeatAt[src] and (now - lastDefeatAt[src]) < cooldown then return end

    local citizenid = Player.PlayerData.citizenid
    if not GetCompanyRole(companyId, citizenid) or not HasActiveTrain(src) then return end
    lastDefeatAt[src] = now

    -- No cash reward for winning (avoids a "start robbery, win it" money
    -- loop) -- award a small amount of company XP instead.
    local xp = (Config.TrainRobbery and Config.TrainRobbery.DefeatXP) or 10
    AddCompanyXP(src, citizenid, companyId, xp)

    Webhook.SendFields('robbery', 'Outlaws Defeated', {
        { 'Player', GetPlayerFullName(Player) },
        { 'Company', CompanyLabel(companyId) },
        { 'XP Awarded', xp },
    }, 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastRobberyAt[src] = nil
    lastDefeatAt[src] = nil
end)
