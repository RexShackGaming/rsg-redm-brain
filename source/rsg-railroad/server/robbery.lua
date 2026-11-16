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
local lastCompanyRobbery = {} -- [companyId] = os.time()

-- The robbery events have no legitimate sender while the feature is off
-- (Config.TrainRobbery.Enabled = false), so they are ignored entirely.
local function RobberyEnabled()
    return Config.TrainRobbery and Config.TrainRobbery.Enabled
end

-- A robbery must be announced (and pass server checks) before it can pay out
-- or be defeated, and each announcement resolves at most once.
local sessions = {}   -- [source] = { companyId, startedAt }
local lastStartAt = {}

local function TakeSession(src, companyId)
    local s = sessions[src]
    if not s or s.companyId ~= companyId then return false end
    local cfg = Config.TrainRobbery or {}
    if (os.time() - s.startedAt) < (cfg.MinSeconds or 10) then return false end
    sessions[src] = nil
    return true
end

function ClearRobberySession(src) sessions[src] = nil end

RegisterNetEvent('rsg-railroad:robberyStarted', function(companyId)
    local src = source
    if not RobberyEnabled() then return end
    if type(companyId) ~= 'string' then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not HasActiveTrain(src) then return end
    if not GetCompanyRole(companyId, Player.PlayerData.citizenid) then return end

    local cfg = Config.TrainRobbery
    local now = os.time()
    if lastStartAt[src] and (now - lastStartAt[src]) < (cfg.StartCooldown or 120) then return end

    -- Robberies never happen inside the station safe zone
    local pc = GetPlayerCoordsServer(src)
    if not pc then return end
    for _, st in ipairs(Config.Stations) do
        if #(vector3(pc.x, pc.y, 0.0) - vector3(st.coords.x, st.coords.y, 0.0)) < (cfg.SafeZoneRadius or 500.0) then return end
    end

    lastStartAt[src] = now
    sessions[src] = { companyId = companyId, startedAt = now }
end)

RegisterNetEvent('rsg-railroad:robberyOccurred', function(companyId)
    local src = source
    if not RobberyEnabled() then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastRobberyAt[src] and (now - lastRobberyAt[src]) < ROBBERY_COOLDOWN_MS then return end
    lastRobberyAt[src] = now
    if not TakeSession(src, companyId) then return end

    -- Only the owner or an approved driver who actually has a train out can
    -- report a robbery against this company.
    local role, ownership = GetCompanyRole(companyId, Player.PlayerData.citizenid)
    if not role or not HasActiveTrain(src) then return end

    -- Per-company cooldown: several drivers can no longer stack robberies on one register.
    local cfg = Config.TrainRobbery or {}
    local nowS = os.time()
    if lastCompanyRobbery[companyId] and (nowS - lastCompanyRobbery[companyId]) < (cfg.CompanyCooldown or 600) then return end

    local balance = tonumber(ownership.cash_register) or 0
    if balance <= 0 then return end

    local percent = cfg.RobberyTakePercent or 0.20
    local take = math.floor(balance * percent)
    take = math.max(cfg.RobberyTakeMin or 0, take)
    take = math.min(take, balance, cfg.RobberyTakeMax or take)

    if take <= 0 then return end
    if (DB.WithdrawFromCashRegister(companyId, take) or 0) < 1 then return end
    lastCompanyRobbery[companyId] = nowS
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
        TriggerClientEvent('RSGCore:Client:Notify', ownerPlayer.PlayerData.source, {
            title       = companyLabel,
            description = locale('robbery_taken_notify', take),
            type        = 'error',
            duration    = 9000,
        })
    end
end)

RegisterNetEvent('rsg-railroad:robberyDefeated', function(companyId)
    local src = source
    if not RobberyEnabled() then return end
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
    if not TakeSession(src, companyId) then return end

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
    sessions[src] = nil
    lastStartAt[src] = nil
end)
